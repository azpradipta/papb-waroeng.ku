-- Jalankan setelah 202611170001_complete_shop.sql. Data lama tidak dihapus.
begin;

create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid unique references auth.users(id) on delete restrict,
  name text not null check (length(btrim(name)) between 1 and 100),
  address text not null default '' check (length(address) <= 300),
  phone text not null default '' check (length(phone) <= 30),
  created_at timestamptz not null default now()
);
alter table public.profiles add column if not exists store_id uuid references public.stores(id);
alter table public.profiles add column if not exists is_active boolean not null default true;
alter table public.products add column if not exists store_id uuid references public.stores(id);
alter table public.transactions add column if not exists store_id uuid references public.stores(id);

-- Database versi lama berisi satu warung. Jangan menebak pembagian jika ada
-- beberapa Pemilik; pengelola harus menentukan pemilik data lama terlebih dulu.
do $$
declare v_owner uuid; v_store uuid; v_name text; v_owners integer;
begin
  if exists(select 1 from public.profiles where store_id is null)
    or exists(select 1 from public.products where store_id is null)
    or exists(select 1 from public.transactions where store_id is null) then
    select count(*) into v_owners from public.profiles where role = 'Pemilik' and store_id is null;
    if v_owners > 1 then
      raise exception 'Data lama memiliki beberapa Pemilik. Tentukan satu Pemilik data lama sebelum menjalankan migrasi toko.';
    end if;
    select id, full_name into v_owner, v_name from public.profiles
      where role = 'Pemilik' and store_id is null limit 1;
    insert into public.stores(owner_id, name)
      values(v_owner, left(coalesce('Toko ' || v_name, 'Toko Lama'), 100)) returning id into v_store;
    update public.profiles set store_id = v_store where store_id is null;
    update public.products set store_id = v_store where store_id is null;
    update public.transactions set store_id = v_store where store_id is null;
  end if;
end;
$$;
alter table public.profiles alter column store_id set not null;
alter table public.products alter column store_id set not null;
alter table public.transactions alter column store_id set not null;
create index if not exists products_store_name_idx on public.products(store_id, name, id);
create index if not exists transactions_store_date_idx on public.transactions(store_id, created_at desc, id);
create index if not exists profiles_store_idx on public.profiles(store_id);
alter table public.stores enable row level security;
revoke all on public.stores from public, anon, authenticated;

-- Hanya app_metadata yang ditulis Auth Admin boleh menandai pembuatan Kasir.
-- Metadata dari form daftar tidak pernah dipakai untuk memilih peran/toko lama.
create or replace function wk_private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_store uuid; v_name text; v_store_name text; v_role text := 'Pemilik';
begin
  v_name := left(coalesce(nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(split_part(new.email, '@', 1), ''), 'Pengguna'), 100);
  if new.raw_app_meta_data->>'wk_cashier_store_id' is not null then
    v_store := (new.raw_app_meta_data->>'wk_cashier_store_id')::uuid;
    if not exists(select 1 from public.stores where id = v_store and owner_id is not null) then
      raise exception 'Toko tujuan tidak tersedia.';
    end if;
    v_role := 'Kasir';
  else
    v_store_name := btrim(coalesce(new.raw_user_meta_data->>'store_name', ''));
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

create or replace function wk_private.require_user(p_owner boolean default false)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := auth.uid(); v_profile public.profiles%rowtype; v_owner uuid;
begin
  select * into v_profile from public.profiles where id = v_id;
  if v_id is null or v_profile.id is null then
    raise exception using errcode = '42501', message = 'Silakan masuk terlebih dahulu.';
  end if;
  if not v_profile.is_active then
    raise exception using errcode = 'P0001', message = 'Akun Kasir sudah dinonaktifkan. Hubungi Pemilik toko.';
  end if;
  select owner_id into v_owner from public.stores where id = v_profile.store_id;
  if v_owner is null then
    raise exception using errcode = 'P0001', message = 'Toko lama belum dihubungkan ke Pemilik. Hubungi pengelola aplikasi.';
  end if;
  if v_profile.role not in ('Pemilik', 'Kasir')
    or (v_profile.role = 'Pemilik' and v_owner <> v_id)
    or (p_owner and v_profile.role <> 'Pemilik') then
    raise exception using errcode = '42501', message = 'Fitur ini hanya untuk Pemilik.';
  end if;
  return v_id;
end;
$$;

create or replace function wk_private.current_store()
returns uuid language plpgsql stable security definer set search_path = '' as $$
begin
  perform wk_private.require_user();
  return (select store_id from public.profiles where id = auth.uid());
end;
$$;

create or replace function public.get_my_profile()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform wk_private.require_user();
  return (select to_jsonb(p) || jsonb_build_object('store_name', s.name)
    from public.profiles p join public.stores s on s.id = p.store_id where p.id = auth.uid());
