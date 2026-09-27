import {openSignIn} from './harness.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {app,home,offer,rpc,until,setMaximumPrice} from './harness.mjs';

test('budget dropdown exposes a native button and range and applies the selection',async()=>{
 const ui=await app({intercept(name,body){
  if(name==='home_feed'&&body.price_range==='0-8')return rpc(home([offer({title:'Keyboard budget result'})]));
 }});
 try{
  const control=ui.document.querySelector('.ml-filters button[aria-expanded]');
  // jsdom does not synthesize native keyboard clicks; Space is checked in the real browser.
  assert.equal(control.tagName,'BUTTON');
  control.click();await until(()=>ui.document.querySelector('input[type="range"]'));
  assert.equal(ui.document.querySelector('input[type="range"]').getAttribute('aria-label'),'Maximum price');
  await setMaximumPrice(ui,8);
  await until(()=>ui.text().includes('Keyboard budget result'),'the button applies the selected budget');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest lands on a named email input with no password field',async()=>{
 const ui=await app({role:'guest'});
 try{
  await openSignIn(ui);
  await until(()=>ui.document.querySelector('input[placeholder="uniqname"]'),'sign-in inputs appear');
  const email=ui.document.querySelector('input[placeholder="uniqname"]');
  assert.equal(email.getAttribute('aria-label'),'U-M uniqname');
  assert.equal(ui.document.querySelector('input[type="password"]'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
