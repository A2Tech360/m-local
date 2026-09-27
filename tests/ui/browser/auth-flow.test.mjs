import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {resolve} from 'node:path';

const source = resolve(import.meta.dirname, '../../..');
const runtime = resolve(process.env.MLOCAL_UI_APP_ROOT || source);
const clientRequire = createRequire(`${runtime}/.jac/client/package.json`);
const testRequire = createRequire(resolve(process.env.MLOCAL_UI_TEST_MODULES || `${runtime}/.jac/ui-test-runtime/node_modules`, '../package.json'));
const {buildSync} = clientRequire('esbuild');
const {JSDOM} = testRequire('jsdom');
// Exercise the actual Jac-compiled component, including reactive state lowering.
const bundle = buildSync({stdin:{contents:`import React from 'react'; import {createRoot} from 'react-dom/client'; import {EmailOnboarding} from './client/onboarding.js'; window.renderAuth = props => { window.authRoot ||= createRoot(document.getElementById('root')); window.authRoot.render(React.createElement(EmailOnboarding, props)); };`,resolveDir:resolve(runtime,'.jac/client/compiled'),loader:'jsx'},bundle:true,write:false,format:'iife',alias:{'@jac/runtime':resolve(runtime,'.jac/client/compiled/client_runtime.js'),'@jac/prelude':resolve(runtime,'.jac/client/compiled/jac_prelude.js')},nodePaths:[`${runtime}/.jac/client/node_modules`]}).outputFiles[0].text;

async function until(predicate) {
 const deadline=Date.now()+2000;
 while(!predicate()){if(Date.now()>deadline)throw new Error('Timed out waiting for auth UI');await new Promise(resolve=>setTimeout(resolve,10));}
}
async function auth(props={}) {
 const dom=new JSDOM('<div id="root"></div>',{url:'http://localhost',runScripts:'outside-only',pretendToBeVisual:true});
 const w=dom.window;w.eval(bundle);
 const settings={kind:'business',initialMode:'signin',onSwitchAudience(){},onCancel(){},requestCode:async()=>({ok:false,message:'Delivery unavailable.'}),verifyCode:async()=>({ok:false,message:'Try again.'}),onVerified(){},...props};
 w.renderAuth(settings);await until(()=>w.document.querySelector('form'));
 // Native Jac subscribes state and focuses the initial field after mounting.
 await until(()=>w.document.activeElement===w.document.querySelector('input[type="email"],input[placeholder="uniqname"]'));
 return {w,doc:w.document,settings,
  click(text){const button=[...w.document.querySelectorAll('button')].find(b=>b.textContent===text);assert.ok(button,`Missing ${text}`);button.click();},
  fill(selector,value){const input=w.document.querySelector(selector);Object.getOwnPropertyDescriptor(w.HTMLInputElement.prototype,'value').set.call(input,value);input.dispatchEvent(new w.Event('input',{bubbles:true}));},
  close(){w.authRoot.unmount();w.close();}};
}

test('public sign-in has one primary action and a compact account-type control',async()=>{
 const ui=await auth();
 try{
  assert.equal(ui.doc.querySelectorAll('button[type="submit"]').length,1);
  assert.ok(ui.doc.querySelector('select[aria-label="Account type"]'));
  assert.equal(ui.doc.querySelectorAll('input').length,1);
  assert.equal(ui.doc.querySelector('input[type="password"]'),null);
  assert.equal(ui.doc.querySelector('h3').textContent,'Sign in');
  assert.equal(ui.doc.body.textContent.includes('Switch to U-M deals'),false);
  ui.click('Create an account');await until(()=>ui.doc.querySelector('[placeholder="Your name"]'));
  assert.equal(ui.doc.querySelector('h3').textContent,'Create your account');
  ui.click('Sign in');await until(()=>!ui.doc.querySelector('[placeholder="Your name"]'));
 }finally{ui.close();}
});

test('verification shows only code actions and keeps retry input after a rejected code',async()=>{
 const calls=[];
 const ui=await auth({requestCode:async(...args)=>{calls.push(args);return {ok:true,challenge:'opaque',email:'owner@example.test',retry_after:60,message:'Sent.'};}});
 try{
  ui.fill('[type="email"]','owner@example.test');ui.click('Send verification code');
  await until(()=>ui.doc.querySelector('[autocomplete="one-time-code"]'));
  assert.deepEqual(calls,[['owner@example.test','business','']]);
  assert.equal(ui.doc.querySelector('select'),null);
  assert.equal([...ui.doc.querySelectorAll('button')].some(b=>b.textContent==='Create an account'),false);
  await until(()=>ui.doc.activeElement===ui.doc.querySelector('[autocomplete="one-time-code"]'));
  ui.fill('[autocomplete="one-time-code"]','123456');ui.click('Verify and continue');
  await until(()=>ui.doc.body.textContent.includes('Try again.'));
  assert.equal(ui.doc.querySelector('[autocomplete="one-time-code"]').value,'123456');
  ui.click('Change email');await until(()=>ui.doc.querySelector('[type="email"]'));
  assert.equal(ui.doc.querySelector('[type="email"]').value,'owner@example.test');
 }finally{ui.close();}
});

test('an old account-type request cannot overwrite the new form',async()=>{
 let release;
 const pending=new Promise(resolve=>{release=resolve;});
 const ui=await auth({requestCode:()=>pending});
 try{
  ui.fill('[type="email"]','owner@example.test');ui.click('Send verification code');
  await until(()=>ui.doc.querySelector('select').disabled);
  ui.w.renderAuth({...ui.settings,kind:'student'});
  await until(()=>ui.doc.querySelector('[placeholder="uniqname"]'));
  release({ok:true,challenge:'old-business',email:'owner@example.test',retry_after:60});
  await new Promise(resolve=>setTimeout(resolve,30));
  assert.equal(ui.doc.querySelector('[autocomplete="one-time-code"]'),null);
  assert.equal(ui.doc.querySelector('[placeholder="uniqname"]').disabled,false);
 }finally{release({ok:false});ui.close();}
});
