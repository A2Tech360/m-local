import test from 'node:test';
import assert from 'node:assert/strict';
import {app,home,offer,rpc,until} from './harness.mjs';

test('budget filter exposes native button semantics and applies the selection',async()=>{
 const ui=await app({intercept(name,body){
  if(name==='home_feed'&&body.price_range==='5to8')return rpc(home([offer({title:'Keyboard budget result'})]));
 }});
 try{
  const control=ui.find('$5 to $8').closest('[tabindex="0"]');
  // jsdom does not synthesize native keyboard clicks; Space is checked in the real browser.
  assert.equal(control.tagName,'BUTTON');
  assert.equal(control.getAttribute('role'),'button');
  ui.click('$5 to $8');
  await until(()=>ui.text().includes('Keyboard budget result'),'the button applies the selected budget');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest claim hands focus to a named email input',async()=>{
 const ui=await app({role:'guest'});
 try{
  ui.click('Current bowl');await until(()=>ui.find('Sign in to claim'),'guest claim action');
  ui.click('Sign in to claim');
  await until(()=>ui.document.querySelector('input[placeholder="uniqname"]'),'sign-in inputs appear');
  const email=ui.document.querySelector('input[placeholder="uniqname"]');
  assert.ok(ui.document.activeElement===email,'focus must move to the newly opened sign-in panel');
  assert.equal(email.getAttribute('aria-label'),'U-M uniqname');
  assert.equal(ui.document.querySelector('input[type="password"]'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest claim opens the sign-in screen and leaves the feed behind',async()=>{
 const ui=await app({role:'guest'});
 try{
  ui.click('Current bowl');await until(()=>ui.find('Sign in to claim'));
  ui.click('Sign in to claim');
  await until(()=>ui.document.querySelector('input[placeholder="uniqname"]'),'sign-in screen opens');
  assert.ok(ui.text().includes('Sign in to M-Local'));
  assert.equal(ui.find('Sign in to claim'),undefined,'the offer is not drawn under the sign-in screen');
  assert.equal(ui.find('Nearby')===undefined,true,'no app menu before sign-in');
  ui.click('Keep browsing');await until(()=>ui.find('Sign in to claim'),'closing sign-in returns to the same offer');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
