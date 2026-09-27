import React, {useEffect, useRef, useState} from 'react';
import {BrandLogo, uiFont, formStack, formInput, formButton, formSecondary, formHint} from './ui.jsx';

const stack=formStack;
const input=formInput;
const button=formButton;
const secondary=formSecondary;
const hint=formHint;
const label={...stack,gap:6,fontSize:14,fontWeight:600};
function Notice({children}) {return children ? <p role="status" aria-live="polite" style={{...hint,color:'#02305C'}}>{children}</p>:null;}
function Input({title,...props}) {return <label style={label}>{title}<input style={input} {...props}/></label>;}

export function audienceForSession(session) {
 if(!session?.authenticated)return '';
 return session.role==='student'?'student':['business','merchant'].includes(session.role)?'business':'';
}

export function AudienceWelcome({onChoose}) {
 const choice={...secondary,textAlign:'left',padding:'22px 20px',display:'flex',alignItems:'center',justifyContent:'space-between',gap:16,borderRadius:20};
 return <main style={{height:'100%',overflowY:'auto',background:'#F9F6F0',fontFamily:uiFont,color:'#0B1F38'}}>
  <style>{'.mlocal-choice:focus-visible{outline:3px solid #02305C;outline-offset:4px}.mlocal-choice:hover{filter:brightness(.97)}'}</style>
  <div style={{...stack,boxSizing:'border-box',minHeight:'100%',maxWidth:480,margin:'0 auto',padding:'36px 24px',justifyContent:'center',gap:28}}>
   <BrandLogo/>
   <header style={{...stack,gap:12}}>
    <p style={{...hint,fontWeight:700}}>Welcome to M-Local</p>
    <h1 style={{fontSize:38,lineHeight:1.04,letterSpacing:-1.2,margin:0,fontWeight:900}}>Good things are happening nearby.</h1>
    <p style={{...hint,fontSize:17}}>How will you join in?</p>
   </header>
   <div style={{...stack,gap:12}}>
    <button className="mlocal-choice ml-welcome-choice" type="button" style={{...choice,background:'#02305C',borderColor:'#02305C',color:'#fff'}} onClick={()=>onChoose('student')}>
     <span style={{...stack,gap:8,color:'inherit'}}><span style={{fontSize:21,fontWeight:750}}>Find local deals</span><span style={{fontSize:14,lineHeight:1.5,fontWeight:400}}>Join with your U-M email.<br/>Discover offers from local favorites.</span></span><span aria-hidden="true" style={{fontSize:26}}>→</span>
    </button>
    <button className="mlocal-choice ml-welcome-choice" type="button" style={choice} onClick={()=>onChoose('business')}>
     <span style={{...stack,gap:8,color:'inherit'}}><span style={{fontSize:21,fontWeight:750}}>List my business</span><span style={{fontSize:14,lineHeight:1.5,fontWeight:400}}>Create your business profile.<br/>Connect with the U-M community.</span></span><span aria-hidden="true" style={{fontSize:26}}>→</span>
    </button>
   </div>
  </div>
 </main>;
}

