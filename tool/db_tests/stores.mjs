import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const owner = randomUUID(), cashier = randomUUID(), otherOwner = randomUUID(), newCashier = randomUUID();
const query = async (sql, args = []) => (await db.query(sql, args)).rows;
const rpc = async (sql, args = []) => (await query(sql, args))[0].result;
const admin = () => db.exec('reset role');
async function user(id, role = 'authenticated') {
  await admin();
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id ?? '']);
  await db.exec(`set role ${role}`);
}
let count = 0;
async function test(name, action) { await action(); console.log(`ok ${++count} - ${name}`); }
async function addUser(id, email, metadata, app = {}) {
  await admin();
  await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)', [id,email,metadata,app]);
}
async function addAdminUser(id, email, metadata, app) {
  await admin();
  await db.exec('begin');
  try {
    // Auth inserts provider metadata first, then updates custom app_metadata.
    // https://github.com/supabase/auth/blob/v2.180.0/internal/api/admin.go#L380-L445
    await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)',
      [id,email,metadata,{provider:'email',providers:['email']}]);
    await query('update auth.users set raw_app_meta_data = raw_app_meta_data || $1 where id = $2', [app,id]);
    await db.exec('commit');
  } catch (error) {
    await db.exec('rollback');
    throw error;
  }
}
const base = await readFile(new URL('../../supabase/migrations/202611170001_complete_shop.sql', import.meta.url), 'utf8');
const migration = await readFile(new URL('../../supabase/migrations/202611180001_stores_and_accounts.sql', import.meta.url), 'utf8');
const cashierTrigger = await readFile(new URL('../../supabase/migrations/202611200001_cashier_auth_trigger.sql', import.meta.url), 'utf8');
try {
  await db.exec(`create role anon nologin; create role authenticated nologin;
    create schema auth;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',raw_app_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid; $$;
    grant usage on schema public,auth to anon,authenticated;`);
  await db.exec(base);
  await addUser(owner,'owner@example.com',{full_name:'Pemilik Lama'});
  await addUser(cashier,'cashier@example.com',{full_name:'Kasir Lama'});
  await query("update profiles set role='Pemilik' where id=$1",[owner]);
  await user(owner);
  const product = await rpc("select create_product('Produk Lama',100,200,10,'pcs') result");
  const saleId = randomUUID();
  await rpc('select checkout($1,$2,200,200) result',[saleId,[{product_id:product.id,qty:1,expected_price:200}]]);
  await admin();
  await test('upgrade dan pengulangan migrasi mempertahankan toko, produk, nota, dan profil lama', async () => {
    await db.exec(migration);
    await db.exec(migration);
    await db.exec(cashierTrigger);
    await db.exec(cashierTrigger);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,1);
    assert.equal((await query('select stock from products where id=$1',[product.id]))[0].stock,9);
    assert.equal((await query('select count(*)::int n from transactions'))[0].n,1);
  });
  const store = (await query('select store_id from profiles where id=$1',[owner]))[0].store_id;
  await test('migrasi dasar ditolak setelah upgrade agar akses toko tidak ditimpa', async () => {
    await assert.rejects(() => db.exec(base), /Skema toko sudah aktif/);
    await db.exec('rollback');
    assert.equal((await query('select store_id from profiles where id=$1',[owner]))[0].store_id,store);
  });
  await test('register publik membuat Pemilik dan toko baru; metadata tidak memilih toko lama', async () => {
    await addUser(otherOwner,'other@example.com',{full_name:'Pemilik Kedua',store_name:'Toko Kedua',role:'Kasir',store_id:store,wk_cashier_store_id:store});
    const profile = (await query('select * from profiles where id=$1',[otherOwner]))[0];
    assert.equal(profile.role,'Pemilik');
    assert.notEqual(profile.store_id,store);
    assert.equal((await query('select owner_id from stores where id=$1',[profile.store_id]))[0].owner_id,otherOwner);
  });
  await test('urutan INSERT lalu UPDATE Auth Admin membuat Kasir tanpa nama toko baru', async () => {
    await addAdminUser(newCashier,'new@example.com',{full_name:'Kasir Baru'}, {wk_cashier_store_id:store});
    const row = (await query('select * from profiles where id=$1',[newCashier]))[0];
    assert.equal(row.role,'Kasir'); assert.equal(row.store_id,store);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,2);
    await user(newCashier);
    assert.equal((await rpc('select get_my_profile() result')).role,'Kasir');
    assert.equal((await rpc('select get_store() result')).id,store);
    await admin();
  });
  await test('penanda Kasir dalam user_metadata tidak melewati kewajiban nama toko', async () => {
    const id=randomUUID();
    await assert.rejects(() => addUser(id,'forged@example.com',{
      full_name:'Palsu',role:'Kasir',store_id:store,wk_cashier_store_id:store,
      app_metadata:{wk_cashier_store_id:store},
    }), /Nama toko/);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from profiles where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,2);
  });
  await test('toko terpercaya tidak ditemukan membatalkan seluruh pembuatan akun Auth Admin', async () => {
    const id=randomUUID();
    await assert.rejects(() => addAdminUser(id,'missing-store@example.com',{full_name:'Salah'},
      {wk_cashier_store_id:randomUUID()}), /Toko tujuan tidak tersedia/);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from profiles where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,2);
  });
  await test('toko terpercaya bukan UUID membatalkan seluruh pembuatan akun Auth Admin', async () => {
    const id=randomUUID();
    await assert.rejects(() => addAdminUser(id,'bad-store@example.com',{full_name:'Salah'},
      {wk_cashier_store_id:'bukan-uuid'}), /uuid|Toko tujuan/);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from profiles where id=$1',[id]))[0].n,0);
  });
  await test('register tanpa nama toko membatalkan akun dan profil seluruhnya', async () => {
    const id=randomUUID();
    await assert.rejects(() => addUser(id,'bad@example.com',{full_name:'Salah'}), /Nama toko/);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from profiles where id=$1',[id]))[0].n,0);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,2);
  });
  await test('pengulangan perbaikan trigger tidak menggandakan atau mengubah profil yang sudah dibuat', async () => {
    const before=await query('select * from profiles order by id');
    await db.exec(cashierTrigger);
    await db.exec(cashierTrigger);
    assert.deepEqual(await query('select * from profiles order by id'),before);
    assert.equal((await query('select count(*)::int n from stores'))[0].n,2);
    const triggers=await query(`select tgdeferrable, tginitdeferred from pg_trigger
      where tgrelid='auth.users'::regclass and tgname='on_auth_user_created'`);
    assert.deepEqual(triggers,[{tgdeferrable:true,tginitdeferred:true}]);
  });
  await user(otherOwner);
  const foreign = await rpc("select create_product('Produk Toko Kedua',500,800,20,'pcs') result");
  await test('katalog hanya berisi produk toko pengguna', async () => {
    assert.deepEqual((await query('select get_products() result')).map(r=>r.result.id),[foreign.id]);
    await user(cashier);
    const rows=await query('select get_products() result');
    assert.deepEqual(rows.map(r=>r.result.id),[product.id]); assert.equal(rows[0].result.cost_price,0);
  });
  await test('Pemilik toko lain tidak dapat edit, tambah stok, atau hapus produk asing', async () => {
    await user(otherOwner);
    for(const [sql,args] of [
      ["select update_product($1,'Curang',1,2,'pcs')",[product.id]],
      ['select add_product_stock($1,10)',[product.id]],['select delete_product($1)',[product.id]],
    ]) await assert.rejects(()=>query(sql,args),/Produk tidak ditemukan/);
  });
  await test('keranjang lintas toko ditolak dan semua perubahan stok/nota dibatalkan', async () => {
    await user(owner);
    await assert.rejects(()=>query('select checkout($1,$2,1000,1000)',[randomUUID(),[
      {product_id:product.id,qty:1,expected_price:200},{product_id:foreign.id,qty:1,expected_price:800},
    ]]));
    await admin();
    assert.equal((await query('select stock from products where id=$1',[product.id]))[0].stock,9);
    assert.equal((await query('select count(*)::int n from transactions'))[0].n,1);
  });
  await test('riwayat, detail nota, dan laporan toko lain tidak dapat dibaca', async () => {
    await user(otherOwner);
    assert.equal((await query('select list_transactions() result')).length,0);
    assert.equal((await rpc('select get_report() result')).transaction_count,0);
    await assert.rejects(()=>query('select get_transaction($1)',[saleId]),/Transaksi tidak ditemukan/);
    await assert.rejects(()=>query('select checkout($1,$2,200,200)',[saleId,[{product_id:foreign.id,qty:1,expected_price:800}]]),/ID transaksi sudah digunakan/);
  });
  await test('Pemilik mengubah profil toko dan nota menggunakan nama toko terbaru', async () => {
    await user(owner);
    const changed=await rpc("select update_store('Warung Baru','Jalan Uji','081234') result");
    assert.equal(changed.id,store);
    assert.equal((await rpc('select get_my_profile() result')).store_name,'Warung Baru');
    assert.equal((await rpc('select get_transaction($1) result',[saleId])).store_name,'Warung Baru');
  });
  await test('daftar Kasir hanya memuat Kasir toko sendiri, dan nama dapat diedit', async () => {
    const rows=await query('select list_cashiers() result');
    assert.deepEqual(new Set(rows.map(r=>r.result.id)),new Set([cashier,newCashier]));
    const changed=await rpc("select update_cashier($1,'Nama Baru',true) result",[newCashier]);
    assert.equal(changed.full_name,'Nama Baru'); assert.equal(changed.email,'new@example.com');
  });
  await test('Pemilik toko lain tidak dapat membaca, mengubah, atau menonaktifkan Kasir asing', async () => {
    await user(otherOwner);
    assert.equal((await query('select list_cashiers() result')).length,0);
    await assert.rejects(()=>query('select get_cashier($1)',[cashier]),/Kasir tidak ditemukan/);
    await assert.rejects(()=>query("select update_cashier($1,'Palsu',false)",[cashier]),/Kasir tidak ditemukan/);
    await user(owner);
    await assert.rejects(()=>query("select update_cashier($1,'Palsu',false)",[owner]),/Kasir tidak ditemukan/);
  });
  await test('Kasir tidak dapat mengelola toko, pegawai, atau menaikkan perannya', async () => {
    await user(cashier);
    for(const sql of ['select list_cashiers()',"select update_store('Curang','','')",'select get_report()',"update profiles set role='Pemilik'",'update profiles set is_active=true']) {
      await assert.rejects(()=>query(sql),/permission denied|Fitur ini hanya/);
    }
    assert.equal((await query('select id from profiles')).length,1);
  });
  await test('anon dan akses tabel langsung tidak dapat melewati fungsi toko', async () => {
    for(const role of ['authenticated','anon']) {
      await user(role==='anon'?null:owner,role);
      for(const table of ['stores','products','transactions','transaction_items']) await assert.rejects(()=>query('select * from '+table),/permission denied/);
    }
    await assert.rejects(()=>query('select get_my_profile()'),/permission denied/);
    await assert.rejects(()=>query('select list_cashiers()'),/permission denied/);
  });
  await test('menonaktifkan Kasir menolak sesi yang sudah login, tanpa menghapus nota lama', async () => {
    await user(owner); await rpc("select update_cashier($1,'Kasir Lama',false) result",[cashier]);
    await user(cashier);
    for(const sql of ['select get_my_profile()','select get_store()','select get_products()','select list_transactions()']) {
      await assert.rejects(()=>query(sql),/dinonaktifkan/);
    }
    await user(owner);
    assert.equal((await rpc('select get_transaction($1) result',[saleId])).total_price,200);
    await rpc("select update_cashier($1,'Kasir Lama',true) result",[cashier]);
    await user(cashier);
    assert.equal((await rpc('select get_my_profile() result')).role,'Kasir');
  });
  await test('checkout dan retry sesudah migrasi tetap atomik dalam toko sendiri', async () => {
    const id=randomUUID(); const items=[{product_id:product.id,qty:1,expected_price:200}];
    const first=await rpc('select checkout($1,$2,300,200) result',[id,items]);
    const retry=await rpc('select checkout($1,$2,300,200) result',[id,items]);
    assert.equal(first.id,retry.id); assert.equal(first.store_name,'Warung Baru'); assert.equal('total_profit' in first,false);
    await admin(); assert.equal((await query('select stock from products where id=$1',[product.id]))[0].stock,8);
  });
  await test('data tanpa Pemilik tidak diwariskan ke pendaftar pertama dan SQL panduan memindahkannya secara eksplisit', async () => {
    const fresh = new PGlite();
    try {
      await fresh.exec(`create role anon nologin; create role authenticated nologin;
        create schema auth;
        create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',raw_app_meta_data jsonb default '{}');
        create function auth.uid() returns uuid language sql stable as $$
          select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid; $$;
        grant usage on schema public,auth to anon,authenticated;`);
      await fresh.exec(base);
      await fresh.exec("insert into products(name,cost_price,selling_price,stock,unit) values('Warisan',100,200,3,'pcs')");
      await fresh.exec(migration);
      await fresh.exec(cashierTrigger);
      const id=randomUUID();
      await fresh.query('insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3)',
        [id,'fresh@example.com',{full_name:'Baru',store_name:'Toko Baru'}]);
      await fresh.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
      await fresh.exec('set role authenticated');
      assert.equal((await fresh.query('select get_products()')).rows.length,0);
      await fresh.exec('reset role');
      const setup=await readFile(new URL('../../docs/SETUP_SUPABASE.md',import.meta.url),'utf8');
      const claim=setup.match(/```sql\r?\n([\s\S]*?)```/)[1].replace('EMAIL_PEMILIK_YANG_DIPILIH','fresh@example.com');
      await fresh.exec(claim);
      await fresh.exec(claim);
      assert.equal((await fresh.query('select count(*)::int n from stores')).rows[0].n,1);
      await fresh.exec('set role authenticated');
      const rows=(await fresh.query('select get_products() result')).rows;
      assert.equal(rows[0].result.name,'Warisan'); assert.equal(rows[0].result.stock,3);
    } finally { await fresh.close(); }
  });
  console.log(`\n${count} store/account checks passed.`);
} finally { await db.close(); }
