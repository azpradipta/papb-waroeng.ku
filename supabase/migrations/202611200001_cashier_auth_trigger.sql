-- Auth Admin memasukkan user sebelum menulis app_metadata kustom.
-- Jalankan profil saat transaksi Auth selesai dan baca metadata baris terbaru.
-- Rujukan: supabase/auth v2.180.0 internal/api/admin.go (adminUserCreate).
begin;

create or replace function wk_private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_store uuid;
  v_name text;
  v_store_name text;
  v_role text := 'Pemilik';
  v_email text;
  v_user_meta jsonb;
  v_app_meta jsonb;
begin
  -- NEW tetap berisi snapshot INSERT, termasuk pada trigger yang ditunda.
  select email, raw_user_meta_data, raw_app_meta_data
    into v_email, v_user_meta, v_app_meta
    from auth.users where id = new.id;
  if not found then return new; end if;

  v_name := left(coalesce(nullif(btrim(v_user_meta->>'full_name'), ''),
    nullif(split_part(v_email, '@', 1), ''), 'Pengguna'), 100);
  if v_app_meta->>'wk_cashier_store_id' is not null then
    v_store := (v_app_meta->>'wk_cashier_store_id')::uuid;
    if not exists(select 1 from public.stores where id = v_store and owner_id is not null) then
      raise exception 'Toko tujuan tidak tersedia.';
    end if;
    v_role := 'Kasir';
  else
    v_store_name := btrim(coalesce(v_user_meta->>'store_name', ''));
    if length(v_store_name) not between 1 and 100 then
      raise exception 'Nama toko wajib diisi, maksimal 100 karakter.';
    end if;
    insert into public.stores(owner_id, name) values(new.id, v_store_name) returning id into v_store;
  end if;
  insert into public.profiles(id, full_name, role, store_id)
    values(new.id, v_name, v_role, v_store);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create constraint trigger on_auth_user_created
  after insert on auth.users
  deferrable initially deferred
  for each row execute function wk_private.handle_new_user();

commit;
