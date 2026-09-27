import React, {useLayoutEffect, useSyncExternalStore} from 'react';
import {createThemeStore} from './theme.mjs';

// Presentation only. Assets are served by Jac's built-in static asset route.
export const uiFont = 'Figtree, system-ui, sans-serif';
export const ui = {
  ink:'var(--ml-ink)', navy:'var(--ml-accent)', paper:'var(--ml-bg)', white:'var(--ml-surface)',
  muted:'var(--ml-muted)', line:'var(--ml-border)', inset:'var(--ml-sunken)', maize:'var(--ml-maize)',
  text:'var(--ml-text)', accentText:'var(--ml-accent-text)', accentSoft:'var(--ml-accent-soft)',
  good:'var(--ml-good)', goodSoft:'var(--ml-good-soft)', warn:'var(--ml-warn)', warnSoft:'var(--ml-warn-soft)',
  bad:'var(--ml-bad)', badSoft:'var(--ml-bad-soft)', focus:'var(--ml-focus)',
  ticket:'var(--ml-ticket)', ticketText:'var(--ml-ticket-text)', onMaize:'#0B1F38',
};
export const formStack = {display:'flex',flexDirection:'column',gap:16,minWidth:0,color:ui.ink,fontFamily:uiFont};
export const formInput = {width:'100%',minWidth:0,boxSizing:'border-box',minHeight:52,padding:'13px 14px',fontFamily:uiFont,fontSize:16,border:`1px solid ${ui.line}`,borderRadius:12,background:ui.white,color:ui.ink};
export const formButton = {...formInput,minHeight:54,background:ui.navy,color:ui.accentText,fontWeight:800,cursor:'pointer',borderColor:ui.navy,borderRadius:14};
export const formSecondary = {...formButton,background:ui.white,color:ui.navy,borderColor:ui.line};
export const formHint = {fontSize:13,lineHeight:1.5,margin:0,color:ui.muted};

// One subscription is shared by the foundation, every control and every logo.
const themeStore=createThemeStore(typeof window==='undefined'?undefined:window);
export function useTheme(){return useSyncExternalStore(themeStore.subscribe,themeStore.getSnapshot,themeStore.getSnapshot);}
export function ThemeControl(){
  const {preference}=useTheme();
  return <label style={{display:'flex',alignItems:'center',justifyContent:'space-between',gap:12,color:ui.muted,fontFamily:uiFont,fontSize:13,fontWeight:700}}>
    <span>Appearance</span>
    <select aria-label="Appearance" value={preference} onChange={event=>themeStore.setPreference(event.target.value)} style={{...formInput,width:'auto',minHeight:44,padding:'9px 12px',fontSize:14,fontWeight:600,cursor:'pointer'}}>
      <option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option>
    </select>
  </label>;
}
export function BrandLogo({reversed=false}) {
  const {resolved}=useTheme();
  return <img src={`/static/assets/brand/logo-${reversed||resolved==='dark'?'reversed':'compact'}.png`} alt="M Local" width="112" height="40" style={{display:'block',width:112,height:40,objectFit:'contain',flexShrink:0}}/>;
}