export function EmailOnboarding({kind='student',initialMode='signin',onSwitchAudience,requestCode,verifyCode,onVerified,onCancel,cancelLabel='Back',inputRef}) {
 const [name,setName]=useState(''),[value,setValue]=useState(''),[mode,setMode]=useState(initialMode);
 const [code,setCode]=useState(''),[challenge,setChallenge]=useState(null),[message,setMessage]=useState('');
 const [busy,setBusy]=useState(false),[cooldown,setCooldown]=useState(0);
 const mounted=useRef(true),inFlight=useRef(false),codeRef=useRef(null),emailRef=useRef(null),revision=useRef(0),previousKind=useRef(kind);
 const quiet={border:0,background:'transparent',padding:'6px 0',minHeight:36,color:'#02305C',font:'700 13px Figtree, system-ui',cursor:'pointer',textDecoration:'underline',textUnderlineOffset:3};
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;revision.current++;};},[]);
 useEffect(()=>{if(previousKind.current===kind)return;previousKind.current=kind;revision.current++;inFlight.current=false;setBusy(false);setValue('');setCode('');setChallenge(null);setMessage('');setCooldown(0);},[kind]);
 useEffect(()=>{if(cooldown<=0)return;const timer=setTimeout(()=>setCooldown(v=>Math.max(0,v-1)),1000);return()=>clearTimeout(timer);},[cooldown]);
 useEffect(()=>{if(challenge)codeRef.current?.focus();else (inputRef?.current||emailRef.current)?.focus();},[challenge,kind]);
 async function run(action){
  if(inFlight.current)return;inFlight.current=true;setBusy(true);setMessage('');
  const ticket=revision.current, current=()=>mounted.current&&ticket===revision.current;
  try{await action(current);}catch{if(current())setMessage('Could not connect. Your entries are kept; please try again.');}
  finally{if(current()){inFlight.current=false;setBusy(false);}}
 }
 async function send(){await run(async current=>{const reply=await requestCode(value.trim(),kind,mode==='signup'?name.trim():'');if(!current())return;setMessage(reply.ok?'':reply.message);if(reply.ok){setChallenge(reply);setCode('');setCooldown(reply.retry_after||60);}});}
 async function verify(){await run(async current=>{const reply=await verifyCode(challenge.challenge,code);if(!current())return;if(!reply.ok){setMessage(reply.message);return;}await onVerified(reply.token);});}
 function switchMode(){setMode(mode==='signup'?'signin':'signup');setMessage('');}
 return <form aria-label={challenge?'Verify your email':mode==='signup'?'Create an account':'Sign in'} className="ml-auth" style={{...stack,gap:20}} onSubmit={e=>{e.preventDefault();challenge?verify():send();}}>
  <style>{'.ml-auth button:focus-visible,.ml-auth select:focus-visible,.ml-auth input:focus-visible{outline:3px solid #02305C;outline-offset:3px}.ml-auth button:disabled{opacity:.55;cursor:default}.ml-auth select{max-width:100%}'}</style>
  <header style={{display:'flex',alignItems:'flex-start',justifyContent:'space-between',gap:16}}>
   <div style={{...stack,gap:8}}>
    {!challenge&&<select aria-label="Account type" value={kind} disabled={busy} onChange={e=>onSwitchAudience(e.target.value)} style={{font:'700 13px Figtree, system-ui',color:'#5F6B7A',border:'1px solid #DDD5C7',borderRadius:6,background:'#F9F6F0',padding:'7px 9px'}}><option value="student">U-M student</option><option value="business">Business</option></select>}
    <h3 style={{fontSize:26,lineHeight:1.2,margin:0}}>{challenge?'Check your email':mode==='signup'?'Create your account':'Sign in'}</h3>
   </div>
   <button style={{...quiet,whiteSpace:'nowrap',color:'#5F6B7A'}} type="button" disabled={busy} onClick={onCancel}>{cancelLabel}</button>
  </header>
  {!challenge ? <>
   <p style={hint}>{mode==='signup'?'Start with your name and email. We’ll send a code to verify it.':'Enter your email. We’ll send a code to sign you in.'}</p>
   {mode==='signup'&&<Input title="Your name" placeholder="Your name" autoComplete="name" maxLength={80} value={name} onChange={e=>setName(e.target.value)} required disabled={busy}/>}
   {kind==='student' ? <label style={label}>U-M email
    <div style={{display:'flex',border:'1px solid #DDD5C7',borderRadius:10,overflow:'hidden',minWidth:0}}>
     <input ref={inputRef||emailRef} aria-label="U-M uniqname" aria-describedby="umich-email-help" style={{...input,border:0,borderRadius:0,flex:1}} placeholder="uniqname" autoComplete="username" autoCapitalize="none" autoCorrect="off" spellCheck={false} pattern="[A-Za-z][A-Za-z0-9]{1,31}" maxLength={32} value={value} onChange={e=>setValue(e.target.value)} required disabled={busy}/>
     <span style={{padding:'13px 10px',background:'#EFE9DE',color:'#5F6B7A',fontWeight:500,whiteSpace:'nowrap'}}>@umich.edu</span>
    </div><span id="umich-email-help" style={hint}>Use your uniqname. No university password needed.</span>
   </label> : <label style={label}>Work email<input ref={inputRef||emailRef} style={input} placeholder="you@business.com" type="email" autoComplete="email" maxLength={254} value={value} onChange={e=>setValue(e.target.value)} required disabled={busy}/></label>}
   <Notice>{message}</Notice>
   <button type="submit" style={button} disabled={busy}>{busy?'Sending...':'Send verification code'}</button>
   <p style={{...hint,textAlign:'center'}}>{mode==='signup'?'Already registered? ':'New here? '}<button style={quiet} type="button" disabled={busy} onClick={switchMode}>{mode==='signup'?'Sign in':'Create an account'}</button></p>
  </> : <>
   <p style={hint}>Enter the 6-digit code sent to <strong>{challenge.email}</strong>.</p>
   <label style={label}>Verification code<input ref={codeRef} style={{...input,letterSpacing:10,fontSize:28,fontVariantNumeric:'tabular-nums',textAlign:'center',minHeight:64}} aria-label="Verification code" placeholder="123456" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={code} onChange={e=>setCode(e.target.value.replace(/\D/g,''))} required disabled={busy}/></label>
   <Notice>{message}</Notice>
   <button type="submit" style={button} disabled={busy}>{busy?'Verifying...':'Verify and continue'}</button>
   <div style={{display:'flex',justifyContent:'space-between',gap:16,flexWrap:'wrap'}}>
    <button style={quiet} type="button" disabled={busy} onClick={()=>{setChallenge(null);setCode('');setMessage('');}}>Change email</button>
    <button style={quiet} type="button" disabled={busy||cooldown>0} onClick={send}>{cooldown>0?`Resend code in ${cooldown}s`:'Resend code'}</button>
   </div><p style={hint}>The code expires in 10 minutes.</p>
  </>}
 </form>;
}

