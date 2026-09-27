import test from 'node:test';
import assert from 'node:assert/strict';
import {app,home,offer,feedItem,rpc,until} from './harness.mjs';

const heart=(ui,word)=>ui.document.querySelector(`[aria-label="${word} Fixture Kitchen ${word==='Add'?'to':'from'} favorites"]`);
const has=(ui,text)=>ui.find(text)!==undefined;

test('guest sees the feed with a sign-in link, a favorites section and no app menu',async()=>{
 const ui=await app({role:'guest'});
 try{
  assert.ok(has(ui,'Current bowl'));assert.ok(has(ui,'Sign in'));assert.ok(has(ui,'Your favorites'));
  assert.equal(has(ui,'Nearby'),false);assert.equal(has(ui,'Account'),false);assert.equal(has(ui,'Log out'),false);
  assert.equal(ui.document.querySelector('input[placeholder="uniqname"]'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('sign-in is its own screen with no feed and no app menu',async()=>{
 const ui=await app({role:'guest'});
 try{
  ui.click('Sign in');await until(()=>ui.document.querySelector('input[placeholder="uniqname"]'));
  assert.ok(ui.text().includes('Sign in to M-Local'));
  assert.equal(has(ui,'Current bowl'),false);assert.equal(has(ui,'Nearby'),false);assert.equal(has(ui,'Account'),false);
  ui.click('Keep browsing');await until(()=>has(ui,'Current bowl'));
  assert.equal(ui.document.querySelector('input[placeholder="uniqname"]'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest heart tap opens sign-in and never calls the favorites endpoint',async()=>{
 const ui=await app({role:'guest'});
 try{
  assert.ok(heart(ui,'Add'));
  heart(ui,'Add').dispatchEvent(new ui.window.MouseEvent('click',{bubbles:true}));
  await until(()=>ui.text().includes('Sign in to save your favorite places.'));
  assert.ok(ui.document.querySelector('input[placeholder="uniqname"]'));
  assert.equal(ui.calls.some(c=>c.name==='toggle_favorite'),false);
  assert.equal(ui.calls.some(c=>c.name==='get_offer'),false,'the heart must not open the offer under it');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('student heart adds the place to the favorites strip and can remove it',async()=>{
 let kept=false;
 const place={slug:'fixture-kitchen',name:'Fixture Kitchen',cuisine:'Test cuisine',neighborhood:'Test area',labels:[],live_offers:1,best_offer_id:'fixture-offer',best_offer_title:'Current bowl',best_price_cents:900,is_demo:false};
 const ui=await app({verified:true,intercept(name){
  if(name==='toggle_favorite'){kept=!kept;return undefined;}
  if(name==='home_feed')return rpc(home([feedItem(offer(),{is_favorite:kept})],{signed_in:true,favorites:kept?[place]:[]}));
 }});
 try{
  assert.ok(has(ui,'Your favorites'));assert.ok(has(ui,'Tap the heart on a place to keep it here.'));
  heart(ui,'Add').dispatchEvent(new ui.window.MouseEvent('click',{bubbles:true}));
  await until(()=>heart(ui,'Remove'),'heart turns on');
  assert.deepEqual(ui.calls.find(c=>c.name==='toggle_favorite').body,{slug:'fixture-kitchen',offer_id:''});
  assert.equal(has(ui,'Tap the heart on a place to keep it here.'),false);
  assert.equal(ui.calls.some(c=>c.name==='get_offer'),false,'the heart must not open the offer under it');
  assert.equal(ui.document.querySelector('button button'),null,'no button nested inside a button');
  heart(ui,'Remove').dispatchEvent(new ui.window.MouseEvent('click',{bubbles:true}));
  await until(()=>heart(ui,'Add'),'heart turns off');
  assert.ok(has(ui,'Tap the heart on a place to keep it here.'));
  assert.equal(ui.calls.filter(c=>c.name==='toggle_favorite').length,2);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('student menu is Offers and Account, and log out returns to guest browsing',async()=>{
 const ui=await app({verified:true});
 try{
  assert.ok(has(ui,'Nearby'));assert.ok(has(ui,'Account'));
  assert.equal(has(ui,'Manage'),false);assert.equal(has(ui,'Redeem'),false);
  assert.ok(has(ui,'Log out'));
  ui.click('Account');await until(()=>ui.text().includes('YOUR ACCOUNT'));
  assert.ok(has(ui,'Log out'));assert.ok(has(ui,'Edit my tastes'));
  ui.click('Log out');await until(()=>has(ui,'Sign in'));
  assert.equal(ui.window.localStorage.getItem('jac_token'),null);
  assert.equal(has(ui,'Nearby'),false);assert.equal(has(ui,'Log out'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('restaurant lands on its offers with Manage, Redeem and Account and can log out',async()=>{
 const ui=await app({role:'merchant',verified:true,audience:'business'});
 try{
  await until(()=>has(ui,'New offer'),'restaurant offers load without a tap');
  assert.ok(has(ui,'Manage'));assert.ok(has(ui,'Redeem'));assert.ok(has(ui,'Account'));
  assert.equal(has(ui,'Nearby'),false);assert.equal(has(ui,'Your favorites'),false);
  ui.click('Redeem');await until(()=>ui.text().includes('Scan a claim'));
  assert.ok(has(ui,'Log out'));
  ui.click('Log out');await until(()=>ui.document.querySelector('input[placeholder="you@business.com"]'));
  assert.equal(ui.window.localStorage.getItem('jac_token'),null);
  assert.equal(has(ui,'Manage'),false);assert.equal(has(ui,'Current bowl'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('business without a restaurant sees only its own account and can log out',async()=>{
 const ui=await app({role:'business',verified:true,audience:'business'});
 try{
  assert.ok(ui.text().includes('YOUR BUSINESS'));assert.ok(has(ui,'Business profile'));assert.ok(has(ui,'Log out'));
  assert.equal(has(ui,'Current bowl'),false);assert.equal(has(ui,'Nearby'),false);assert.equal(has(ui,'Manage'),false);
  ui.click('Log out');await until(()=>ui.document.querySelector('input[placeholder="you@business.com"]'));
  assert.equal(has(ui,'Business profile'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('sample listings stay hidden unless the server turns demo mode on',async()=>{
 const sample=feedItem(offer({id:'sample-offer',title:'Sample bowl',restaurant:'Sample Place (Demo)',is_demo:true}),{place:'sample-place'});
 const feed=on=>rpc(home([feedItem(offer()),sample],{show_samples:on}));
 const hidden=await app({role:'guest',intercept(name){if(name==='home_feed')return feed(false);}});
 try{assert.ok(has(hidden,'Current bowl'));assert.equal(has(hidden,'Sample bowl'),false);assert.deepEqual(hidden.errors,[]);}finally{hidden.close();}
 const shown=await app({role:'guest',intercept(name){if(name==='home_feed')return feed(true);}});
 try{await until(()=>has(shown,'Sample bowl'));assert.ok(has(shown,'Current bowl'));assert.deepEqual(shown.errors,[]);}finally{shown.close();}
});