export function UiFoundation() {
  const {resolved}=useTheme();
  useLayoutEffect(()=>{
    document.documentElement.dataset.theme=resolved;
    document.documentElement.style.colorScheme=resolved;
  },[resolved]);
  return <style>{`
    @font-face{font-family:Figtree;src:url('/static/assets/brand/Figtree.ttf') format('truetype');font-style:normal;font-weight:300 900;font-display:swap}
    :root{--ml-bg:#F9F6F0;--ml-surface:#FFFFFF;--ml-sunken:#EFE9DE;--ml-border:#DDD5C7;--ml-ink:#0B1F38;--ml-text:#3A4657;--ml-muted:#5F6B7A;--ml-accent:#02305C;--ml-accent-soft:#E3ECF7;--ml-accent-text:#FFFFFF;--ml-maize:#FEC809;--ml-good:#1E6B3F;--ml-good-soft:#E4F2E8;--ml-warn:#7A4A00;--ml-warn-soft:#FFF1CF;--ml-bad:#B42318;--ml-bad-soft:#FDECEA;--ml-focus:#2365A0;--ml-hover:#02305C22;--ml-disabled:#687787;--ml-ticket:#02305C;--ml-ticket-text:#F9F6F0;--ml-shadow:#001D3D18;--ml-chart-cancelled:#AF633C;--ml-chart-expired:#84745A}
    :root[data-theme=dark]{--ml-bg:#091624;--ml-surface:#12243A;--ml-sunken:#1C3047;--ml-border:#34485F;--ml-ink:#F9F6F0;--ml-text:#D6DFE9;--ml-muted:#B0C0D1;--ml-accent:#FEC809;--ml-accent-soft:#323220;--ml-accent-text:#0B1F38;--ml-good:#91D6A7;--ml-good-soft:#153B2E;--ml-warn:#F5D58B;--ml-warn-soft:#3A3020;--ml-bad:#FFB4AA;--ml-bad-soft:#482A30;--ml-focus:#FEC809;--ml-hover:#FEC80944;--ml-disabled:#60748B;--ml-ticket:#17365A;--ml-ticket-text:#F9F6F0;--ml-shadow:#00000044;--ml-chart-cancelled:#E7A882;--ml-chart-expired:#B6A98F}
    html,body,#root{background:var(--ml-bg);color:var(--ml-ink);font-family:Figtree,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
    #root input,#root textarea,#root select,#root button{font-family:Figtree,system-ui,sans-serif}
    #root button,#root [role=button],#root input,#root select,#root textarea{transition:background-color 150ms ease,border-color 150ms ease,box-shadow 150ms ease}
    #root button:not(:disabled):hover,#root [role=button]:not([aria-disabled=true]):hover{box-shadow:inset 0 0 0 1px var(--ml-hover)}
    #root button:focus-visible,#root [role=button]:focus-visible,#root input:focus-visible,#root select:focus-visible,#root textarea:focus-visible{outline:3px solid var(--ml-focus);outline-offset:3px}
    #root button:disabled,#root [aria-disabled=true]{opacity:.55;cursor:default}
    #root input[type=checkbox]{accent-color:var(--ml-accent)}
    #root a{color:var(--ml-accent);text-underline-offset:3px}
    [data-testid=app-tabbar]{padding-bottom:max(10px,env(safe-area-inset-bottom))!important}
    [data-testid=app-masthead]{padding-top:max(16px,env(safe-area-inset-top))!important}
    .ml-welcome-choice{position:relative;transition:transform 150ms ease,box-shadow 150ms ease}
    .ml-welcome-choice:first-child:after{content:'';position:absolute;right:22px;top:-7px;width:18px;height:18px;border-radius:3px;background:#FEC809}
    .ml-welcome-choice:active{transform:translateY(1px)}
    .ml-qr-ticket{position:relative;border:1px solid var(--ml-border);box-shadow:0 8px 24px var(--ml-shadow)}
    .ml-qr-ticket:before{content:'';position:absolute;right:18px;top:-9px;width:20px;height:20px;border-radius:3px;background:#FEC809}
    .ml-scan-window{position:relative;min-height:240px;border-radius:20px;background:#0E1622;overflow:hidden;display:flex;align-items:center;justify-content:center}
    .ml-scan-reticle{position:absolute;inset:30px;pointer-events:none;background:linear-gradient(#FEC809,#FEC809) left top/36px 4px no-repeat,linear-gradient(#FEC809,#FEC809) left top/4px 36px no-repeat,linear-gradient(#FEC809,#FEC809) right top/36px 4px no-repeat,linear-gradient(#FEC809,#FEC809) right top/4px 36px no-repeat,linear-gradient(#FEC809,#FEC809) left bottom/36px 4px no-repeat,linear-gradient(#FEC809,#FEC809) left bottom/4px 36px no-repeat,linear-gradient(#FEC809,#FEC809) right bottom/36px 4px no-repeat,linear-gradient(#FEC809,#FEC809) right bottom/4px 36px no-repeat}
    @media(prefers-reduced-motion:reduce){#root *,#root *:before,#root *:after{transition:none!important;animation:none!important}}
  `}</style>;
}

export function NavIcon({name,active=false}) {
  const paths = {
    discover:<><path d="M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z"/></>,
    merchant:<><rect x="4" y="7" width="16" height="14" rx="2"/><path d="M8 7V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v3M8 12h8M8 16h5"/></>,
    redeem:<><path d="M3 8V3h5M16 3h5v5M21 16v5h-5M8 21H3v-5M7 7h3v3H7zM14 7h3v3h-3zM7 14h3v3H7zM14 14h3v3h-3z"/></>,
    insights:<><path d="M4 3v18h17M8 16v-5M13 16V6M18 16v-8"/></>,
    account:<><circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/></>,
  };
  return <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke={active?ui.navy:ui.muted} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name]}</svg>;
}

export function StockBar({remaining,total}) {
  if (!(total>0)) return null;
  const width=Math.max(0,Math.min(100,remaining/total*100));
  return <div aria-hidden="true" style={{height:4,borderRadius:3,background:ui.inset,overflow:'hidden',width:'100%'}}><div style={{height:'100%',width:`${width}%`,borderRadius:3,background:ui.navy}}/></div>;
}
