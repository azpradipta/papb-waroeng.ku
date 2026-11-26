-- Jalankan setelah 202611200002_account_deletion_requests.sql.
-- Permintaan lama tetap manual sampai pemilik akun mengonfirmasi ulang password.
begin;

alter table public.account_deletion_requests
  add column if not exists automated_confirmed_at timestamptz,
  add column if not exists worker_lease_id uuid,
  add column if not exists worker_lease_until timestamptz,
  add column if not exists worker_attempts integer not null default 0,
  add column if not exists next_attempt_at timestamptz,
  add column if not exists worker_last_error text;
create index if not exists account_deletion_requests_worker_idx
  on public.account_deletion_requests(next_attempt_at, requested_at)
  where automated_confirmed_at is not null and status in ('pending','processing');

-- Hanya Edge Function yang sudah memverifikasi JWT + password boleh memanggil.
create or replace function public.authorize_automatic_account_deletion(p_user_id uuid, p_confirm boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request jsonb;
begin
  if p_confirm is distinct from true then raise exception 'Konfirmasi penghapusan diperlukan.'; end if;
  v_request := wk_private.enqueue_account_deletion(p_user_id);
  update public.account_deletion_requests
    set automated_confirmed_at = coalesce(automated_confirmed_at, clock_timestamp()),
        next_attempt_at = coalesce(next_attempt_at, clock_timestamp())
    where id = (v_request->>'id')::uuid and status in ('pending','processing');
  return jsonb_build_object('id',v_request->'id','status',v_request->'status',
    'requested_at',v_request->'requested_at');
end;
$$;

-- SKIP LOCKED dan lease unik mencegah dua worker mengambil antrean yang sama.
create or replace function public.claim_automatic_account_deletions(
  p_limit integer default 3, p_request_id uuid default null)
returns setof jsonb language plpgsql security definer set search_path = '' as $$
begin
  return query
  with candidates as (
    select r.id from public.account_deletion_requests r
    where r.automated_confirmed_at is not null
      and r.status in ('pending','processing')
      and (p_request_id is null or r.id = p_request_id)
      and coalesce(r.next_attempt_at,r.requested_at) <= clock_timestamp()
      and (r.worker_lease_until is null or r.worker_lease_until <= clock_timestamp())
    order by coalesce(r.next_attempt_at,r.requested_at),r.requested_at,r.id
    limit greatest(1,least(coalesce(p_limit,3),3)) for update skip locked
  ), claimed as (
    update public.account_deletion_requests r
    set worker_lease_id = gen_random_uuid(),
        worker_lease_until = clock_timestamp() + interval '2 minutes',
        worker_attempts = worker_attempts + 1, worker_last_error = null
    from candidates c where r.id = c.id
    returning r.id,r.worker_lease_id
  ) select jsonb_build_object('request_id',id,'lease_id',worker_lease_id) from claimed;
end;
$$;

create or replace function wk_private.require_deletion_lease(p_request_id uuid,p_lease_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_store uuid;
begin
  select store_id into v_store from public.account_deletion_requests where id = p_request_id;
  if v_store is not null then
    perform pg_advisory_xact_lock(hashtextextended('delete_store:' || v_store::text,0));
  end if;
  perform 1 from public.account_deletion_requests r where r.id = p_request_id
    and r.automated_confirmed_at is not null and r.status in ('pending','processing')
    and r.worker_lease_id = p_lease_id and r.worker_lease_until > clock_timestamp()
    for update;
  if not found then raise exception 'Lease penghapusan tidak berlaku.'; end if;
end;
$$;

create or replace function public.prepare_automatic_account_deletion(p_request_id uuid,p_lease_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_prepared jsonb; v_ids uuid[]; v_remaining integer;
begin
  perform wk_private.require_deletion_lease(p_request_id,p_lease_id);
  v_prepared := public.prepare_account_deletion(p_request_id,true);
  -- Array asli tidak diubah: retry tetap mengetahui semua Auth UID walau profil hilang.
  select count(*)::integer into v_remaining from auth.users u
    where u.id in (select jsonb_array_elements_text(v_prepared->'auth_user_ids')::uuid);
  select coalesce(array_agg(id order by id),'{}'::uuid[]) into v_ids from (
    select u.id from auth.users u
    where u.id in (select jsonb_array_elements_text(v_prepared->'auth_user_ids')::uuid)
    order by u.id limit 20
  ) remaining;
  return jsonb_build_object('request_id',p_request_id,'status',v_prepared->'status',
    'auth_user_ids',v_ids,'remaining_count',v_remaining);
end;
$$;

create or replace function public.complete_automatic_account_deletion(p_request_id uuid,p_lease_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  perform wk_private.require_deletion_lease(p_request_id,p_lease_id);
  v_result := public.complete_account_deletion(p_request_id);
  update public.account_deletion_requests set worker_lease_id = null,
    worker_lease_until = null,next_attempt_at = null,worker_last_error = null
    where status = 'completed' and worker_lease_id is not null;
  return v_result;
end;
$$;

create or replace function public.retry_automatic_account_deletion(p_request_id uuid,p_lease_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  -- Pemegang lease lama tidak boleh melepas lease worker baru.
  update public.account_deletion_requests set worker_lease_id = null,worker_lease_until = null,
    next_attempt_at = clock_timestamp() + make_interval(secs => least(3600,
      (30 * power(2,least(worker_attempts - 1,7)))::integer)),
    worker_last_error = 'Pemrosesan akan dicoba kembali secara otomatis.'
    where id = p_request_id and worker_lease_id = p_lease_id
      and automated_confirmed_at is not null and status in ('pending','processing');
  return found;
end;
$$;

revoke all on function wk_private.require_deletion_lease(uuid,uuid) from public,anon,authenticated;
revoke all on function public.authorize_automatic_account_deletion(uuid,boolean),
  public.claim_automatic_account_deletions(integer,uuid),
  public.prepare_automatic_account_deletion(uuid,uuid),
  public.complete_automatic_account_deletion(uuid,uuid),
  public.retry_automatic_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.authorize_automatic_account_deletion(uuid,boolean),
  public.claim_automatic_account_deletions(integer,uuid),
  public.prepare_automatic_account_deletion(uuid,uuid),
  public.complete_automatic_account_deletion(uuid,uuid),
  public.retry_automatic_account_deletion(uuid,uuid) to service_role;

comment on column public.account_deletion_requests.automated_confirmed_at is
  'NULL berarti tetap manual. Hanya backend setelah memverifikasi ulang password boleh mengaktifkan otomatisasi.';
notify pgrst, 'reload schema';
commit;