const empty={name:'',cuisine:'',description:'',address:'',website:'',menu_text:'',menu_url:'',image_url:'',status:'draft',image_urls:[],menu_urls:[],sources:[]};
export function BusinessOnboarding({getDraft,importWebsite,saveDraft,onActivated}) {
 const [draft,setDraft]=useState(empty),[message,setMessage]=useState(''),[busy,setBusy]=useState(false),[confirmed,setConfirmed]=useState(false),[ready,setReady]=useState(false),[loadFailed,setLoadFailed]=useState(false);
 const mounted=useRef(true),inFlight=useRef(false),edited=useRef(false);
 async function load(){
  if(inFlight.current)return;inFlight.current=true;setReady(false);setLoadFailed(false);setMessage('');
  try{const reply=await getDraft();if(!mounted.current)return;if(reply.ok){setDraft({...empty,...reply});setReady(true);}else{setLoadFailed(true);setMessage(reply.message||'Could not load your saved profile.');}}
  catch{if(mounted.current){setLoadFailed(true);setMessage('Could not load your saved profile. Retry before making changes.');}}
  finally{inFlight.current=false;}
 }
 useEffect(()=>{mounted.current=true;load();return()=>{mounted.current=false;};},[]);
 const field=(key,value)=>{edited.current=true;setDraft(d=>({...d,[key]:value,status:'draft'}));setConfirmed(false);};
 async function openManagement(){
  try{const opened=await onActivated();if(!opened&&mounted.current)setMessage('Your business profile was saved, but offer management could not be opened. Check your connection and try Open offer management.');}
  catch{if(mounted.current)setMessage('Your business profile was saved, but offer management could not be opened. Check your connection and try Open offer management.');}
 }
 async function retryManagement(){
  if(inFlight.current)return;inFlight.current=true;setBusy(true);setMessage('');
  try{await openManagement();}finally{inFlight.current=false;if(mounted.current)setBusy(false);}
 }
 async function run(action,activate=false){if(inFlight.current)return;inFlight.current=true;setBusy(true);setMessage('');try{const reply=await action();if(!mounted.current)return;if(reply.ok){setDraft({...empty,...reply});setConfirmed(false);}setMessage(reply.message);if(reply.ok&&reply.status==='active'&&activate)await openManagement();}catch{if(mounted.current)setMessage('Could not connect. Your entries are kept; please retry.');}finally{inFlight.current=false;if(mounted.current)setBusy(false);}}
 const imported=()=>run(()=>importWebsite(draft.website));
 return <section aria-label="Create your business profile" style={{...stack,paddingTop:16,borderTop:'1px solid #DDD5C7'}}>
  <h3 style={{margin:0,fontSize:20}}>{draft.name?'Your business profile':'Bring your business to M-Local'}</h3>
  {draft.status==='pending_review'&&<p role="status" style={hint}>Your saved details are here. Save your business profile to start posting.</p>}
  {draft.status==='active'&&<><p role="status" style={hint}>Your business profile is saved.</p><button style={secondary} type="button" disabled={busy} onClick={retryManagement}>{busy?'Opening offer management...':'Open offer management'}</button></>}
  {!ready&&!loadFailed&&<p role="status" style={hint}>Loading your business profile...</p>}
  {loadFailed&&<button style={secondary} type="button" onClick={load}>Retry business profile</button>}
  <p style={hint}>Start with your website. We’ll find details, menu links and image options for you to review. You can also fill this in yourself.</p>
  <form style={stack} onSubmit={e=>{e.preventDefault();imported();}}>
   <Input title="Business website" placeholder="https://your-business.com" type="url" value={draft.website} onChange={e=>field('website',e.target.value)} disabled={busy||!ready} required/>
   <button style={secondary} disabled={busy||!ready}>{busy?'Working...':'Import website details'}</button>
  </form>
  <Notice>{message}</Notice>
  {draft.sources.length>0&&<div style={hint}>Sources: {draft.sources.map((url,i)=><React.Fragment key={url}>{i>0?' · ':''}<a href={url} target="_blank" rel="noopener noreferrer">{i===0?'Website':'Menu page'}</a></React.Fragment>)}</div>}
  <form style={stack} onSubmit={e=>{e.preventDefault();run(()=>saveDraft(draft.name,draft.cuisine,draft.description,draft.address,draft.website,draft.menu_text,draft.menu_url,draft.image_url,confirmed),true);}}>
   <Input title="Business name" placeholder="Business name" maxLength={120} value={draft.name} onChange={e=>field('name',e.target.value)} required disabled={busy||!ready}/>
   <Input title="Cuisine" placeholder="Cuisine" maxLength={80} value={draft.cuisine} onChange={e=>field('cuisine',e.target.value)} disabled={busy||!ready}/>
   <Input title="Street address" placeholder="Street address" maxLength={240} value={draft.address} onChange={e=>field('address',e.target.value)} required disabled={busy||!ready}/>
   <label style={label}>About your business<textarea style={{...input,minHeight:90,resize:'vertical'}} placeholder="About your business" maxLength={1000} value={draft.description} onChange={e=>field('description',e.target.value)} disabled={busy||!ready}/></label>
   <label style={label}>Menu notes to review<textarea style={{...input,minHeight:120,resize:'vertical'}} placeholder="Menu items and prices" maxLength={4000} value={draft.menu_text} onChange={e=>field('menu_text',e.target.value)} disabled={busy||!ready}/></label>
   <p style={hint}>Check item names and prices against your current menu. These notes do not create offers.</p>
   {draft.menu_urls.length>0&&<label style={label}>Found menu links<select style={input} value={draft.menu_url} onChange={e=>field('menu_url',e.target.value)} disabled={busy}><option value="">Choose a menu link</option>{draft.menu_urls.map(url=><option key={url} value={url}>{url}</option>)}</select></label>}
   <Input title="Menu link" placeholder="https://your-business.com/menu" type="url" maxLength={2048} value={draft.menu_url} onChange={e=>field('menu_url',e.target.value)} disabled={busy||!ready}/>
   {draft.image_urls.length>0&&<label style={label}>Found images<select style={input} value={draft.image_url} onChange={e=>field('image_url',e.target.value)} disabled={busy}><option value="">Choose an image</option>{draft.image_urls.map(url=><option key={url} value={url}>{url}</option>)}</select></label>}
   <Input title="Image link" placeholder="https://your-business.com/photo.jpg" type="url" maxLength={2048} value={draft.image_url} onChange={e=>field('image_url',e.target.value)} disabled={busy||!ready}/>
   {draft.image_url&&/^https:\/\//.test(draft.image_url)&&<a href={draft.image_url} target="_blank" rel="noopener noreferrer" style={hint}>Review selected image</a>}
   <label style={{...hint,display:'flex',gap:10,alignItems:'flex-start',minHeight:44}}><input type="checkbox" checked={confirmed} onChange={e=>setConfirmed(e.target.checked)} disabled={busy||!ready} style={{width:20,height:20,flexShrink:0}}/>I can represent this business and have permission to use the details and selected image.</label>
   <button style={button} disabled={busy||!ready||!confirmed}>{busy?'Saving...':'Save business profile'}</button>
   <p style={hint}>Save your business profile to start posting. You can then create offers and edit your business details from Manage.</p>
  </form>
 </section>;
}
