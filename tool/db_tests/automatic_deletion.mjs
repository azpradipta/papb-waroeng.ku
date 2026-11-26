import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const query = async (sql, args = []) => (await db.query(sql,args)).rows;
const rpc = async (sql,args = []) => (await query(sql,args))[0].result;
const admin = () => db.exec('reset role');
async function asService() { await admin(); await db.exec('set role service_role'); }
let count = 0;
async function test(name, action) { await action(); console.log(`ok ${++count} - ${name}`); }
async function addOwner() {
  await admin(); const id = randomUUID();
  await query('insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3)',
    [id,`${id}@example.com`,{full_name:'Pemilik Uji',store_name:'Toko Uji'}]);
  return id;
}
const authorize = (id) => rpc('select authorize_automatic_account_deletion($1,true) result',[id]);
const claims = (id = null,limit = 3) => query('select claim_automatic_account_deletions($1,$2) result',[limit,id]).then((rows)=>rows.map((r)=>r.result));
const prepare = (c) => rpc('select prepare_automatic_account_deletion($1,$2) result',[c.request_id,c.lease_id]);
const complete = (c) => rpc('select complete_automatic_account_deletion($1,$2) result',[c.request_id,c.lease_id]);
const retry = (c) => rpc('select retry_automatic_account_deletion($1,$2) result',[c.request_id,c.lease_id]);
const migrationNames = ['202611170001_complete_shop.sql','202611180001_stores_and_accounts.sql',
  '202611200001_cashier_auth_trigger.sql','202611200002_account_deletion_requests.sql',
  '202611260001_automatic_account_deletion.sql'];
