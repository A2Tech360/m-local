import React, {useEffect, useRef, useState} from 'react';

const ink='#1d1a16',muted='#6b6157',accent='#b83a0b',line='#e4dccf',paper='#fff',good='#1f6b3a';
const wrap={display:'flex',flexDirection:'column',gap:10,minWidth:0,color:ink,fontFamily:'system-ui, sans-serif'};
const grid={display:'grid',gridTemplateColumns:'repeat(2, minmax(0, 1fr))',gap:16,paddingRight:8,paddingBottom:8,paddingTop:6,alignItems:'stretch'};
const stackCard={position:'relative',aspectRatio:'1 / 1',minWidth:0,boxSizing:'border-box',display:'flex',flexDirection:'column',background:paper,
 border:`1px solid ${line}`,borderRadius:16,boxShadow:`4px 4px 0 -1px ${paper}, 4px 4px 0 0 ${line}, 8px 8px 0 -1px ${paper}, 8px 8px 0 0 ${line}`};
const face={flex:1,minHeight:0,minWidth:0,display:'flex',flexDirection:'column',gap:4,alignItems:'flex-start',textAlign:'left',padding:'12px 12px 8px',
 background:'none',border:0,borderRadius:16,cursor:'pointer',color:ink,font:'inherit',overflow:'hidden'};
const kindText={fontSize:11,fontWeight:800,letterSpacing:.6,lineHeight:'14px',textTransform:'uppercase',color:accent};
const nameText={fontSize:15,fontWeight:700,lineHeight:'18px',display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden',wordBreak:'break-word'};
const smallText={fontSize:12,lineHeight:'16px',color:muted,maxWidth:'100%',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'};
const dealText={fontSize:12,lineHeight:'15px',fontWeight:700,color:good,display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden'};
const badge={position:'absolute',top:-8,right:-6,fontSize:11,lineHeight:'14px',fontWeight:800,color:'#fff',background:good,borderRadius:999,padding:'2px 9px',border:`2px solid ${paper}`};
const foot={display:'flex',justifyContent:'space-between',alignItems:'center',gap:8,padding:'0 12px 10px',minHeight:20};
const link={background:'none',border:0,padding:0,color:accent,fontWeight:700,fontSize:13,cursor:'pointer',fontFamily:'inherit'};

export const plainName=name=>String(name||'').replace(/\s*\((Sample|Demo)\)\s*$/,'');

export function WhatNow({offerId,load,onOpenDeal}) {
 const [view,setView]=useState(null),[at,setAt]=useState({});
 const mounted=useRef(true);
 useEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
 useEffect(()=>{
  let current=true;setView(null);setAt({});
  Promise.resolve().then(()=>load(offerId)).then(found=>{
   if(!current||!mounted.current)return;
   const groups=Array.isArray(found?.groups)?found.groups.filter(g=>Array.isArray(g?.cards)&&g.cards.length>0):[];
   setView(found?.ok&&groups.length?{...found,groups}:null);
  }).catch(()=>{if(current&&mounted.current)setView(null);});
  return()=>{current=false;};
 },[offerId]);
 if(!view)return null;
 return <section aria-label="What now?" style={wrap}>
  <style>{'@keyframes mlocal-flip{from{transform:rotateY(70deg);opacity:.2}to{transform:none;opacity:1}}.mlocal-card-face{animation:mlocal-flip .22s ease-out}.mlocal-next:focus-visible{outline:3px solid #1f3a5f;outline-offset:2px}@media (prefers-reduced-motion: reduce){.mlocal-card-face{animation:none}}'}</style>
  <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',gap:8,flexWrap:'wrap'}}>
   <h3 style={{fontSize:20,margin:0}}>{view.heading||'What now?'}</h3>
   {view.has_samples&&<span style={{fontSize:12,color:muted,fontWeight:700}}>Sample places</span>}
  </div>
  <p style={{fontSize:13,margin:0,color:muted,lineHeight:1.4}}>A short walk from {plainName(view.origin)}. Tap a card to see the next place.</p>
  <div style={grid}>
   {view.groups.map(group=>{
    const index=(at[group.kind]||0)%group.cards.length,place=group.cards[index];
    return <div key={group.kind} className="mlocal-stack" style={stackCard}>
     {place.deal&&<span style={badge}>Deal</span>}
     <button type="button" className="mlocal-next" style={face}
      aria-label={`${group.label}: ${place.name}, ${place.distance}, ${index+1} of ${group.cards.length}${place.deal?', has a deal':''}. Tap for the next place.`}
      onClick={()=>setAt(old=>({...old,[group.kind]:((old[group.kind]||0)+1)%group.cards.length}))}>
      <span style={kindText}>{group.label}{place.adults_only?' · 21+':''}</span>
      <span key={index} className="mlocal-card-face" style={{display:'flex',flexDirection:'column',gap:3,minWidth:0,maxWidth:'100%'}}>
       <span style={nameText}>{plainName(place.name)}</span>
       {!place.deal&&<span style={smallText}>{place.what}</span>}
       <span style={smallText}>{place.distance} · {place.minutes} min walk</span>
       {place.deal&&<span style={dealText}>{place.deal}</span>}
      </span>
     </button>
     <div style={foot}>
      {place.deal_offer_id?<button type="button" style={link} onClick={()=>onOpenDeal(place.deal_offer_id)}>See this deal</button>:<span/>}
      <span style={{fontSize:11,color:muted}}>{index+1} of {group.cards.length}</span>
     </div>
    </div>;
   })}
  </div>
 </section>;
}
