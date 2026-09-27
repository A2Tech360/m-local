import React, {useEffect, useRef, useState} from 'react';
import {QRCodeSVG} from 'qrcode.react';
import {BrowserQRCodeReader} from '@zxing/browser';
import {createScanController, isClaimPayload} from './scan-controller.mjs';

const box = {display:'flex',flexDirection:'column',gap:12,color:'#28221d',fontFamily:'inherit'};
const button = {minHeight:46,padding:'12px 16px',borderRadius:12,border:'1px solid #dad3c8',background:'#b24a2f',color:'#fff',fontSize:15,fontWeight:700,cursor:'pointer'};
const secondary = {...button,background:'#fff',color:'#28221d'};
const price = cents => '$'+(cents/100).toFixed(2);

// Browser-only React bridge: MobUI has no video capture primitive.
export function ClaimQr({payload, expiresTs}) {
  const [now,setNow] = useState(Date.now()/1000);
  useEffect(() => {const timer=setInterval(()=>setNow(Date.now()/1000),1000);return ()=>clearInterval(timer);},[]);
  if (!isClaimPayload(payload)) return <p role="alert">This claim QR is unavailable. Refresh the offer to try again.</p>;
  if (!expiresTs || now >= expiresTs) return <p role="status">This hold has expired. Refresh the offer to check availability.</p>;
  return <div style={{background:'#fff',padding:12,borderRadius:12,alignSelf:'center',width:'100%',maxWidth:264,boxSizing:'border-box'}}>
    <QRCodeSVG value={payload} size={240} level="M" marginSize={4} title="Show this M-Local claim QR to the restaurant" style={{display:'block',width:'100%',maxWidth:240,height:'auto'}} />
  </div>;
}

export function ClaimScanner({resolveClaim, redeemClaim, onRedeemed}) {
  const video = useRef(null), controller = useRef(null), callbacks = useRef({resolveClaim,redeemClaim,onRedeemed});
  callbacks.current = {resolveClaim,redeemClaim,onRedeemed};
  const [state,setState] = useState({phase:'idle',message:'',preview:null});
  useEffect(() => {
    const reader = new BrowserQRCodeReader();
    const instance = createScanController({
      secure: window.isSecureContext,
      requestStream: navigator.mediaDevices?.getUserMedia ? () => navigator.mediaDevices.getUserMedia({audio:false,video:{facingMode:{ideal:'environment'}}}) : null,
      decode: (stream,element,callback) => reader.decodeFromStream(stream,element,callback),
      resolveClaim: value => callbacks.current.resolveClaim(value),
      redeemClaim: value => callbacks.current.redeemClaim(value),
      onRedeemed: () => callbacks.current.onRedeemed?.()
    },setState);
    controller.current=instance;
    const hide = () => {if (document.hidden && ['requesting','scanning','resolving'].includes(instance.state.phase)) instance.cancel();};
    const leave = () => instance.cancel();
    document.addEventListener('visibilitychange',hide); window.addEventListener('pagehide',leave);
    return () => {document.removeEventListener('visibilitychange',hide);window.removeEventListener('pagehide',leave);instance.dispose();controller.current=null;};
  },[]);
  const active=['requesting','scanning','resolving'].includes(state.phase), confirming=state.phase==='redeeming';
  return <section aria-label="Scan a student claim" style={box}>
    <p style={{margin:0,lineHeight:1.5}}>Scan the student’s QR, review the saved offer, then confirm redemption.</p>
    <video ref={video} muted playsInline aria-label="QR camera preview" style={{width:'100%',maxHeight:320,background:'#171513',borderRadius:12,display:active?'block':'none'}} />
    {state.message && <p role={state.phase==='error'?'alert':'status'} aria-live="polite" style={{margin:0,lineHeight:1.5}}>{state.message}</p>}
    {state.preview && <div style={{...box,background:'#f3f0e9',padding:16,borderRadius:12}}>
      <strong>{state.preview.title_snapshot}</strong>
      <strong style={{fontSize:26}}>{price(state.preview.price_cents)}</strong>
      <span>{state.preview.restaurant}</span>
      <span>For: {state.preview.eligibility || 'See restaurant conditions.'}</span>
      <span>{state.preview.terms || 'No additional terms.'}</span>
      <span>Hold expires {state.preview.expires_label}.</span>
      <small>Prices exclude tax unless the saved terms say otherwise. Check the stated ID requirement.</small>
      <button style={button} type="button" disabled={confirming} onClick={()=>controller.current?.confirm()}>{confirming?'Confirming…':'Confirm redemption'}</button>
    </div>}
    {!active && !state.preview && <button style={button} type="button" onClick={()=>controller.current?.start(video.current)}>{state.phase==='success'?'Scan next claim':state.phase==='error'?'Retry camera scan':'Start camera scan'}</button>}
    {(active || state.preview) && <button style={secondary} type="button" disabled={confirming} onClick={()=>controller.current?.cancel()}>Cancel scan</button>}
    <small style={{lineHeight:1.5}}>Camera access needs permission. A remote phone needs HTTPS; localhost on the merchant laptop is the first camera test path.</small>
  </section>;
}
