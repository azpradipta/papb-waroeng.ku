import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../../supabase/functions/delete-account/handler.mjs';
import { createWorkerHandler } from '../../supabase/functions/process-account-deletions/handler.mjs';
import { processQueue } from '../../supabase/functions/process-account-deletions/worker.mjs';

const secret='a'.repeat(48);
function request(body={password:'correct-password',confirm:true},token='valid') {
  return new Request('https://example.com/delete-account',{method:'POST',
    headers:token?{Authorization:`Bearer ${token}`}:{},body:JSON.stringify(body)});
}
function fixture(overrides={}) {
  const calls=[];
  const setup={
    workerSecret:secret,
    userClient:()=>({auth:{getUser:async()=>({data:{user:{id:'caller',email:'caller@example.com'}}})}}),
    passwordClient:()=>({auth:{
      signInWithPassword:async(args)=>{calls.push(['password',args]);return{data:{user:{id:'caller'}}};},
      signOut:async(args)=>{calls.push(['signOut',args]);return{};},
    }}),
    admin:{rpc:async(name,args)=>{calls.push([name,args]);return{data:{id:'request',status:'pending',requested_at:'2026-11-26'}};}},
    process:async(admin,args)=>{calls.push(['process',args]);return{};},
    schedule:(promise)=>{calls.push(['schedule']);return promise;},
    ...overrides,
  };
  return{handler:createHandler(setup),calls};
}
test('preflight and method handling',async()=>{
  const {handler}=fixture();
  assert.equal((await handler(new Request('https://example.com',{method:'OPTIONS'}))).status,200);
  assert.equal((await handler(new Request('https://example.com'))).status,405);
});
test('missing or invalid bearer never verifies password or enqueues',async()=>{
  const {handler,calls}=fixture();assert.equal((await handler(request({},null))).status,401);assert.deepEqual(calls,[]);
  const invalid=fixture({userClient:()=>({auth:{getUser:async()=>({error:{message:'private detail'}})}})});
  assert.equal((await invalid.handler(request())).status,401);assert.deepEqual(invalid.calls,[]);
});
test('missing worker configuration fails closed before authorization',async()=>{
  const {handler,calls}=fixture({workerSecret:''});
  const result=await handler(request());assert.equal(result.status,503);
  assert.equal((await result.json()).code,'configuration_error');assert.deepEqual(calls,[]);
});
test('confirmation,password,target injection and excessive payload rejected',async()=>{
  for(const body of [{password:'pw',confirm:false},{password:'',confirm:true},
    {password:'pw',confirm:true,user_id:'victim'},{password:'pw',confirm:true,store_id:'victim'},
    {password:'x'.repeat(129),confirm:true},[],null]) {
    const {handler,calls}=fixture();assert.equal((await handler(request(body))).status,400);assert.deepEqual(calls,[]);
  }
});
test('wrong password or mismatched authenticated UID never enables automation',async()=>{
  for(const result of [{error:{message:'secret'}},{data:{user:{id:'victim'}}}]) {
    const {handler,calls}=fixture({passwordClient:()=>({auth:{signInWithPassword:async()=>result,signOut:async()=>({})}})});
    const response=await handler(request());assert.equal(response.status,400);
    assert.deepEqual(await response.json(),{error:'Password tidak sesuai. Coba lagi.',code:'invalid_password'});
    assert.deepEqual(calls,[]);
  }
});
test('valid reauthentication derives UID/email server-side and returns only request metadata',async()=>{
  const {handler,calls}=fixture();const response=await handler(request());
  assert.equal(response.status,202);assert.deepEqual(await response.json(),{id:'request',status:'pending',requested_at:'2026-11-26'});
  assert.deepEqual(calls.find(([name])=>name==='password')[1],{email:'caller@example.com',password:'correct-password'});
  assert.deepEqual(calls.find(([name])=>name==='authorize_automatic_account_deletion')[1],{p_user_id:'caller',p_confirm:true});
  assert.deepEqual(calls.find(([name])=>name==='process')[1],{requestId:'request',limit:1});
  assert.deepEqual(calls.find(([name])=>name==='signOut')[1],{scope:'local'});
});
test('queue failure redacts internal errors and never schedules deletion',async()=>{
  const {handler,calls}=fixture({admin:{rpc:async()=>({error:{message:'service role password token'}})}});
  const response=await handler(request());assert.equal(response.status,503);
  assert.equal((await response.json()).code,'queue_unavailable');assert.ok(!calls.some(([name])=>name==='process'));
});
test('background failure still retains accepted durable request',async()=>{
  const {handler}=fixture({process:async()=>{throw new Error('private');}});
  assert.equal((await handler(request())).status,202);
});
function workerFixture({deleteResult={},checkResult={},completeError=false,claimError=false,prepareError=false}={}) {
  const calls=[];
  const admin={
    rpc:async(name,args)=>{
      calls.push([name,args]);
      if(name==='claim_automatic_account_deletions')return claimError?{error:{}}:{data:[{request_id:'request',lease_id:'lease'}]};
      if(name==='prepare_automatic_account_deletion')return prepareError?{error:{}}:{data:{auth_user_ids:['user']}};
      if(name==='complete_automatic_account_deletion')return completeError?{error:{}}:{data:{status:'completed'}};
      return{data:true};
    },
    auth:{admin:{
      deleteUser:async(...args)=>{calls.push(['deleteUser',args]);return deleteResult;},
      getUserById:async(...args)=>{calls.push(['getUserById',args]);return checkResult;},
    }},
  };
  return{admin,calls};
}
test('worker authenticates private secret and never accepts ordinary user JWT',async()=>{
  let processed=0;const handler=createWorkerHandler({workerSecret:secret,admin:{},process:async()=>{processed++;return{};}});
  for(const headers of [{},{Authorization:'Bearer user'},{'X-Worker-Secret':'wrong'}]) {
    assert.equal((await handler(new Request('https://example.com',{method:'POST',headers}))).status,401);
  }
  assert.equal(processed,0);
  assert.equal((await handler(new Request('https://example.com',{method:'POST',headers:{'X-Worker-Secret':secret}}))).status,200);
  assert.equal(processed,1);
});
test('worker prepares data then deletes Auth then completes with same lease',async()=>{
  const {admin,calls}=workerFixture();assert.deepEqual(await processQueue(admin),{claimed:1,completed:1,retrying:0});
  assert.deepEqual(calls.map(([name])=>name),['claim_automatic_account_deletions','prepare_automatic_account_deletion','deleteUser','complete_automatic_account_deletion']);
  assert.deepEqual(calls.find(([name])=>name==='deleteUser')[1],['user',false]);
});
test('only verified Auth user-not-found may be treated as a successful delete retry',async()=>{
  const success=workerFixture({deleteResult:{error:{}},checkResult:{error:{status:404,code:'user_not_found'}}});
  assert.equal((await processQueue(success.admin)).completed,1);
  for(const checkResult of [{data:{user:{id:'user'}}},{error:{status:500,code:'user_not_found'}},{error:{status:404,code:'unexpected'}}]) {
    const f=workerFixture({deleteResult:{error:{}},checkResult});
    assert.equal((await processQueue(f.admin)).retrying,1);
    assert.ok(!f.calls.some(([name])=>name==='complete_automatic_account_deletion'));
    assert.equal(f.calls.at(-1)[0],'retry_automatic_account_deletion');
  }
});
test('failed preparation or incomplete Auth deletion is durably retried without logging secrets',async()=>{
  for(const options of [{prepareError:true},{completeError:true}]) {
    const {admin,calls}=workerFixture(options);assert.deepEqual(await processQueue(admin),{claimed:1,completed:0,retrying:1});
    assert.equal(calls.at(-1)[0],'retry_automatic_account_deletion');
  }
});
test('unavailable queue is not reported as successful processing',async()=>{
  const {admin}=workerFixture({claimError:true});assert.equal((await processQueue(admin)).unavailable,true);
});
test('expired processing budget releases claimed work for retry',async()=>{
  let reads=0;const {admin,calls}=workerFixture();
  const result=await processQueue(admin,{now:()=>reads++===0?0:60_000});
  assert.equal(result.retrying,1);assert.ok(!calls.some(([name])=>name==='deleteUser'));
});
