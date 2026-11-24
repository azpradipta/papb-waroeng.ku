-- Antrean permintaan hapus akun; pengiriman bukan penghapusan langsung.
-- Jalankan setelah 202611200001_cashier_auth_trigger.sql.
begin;

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  store_id uuid references public.stores(id) on delete set null,
  user_role text not null check (user_role in ('Pemilik', 'Kasir')),
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed')),
  requested_at timestamptz not null default now(),
  processing_at timestamptz,
  completed_at timestamptz,
  auth_user_ids uuid[] not null default '{}',
  check ((status = 'pending' and processing_at is null and completed_at is null)
    or (status = 'processing' and processing_at is not null and completed_at is null)
    or (status = 'completed' and processing_at is not null and completed_at is not null))
);
create unique index if not exists account_deletion_requests_open_user_idx
  on public.account_deletion_requests(user_id) where status in ('pending', 'processing');
create index if not exists account_deletion_requests_user_date_idx
  on public.account_deletion_requests(user_id, requested_at desc, id desc);

alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from public, anon, authenticated;
grant select, update, delete on public.account_deletion_requests to service_role;

-- Tidak memakai require_user(): Kasir yang dinonaktifkan tetap boleh meminta
-- penghapusan akunnya. UID, toko, dan peran selalu dibaca dari server.
create or replace function wk_private.enqueue_account_deletion(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := p_user_id;
  v_profile public.profiles%rowtype;
  v_request public.account_deletion_requests%rowtype;
begin
  if v_user is null or not exists(select 1 from auth.users where id = v_user) then
    raise exception using errcode = '42501', message = 'Silakan masuk terlebih dahulu.';
  end if;
  select * into v_request from public.account_deletion_requests
    where user_id = v_user and status in ('pending', 'processing');
  if found then
    return jsonb_build_object('id', v_request.id, 'status', v_request.status,
      'requested_at', v_request.requested_at, 'completed_at', v_request.completed_at);
  end if;
  select * into v_profile from public.profiles where id = v_user;
  if not found then
    raise exception using errcode = 'P0001', message = 'Profil akun tidak ditemukan. Hubungi pengelola aplikasi.';
  end if;

  insert into public.account_deletion_requests(user_id, store_id, user_role)
    values(v_user, v_profile.store_id, v_profile.role)
    on conflict(user_id) where status in ('pending', 'processing')
    -- Retry jaringan mengembalikan permintaan yang sama, tanpa mengubah tanggal.
    do update set user_id = excluded.user_id
    returning * into v_request;
  return jsonb_build_object('id', v_request.id, 'status', v_request.status,
    'requested_at', v_request.requested_at, 'completed_at', v_request.completed_at);
end;
$$;

create or replace function public.request_account_deletion(p_confirm boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_confirm is distinct from true then
    raise exception using errcode = 'P0001', message = 'Konfirmasi permintaan hapus akun terlebih dahulu.';
  end if;
  return wk_private.enqueue_account_deletion(auth.uid());
end;
$$;

-- Jalur email untuk pengguna yang tidak bisa masuk: hanya pengelola yang telah
-- memverifikasi identitas/kepemilikan email boleh membuat antrean atas UID ini.
create or replace function public.request_account_deletion_for_user(p_user_id uuid, p_confirm boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if p_confirm is distinct from true then
    raise exception 'Konfirmasi identitas pemohon terlebih dahulu.';
  end if;
  return wk_private.enqueue_account_deletion(p_user_id);
end;
$$;

create or replace function public.get_my_account_deletion_request()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_result jsonb;
begin
  if v_user is null or not exists(select 1 from auth.users where id = v_user) then
    raise exception using errcode = '42501', message = 'Silakan masuk terlebih dahulu.';
  end if;
  select jsonb_build_object('id', r.id, 'status', r.status,
    'requested_at', r.requested_at, 'completed_at', r.completed_at)
    into v_result from public.account_deletion_requests r
    where r.user_id = v_user order by r.requested_at desc, r.id desc limit 1;
  return v_result;
end;
$$;

revoke all on function public.request_account_deletion(boolean),
  public.get_my_account_deletion_request() from public, anon, authenticated;
grant execute on function public.request_account_deletion(boolean),
  public.get_my_account_deletion_request() to authenticated;

-- Nota bukan identitas akun: menghapus Kasir mempertahankan angka penjualan,
-- tetapi melepas hubungan/nama Kasir dari nota lama.
alter table public.transactions alter column created_by drop not null;
alter table public.transactions drop constraint if exists transactions_created_by_fkey;
alter table public.transactions add constraint transactions_created_by_fkey
  foreign key(created_by) references public.profiles(id) on delete set null;

create or replace function wk_private.transaction_json(p_id uuid, p_detail boolean default true)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_owner boolean; v_result jsonb;
begin
  perform wk_private.require_user();
  select role = 'Pemilik' into v_owner from public.profiles where id = auth.uid();
  select jsonb_build_object(
    'id', t.id, 'invoice_code', t.invoice_code, 'created_at', t.created_at,
    'cashier_name', coalesce(p.full_name, 'Kasir dihapus'), 'store_name', s.name,
    'total_price', t.total_price, 'cash_paid', t.cash_paid, 'change_paid', t.change_paid
  ) || case when v_owner then jsonb_build_object('total_profit', t.total_profit) else '{}'::jsonb end
  || case when p_detail then jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'product_id', i.product_id, 'product_name', i.product_name,
      'selling_price', i.selling_price, 'qty', i.qty, 'subtotal', i.subtotal
    ) || case when v_owner then jsonb_build_object(
      'cost_price', i.cost_price, 'profit', i.profit) else '{}'::jsonb end order by i.id)
    from public.transaction_items i where i.transaction_id = t.id
  ), '[]'::jsonb)) else '{}'::jsonb end into v_result
  from public.transactions t left join public.profiles p on p.id = t.created_by
    join public.stores s on s.id = t.store_id
    where t.id = p_id and t.store_id = wk_private.current_store();
  if v_result is null then raise exception using errcode = 'P0001', message = 'Transaksi tidak ditemukan.'; end if;
  return v_result;