end;
$$;

create or replace function public.get_store()
returns jsonb language sql stable security definer set search_path = '' as $$
  select to_jsonb(s) from public.stores s where s.id = wk_private.current_store();
$$;

create or replace function public.update_store(p_name text, p_address text, p_phone text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_store public.stores%rowtype;
begin
  perform wk_private.require_user(true);
  if p_name is null or length(btrim(p_name)) not between 1 and 100
    or length(coalesce(p_address, '')) > 300 or length(coalesce(p_phone, '')) > 30 then
    raise exception using errcode = 'P0001', message = 'Nama, alamat, atau nomor telepon toko tidak valid.';
  end if;
  update public.stores set name = btrim(p_name), address = btrim(coalesce(p_address, '')),
    phone = btrim(coalesce(p_phone, '')) where id = wk_private.current_store() returning * into v_store;
  return to_jsonb(v_store);
end;
$$;

create or replace function public.get_cashier(p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
  perform wk_private.require_user(true);
  select to_jsonb(p) || jsonb_build_object('email', u.email) into v_result
    from public.profiles p join auth.users u on u.id = p.id
    where p.id = p_id and p.role = 'Kasir' and p.store_id = wk_private.current_store();
  if v_result is null then raise exception using errcode = 'P0001', message = 'Akun Kasir tidak ditemukan.'; end if;
  return v_result;
end;
$$;

create or replace function public.list_cashiers()
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform wk_private.require_user(true);
  return query select to_jsonb(p) || jsonb_build_object('email', u.email)
    from public.profiles p join auth.users u on u.id = p.id
    where p.store_id = wk_private.current_store() and p.role = 'Kasir'
    order by p.is_active desc, p.full_name, p.id;
end;
$$;

create or replace function public.update_cashier(p_id uuid, p_name text, p_active boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  perform public.get_cashier(p_id);
  if p_name is null or length(btrim(p_name)) not between 1 and 100 or p_active is null then
    raise exception using errcode = 'P0001', message = 'Nama atau status Kasir tidak valid.';
  end if;
  update public.profiles set full_name = btrim(p_name), is_active = p_active
    where id = p_id and role = 'Kasir' and store_id = wk_private.current_store();
  return public.get_cashier(p_id);
end;
$$;

create or replace function public.get_products(p_offset integer default 0)
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_owner boolean; v_store uuid := wk_private.current_store();
begin
  select role = 'Pemilik' into v_owner from public.profiles where id = auth.uid();
  return query select to_jsonb(p) || jsonb_build_object(
    'cost_price', case when v_owner then p.cost_price else 0 end)
    from public.products p where p.store_id = v_store
    order by p.name, p.id limit 200 offset greatest(p_offset, 0);
end;
$$;

create or replace function public.create_product(p_name text, p_cost integer,
  p_price integer, p_stock integer, p_unit text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_product public.products%rowtype;
begin
  perform wk_private.require_user(true);
  perform wk_private.validate_product(p_name, p_cost, p_price, p_unit);
  if p_stock is null or p_stock < 0 then
    raise exception using errcode = 'P0001', message = 'Stok awal tidak valid.';
  end if;
  insert into public.products(name, cost_price, selling_price, stock, unit, store_id)
    values(btrim(p_name), p_cost, p_price, p_stock, btrim(p_unit), wk_private.current_store()) returning * into v_product;
  return to_jsonb(v_product);
end;
$$;

create or replace function public.update_product(p_id bigint, p_name text,
  p_cost integer, p_price integer, p_unit text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_product public.products%rowtype;
begin
  perform wk_private.require_user(true);
  perform wk_private.validate_product(p_name, p_cost, p_price, p_unit);
  update public.products set name = btrim(p_name), cost_price = p_cost,
    selling_price = p_price, unit = btrim(p_unit)
    where id = p_id and store_id = wk_private.current_store() returning * into v_product;
  if not found then raise exception using errcode = 'P0001', message = 'Produk tidak ditemukan di toko ini.'; end if;
  return to_jsonb(v_product);
end;
$$;

create or replace function public.add_product_stock(p_product_id bigint, p_quantity integer)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_product public.products%rowtype;
begin
  perform wk_private.require_user(true);
  if p_quantity is null or p_quantity <= 0 then
    raise exception using errcode = 'P0001', message = 'Jumlah stok harus lebih dari 0.';
  end if;
  update public.products set stock = stock + p_quantity
    where id = p_product_id and store_id = wk_private.current_store() returning * into v_product;
  if not found then raise exception using errcode = 'P0001', message = 'Produk tidak ditemukan di toko ini.'; end if;
  return to_jsonb(v_product);
end;
$$;

create or replace function public.delete_product(p_id bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform wk_private.require_user(true);
  delete from public.products where id = p_id and store_id = wk_private.current_store();
  if not found then raise exception using errcode = 'P0001', message = 'Produk tidak ditemukan di toko ini.'; end if;
end;
$$;

create or replace function wk_private.transaction_json(p_id uuid, p_detail boolean default true)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_owner boolean; v_result jsonb;
begin
  perform wk_private.require_user();
  select role = 'Pemilik' into v_owner from public.profiles where id = auth.uid();
  select jsonb_build_object(
    'id', t.id, 'invoice_code', t.invoice_code, 'created_at', t.created_at,
    'cashier_name', p.full_name, 'store_name', s.name, 'total_price', t.total_price,
    'cash_paid', t.cash_paid, 'change_paid', t.change_paid
  ) || case when v_owner then jsonb_build_object('total_profit', t.total_profit) else '{}'::jsonb end
  || case when p_detail then jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'product_id', i.product_id, 'product_name', i.product_name,
      'selling_price', i.selling_price, 'qty', i.qty, 'subtotal', i.subtotal
    ) || case when v_owner then jsonb_build_object(
      'cost_price', i.cost_price, 'profit', i.profit) else '{}'::jsonb end order by i.id)
    from public.transaction_items i where i.transaction_id = t.id
  ), '[]'::jsonb)) else '{}'::jsonb end into v_result
  from public.transactions t join public.profiles p on p.id = t.created_by
    join public.stores s on s.id = t.store_id
    where t.id = p_id and t.store_id = wk_private.current_store();
  if v_result is null then raise exception using errcode = 'P0001', message = 'Transaksi tidak ditemukan.'; end if;
  return v_result;
end;
$$;

create or replace function public.get_transaction(p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select wk_private.transaction_json(p_id);
$$;

create or replace function public.list_transactions(p_search text default '',
  p_from timestamptz default null, p_until timestamptz default null, p_offset integer default 0)
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform wk_private.require_user();
  return query select wk_private.transaction_json(t.id, false)
  from public.transactions t join public.profiles p on p.id = t.created_by
  where t.store_id = wk_private.current_store() and (p_from is null or t.created_at >= p_from)
    and (p_until is null or t.created_at < p_until)
    and (coalesce(p_search, '') = '' or strpos(lower(t.invoice_code || ' ' || p.full_name), lower(p_search)) > 0)
  order by t.created_at desc, t.id desc limit 50 offset greatest(p_offset, 0);
end;
$$;

-- Satu RPC = satu transaksi database. Error apa pun membatalkan nota, item, dan stok.
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
  -- Retry setelah respons jaringan hilang mengembalikan nota yang sama.
  perform pg_advisory_xact_lock(hashtextextended(p_request_id::text, 0));
  select * into v_existing from public.transactions where id = p_request_id;
  if found then
    if v_existing.created_by <> v_user or v_existing.store_id <> v_store then
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

  -- Urutan ID yang sama pada semua checkout mencegah deadlock antar keranjang.
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
  if p_cash < v_total then
    raise exception using errcode = 'P0001', message = 'Uang yang diterima kurang.';
  end if;
  update public.transactions set total_price = v_total, total_profit = v_profit,
    change_paid = p_cash - v_total where id = p_request_id;
  return wk_private.transaction_json(p_request_id);
end;
$$;

create or replace function public.get_report(p_from timestamptz default null, p_until timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_report jsonb;
begin
  perform wk_private.require_user(true);
  select jsonb_build_object(
    'transaction_count', count(*), 'total_sales', coalesce(sum(t.total_price), 0),
    'total_profit', coalesce(sum(t.total_profit), 0),
    'item_count', (select coalesce(sum(i.qty), 0) from public.transaction_items i
      join public.transactions tx on tx.id = i.transaction_id
      where tx.store_id = wk_private.current_store() and (p_from is null or tx.created_at >= p_from) and (p_until is null or tx.created_at < p_until))
  ) into v_report from public.transactions t
  where t.store_id = wk_private.current_store() and (p_from is null or t.created_at >= p_from) and (p_until is null or t.created_at < p_until);
  return v_report;
end;
$$;


-- Hak akses fungsi baru selalu ditetapkan secara eksplisit.
revoke all on all functions in schema wk_private from public, anon, authenticated;
revoke all on function public.get_my_profile(), public.get_store(),
  public.update_store(text,text,text), public.get_cashier(uuid), public.list_cashiers(),
  public.update_cashier(uuid,text,boolean) from public, anon, authenticated;
grant execute on function public.get_my_profile(), public.get_store(),
  public.update_store(text,text,text), public.get_cashier(uuid), public.list_cashiers(),
  public.update_cashier(uuid,text,boolean) to authenticated;
notify pgrst, 'reload schema';
commit;