try {
  await db.exec(`create role anon nologin; create role authenticated nologin;
    create role service_role nologin bypassrls; create schema auth;
    create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb default '{}',raw_app_meta_data jsonb default '{}');
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid; $$;
    grant usage on schema public,auth to anon,authenticated,service_role;`);
  for (const name of migrationNames) await db.exec(await readFile(new URL(`../../supabase/migrations/${name}`,import.meta.url),'utf8'));
  const owner = await addOwner(); let request,claim;
  await test('permintaan lama tetap manual setelah migrasi dan tidak diambil worker',async()=>{
    request=await rpc('select request_account_deletion_for_user($1,true) result',[owner]);
    await asService(); assert.deepEqual(await claims(request.id),[]);
    await admin();
    const migration=await readFile(new URL('../../supabase/migrations/202611260001_automatic_account_deletion.sql',import.meta.url),'utf8');
    await db.exec(migration);
    assert.equal((await query('select automated_confirmed_at from account_deletion_requests where id=$1',[request.id]))[0].automated_confirmed_at,null);
  });
  await test('anon dan pengguna tidak dapat mengaktifkan, mengambil, atau menyelesaikan otomatisasi',async()=>{
    for (const role of ['anon','authenticated']) {
      await admin(); await db.exec(`set role ${role}`);
      for(const sql of ['select authorize_automatic_account_deletion($1,true)',
        'select claim_automatic_account_deletions(3,$1)',
        'select prepare_automatic_account_deletion($1,$1)',
        'select complete_automatic_account_deletion($1,$1)',
        'select retry_automatic_account_deletion($1,$1)']) {
        await assert.rejects(()=>query(sql,[owner]),/permission denied/);
      }
      await assert.rejects(()=>query('update account_deletion_requests set automated_confirmed_at=now()'),/permission denied/);
    }
  });
  await test('otorisasi ulang hanya mempromosikan permintaan yang sama dan tetap idempotent',async()=>{
    await asService();
    await assert.rejects(()=>rpc('select authorize_automatic_account_deletion($1,false) result',[owner]),/Konfirmasi/);
    await assert.rejects(()=>authorize(randomUUID()),/Silakan masuk/);
    const enabled=await authorize(owner);
    assert.equal(enabled.id,request.id); assert.equal(enabled.requested_at,request.requested_at);
    assert.deepEqual(Object.keys(enabled).sort(),['id','requested_at','status']);
    assert.deepEqual(await authorize(owner),enabled);
  });
  await test('lease unik mencegah claim ganda termasuk panggilan bersamaan',async()=>{
    const calls=await Promise.all([claims(request.id),claims(request.id)]);
    assert.equal(calls.flat().length,1); claim=calls.flat()[0];
    assert.equal(claim.request_id,request.id); assert.ok(claim.lease_id);
    assert.deepEqual(await claims(request.id),[]);
  });
  await test('lease palsu tidak dapat menyiapkan atau menyelesaikan penghapusan',async()=>{
    const fake={request_id:request.id,lease_id:randomUUID()};
    await assert.rejects(()=>prepare(fake),/Lease/); await assert.rejects(()=>complete(fake),/Lease/);
    assert.equal(await retry(fake),false);
    await admin(); assert.equal((await query('select count(*)::int n from profiles where id=$1',[owner]))[0].n,1);
  });
  await test('persiapan menyimpan target Auth sebelum data toko dihapus',async()=>{
    await asService(); const prepared=await prepare(claim);
    assert.deepEqual(prepared.auth_user_ids,[owner]); assert.equal(prepared.remaining_count,1);
    await assert.rejects(()=>complete(claim),/Auth belum/);
    await admin(); assert.equal((await query('select count(*)::int n from profiles where id=$1',[owner]))[0].n,0);
    assert.deepEqual((await query('select auth_user_ids from account_deletion_requests where id=$1',[request.id]))[0].auth_user_ids,[owner]);
  });
  await test('kegagalan melepas lease dan menjadwalkan retry dengan backoff',async()=>{
    await asService(); assert.equal(await retry(claim),true);
    assert.deepEqual(await claims(request.id),[]);
    await admin(); const row=(await query('select * from account_deletion_requests where id=$1',[request.id]))[0];
    assert.equal(row.worker_lease_id,null); assert.equal(row.worker_attempts,1);
    assert.ok(row.next_attempt_at > new Date()); assert.equal(row.status,'processing');
    await query("update account_deletion_requests set next_attempt_at=clock_timestamp()-interval '1 second' where id=$1",[request.id]);
  });
  await test('retry memakai lease baru; worker lama tidak bisa melepas atau memakai lease baru',async()=>{
    await asService(); const next=(await claims(request.id))[0];
    assert.notEqual(next.lease_id,claim.lease_id);
    assert.equal(await retry(claim),false); await assert.rejects(()=>prepare(claim),/Lease/);
    claim=next; assert.deepEqual((await prepare(claim)).auth_user_ids,[owner]);
  });
  await test('completion menunggu Auth hilang lalu menghapus identitas dan metadata lease',async()=>{
    await admin(); await query('delete from auth.users where id=$1',[owner]);
    await asService(); assert.deepEqual((await prepare(claim)).auth_user_ids,[]);
    assert.equal((await complete(claim)).status,'completed');
    await admin(); const row=(await query('select * from account_deletion_requests where id=$1',[request.id]))[0];
    assert.equal(row.user_id,null); assert.equal(row.store_id,null); assert.deepEqual(row.auth_user_ids,[]);
    assert.equal(row.worker_lease_id,null); assert.equal(row.next_attempt_at,null);
    await asService(); assert.deepEqual(await claims(request.id),[]);
  });
  await test('lease kedaluwarsa dipulihkan dan batch selalu dibatasi tiga',async()=>{
    const ids=[];for(let i=0;i<5;i++) ids.push(await addOwner());
    await asService(); const requests=[]; for(const id of ids) requests.push(await authorize(id));
    const first=await claims(null,999); assert.equal(first.length,3);
    const second=await claims(); assert.equal(second.length,2);
    await admin(); await query("update account_deletion_requests set worker_lease_until=clock_timestamp()-interval '1 second' where id=$1",[first[0].request_id]);
    await asService(); const recovered=await claims(first[0].request_id);
    assert.equal(recovered.length,1); assert.notEqual(recovered[0].lease_id,first[0].lease_id);
  });
  await test('toko besar diproses bertahap tanpa menghilangkan daftar UID untuk retry',async()=>{
    const largeOwner=await addOwner();
    const store=(await query('select store_id from profiles where id=$1',[largeOwner]))[0].store_id;
    for(let i=0;i<22;i++) {
      const id=randomUUID();await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)',
        [id,`${id}@example.com`,{full_name:'Kasir Uji'},{wk_cashier_store_id:store}]);
    }
    await asService(); const queued=await authorize(largeOwner); let leased=(await claims(queued.id))[0];
    const first=await prepare(leased);assert.equal(first.remaining_count,23);assert.equal(first.auth_user_ids.length,20);
    await admin();await query('delete from auth.users where id=any($1::uuid[])',[first.auth_user_ids]);
    await asService();await assert.rejects(()=>complete(leased),/Auth belum/);
    const rest=await prepare(leased);assert.equal(rest.remaining_count,3);assert.equal(rest.auth_user_ids.length,3);
    await admin();const original=(await query('select auth_user_ids from account_deletion_requests where id=$1',[queued.id]))[0].auth_user_ids;
    assert.equal(original.length,23);
    await query('delete from auth.users where id=any($1::uuid[])',[rest.auth_user_ids]);
    await asService();assert.equal((await complete(leased)).status,'completed');
  });
  await test('penutupan toko mencakup Kasir processing dan menyelesaikan semua permintaan terkait',async()=>{
    const closingOwner=await addOwner();
    const store=(await query('select store_id from profiles where id=$1',[closingOwner]))[0].store_id;
    const cashier=randomUUID();
    await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)',
      [cashier,`${cashier}@example.com`,{full_name:'Kasir Tutup'},{wk_cashier_store_id:store}]);
    await asService();const cashierRequest=await authorize(cashier);
    const cashierClaim=(await claims(cashierRequest.id))[0];await prepare(cashierClaim);
    const ownerRequest=await authorize(closingOwner),ownerClaim=(await claims(ownerRequest.id))[0];
    const targets=(await prepare(ownerClaim)).auth_user_ids;
    assert.equal(targets.length,2);assert.ok(targets.includes(cashier));assert.ok(targets.includes(closingOwner));
    await admin();await query('delete from auth.users where id=any($1::uuid[])',[targets]);
    await asService();assert.equal((await complete(ownerClaim)).status,'completed');
    await assert.rejects(()=>prepare(cashierClaim),/Lease/);
    await admin();const rows=await query('select status,auth_user_ids from account_deletion_requests where id=any($1::uuid[])',[[ownerRequest.id,cashierRequest.id]]);
    assert.equal(rows.length,2);assert.ok(rows.every((row)=>row.status==='completed'&&row.auth_user_ids.length===0));
  });
  console.log(`\n${count} automatic deletion checks passed.`);
} finally { await db.close(); }
