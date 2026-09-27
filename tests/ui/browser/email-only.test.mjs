import test from 'node:test';
import assert from 'node:assert/strict';
import {app,home,offer,rpc,until} from './harness.mjs';

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
  if(name==='home_feed')return rpc(home([offer(),offer({id:'sample-offer',title:'Seeded sample lunch',restaurant:'Seeded sample cafe',is_demo:true})]));
 }});
 try{
  assert.ok(ui.calls.some(call=>call.name==='home_feed'));
  assert.ok(ui.text().includes('Current bowl'));
  assert.equal(ui.text().includes('Seeded sample lunch'),false);
  assert.equal(ui.text().includes('Seeded sample cafe'),false);
  assert.equal(/demo/i.test(ui.text()),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('visible deal count excludes sample rows and the unfiltered server total',async()=>{
 const ui=await app({role:'guest',intercept(name){
  if(name==='home_feed')return rpc(home([
   offer(),
   offer({id:'second-real',title:'Real evening bowl',is_demo:false}),
   offer({id:'sample-offer',title:'Seeded sample lunch',is_demo:true})
  ],{total_deals:83}));
 }});
 try{
  assert.ok(ui.text().includes('Current bowl'));
  assert.ok(ui.text().includes('Real evening bowl'));
  assert.equal(ui.text().match(/Showing \d+(?: of \d+)? deals/)?.[0],'Showing 2 deals');
  assert.equal(ui.text().includes('Seeded sample lunch'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('favorites retain real businesses and hide sample businesses even without a live offer',async()=>{
 const favorite={slug:'real-favorite',name:'Favorite real cafe',cuisine:'Bowls',neighborhood:'Test area',labels:[],live_offers:1,best_offer_id:'real-favorite-offer',best_offer_title:'Favorite real lunch',best_price_cents:600,is_demo:false};
 const ui=await app({role:'student',intercept(name){
  if(name==='home_feed')return rpc(home([offer()],{signed_in:true,favorites:[
   favorite,
   {...favorite,slug:'sample-favorite',name:'Favorite sample cafe',best_offer_id:'sample-favorite-offer',best_offer_title:'Favorite sample lunch',is_demo:true},
   {...favorite,slug:'sample-no-offer',name:'Dormant sample cafe',live_offers:0,best_offer_id:'',best_offer_title:'',best_price_cents:0,is_demo:true}
  ]}));
 }});
 try{
  assert.ok(ui.text().includes('Your favorites'));
  assert.ok(ui.text().includes('Favorite real cafe'));
  assert.ok(ui.text().includes('Favorite real lunch'));
  assert.equal(ui.text().includes('Favorite sample cafe'),false);
  assert.equal(ui.text().includes('Favorite sample lunch'),false);
  assert.equal(ui.text().includes('Dormant sample cafe'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

for(const [description,items] of [['sample-only',[offer({id:'sample-offer',title:'Seeded sample lunch',is_demo:true})]],['empty',[]]]) {
test(`a ${description} feed has an honest empty state instead of a filter error`,async()=>{
 let reads=0;
 const ui=await app({role:'guest',intercept(name){
  if(name==='home_feed'&&reads++>0)return rpc(home(items));
 }});
 try{
  ui.click('Under $5');await until(()=>ui.text().includes('Nothing matches yet'));
  assert.equal(ui.text().includes('Seeded sample lunch'),false);
  ui.click('Any price');await until(()=>ui.text().includes('Offers are on their way'));
  assert.equal(ui.text().includes('Try removing a filter.'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
}
