import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

export async function testAccountDeletion({ db, query, rpc, user, admin, test, migration }) {
  const owner = randomUUID(), cashier = randomUUID(), otherOwner = randomUUID();
  const noProfile = randomUUID();
  let store, ownerRequest, cashierRequest, product, saleId, preparedOwner;
  const cashier2=randomUUID(), cashier3=randomUUID();
  let cashier2Request, cashier3Request, externalProduct, externalSale;
  await admin();
  await db.exec(migration);
  await query(`insert into auth.users(id,email,raw_user_meta_data) values
    ($1,'deletion-owner@example.com',$2),($3,'deletion-other@example.com',$4)`,
    [owner,{full_name:'Pemilik Hapus',store_name:'Toko Hapus'},
      otherOwner,{full_name:'Pemilik Lain',store_name:'Toko Lain'}]);
  store = (await query('select store_id from profiles where id=$1',[owner]))[0].store_id;
  await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)',
    [cashier,'deletion-cashier@example.com',{full_name:'Kasir Hapus'}, {wk_cashier_store_id:store}]);

  await test('permintaan hapus akun baru belum ada dan pengajuan wajib dikonfirmasi', async () => {
    await user(owner);
    assert.equal(await rpc('select get_my_account_deletion_request() result'),null);
    for (const confirmation of [false,null]) {
      await assert.rejects(() => rpc('select request_account_deletion($1) result',[confirmation]),/Konfirmasi/);
    }
    assert.equal(await rpc('select get_my_account_deletion_request() result'),null);
  });
  await test('Pemilik mengajukan penghapusan miliknya dengan identitas dan toko dari server', async () => {
    ownerRequest = await rpc('select request_account_deletion(true) result');
    assert.equal(ownerRequest.status,'pending');
    assert.equal(ownerRequest.completed_at,null);
    assert.deepEqual(Object.keys(ownerRequest).sort(),['completed_at','id','requested_at','status']);
    assert.deepEqual(await rpc('select get_my_account_deletion_request() result'),ownerRequest);
    await admin();
    const row = (await query('select * from account_deletion_requests where id=$1',[ownerRequest.id]))[0];
    assert.equal(row.user_id,owner); assert.equal(row.store_id,store); assert.equal(row.user_role,'Pemilik');
  });
  await test('retry permintaan penghapusan mengembalikan ID dan tanggal sama tanpa antrean ganda', async () => {
    await user(owner);
    const results = await Promise.all([
      rpc('select request_account_deletion(true) result'),
      rpc('select request_account_deletion(true) result'),
    ]);
    assert.deepEqual(results,[ownerRequest,ownerRequest]);
    await admin();
    assert.equal((await query('select count(*)::int n from account_deletion_requests where user_id=$1',[owner]))[0].n,1);
  });
  await test('pengajuan tidak menghapus atau menonaktifkan akun dan toko', async () => {
    const profile = (await query('select * from profiles where id=$1',[owner]))[0];
    assert.equal(profile.is_active,true); assert.equal(profile.store_id,store);
    assert.equal((await query('select owner_id from stores where id=$1',[store]))[0].owner_id,owner);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[owner]))[0].n,1);
    await user(owner);
    assert.equal((await rpc('select get_my_profile() result')).id,owner);
  });
  await test('Kasir nonaktif tetap dapat mengajukan permintaan untuk akunnya sendiri', async () => {
    await user(owner);
    await rpc("select update_cashier($1,'Kasir Hapus',false) result",[cashier]);
    await user(cashier);
    await assert.rejects(() => rpc('select get_my_profile() result'),/dinonaktifkan/);
    assert.equal(await rpc('select get_my_account_deletion_request() result'),null);
    cashierRequest = await rpc('select request_account_deletion(true) result');
    assert.equal(cashierRequest.status,'pending'); assert.notEqual(cashierRequest.id,ownerRequest.id);
    assert.deepEqual(await rpc('select get_my_account_deletion_request() result'),cashierRequest);
    await admin();
    assert.equal((await query('select user_role from account_deletion_requests where id=$1',[cashierRequest.id]))[0].user_role,'Kasir');
  });
  await test('Pemilik maupun toko lain tidak dapat melihat atau mengubah permintaan milik orang lain', async () => {
    await user(owner);
    assert.deepEqual(await rpc('select get_my_account_deletion_request() result'),ownerRequest);
    await user(otherOwner);
    assert.equal(await rpc('select get_my_account_deletion_request() result'),null);
    for(const roleId of [owner,cashier,otherOwner]) {
      await user(roleId);
      for(const sql of [
        'select * from account_deletion_requests',
        "update account_deletion_requests set status='completed',completed_at=now()",
        'delete from account_deletion_requests',
        "insert into account_deletion_requests(user_id,store_id,user_role) values(null,null,'Pemilik')",
      ]) await assert.rejects(() => query(sql),/permission denied/);
    }
    await assert.rejects(() => query('select request_account_deletion(true,$1)',[owner]),/does not exist/);
    await assert.rejects(() => query('select get_my_account_deletion_request($1)',[owner]),/does not exist/);
  });
  await test('anon dan sesi tanpa UID yang valid tidak dapat membaca atau mengirim permintaan', async () => {
    await user(null,'anon');
    for(const sql of ['select get_my_account_deletion_request()','select request_account_deletion(true)','select * from account_deletion_requests']) {
      await assert.rejects(() => query(sql),/permission denied/);
    }
    for(const id of [null,randomUUID()]) {
      await user(id);
      for(const sql of ['select get_my_account_deletion_request()','select request_account_deletion(true)']) {
        await assert.rejects(() => query(sql),/Silakan masuk/);
      }
    }
  });
  await test('akun Auth tanpa profil tidak dapat menciptakan permintaan dengan identitas palsu', async () => {
    await admin();
    await query('insert into auth.users(id,email,raw_user_meta_data) values($1,$2,$3)',
      [noProfile,'deletion-orphan@example.com',{store_name:'Toko Tanpa Profil'}]);
    await query('delete from profiles where id=$1',[noProfile]);
    await user(noProfile);
    await assert.rejects(() => rpc('select request_account_deletion(true) result'),/Profil akun tidak ditemukan/);
    await admin();
    assert.equal((await query('select count(*)::int n from account_deletion_requests where user_id=$1',[noProfile]))[0].n,0);
  });
  await test('antrean tetap privat oleh RLS jika grant select diberikan tanpa sengaja', async () => {
    await admin(); await db.exec('grant select on account_deletion_requests to authenticated');
    await user(owner);
    assert.deepEqual(await query('select * from account_deletion_requests'),[]);
    assert.deepEqual(await rpc('select get_my_account_deletion_request() result'),ownerRequest);
    await admin(); await db.exec('revoke select on account_deletion_requests from authenticated');
  });
  await test('seluruh RPC pengelola ditolak untuk Pemilik, Kasir, toko lain, dan anon', async () => {
    for(const id of [owner,cashier,otherOwner,null]) {
      await user(id,id===null?'anon':'authenticated');
      for(const sql of [
        'select request_account_deletion_for_user($1,true)',
        'select preview_account_deletion($1)',
        'select prepare_account_deletion($1,true)',
        'select complete_account_deletion($1)',
      ]) await assert.rejects(() => query(sql,[ownerRequest.id]),/permission denied/);
    }
    await admin();
    await assert.rejects(() => query("update account_deletion_requests set status='completed' where id=$1",[ownerRequest.id]),/check constraint/);
  });
  await test('pengelola dapat membuat antrean untuk pemohon email terverifikasi tanpa menggandakan permintaan', async () => {
    await db.exec('set role service_role');
    await assert.rejects(() => rpc('select request_account_deletion_for_user($1,false) result',[otherOwner]),/Konfirmasi identitas/);
    await assert.rejects(() => rpc('select request_account_deletion_for_user($1,true) result',[randomUUID()]),/Silakan masuk/);
    const created=await rpc('select request_account_deletion_for_user($1,true) result',[otherOwner]);
    assert.equal(created.status,'pending');
    assert.deepEqual(await rpc('select request_account_deletion_for_user($1,true) result',[otherOwner]),created);
    await user(otherOwner);
    assert.deepEqual(await rpc('select get_my_account_deletion_request() result'),created);
    assert.deepEqual(await rpc('select request_account_deletion(true) result'),created);
    await admin();
    const row=(await query('select user_id,store_id,user_role from account_deletion_requests where id=$1',[created.id]))[0];
    assert.equal(row.user_id,otherOwner); assert.notEqual(row.store_id,store); assert.equal(row.user_role,'Pemilik');
  });
  await test('pratinjau tidak mengubah data, persiapan wajib dikonfirmasi, dan status belum bisa diselesaikan', async () => {
    await user(owner);
    product=await rpc("select create_product('Produk Hapus',100,200,4,'pcs') result");
    await rpc("select update_cashier($1,'Kasir Hapus',true) result",[cashier]);
    await user(cashier);
    saleId=randomUUID();
    await rpc('select checkout($1,$2,200,200) result',[saleId,[{product_id:product.id,qty:1,expected_price:200}]]);
    await user(owner); await rpc("select update_cashier($1,'Kasir Hapus',false) result",[cashier]);
    await admin();
    await db.exec('set role service_role');
    const preview=await rpc('select preview_account_deletion($1) result',[cashierRequest.id]);
    assert.equal(preview.scope,'account'); assert.equal(preview.status,'pending');
    assert.equal(preview.counts.accounts,1); assert.equal(preview.counts.transactions,1);
    await assert.rejects(() => rpc('select prepare_account_deletion($1,false) result',[cashierRequest.id]),/Konfirmasi/);
    await assert.rejects(() => rpc('select complete_account_deletion($1) result',[cashierRequest.id]),/Siapkan/);
    await assert.rejects(() => rpc('select preview_account_deletion($1) result',[randomUUID()]),/tidak ditemukan/);
    await admin();
    assert.equal((await query('select created_by from transactions where id=$1',[saleId]))[0].created_by,cashier);
    assert.equal((await query('select status from account_deletion_requests where id=$1',[cashierRequest.id]))[0].status,'pending');
  });
  await test('penghapusan profil Kasir mempertahankan nota dan laporan dengan identitas anonim', async () => {
    await db.exec('set role service_role');
    const prepared=await rpc('select prepare_account_deletion($1,true) result',[cashierRequest.id]);
    assert.equal(prepared.status,'processing'); assert.deepEqual(prepared.auth_user_ids,[cashier]);
    await admin();
    assert.equal((await query('select count(*)::int n from profiles where id=$1',[cashier]))[0].n,0);
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[cashier]))[0].n,1);
    assert.equal((await query('select created_by from transactions where id=$1',[saleId]))[0].created_by,null);
    assert.equal((await query('select stock from products where id=$1',[product.id]))[0].stock,3);
    await user(owner);
    const detail=await rpc('select get_transaction($1) result',[saleId]);
    assert.equal(detail.cashier_name,'Kasir dihapus'); assert.equal(detail.items.length,1);
    assert.equal((await rpc('select get_report() result')).total_sales,200);
    assert.equal((await query("select list_transactions('Kasir dihapus') result")).length,1);
    assert.equal((await query("select list_transactions('Kasir Hapus') result")).length,0);
    await user(cashier);
    const status=await rpc('select get_my_account_deletion_request() result');
    assert.equal(status.status,'processing'); assert.equal(status.id,cashierRequest.id);
    assert.deepEqual(await rpc('select request_account_deletion(true) result'),status);
    await admin();
  });
  await test('UUID nota milik Kasir yang dihapus tidak dapat diambil alih checkout Pemilik atau toko lain', async () => {
    for(const id of [owner,otherOwner]) {
      await user(id);
      await assert.rejects(() => rpc('select checkout($1,$2,200,200) result',
        [saleId,[{product_id:product.id,qty:1,expected_price:200}]]),/ID transaksi sudah digunakan/);
    }
    await admin();
    assert.equal((await query('select stock from products where id=$1',[product.id]))[0].stock,3);
    assert.equal((await query('select created_by from transactions where id=$1',[saleId]))[0].created_by,null);
  });
  await test('retry processing memakai UID tersimpan dan completion menolak Auth yang masih ada', async () => {
    await db.exec('set role service_role');
    const first=await rpc('select prepare_account_deletion($1,true) result',[cashierRequest.id]);
    assert.deepEqual(await rpc('select prepare_account_deletion($1,true) result',[cashierRequest.id]),first);
    await assert.rejects(() => rpc('select complete_account_deletion($1) result',[cashierRequest.id]),/Auth belum/);
    await admin();
    // Model Auth Admin untuk tes lokal; produksi memakai endpoint Auth Admin.
    await query('delete from auth.users where id=$1',[cashier]);
    await db.exec('set role service_role');
    const complete=await rpc('select complete_account_deletion($1) result',[cashierRequest.id]);
    assert.equal(complete.status,'completed'); assert.ok(complete.completed_at);
    assert.deepEqual(await rpc('select complete_account_deletion($1) result',[cashierRequest.id]),complete);
    await admin();
    const row=(await query('select * from account_deletion_requests where id=$1',[cashierRequest.id]))[0];
    assert.equal(row.user_id,null); assert.equal(row.store_id,null); assert.deepEqual(row.auth_user_ids,[]);
    assert.equal((await query('select count(*)::int n from transactions where id=$1',[saleId]))[0].n,1);
  });
  await test('pratinjau penutupan toko mencakup akun Kasir yang proses Auth-nya belum selesai', async () => {
    for(const id of [cashier2,cashier3]) {
      await query('insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values($1,$2,$3,$4)',
        [id,id+'@example.com',{full_name:'Kasir Toko Hapus'}, {wk_cashier_store_id:store}]);
      await user(id);
      const request=await rpc('select request_account_deletion(true) result');
      if(id===cashier2) cashier2Request=request; else cashier3Request=request;
      await admin();
    }
    await db.exec('set role service_role');
    await rpc('select prepare_account_deletion($1,true) result',[cashier3Request.id]);
    await user(cashier2);
    await rpc('select checkout($1,$2,200,200) result',[randomUUID(),[{product_id:product.id,qty:1,expected_price:200}]]);
    await user(otherOwner);
    externalProduct=await rpc("select create_product('Jangan Hapus',300,500,5,'pcs') result");
    externalSale=randomUUID();
    await rpc('select checkout($1,$2,500,500) result',[externalSale,[{product_id:externalProduct.id,qty:1,expected_price:500}]]);
    await admin(); await db.exec('set role service_role');
    const preview=await rpc('select preview_account_deletion($1) result',[ownerRequest.id]);
    assert.equal(preview.scope,'store'); assert.equal(preview.counts.accounts,3);
    assert.equal(preview.counts.products,1); assert.equal(preview.counts.transactions,2);
    assert.equal(preview.counts.auth_accounts_remaining,3);
    await admin();
    assert.equal((await query('select count(*)::int n from products where id=$1',[product.id]))[0].n,1);
  });
  await test('penutupan toko menghapus hanya lingkup toko pemohon, termasuk item, dan menyimpan seluruh UID untuk retry', async () => {
    await db.exec('set role service_role');
    preparedOwner=await rpc('select prepare_account_deletion($1,true) result',[ownerRequest.id]);
    assert.equal(preparedOwner.status,'processing');
    assert.deepEqual(new Set(preparedOwner.auth_user_ids),new Set([owner,cashier2,cashier3]));
    await admin();
    for(const table of ['profiles','products','transactions']) {
      assert.equal((await query('select count(*)::int n from '+table+' where store_id=$1',[store]))[0].n,0);
    }
    assert.equal((await query('select count(*)::int n from transaction_items where transaction_id=$1',[saleId]))[0].n,0);
    assert.equal((await query('select count(*)::int n from stores where id=$1',[store]))[0].n,0);
    assert.equal((await query('select count(*)::int n from auth.users where id=any($1::uuid[])',[[owner,cashier2,cashier3]]))[0].n,3);
    const related=(await query('select status,auth_user_ids from account_deletion_requests where id=$1',[cashier2Request.id]))[0];
    assert.equal(related.status,'processing'); assert.deepEqual(related.auth_user_ids,[cashier2]);
    await user(otherOwner);
    assert.equal((await rpc('select get_transaction($1) result',[externalSale])).total_price,500);
    assert.equal((await rpc('select get_report() result')).transaction_count,1);
    assert.equal((await query('select get_products() result'))[0].result.stock,4);
    await admin();
  });
  await test('retry sesudah sebagian Auth terhapus menuntaskan semua akun dan permintaan Kasir terkait', async () => {
    await query('delete from auth.users where id=$1',[owner]);
    await db.exec('set role service_role');
    assert.deepEqual(await rpc('select prepare_account_deletion($1,true) result',[ownerRequest.id]),preparedOwner);
    await assert.rejects(() => rpc('select complete_account_deletion($1) result',[ownerRequest.id]),/Auth belum/);
    await admin();
    await query('delete from auth.users where id in ($1,$2)',[cashier2,cashier3]);
    await db.exec('set role service_role');
    assert.equal((await rpc('select complete_account_deletion($1) result',[ownerRequest.id])).status,'completed');
    await admin();
    const rows=await query('select * from account_deletion_requests where id=any($1::uuid[])',[[ownerRequest.id,cashier2Request.id,cashier3Request.id]]);
    assert.equal(rows.length,3);
    assert.ok(rows.every(row=>row.status==='completed' && row.completed_at));
    assert.ok(rows.every(row=>row.user_id===null && row.store_id===null && row.auth_user_ids.length===0));
    assert.equal((await query('select count(*)::int n from auth.users where id=$1',[otherOwner]))[0].n,1);
    await user(owner);
    await assert.rejects(() => rpc('select get_my_account_deletion_request() result'),/Silakan masuk/);
    await admin();
  });
  await test('pengulangan migrasi mempertahankan audit dan tidak membuka akses publik', async () => {
    const before=await query('select * from account_deletion_requests order by id');
    await db.exec(migration); await db.exec(migration);
    assert.deepEqual(await query('select * from account_deletion_requests order by id'),before);
    assert.equal((await query("select relrowsecurity from pg_class where oid='public.account_deletion_requests'::regclass"))[0].relrowsecurity,true);
    await user(null,'anon');
    await assert.rejects(() => query('select get_my_account_deletion_request()'),/permission denied/);
    await admin();
  });
}
