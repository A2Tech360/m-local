import test from 'node:test';
import assert from 'node:assert/strict';
import {app,offer,rpc,until} from './harness.mjs';

test('budget filter exposes native button semantics and applies the selection',async()=>{
 const ui=await app({intercept(name,body){
  if(name==='list_offers'&&body.max_price==='8')return rpc([offer({title:'Keyboard budget result'})]);
 }});
 try{
  const control=ui.find('Under $8').closest('[tabindex="0"]');
  // jsdom does not synthesize native keyboard clicks; Space is checked in the real browser.
  assert.equal(control.tagName,'BUTTON');
  assert.equal(control.getAttribute('role'),'button');
  ui.click('Under $8');
  await until(()=>ui.text().includes('Keyboard budget result'),'the button applies the selected budget');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest claim hands focus to a named email input',async()=>{
 const ui=await app({role:'guest'});
 try{
  ui.click('Current bowl');await until(()=>ui.find('Sign in to claim'),'guest claim action');
  ui.click('Sign in to claim');
  await until(()=>ui.document.querySelector('input[placeholder="Email"]'),'sign-in inputs appear');
  const email=ui.document.querySelector('input[placeholder="Email"]');
  assert.ok(ui.document.activeElement===email,'focus must move to the newly opened sign-in panel');
  assert.equal(email.getAttribute('aria-label'),'Email');
  assert.equal(ui.document.querySelector('input[placeholder="Password"]').getAttribute('aria-label'),'Password');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('guest claim refocuses a sign-in panel that was already open',async()=>{
 const ui=await app({role:'guest'});
 try{
  ui.click('Open sign in');await until(()=>ui.document.querySelector('input[placeholder="Email"]'));
  ui.fill('Email','student@example.test');
  ui.click('Current bowl');await until(()=>ui.find('Sign in to claim'));
  ui.find('Sign in to claim').closest('[tabindex="0"]').focus();
  ui.click('Sign in to claim');
  await until(()=>ui.document.activeElement===ui.document.querySelector('input[placeholder="Email"]'),'existing sign-in field receives focus');
  assert.equal(ui.document.activeElement.value,'student@example.test','preserve the existing email');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});
