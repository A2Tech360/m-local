import test from 'node:test';
import assert from 'node:assert/strict';
import {app,offer,rpc,until} from './harness.mjs';

test('returning email sign-in needs no name and can switch to business signup',async()=>{
 const ui=await app({role:'guest',intercept(name){if(name==='request_email_code')return rpc({ok:false,message:'Fixture delivery disabled.'});}});
 try{
  ui.click('Open sign in');await until(()=>ui.document.querySelector('[placeholder="uniqname"]'));
  assert.equal(ui.document.querySelector('[placeholder="Your name"]'),null,'returning users should not have to invent a name again');
  ui.fill('uniqname','fixture');ui.click('Send verification code');await until(()=>ui.text().includes('Fixture delivery disabled.'));
  assert.equal(ui.calls.find(c=>c.name==='request_email_code').body.name,'');
  ui.click('Create an account');await until(()=>ui.document.querySelector('[placeholder="Your name"]'));
  assert.equal(ui.document.querySelector('[placeholder="Your name"]').required,true);
  ui.click('Switch to business');await until(()=>ui.document.querySelector('[placeholder="you@business.com"]'));
  assert.equal(ui.document.querySelector('[placeholder="uniqname"]'),null);
  assert.equal(ui.window.localStorage.getItem('mlocal_audience'),'business');
  assert.equal(ui.document.querySelector('[type="password"]'),null);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('account edit persists on reopen, refreshes session name, and cannot edit email or role',async()=>{
 let displayName='Fixture student';
 const profile=()=>({ok:true,message:'',display_name:displayName,email:'fixture@umich.edu',role:'student',email_verified:true,is_demo:false});
 const ui=await app({verified:true,intercept(name,body){
  if(name==='get_account_profile')return rpc(profile());
  if(name==='save_account_profile'){displayName=body.display_name;return rpc({...profile(),message:'Account profile saved.'});}
  if(name==='current_session')return rpc({authenticated:true,actor_id:'fixture-student',role:'student',restaurant_id:'',display_name:displayName,email_verified:true,is_demo:false});
 }});
 try{
  ui.click('Account');await until(()=>ui.document.querySelector('[placeholder="Display name"]'));
  await until(()=>!ui.document.querySelector('[placeholder="Display name"]').disabled);
  assert.ok(ui.text().includes('fixture@umich.edu'));assert.ok(ui.text().includes('Email verified'));
  assert.equal(ui.document.querySelector('input[type="email"]'),null);
  assert.equal(ui.document.querySelector('select'),null);
  ui.fill('Display name','Updated fixture');ui.click('Save account');await until(()=>ui.text().includes('Account profile saved.'));
  await until(()=>ui.find('Updated fixture'));
  assert.deepEqual(ui.calls.find(c=>c.name==='save_account_profile').body,{display_name:'Updated fixture'});
  ui.click('Close account');await until(()=>!ui.document.querySelector('[placeholder="Display name"]'));
  ui.click('Account');await until(()=>ui.document.querySelector('[placeholder="Display name"]')?.value==='Updated fixture');
  ui.fill('Display name','Not saved');ui.click('Cancel changes');
  await until(()=>ui.document.querySelector('[placeholder="Display name"]')?.value==='Updated fixture');
  assert.equal(ui.calls.filter(c=>c.name==='save_account_profile').length,1);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('account rejection preserves input and allows a successful retry',async()=>{
 let attempts=0;
 const profile={ok:true,message:'',display_name:'Fixture student',email:'fixture@umich.edu',role:'student',email_verified:true,is_demo:false};
 const ui=await app({verified:true,intercept(name,body){
  if(name==='get_account_profile')return rpc(profile);
  if(name==='save_account_profile')return rpc(++attempts===1?{...profile,ok:false,message:'Fixture save rejected.'}:{...profile,display_name:body.display_name,message:'Account profile saved.'});
 }});
 try{
  ui.click('Account');await until(()=>ui.document.querySelector('[placeholder="Display name"]')?.value==='Fixture student');
  ui.fill('Display name','Kept name');ui.click('Save account');await until(()=>ui.text().includes('Fixture save rejected.'));
  assert.equal(ui.document.querySelector('[placeholder="Display name"]').value,'Kept name');
  assert.equal(ui.find('Save account').disabled,false);
  ui.click('Save account');await until(()=>ui.text().includes('Account profile saved.'));
  assert.equal(attempts,2);assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('saved business application reopens for editing with honest pending access',async()=>{
 const draft={ok:true,name:'Saved fixture cafe',address:'123 Fixture Street',status:'pending_review',message:''};
 const ui=await app({role:'business',verified:true,intercept(name){if(name==='get_business_draft')return rpc(draft);}});
 try{
  ui.click('Business profile');await until(()=>ui.document.querySelector('[placeholder="Business name"]')?.value==='Saved fixture cafe');
  assert.ok(ui.text().includes('Pending review'));
  assert.equal(ui.find('New offer'),undefined);assert.equal(ui.find('Manage'),undefined);
  ui.click('Close business profile');await until(()=>!ui.document.querySelector('[placeholder="Business name"]'));
  ui.click('Business profile');await until(()=>ui.document.querySelector('[placeholder="Business name"]')?.value==='Saved fixture cafe');
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('offer validation blocks invalid prices and confirmed publication appears in the refreshed list',async()=>{
 let posted=null;
 const ui=await app({role:'merchant',intercept(name,body){
  if(name==='save_offer'){posted=offer({id:'new-post',title:body.title,price:Number(body.price)});return rpc({ok:true,message:'Offer published.',code:'new-post'});}
  if(name==='merchant_portal'&&posted)return rpc({ok:true,name:'Fixture Kitchen',cuisine:'Test cuisine',blurb:'Fixture profile',address:'Test address',neighborhood:'Test area',entrance_note:'',note_date:'',offers:[posted],claims:[],is_demo:true,message:''});
  if(name==='list_offers'&&posted)return rpc([posted]);
 }});
 try{
  ui.click('Manage');await until(()=>ui.find('New offer'));ui.click('New offer');
  await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  ui.fill('Lunch bowl for $7','Posted fixture lunch');ui.fill('7.00','7.123');
  ui.click('Publish offer');await until(()=>ui.text().includes('at most two decimal places'));
  assert.equal(ui.calls.some(c=>c.name==='save_offer'),false);
  ui.fill('7.00','7.25');ui.fill('One per student. Dine-in only.','One per student.');ui.click('Publish offer');await until(()=>ui.find('Posted fixture lunch'));
  assert.equal(ui.document.querySelector('[placeholder="Lunch bowl for $7"]'),null);
  assert.equal(ui.calls.filter(c=>c.name==='save_offer').length,1);
  ui.click('Offers');await until(()=>ui.find('Posted fixture lunch'));
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('rejected offer publication preserves every entered value and remains editable',async()=>{
 const ui=await app({role:'merchant',intercept(name){if(name==='save_offer')return rpc({ok:false,message:'Fixture publication rejected.',code:''});}});
 try{
  ui.click('Manage');await until(()=>ui.find('New offer'));ui.click('New offer');await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  ui.fill('Lunch bowl for $7','Keep this lunch');ui.fill('7.00','6.50');ui.fill('One per student. Dine-in only.','Keep these terms');ui.click('Publish offer');
  await until(()=>ui.text().includes('Fixture publication rejected.'));
  assert.equal(ui.document.querySelector('[placeholder="Lunch bowl for $7"]').value,'Keep this lunch');
  assert.equal(ui.document.querySelector('[placeholder="7.00"]').value,'6.50');
  assert.equal(ui.document.querySelector('[placeholder="One per student. Dine-in only."]').value,'Keep these terms');
  assert.equal(ui.find('Publish offer').disabled,false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('business load failure blocks overwriting a saved application until retry succeeds',async()=>{
 let reads=0;
 const ui=await app({role:'business',verified:true,intercept(name){if(name==='get_business_draft')return rpc(++reads===1?{ok:false,message:'Fixture load failed.'}:{ok:true,name:'Retained cafe',address:'123 Fixture Street',status:'pending_review'});}});
 try{
  ui.click('Business profile');await until(()=>ui.text().includes('Fixture load failed.'));
  assert.equal(ui.document.querySelector('[placeholder="Business name"]').disabled,true);
  ui.click('Retry business profile');await until(()=>ui.document.querySelector('[placeholder="Business name"]')?.value==='Retained cafe');
  assert.equal(ui.document.querySelector('[placeholder="Business name"]').disabled,false);
  assert.equal(ui.calls.some(c=>c.name==='save_business_draft'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('merchant profile cancellation restores saved details without sending a write',async()=>{
 const ui=await app({role:'merchant'});
 try{
  ui.click('Manage');await until(()=>ui.document.querySelector('[placeholder="Restaurant name"]')?.value==='Fixture Kitchen');
  ui.fill('Restaurant name','Unsaved name');ui.click('Cancel profile changes');
  await until(()=>ui.document.querySelector('[placeholder="Restaurant name"]')?.value==='Fixture Kitchen');
  assert.equal(ui.calls.some(c=>c.name==='update_profile'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('editing an offer keeps absent regular price optional and uses save changes',async()=>{
 const ui=await app({role:'merchant',item:offer({regular_price:0,state:'paused'})});
 try{
  ui.click('Manage');await until(()=>ui.find('Edit'));ui.click('Edit');await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  assert.equal(ui.document.querySelector('[placeholder="11.50"]').value,'');
  assert.equal(ui.find('Publish offer'),undefined);
  ui.fill('Lunch bowl for $7','Updated paused lunch');ui.click('Save changes');await until(()=>ui.text().includes('Fixture offer saved'));
  assert.equal(ui.calls.find(c=>c.name==='save_offer').body.offer_id,'fixture-offer');
  assert.equal(ui.calls.find(c=>c.name==='save_offer').body.regular_price,'');
  assert.equal(ui.calls.some(c=>c.name==='set_offer_status'),false);
  assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('unsaved offer details survive moving between Offers and Manage',async()=>{
 const ui=await app({role:'merchant'});
 try{
  ui.click('Manage');await until(()=>ui.find('New offer'));ui.click('New offer');await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  ui.fill('Lunch bowl for $7','Retain this draft');ui.fill('7.00','6.75');ui.fill('One per student. Dine-in only.','Keep draft terms');
  ui.click('Offers');await until(()=>!ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  ui.click('Manage');await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  assert.equal(ui.document.querySelector('[placeholder="Lunch bowl for $7"]').value,'Retain this draft');
  assert.equal(ui.document.querySelector('[placeholder="7.00"]').value,'6.75');
  assert.equal(ui.document.querySelector('[placeholder="One per student. Dine-in only."]').value,'Keep draft terms');
  assert.equal(ui.calls.some(c=>c.name==='save_offer'),false);assert.deepEqual(ui.errors,[]);
 }finally{ui.close();}
});

test('pending publication blocks navigation and repeat submission until confirmed',async()=>{
 let release;const pending=new Promise(resolve=>{release=resolve;});
 const ui=await app({role:'merchant',intercept:async(name)=>{if(name==='save_offer'){await pending;return rpc({ok:true,message:'Deferred publication complete.',code:'new-post'});}}});
 try{
  ui.click('Manage');await until(()=>ui.find('New offer'));ui.click('New offer');await until(()=>ui.document.querySelector('[placeholder="Lunch bowl for $7"]'));
  ui.fill('Lunch bowl for $7','Publish only once');ui.fill('7.00','6.75');ui.fill('One per student. Dine-in only.','One per student.');ui.click('Publish offer');
  await until(()=>ui.calls.some(c=>c.name==='save_offer'));
  ui.click('Offers');ui.click('Saving...');
  assert.ok(ui.document.querySelector('[placeholder="Lunch bowl for $7"]'),'keep the composer mounted while the write is pending');
  assert.equal(ui.calls.filter(c=>c.name==='save_offer').length,1);
  release();await until(()=>ui.text().includes('Deferred publication complete.'));
  assert.equal(ui.document.querySelector('[placeholder="Lunch bowl for $7"]'),null);
  assert.equal(ui.calls.filter(c=>c.name==='save_offer').length,1);assert.deepEqual(ui.errors,[]);
 }finally{release();ui.close();}
});

test('merchant profile fields prevent newer edits being overwritten by a pending save',async()=>{
 let release;const pending=new Promise(resolve=>{release=resolve;});
 const ui=await app({role:'merchant',intercept:async(name)=>{if(name==='update_profile')await pending;}});
 try{
  ui.click('Manage');await until(()=>ui.document.querySelector('[placeholder="Restaurant name"]'));
  ui.fill('Restaurant name','Submitted name');ui.click('Save profile');await until(()=>ui.calls.some(c=>c.name==='update_profile'));
  const inputs=[...ui.document.querySelectorAll('[placeholder="Restaurant name"],[placeholder="Noodles"],[placeholder="Short description"],[placeholder="Street address"],[placeholder="Kerrytown"],[placeholder="Use the side door while sidewalk work continues"],[placeholder="2026-09-26"]')];
  assert.equal(inputs.length,7);assert.ok(inputs.every(input=>input.readOnly),'the submitted profile must stay unchanged until its response arrives');
  release();await until(()=>!ui.document.querySelector('[placeholder="Restaurant name"]').readOnly);
  assert.deepEqual(ui.errors,[]);
 }finally{release();ui.close();}
});
