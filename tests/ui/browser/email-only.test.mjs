import test from 'node:test';
import assert from 'node:assert/strict';
import {app,offer,rpc,until} from './harness.mjs';

for (const audience of ['student','business']) {
 test(`${audience} sign-in uses email verification with no demo password entry`,async()=>{
  const ui=await app({role:'guest',audience,intercept(name){
   if(name==='request_email_code')return rpc({ok:true,challenge:'fixture-code',email:audience==='student'?'fixture@umich.edu':'owner@example.test',retry_after:60,message:'Check your inbox.'});
  }});
  try{
   ui.click('Open sign in');
   const field=audience==='student'?'uniqname':'you@business.com';
   await until(()=>ui.document.querySelector(`[placeholder="${field}"]`));
   assert.equal(ui.find('Demo sign-in'),undefined);
   assert.equal(ui.find('Existing restaurant sign-in'),undefined);
   assert.equal(ui.document.querySelector('input[type="password"]'),null);
   ui.fill(field,audience==='student'?'fixture':'owner@example.test');
   ui.click('Send verification code');
   await until(()=>ui.document.querySelector('input[autocomplete="one-time-code"]'));
   assert.ok(ui.text().includes('Check your email'));
   assert.equal(ui.calls.some(call=>call.name==='login'),false);
   assert.deepEqual(ui.errors,[]);
  }finally{ui.close();}
 });
}

test('account presentation uses verification status without demo branding',async()=>{
 const ui=await app({role:'student',intercept(name){
  if(name==='get_account_profile')return rpc({ok:true,display_name:'Fixture student',email:'',role:'student',email_verified:false,is_demo:true});
 }});
 try{
  assert.equal(/demo/i.test(ui.text()),false);
  ui.click('Account');await until(()=>ui.document.querySelector('[placeholder="Display name"]'));
  assert.ok(ui.text().includes('Email not verified'));
  assert.equal(/demo/i.test(ui.text()),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('public browsing keeps real offers and hides seeded sample listings',async()=>{
 const ui=await app({role:'guest',intercept(name){
  if(name==='list_offers')return rpc([offer(),offer({id:'sample-offer',title:'Seeded sample lunch',is_demo:true})]);
 }});
 try{
  assert.ok(ui.text().includes('Current bowl'));
  assert.equal(ui.text().includes('Seeded sample lunch'),false);
  assert.equal(/demo/i.test(ui.text()),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('a sample-only feed has an honest empty state instead of a filter error',async()=>{
 let reads=0;
 const ui=await app({role:'guest',intercept(name,body){
  if(name==='list_offers'&&reads++>0)return rpc([offer({id:'sample-offer',title:'Seeded sample lunch',is_demo:true})]);
 }});
 try{
  ui.click('Under $5');await until(()=>ui.text().includes('Nothing matches yet'));
  assert.equal(ui.text().includes('Seeded sample lunch'),false);
  ui.click('Any price');await until(()=>ui.text().includes('Offers are on their way'));
  assert.equal(ui.text().includes('Try removing a filter.'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
