import React from 'react';

// Presentation only. Assets are served by Jac's built-in static asset route.
export const uiFont = 'Figtree, system-ui, sans-serif';
export const ui = {
  ink:'#0B1F38', navy:'#02305C', paper:'#F9F6F0', white:'#FFFFFF',
  muted:'#5F6B7A', line:'#DDD5C7', inset:'#EFE9DE', maize:'#FEC809',
};
export const formStack = {display:'flex',flexDirection:'column',gap:16,minWidth:0,color:ui.ink,fontFamily:uiFont};
export const formInput = {width:'100%',minWidth:0,boxSizing:'border-box',minHeight:52,padding:'13px 14px',fontFamily:uiFont,fontSize:16,border:`1px solid ${ui.line}`,borderRadius:12,background:ui.white,color:ui.ink};
export const formButton = {...formInput,minHeight:54,background:ui.navy,color:ui.white,fontWeight:800,cursor:'pointer',borderColor:ui.navy,borderRadius:14};
export const formSecondary = {...formButton,background:ui.white,color:ui.navy,borderColor:ui.line};
export const formHint = {fontSize:13,lineHeight:1.5,margin:0,color:ui.muted};

export function BrandLogo({reversed=false}) {
  return <img src={`/static/assets/brand/logo-${reversed?'reversed':'compact'}.png`} alt="M Local" width="112" height="40" style={{display:'block',width:112,height:40,objectFit:'contain',flexShrink:0}}/>;
}

export function UiFoundation() {
  return <style>{`
    @font-face{font-family:Figtree;src:url('/static/assets/brand/Figtree.ttf') format('truetype');font-style:normal;font-weight:300 900;font-display:swap}
    html,body,#root{background:#F9F6F0;font-family:Figtree,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
    #root input,#root textarea,#root select,#root button{font-family:Figtree,system-ui,sans-serif}
    #root button,#root [role=button],#root input,#root select,#root textarea{transition:background-color 150ms ease,border-color 150ms ease,box-shadow 150ms ease}
    #root button:not(:disabled):hover,#root [role=button]:not([aria-disabled=true]):hover{box-shadow:inset 0 0 0 1px #02305C22}
    #root button:focus-visible,#root [role=button]:focus-visible,#root input:focus-visible,#root select:focus-visible,#root textarea:focus-visible{outline:3px solid #2365A0;outline-offset:3px}
    #root button:disabled,#root [aria-disabled=true]{opacity:.55;cursor:default}
    #root input[type=checkbox]{accent-color:#02305C}
    #root a{color:#02305C;text-underline-offset:3px}
    [data-testid=app-tabbar]{padding-bottom:max(10px,env(safe-area-inset-bottom))!important}
    [data-testid=app-masthead]{padding-top:max(16px,env(safe-area-inset-top))!important}
    .ml-welcome-choice{position:relative;transition:transform 150ms ease,box-shadow 150ms ease}
    .ml-welcome-choice:first-child:after{content:'';position:absolute;right:22px;top:-7px;width:18px;height:18px;border-radius:3px;background:#FEC809}
    .ml-welcome-choice:active{transform:translateY(1px)}
    .ml-qr-ticket{position:relative;border:1px solid #DDD5C7;box-shadow:0 8px 24px #001D3D12}
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
