import assert from 'node:assert/strict';
import test from 'node:test';
import { createHandler } from '../../supabase/functions/manage-cashier/handler.mjs';

const owner='10000000-0000-4000-8000-000000000001';
const cashier='10000000-0000-4000-8000-000000000002';
function fixture(options={}) {
  const writes=[];
  const profile={id:owner,role:'Pemilik',is_active:true,store_id:'store-1',...options.profile};
  const client={auth:{getUser:async()=>({data:{user:options.invalidToken?null:{id:owner}},error:options.invalidToken?{}:null})},
    rpc:async(name)=>name==='get_my_profile'
      ? {data:profile,error:options.profileError?{}:null}
      : {data:{id:cashier,role:'Kasir',store_id:'store-1',...options.cashier},error:options.cashierError?{}:null}};
  const handler=createHandler({userClient:()=>client,admin:{auth:{admin:{
    createUser:async(payload)=>{writes.push(payload);return {data:{user:{id:cashier}},error:options.createError??null};},
    updateUserById:async(id,payload)=>{writes.push({id,...payload});return {error:null};},
  }}}});
  async function call(body,headers={Authorization:'Bearer valid-token'}) {
    return handler(new Request('https://example.test/manage-cashier',{method:'POST',headers,body:JSON.stringify(body)}));
  }
  return {handler,call,writes};
}
const create={action:'create',name:'Dina',email:'dina@example.com',password:'valid123'};

test('tanpa token atau token tidak valid tidak pernah memanggil Auth Admin',async()=>{
  for(const options of [{},{invalidToken:true}]) {
    const f=fixture(options); const response=await f.call(create,options.invalidToken?undefined:{});
    assert.equal(response.status,401); assert.equal(f.writes.length,0);
  }
});
test('Kasir, Pemilik nonaktif, profil hilang, dan identitas tidak cocok ditolak',async()=>{
  for(const options of [{profile:{role:'Kasir'}},{profile:{is_active:false}},{profileError:true},{profile:{id:cashier}}]) {
    const f=fixture(options); assert.equal((await f.call(create)).status,403); assert.equal(f.writes.length,0);
  }
});
test('pembuatan Kasir menetapkan toko dari sesi dan role dari jalur server',async()=>{
  const f=fixture(); const response=await f.call({...create,store_id:'toko-asing',role:'Pemilik',app_metadata:{}});
  assert.equal(response.status,201);
  assert.deepEqual(f.writes,[{email:create.email,password:create.password,email_confirm:true,
    user_metadata:{full_name:'Dina'},app_metadata:{wk_cashier_store_id:'store-1'}}]);
  assert.equal((await response.json()).is_active,true);
});
test('nama/email/password tidak valid ditolak sebelum pembuatan akun',async()=>{
  for(const invalid of [{name:''},{email:'salah'},{password:'123'},{password:5},{name:'a'.repeat(101)}]) {
    const f=fixture(); assert.equal((await f.call({...create,...invalid})).status,400); assert.equal(f.writes.length,0);
  }
});
test('email duplikat menghasilkan pesan yang dapat ditampilkan',async()=>{
  const f=fixture({createError:{code:'email_exists'}}); const response=await f.call(create);
  assert.equal(response.status,409); assert.match((await response.json()).error,/Email sudah digunakan/);
});
test('reset password hanya berlaku pada Kasir di toko Pemilik',async()=>{
  for(const options of [{cashier:{store_id:'toko-asing'}},{cashier:{role:'Pemilik'}},{cashierError:true}]) {
    const f=fixture(options); assert.equal((await f.call({action:'reset_password',id:cashier,password:'baru1234'})).status,404);
    assert.equal(f.writes.length,0);
  }
  const f=fixture(); assert.equal((await f.call({action:'reset_password',id:cashier,password:'baru1234'})).status,200);
  assert.deepEqual(f.writes,[{id:cashier,password:'baru1234'}]);
});
test('CORS preflight tersedia dan metode lain ditolak',async()=>{
  const f=fixture();
  assert.equal((await f.handler(new Request('https://example.test',{method:'OPTIONS'}))).headers.get('Access-Control-Allow-Origin'),'*');
  assert.equal((await f.handler(new Request('https://example.test'))).status,405);
  assert.equal(f.writes.length,0);
});
test('payload rusak dan aksi tidak dikenal tidak menjalankan Auth Admin',async()=>{
  const f=fixture();
  assert.equal((await f.handler(new Request('https://example.test',{method:'POST',headers:{Authorization:'Bearer ok'},body:'{bad'}))).status,400);
  assert.equal((await f.call({...create,action:'delete_everything'})).status,400);
  assert.equal(f.writes.length,0);
});
