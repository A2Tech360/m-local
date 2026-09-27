import React, {useEffect, useRef, useState} from 'react';
import {formStack, formInput, formSecondary, formHint} from './ui.jsx';

const stack=formStack;
const input=formInput;
const button=formSecondary;
const hint=formHint;
const row={display:'grid',gridTemplateColumns:'repeat(auto-fit,minmax(min(100%,180px),1fr))',gap:12};

function validate(d){
 if(!d.title.trim())return 'Add an offer title so customers know what they get.';
 if(!/^\d+(\.\d{1,2})?$/.test(d.price)||Number(d.price)>9999.99)return 'Enter an offer price from 0 to 9999.99 with at most two decimal places.';
 if(d.regular_price&&(!/^\d+(\.\d{1,2})?$/.test(d.regular_price)||Number(d.regular_price)>9999.99||Number(d.regular_price)<Number(d.price)))return 'Regular price must be at least the offer price, with at most two decimal places.';
 if(!d.start_local||!d.end_local||d.end_local<=d.start_local)return 'Choose an end time after the start time. Times are local to Ann Arbor.';
 if(!/^\d+$/.test(d.quantity)||Number(d.quantity)<1||Number(d.quantity)>10000)return 'Quantity must be a whole number from 1 to 10000.';
 if(!d.eligibility.trim()||!d.terms.trim())return 'Add eligibility and terms so customers know how to use this offer.';
 if(d.dietary.split(',').map(v=>v.trim().toLowerCase()).filter(Boolean).some(v=>!['vegetarian','vegan','gluten-free','halal'].includes(v)))return 'Use only these dietary tags: vegetarian, vegan, gluten-free, halal.';
 return '';
}

export function OfferEditor({initial,onDraftChange,onBusyChange,saveOffer,onSaved,onCancel}) {
 const draft={...initial,start_local:initial.start_local.replace(' ','T'),end_local:initial.end_local.replace(' ','T')};
 const [busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const mounted=useRef(true),inFlight=useRef(false),errorRef=useRef(null);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 const field=(key,value)=>onDraftChange({...draft,[key]:value});
 function showError(text){setMessage(text);requestAnimationFrame(()=>errorRef.current?.focus());}
 async function submit(event){
  event.preventDefault();if(inFlight.current)return;
  const invalid=validate(draft);if(invalid){showError(invalid);return;}
  inFlight.current=true;setBusy(true);onBusyChange(true);setMessage('');
  try{
   const reply=await saveOffer(draft.offer_id,draft.title.trim(),draft.description.trim(),draft.price,draft.regular_price,draft.start_local,draft.end_local,draft.quantity,draft.eligibility.trim(),draft.terms.trim(),draft.dietary,draft.menu_item.trim());
   if(!mounted.current)return;
   if(!reply.ok){showError(reply.message||'The offer could not be saved.');return;}
   await onSaved(reply.message||'Offer saved.');
  }catch{if(mounted.current)showError('Could not save the offer. Your entries are kept; check the connection and retry.');}
  finally{inFlight.current=false;if(mounted.current){setBusy(false);onBusyChange(false);}}
 }
 const text=(key,title,placeholder,maxLength,options={})=><label style={{...stack,gap:6,fontSize:14,fontWeight:600}}>{title}<input style={input} placeholder={placeholder} maxLength={maxLength} value={draft[key]} disabled={busy} onChange={e=>field(key,e.target.value)} {...options}/></label>;
 const multi=(key,title,placeholder)=><label style={{...stack,gap:6,fontSize:14,fontWeight:600}}>{title}<textarea style={{...input,minHeight:88,resize:'vertical'}} placeholder={placeholder} maxLength={2000} value={draft[key]} disabled={busy} onChange={e=>field(key,e.target.value)}/></label>;
 return <form aria-label={draft.offer_id?'Edit offer':'New offer'} style={stack} onSubmit={submit} noValidate>
  <h3 style={{fontSize:20,margin:0}}>{draft.offer_id?'Edit offer':'New offer'}</h3>
  <p style={hint}>{draft.offer_id?'Saving updates future claims. Existing claims keep their promised price, terms and expiry. Paused offers stay paused.':'Your offer appears publicly when you publish. A future start time schedules it. This form is not saved until you publish.'}</p>
  {text('title','Title *','Lunch bowl for $7',120,{required:true,autoFocus:true})}
  {multi('description','Description','What the student gets')}
  <div style={row}>{text('price','Offer price ($) *','7.00',10,{inputMode:'decimal',required:true})}{text('regular_price','Regular price ($), optional','11.50',10,{inputMode:'decimal'})}</div>
  <p style={hint}>Prices exclude tax unless your terms say otherwise. No payment is collected here.</p>
  <div style={row}>{text('start_local','Starts *','2026-09-26 11:00',30,{type:'datetime-local',required:true})}{text('end_local','Ends *','2026-09-26 14:00',30,{type:'datetime-local',required:true})}</div>
  <p style={hint}>Times are Ann Arbor local time (Eastern), even when you are traveling.</p>
  <div style={row}>{text('quantity','Quantity *','10',5,{inputMode:'numeric',required:true})}{text('menu_item','Menu item, optional','Veggie Dan Dan Noodles',120)}</div>
  {text('eligibility','Eligibility *','Students with a valid ID',300,{required:true})}
  {multi('terms','Terms *','One per student. Dine-in only.')}
  {text('dietary','Dietary tags, separated by commas','vegetarian, vegan, gluten-free, halal',200)}
  {message&&<p ref={errorRef} tabIndex={-1} role="alert" style={{...hint,color:'var(--ml-bad)'}}>{message}</p>}
  <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
   <button style={{...button,flex:'1 1 180px',background:'var(--ml-accent)',borderColor:'var(--ml-accent)',color:'var(--ml-accent-text)'}} disabled={busy}>{busy?'Saving...':draft.offer_id?'Save changes':'Publish offer'}</button>
   <button style={{...button,flex:'1 1 120px'}} disabled={busy} type="button" onClick={onCancel}>Cancel</button>
  </div>
 </form>;
}
