import React, {useEffect, useRef, useState} from 'react';

const stack={display:'flex',flexDirection:'column',gap:12,minWidth:0,fontFamily:'system-ui, sans-serif',color:'#1d1a16'};
const input={boxSizing:'border-box',width:'100%',minWidth:0,minHeight:48,padding:12,fontSize:16,border:'1px solid #c9bfb2',borderRadius:10,background:'#fff',color:'#1d1a16'};
const button={...input,cursor:'pointer',fontWeight:700};
const hint={margin:0,fontSize:13,lineHeight:1.5,color:'#6b6157'};

export function AccountProfile({getProfile,saveProfile,onSaved}) {
 const [profile,setProfile]=useState(null),[name,setName]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true),[message,setMessage]=useState(''),[failed,setFailed]=useState(false);
 const mounted=useRef(false),inFlight=useRef(false);
 async function load(){
  if(inFlight.current)return;inFlight.current=true;setLoading(true);setMessage('');setFailed(false);
  try{const reply=await getProfile();if(!mounted.current)return;if(!reply.ok){setFailed(true);setMessage(reply.message||'Could not load your account.');return;}setProfile(reply);setName(reply.display_name||'');}
  catch{if(mounted.current){setFailed(true);setMessage('Could not load your account. Check your connection and retry.');}}
  finally{inFlight.current=false;if(mounted.current)setLoading(false);}
 }
 useEffect(()=>{mounted.current=true;load();return()=>{mounted.current=false;};},[]);
 async function save(event){
  event.preventDefault();if(inFlight.current)return;
  const clean=name.trim();if(!clean||clean.length>80){setFailed(true);setMessage('Enter a display name between 1 and 80 characters.');return;}
  inFlight.current=true;setBusy(true);setFailed(false);setMessage('');
  try{
   const reply=await saveProfile(clean);if(!mounted.current)return;
   if(!reply.ok){setFailed(true);setMessage(reply.message||'Your account could not be saved.');return;}
   setProfile(reply);setName(reply.display_name);setMessage(reply.message||'Account profile saved.');
   await onSaved(reply.display_name);
  }catch{if(mounted.current){setFailed(true);setMessage('Could not save your account. Your entries are kept; check the connection and retry.');}}
  finally{inFlight.current=false;if(mounted.current)setBusy(false);}
 }
 return <section aria-label="Account profile" style={{...stack,paddingTop:16,borderTop:'1px solid #e7dfd3'}}>
  <h3 style={{fontSize:20,margin:0}}>Account profile</h3>
  {loading?<p role="status" style={hint}>Loading your account...</p>:profile?<form style={stack} onSubmit={save} noValidate>
   <label style={{...stack,gap:6,fontSize:14,fontWeight:600}}>Display name<input style={input} placeholder="Display name" autoComplete="name" value={name} maxLength={80} required disabled={busy} onChange={e=>setName(e.target.value)}/></label>
   <div style={stack}><div><strong style={{fontSize:14}}>Email</strong><p style={{...hint,overflowWrap:'anywhere'}}>{profile.email||'Not available for this account'}</p></div>
    <p style={hint}>{profile.email_verified?'Email verified':'Email not verified'}{profile.is_demo?' · Provisioned demo account':''}</p>
    <p style={hint}>{profile.role==='merchant'?'Approved merchant':profile.role==='business'?'Business account · approval required before posting':profile.role==='student'?'U-M customer account':'Account access'}<br/>Your email and account access are managed by the sign-in service.</p>
   </div>
   <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
    <button style={{...button,flex:'1 1 160px',background:'#b83a0b',borderColor:'#b83a0b',color:'#fff'}} disabled={busy||name.trim()===(profile.display_name||'')}>{busy?'Saving account...':'Save account'}</button>
    <button style={{...button,flex:'1 1 160px'}} type="button" disabled={busy} onClick={()=>{setName(profile.display_name||'');setMessage('');setFailed(false);}}>Cancel changes</button>
   </div>
  </form>:<button style={button} type="button" onClick={load}>Retry account</button>}
  {message&&<p role={failed?'alert':'status'} aria-live="polite" style={{...hint,color:failed?'#9d2c13':'#1f3a5f'}}>{message}</p>}
 </section>;
}