end;
$$;

create or replace function public.list_transactions(p_search text default '',
  p_from timestamptz default null, p_until timestamptz default null, p_offset integer default 0)
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform wk_private.require_user();
  return query select wk_private.transaction_json(t.id, false)
    from public.transactions t left join public.profiles p on p.id = t.created_by
    where t.store_id = wk_private.current_store()
      and (p_from is null or t.created_at >= p_from) and (p_until is null or t.created_at < p_until)
      and (coalesce(p_search, '') = '' or strpos(lower(t.invoice_code || ' ' ||
        coalesce(p.full_name, 'Kasir dihapus')), lower(p_search)) > 0)
    order by t.created_at desc, t.id desc limit 50 offset greatest(p_offset, 0);
end;
$$;

-- ID nota anonim tetap tidak boleh diambil alih oleh checkout akun lain.
create or replace function public.checkout(p_request_id uuid, p_items jsonb,
  p_cash integer, p_expected_total integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid; v_store uuid; v_existing public.transactions%rowtype; v_item jsonb;
  v_product public.products%rowtype; v_qty integer; v_price integer;
  v_total bigint := 0; v_profit bigint := 0; v_invoice text;
begin
  v_user := wk_private.require_user();
  v_store := wk_private.current_store();
  if p_request_id is null then raise exception using errcode = 'P0001', message = 'ID permintaan wajib diisi.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into v_existing from public.transactions where id = p_request_id;
  if found then
    if v_existing.created_by is distinct from v_user or v_existing.store_id is distinct from v_store then
      raise exception using errcode = '42501', message = 'ID transaksi sudah digunakan.';
    end if;
    return wk_private.transaction_json(p_request_id);
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception using errcode = 'P0001', message = 'Keranjang tidak valid.';
  end if;
  if jsonb_array_length(p_items) not between 1 and 200
    or p_cash is null or p_cash < 0 or p_expected_total is null or p_expected_total < 0 then
    raise exception using errcode = 'P0001', message = 'Keranjang atau pembayaran tidak valid.';
  end if;
  for v_item in select value from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object'
      or coalesce(v_item->>'product_id', '') !~ '^[1-9][0-9]{0,17}$'
      or coalesce(v_item->>'qty', '') !~ '^[1-9][0-9]{0,6}$'
      or coalesce(v_item->>'expected_price', '') !~ '^[0-9]{1,10}$' then
      raise exception using errcode = 'P0001', message = 'Barang atau jumlah beli tidak valid.';
    end if;
  end loop;
  if (select count(distinct value->>'product_id') from jsonb_array_elements(p_items)) <> jsonb_array_length(p_items) then
    raise exception using errcode = 'P0001', message = 'Produk duplikat di keranjang.';
  end if;
  v_invoice := 'WK-' || lpad(nextval('wk_private.invoice_number')::text, 10, '0');
  insert into public.transactions(id, invoice_code, created_by, total_price, total_profit, cash_paid, change_paid, store_id)
    values (p_request_id, v_invoice, v_user, 0, 0, p_cash, p_cash, v_store);
  for v_item in select value from jsonb_array_elements(p_items) order by (value->>'product_id')::bigint
  loop
    v_qty := (v_item->>'qty')::integer;
    v_price := (v_item->>'expected_price')::integer;
    select * into v_product from public.products where id = (v_item->>'product_id')::bigint and store_id = v_store for update;
    if not found then raise exception using errcode = 'P0001', message = 'Produk sudah dihapus. Muat ulang keranjang.'; end if;
    if v_qty > 1000000 or v_product.stock < v_qty then
      raise exception using errcode = 'P0001', message = 'Stok ' || v_product.name || ' tidak mencukupi.';
    end if;
    if v_product.selling_price <> v_price then
      raise exception using errcode = 'P0001', message = 'Harga produk berubah. Muat ulang keranjang.';
    end if;
    v_total := v_total + v_product.selling_price::bigint * v_qty;
    v_profit := v_profit + (v_product.selling_price::bigint - v_product.cost_price) * v_qty;
    if v_total > 2147483647 or v_profit not between -2147483648 and 2147483647 then
      raise exception using errcode = 'P0001', message = 'Total transaksi melebihi batas nominal.';
    end if;
    insert into public.transaction_items(transaction_id, product_id, product_name,
      cost_price, selling_price, qty, subtotal, profit)
      values (p_request_id, v_product.id, v_product.name, v_product.cost_price,
        v_product.selling_price, v_qty, v_product.selling_price::bigint * v_qty,
        (v_product.selling_price::bigint - v_product.cost_price) * v_qty);
    update public.products set stock = stock - v_qty where id = v_product.id;
  end loop;
  if v_total <> p_expected_total then
    raise exception using errcode = 'P0001', message = 'Total berubah. Muat ulang keranjang.';
  end if;
  if p_cash < v_total then raise exception using errcode = 'P0001', message = 'Uang yang diterima kurang.'; end if;
  update public.transactions set total_price = v_total, total_profit = v_profit,
    change_paid = p_cash - v_total where id = p_request_id;
  return wk_private.transaction_json(p_request_id);
end;
$$;

-- Tiga RPC berikut hanya untuk alat pengelola dengan secret/service_role key.
-- Aplikasi Flutter tidak menerima key maupun hak execute fungsi ini.
create or replace function public.preview_account_deletion(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype; v_ids uuid[]; v_counts jsonb;
begin
  select * into v_request from public.account_deletion_requests where id = p_request_id;
  if not found then raise exception 'Permintaan hapus akun tidak ditemukan.'; end if;
  v_ids := v_request.auth_user_ids;
  if v_request.status = 'pending' then
    if v_request.user_role = 'Pemilik' then
      select coalesce(array_agg(id order by id), '{}'::uuid[]) into v_ids from (
        select id from public.profiles where store_id = v_request.store_id
        union select unnest(auth_user_ids) from public.account_deletion_requests
          where store_id = v_request.store_id and status = 'processing'
      ) affected;
    else v_ids := array[v_request.user_id]; end if;
  end if;
  select jsonb_build_object(
    'accounts', cardinality(v_ids),
    'auth_accounts_remaining', (select count(*) from auth.users where id = any(v_ids)),
    'products', case when v_request.user_role = 'Pemilik' then
      (select count(*) from public.products where store_id = v_request.store_id) else 0 end,
    'transactions', (select count(*) from public.transactions where
      (v_request.user_role = 'Pemilik' and store_id = v_request.store_id)
      or (v_request.user_role = 'Kasir' and created_by = v_request.user_id))
  ) into v_counts;
  return jsonb_build_object('request_id', v_request.id, 'status', v_request.status,
    'user_role', v_request.user_role, 'store_id', v_request.store_id,
    'store_name', (select name from public.stores where id = v_request.store_id),
    'scope', case when v_request.user_role = 'Pemilik' then 'store' else 'account' end,
    'data_prepared', v_request.status <> 'pending', 'counts', v_counts);
end;
$$;

create or replace function public.prepare_account_deletion(p_request_id uuid, p_confirm boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype; v_profile public.profiles%rowtype;
  v_store uuid; v_ids uuid[];
begin
  if p_confirm is distinct from true then raise exception 'Konfirmasi penghapusan administratif diperlukan.'; end if;
  select store_id into v_store from public.account_deletion_requests where id = p_request_id;
  -- Serialisasi penutupan toko dan penghapusan Kasir toko yang sama.
  if v_store is not null then
    perform pg_advisory_xact_lock(hashtextextended('delete_store:' || v_store::text, 0));
  end if;
  select * into v_request from public.account_deletion_requests where id = p_request_id for update;
  if not found then raise exception 'Permintaan hapus akun tidak ditemukan.'; end if;
  if v_request.status <> 'pending' then
    return jsonb_build_object('request_id', v_request.id, 'status', v_request.status,
      'auth_user_ids', v_request.auth_user_ids);
  end if;
  select * into v_profile from public.profiles where id = v_request.user_id for update;
  if not found or v_profile.role <> v_request.user_role or v_profile.store_id <> v_request.store_id then
    raise exception 'Identitas atau toko permintaan berubah. Tinjau secara manual.';
  end if;
  perform 1 from public.stores where id = v_profile.store_id for update;
  if v_profile.role = 'Pemilik' then
    if not exists(select 1 from public.stores where id = v_profile.store_id and owner_id = v_profile.id) then
      raise exception 'Kepemilikan toko tidak cocok. Penghapusan dibatalkan.';
    end if;
    select array_agg(id order by id) into v_ids from (
      select id from public.profiles where store_id = v_profile.store_id
      union select unnest(auth_user_ids) from public.account_deletion_requests
        where store_id = v_profile.store_id and status = 'processing'
    ) affected;
  else v_ids := array[v_profile.id]; end if;

  update public.account_deletion_requests set status = 'processing', processing_at = now(),
    auth_user_ids = v_ids where id = p_request_id;
  if v_profile.role = 'Pemilik' then
    -- Permintaan Kasir lain ikut tercakup oleh penutupan toko ini.
    update public.account_deletion_requests set status = 'processing', processing_at = now(),
      auth_user_ids = array[user_id] where id <> p_request_id and status = 'pending'
      and store_id = v_profile.store_id and user_id = any(v_ids);
    delete from public.transaction_items where transaction_id in
      (select id from public.transactions where store_id = v_profile.store_id);
    delete from public.transactions where store_id = v_profile.store_id;
    delete from public.products where store_id = v_profile.store_id;
    delete from public.profiles where store_id = v_profile.store_id;
    delete from public.stores where id = v_profile.store_id;
  else
    delete from public.profiles where id = v_profile.id;
  end if;
  -- Auth Admin masih harus menghapus semua UID ini. Array disimpan untuk retry
  -- setelah koneksi gagal; status belum boleh completed pada tahap ini.
  return jsonb_build_object('request_id', p_request_id, 'status', 'processing', 'auth_user_ids', v_ids);
end;
$$;

create or replace function public.complete_account_deletion(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_request public.account_deletion_requests%rowtype;
begin
  select * into v_request from public.account_deletion_requests where id = p_request_id for update;
  if not found then raise exception 'Permintaan hapus akun tidak ditemukan.'; end if;
  if v_request.status = 'completed' then
    return jsonb_build_object('request_id', v_request.id, 'status', 'completed', 'completed_at', v_request.completed_at);
  end if;
  if v_request.status <> 'processing' or cardinality(v_request.auth_user_ids) = 0 then
    raise exception 'Siapkan penghapusan data terlebih dahulu.';
  end if;
  if exists(select 1 from auth.users where id = any(v_request.auth_user_ids)) then
    raise exception 'Akun Auth belum seluruhnya dihapus. Lanjutkan proses Auth Admin.';
  end if;
  update public.account_deletion_requests r set status = 'completed', completed_at = now(),
    auth_user_ids = '{}'::uuid[], user_id = null, store_id = null
    where r.status = 'processing' and cardinality(r.auth_user_ids) > 0
      and r.auth_user_ids <@ v_request.auth_user_ids
      and not exists(select 1 from auth.users u where u.id = any(r.auth_user_ids));
  return jsonb_build_object('request_id', v_request.id, 'status', 'completed', 'completed_at', now());
end;
$$;

revoke all on function wk_private.transaction_json(uuid,boolean),
  wk_private.enqueue_account_deletion(uuid) from public, anon, authenticated;
revoke all on function public.request_account_deletion_for_user(uuid,boolean), public.preview_account_deletion(uuid),
  public.prepare_account_deletion(uuid,boolean), public.complete_account_deletion(uuid)
  from public, anon, authenticated;
grant execute on function public.request_account_deletion_for_user(uuid,boolean), public.preview_account_deletion(uuid),
  public.prepare_account_deletion(uuid,boolean), public.complete_account_deletion(uuid) to service_role;

comment on table public.account_deletion_requests is
  'Antrean privat pengelola. pending belum menghapus data; processing menunggu Auth Admin; completed hanya setelah semua akun Auth terkait dihapus.';

notify pgrst, 'reload schema';
commit;
