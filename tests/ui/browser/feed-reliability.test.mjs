import {setMaximumPrice} from './harness.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {app,home,offer,rpc,until} from './harness.mjs';
import {validateHomeFeed} from '../../../client/feed-validation.mjs';

const feedCalls=ui=>ui.calls.filter(call=>call.name==='home_feed');
const refreshReady=ui=>{const button=ui.find('Refresh offers')?.closest('button');return button&&!button.disabled;};
const settle=()=>new Promise(resolve=>setTimeout(resolve,35));

const favorite=()=>({slug:'fixture-kitchen',name:'Fixture Kitchen',cuisine:'Test cuisine',neighborhood:'Test area',
 labels:[],live_offers:0,best_offer_id:'',best_offer_title:'',best_price_cents:0,is_demo:false});

test('raw feed validation preserves valid DTOs and rejects omitted collections before Jac hydration',()=>{
 for(const value of [home([]),home([offer()],{favorites:[favorite()],extra_metadata:'preserved'})])assert.equal(validateHomeFeed(value),value);
 // Jac HomeView constructors supply [] for omitted fields. The gateway validates the
 // raw DTO first; these omissions cannot be recovered from an already hydrated object.
 for(const key of ['items','favorites']){
  const value=home([]);delete value[key];
  assert.throws(()=>validateHomeFeed(value),/Invalid offer feed response/);
 }
});

test('feed validation rejects empty offer and favorite identities even after hydration defaults',()=>{
 for(const key of ['id','title','restaurant']){
  assert.throws(()=>validateHomeFeed(home([offer({[key]:' '})])),/Invalid offer feed response/);
 }
 for(const key of ['slug','name']){
  assert.throws(()=>validateHomeFeed(home([],{favorites:[{...favorite(),[key]:''}]})),/Invalid offer feed response/);
 }
});

function feedClock(){
 let window,visibility='visible',nextId=1;
 const timers=new Map();
 return {
  configureWindow(w){
   window=w;
   Object.defineProperty(w.document,'visibilityState',{configurable:true,get:()=>visibility});
   Object.defineProperty(w.document,'hidden',{configurable:true,get:()=>visibility==='hidden'});
   w.setInterval=(callback,delay)=>{const id=nextId++;timers.set(id,{callback,delay});return id;};
   w.clearInterval=id=>timers.delete(id);
  },
  tick(){for(const timer of [...timers.values()])if(timer.delay===30000)timer.callback();},
  event(name){window.dispatchEvent(new window.Event(name));},
  visible(value,notify=true){visibility=value?'visible':'hidden';if(notify)window.document.dispatchEvent(new window.Event('visibilitychange'));},
  pollingCount(){return [...timers.values()].filter(timer=>timer.delay===30000).length;}
 };
}

for(const [name,response] of [
 ['null result',()=>rpc(null)],
 ['missing result',()=>Response.json({ok:true,type:'response',data:{reports:[]},error:null})],
 ['null items',()=>rpc({...home([]),items:null})],
 ['null favorites',()=>rpc({...home([]),favorites:null})],
 ['malformed items',()=>rpc({...home([]),items:{}})],
 ['missing offer structure',()=>rpc({...home([]),items:[{offer:{}}]})],
 ['malformed favorite',()=>rpc(home([],{favorites:[null]}))]
]) {
 test(`${name} is an error with a working retry, never a successful empty feed`,async()=>{
  let retry=false;
  const ui=await app({intercept(endpoint){if(endpoint==='home_feed')return retry?rpc(home([offer()])):response();}});
  try{
   await until(()=>ui.text().includes('Could not load offers.'),'invalid response becomes a load error');
   assert.equal(ui.text().includes('Offers are on their way'),false);
   retry=true;ui.click('Refresh offers');await until(()=>ui.find('Current bowl'));
   assert.deepEqual(ui.errors,[]);
  }finally{ui.close();}
 });
}

for(const initialItems of [[],[offer()]]) {
 test(`manual refresh is available on a ${initialItems.length?'populated':'valid empty'} feed and discovers a new offer`,async()=>{
  let published=false;
  const ui=await app({intercept(name){if(name==='home_feed')return rpc(home(published?[offer({title:'Newly published lunch'})]:initialItems));}});
  try{
   if(!initialItems.length)assert.ok(ui.text().includes('Offers are on their way'));
   published=true;ui.click('Refresh offers');await until(()=>ui.find('Newly published lunch'));
   assert.equal(feedCalls(ui).length,2);assert.deepEqual(ui.errors,[]);
  }finally{ui.close();}
 });
}

