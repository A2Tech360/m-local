import test from 'node:test';
import assert from 'node:assert/strict';
import {app,held,offer,rpc,until} from './harness.mjs';

const card=(name,kind,extra={})=>({name,kind,what:'Fixture place',meters:300,distance:'0.2 mi',minutes:4,deal:'',deal_offer_id:'',is_sample:true,adults_only:kind==='bars',...extra});
const nearby=()=>({ok:true,heading:'What now?',origin:'Fixture Kitchen (Demo)',has_samples:true,note:'',groups:[
 {kind:'activity',label:'Activities',cards:[card('First Books (Sample)','activity'),card('Second Records (Sample)','activity',{distance:'0.4 mi',minutes:8}),card('Third Gallery (Sample)','activity')]},
 {kind:'coffee',label:'Coffee',cards:[card('Listed Cafe','coffee',{deal:'Deal on now: $3 oat latte',deal_offer_id:'listed-offer',is_sample:false}),card('Plain Coffee (Sample)','coffee')]},
 {kind:'dessert',label:'Dessert',cards:[card('Cone Stand (Sample)','dessert',{deal:'Sample deal: Free topping with a cone'})]},
 {kind:'bars',label:'Bars',cards:[card('Blue Door Pub (Sample)','bars'),card('Tap Room (Sample)','bars')]}
]});
const squares=ui=>[...ui.document.querySelectorAll('section[aria-label="What now?"] button.mlocal-next')];
const square=(ui,label)=>squares(ui).find(b=>b.getAttribute('aria-label').startsWith(label+':')).parentElement;
const tap=(ui,label)=>square(ui,label).querySelector('button.mlocal-next').dispatchEvent(new ui.window.MouseEvent('click',{bubbles:true}));
const spoken=(ui,label)=>square(ui,label).querySelector('button.mlocal-next').getAttribute('aria-label');
async function redeemed(intercept) {
 const ui=await app({item:held({my_status:'redeemed',my_qr_payload:''}),intercept(name,body){
  if(intercept){const own=intercept(name,body);if(own!==undefined)return own;}
  if(name==='nearby_after')return rpc(nearby());
 }});
 ui.click('Saved bowl');
 return ui;
}

test('a redeemed claim shows four cards, two to a line, one per kind, with distance and deal marks',async()=>{
 const ui=await redeemed();
 try{
  await until(()=>squares(ui).length===4,'four cards');
  assert.deepEqual(squares(ui).map(b=>b.getAttribute('aria-label').split(':')[0]),['Activities','Coffee','Dessert','Bars']);
  assert.equal(square(ui,'Coffee').parentElement.style.gridTemplateColumns,'repeat(2, minmax(0, 1fr))');
  assert.ok(new Set(squares(ui).map(b=>b.parentElement.parentElement)).size===1,'all four share one grid');
  assert.ok(squares(ui).every(b=>b.parentElement.style.aspectRatio==='1 / 1'),'every card is a square');
  assert.equal(spoken(ui,'Activities'),'Activities: First Books (Sample), 0.2 mi, 1 of 3. Tap for the next place.');
  assert.equal(spoken(ui,'Coffee'),'Coffee: Listed Cafe, 0.2 mi, 1 of 2, has a deal. Tap for the next place.');
  assert.ok(square(ui,'Coffee').textContent.includes('Deal'));assert.ok(square(ui,'Dessert').textContent.includes('Deal'));
  assert.equal(square(ui,'Activities').textContent.includes('Deal'),false);
  assert.ok(square(ui,'Activities').textContent.includes('First Books'));assert.ok(square(ui,'Activities').textContent.includes('1 of 3'));
  assert.ok(square(ui,'Activities').textContent.includes('Fixture place'));assert.ok(square(ui,'Activities').textContent.includes('0.2 mi · 4 min walk'));
  assert.ok(square(ui,'Coffee').textContent.includes('Deal on now: $3 oat latte'));assert.ok(square(ui,'Dessert').textContent.includes('Sample deal: Free topping with a cone'));
  assert.ok(square(ui,'Bars').textContent.includes('Bars · 21+'));assert.equal(square(ui,'Coffee').textContent.includes('21+'),false);
  assert.ok(ui.text().includes('Sample places'));assert.ok(ui.text().includes('A short walk from Fixture Kitchen, nearest first.'));
  assert.deepEqual(ui.calls.filter(c=>c.name==='nearby_after').map(c=>c.body),[{offer_id:'fixture-offer'}]);
  assert.equal(ui.document.querySelector('button button'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('tapping a card flips through its kind in order and wraps, leaving the others alone',async()=>{
 const ui=await redeemed();
 try{
  await until(()=>squares(ui).length===4);
  assert.ok(square(ui,'Activities').textContent.includes('First Books'));
  tap(ui,'Activities');await until(()=>square(ui,'Activities').textContent.includes('Second Records'));
  assert.ok(square(ui,'Activities').textContent.includes('2 of 3'));assert.ok(square(ui,'Activities').textContent.includes('0.4 mi · 8 min walk'));
  assert.equal(square(ui,'Activities').textContent.includes('First Books'),false);
  tap(ui,'Activities');await until(()=>square(ui,'Activities').textContent.includes('Third Gallery'));
  tap(ui,'Activities');await until(()=>square(ui,'Activities').textContent.includes('First Books'));
  assert.ok(square(ui,'Activities').textContent.includes('1 of 3'));
  assert.ok(square(ui,'Coffee').textContent.includes('Listed Cafe'));assert.ok(square(ui,'Bars').textContent.includes('Blue Door Pub'));
  tap(ui,'Bars');await until(()=>square(ui,'Bars').textContent.includes('Tap Room'));
  assert.ok(square(ui,'Activities').textContent.includes('First Books'));
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('a place with a live deal names it and opens that deal',async()=>{
 const ui=await redeemed(name=>undefined);
 try{
  await until(()=>squares(ui).length===4);
  assert.equal(square(ui,'Dessert').querySelectorAll('button').length,1,'a sample deal has nothing to open');
  assert.equal([...ui.document.querySelectorAll('section[aria-label="What now?"] button')].filter(b=>b.textContent==='See this deal').length,1);
  assert.ok(square(ui,'Coffee').textContent.includes('See this deal'));
  ui.click('See this deal');
  await until(()=>ui.calls.some(c=>c.name==='get_offer'&&c.body.offer_id==='listed-offer'),'the listed deal opens');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('nothing is suggested before redemption or when no places come back',async()=>{
 const waiting=await app({item:held()});
 try{
  waiting.click('Saved bowl');await until(()=>waiting.text().includes('Saved meal terms'));
  assert.equal(waiting.document.querySelector('section[aria-label="What now?"]'),null);
  assert.equal(waiting.calls.some(c=>c.name==='nearby_after'),false);
  assert.deepEqual(waiting.errors,[]);
 }finally{waiting.close();}
 for(const reply of [rpc({ok:false,groups:[],note:'No nearby places are listed yet.'}),rpc(null),rpc({ok:true,groups:[{kind:'coffee',label:'Coffee',cards:[]}]})]){
  const empty=await redeemed(name=>name==='nearby_after'?reply.clone():undefined);
  try{
   await until(()=>empty.calls.some(c=>c.name==='nearby_after'));await new Promise(r=>setTimeout(r,60));
   assert.equal(empty.document.querySelector('section[aria-label="What now?"]'),null);
   assert.deepEqual(empty.errors,[]);
  }finally{empty.close();}
 }
});