for(const trigger of ['focus','visible','online']) {
 test(`${trigger} revalidation finds an offer published while the feed was empty`,async()=>{
  const clock=feedClock();let published=false;
  const ui=await app({configureWindow:clock.configureWindow,intercept(name){if(name==='home_feed')return rpc(home(published?[offer({title:'Published from another device'})]:[]));}});
  try{
   assert.ok(ui.text().includes('Offers are on their way'));
   clock.visible(false);published=true;
   clock.visible(true,trigger==='visible');
   if(trigger!=='visible')clock.event(trigger);
   await until(()=>ui.find('Published from another device'));
   assert.deepEqual(ui.errors,[]);
  }finally{ui.close();}
 });
}

test('30 second polling skips hidden pages, prevents overlap, and stops off the active feed',async()=>{
 const clock=feedClock();let release;
 const pending=new Promise(resolve=>{release=resolve;});
 const ui=await app({configureWindow:clock.configureWindow,intercept:async(name,body,{calls})=>{if(name==='home_feed'&&calls.filter(call=>call.name==='home_feed').length===2){await pending;return rpc(home([offer()]));}}});
 try{
  assert.equal(clock.pollingCount(),1,'active feed installs one 30 second poll');
  clock.visible(false);clock.tick();clock.event('focus');clock.event('online');await settle();
  assert.equal(feedCalls(ui).length,1,'hidden feed must not fetch');
  clock.visible(true);await until(()=>feedCalls(ui).length===2);
  clock.tick();clock.event('focus');clock.event('online');clock.visible(true);await settle();
  assert.equal(feedCalls(ui).length,2,'pending refresh must coalesce every revalidation event');
  release();await until(()=>refreshReady(ui));await settle();
  clock.tick();await until(()=>feedCalls(ui).length===3,'visible interval refreshes');
  await until(()=>refreshReady(ui));ui.click('Current bowl');await until(()=>ui.find('Claim this offer'));
  assert.equal(clock.pollingCount(),0,'leaving feed clears its timer');
  const previous=feedCalls(ui).length;clock.tick();clock.event('focus');clock.event('online');clock.visible(true);await settle();
  assert.equal(feedCalls(ui).length,previous,'leaving feed removes revalidation listeners');
  assert.deepEqual(ui.errors,[]);
 }finally{release();ui.close();}
});

test('revalidation uses current filter values and skips an already busy manual refresh',async()=>{
 const clock=feedClock();let hold=false,release;
 const pending=new Promise(resolve=>{release=resolve;});
 const ui=await app({configureWindow:clock.configureWindow,intercept:async(name,body,{calls})=>{
  if(name==='home_feed'&&body.price_range){
   if(hold)await pending;
   return rpc(home([offer({title:`Filtered bowl ${calls.filter(call=>call.name==='home_feed').length}`})]));
  }
 }});
 try{
  await setMaximumPrice(ui,5);await until(()=>ui.find('Filtered bowl 2')&&refreshReady(ui));
  clock.event('focus');await until(()=>ui.find('Filtered bowl 3')&&refreshReady(ui));
  assert.equal(feedCalls(ui).at(-1).body.price_range,'0-5','auto refresh must use the latest filter closure');
  hold=true;ui.click('Refresh offers');await until(()=>feedCalls(ui).length===4);
  clock.event('focus');clock.event('online');clock.tick();await settle();
  assert.equal(feedCalls(ui).length,4,'manual loading also suppresses automatic refresh');
  release();await until(()=>ui.find('Filtered bowl 4')&&refreshReady(ui));assert.deepEqual(ui.errors,[]);
 }finally{release();ui.close();}
});

test('a transient refresh failure recovers on online without a false empty state or lost filters',async()=>{
 const clock=feedClock();let offline=false,published=false;
 const ui=await app({configureWindow:clock.configureWindow,intercept(name,body){
  if(name==='home_feed'){
   if(offline)throw new Error('Fixture connection lost');
   return rpc(home([offer({title:published?'Recovered new lunch':body.price_range?'Filtered bowl':'Current bowl'})]));
  }
 }});
 try{
  await setMaximumPrice(ui,5);await until(()=>ui.find('Filtered bowl')&&refreshReady(ui));
  offline=true;clock.event('focus');await until(()=>ui.text().includes('Could not load offers.'));
  assert.equal(ui.text().includes('Offers are on their way'),false);
  assert.equal(ui.text().includes('Nothing matches yet'),false);
  offline=false;published=true;clock.event('online');await until(()=>ui.find('Recovered new lunch'));
  assert.equal(feedCalls(ui).at(-1).body.price_range,'0-5');
  assert.equal(ui.text().includes('Could not load offers.'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
