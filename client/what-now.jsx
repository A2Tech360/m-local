import React, {useEffect, useRef, useState} from 'react';

const ink='var(--ml-ink)',muted='var(--ml-muted)',accent='var(--ml-accent)',line='var(--ml-border)',paper='var(--ml-surface)',good='var(--ml-good)',goodSoft='var(--ml-good-soft)';
const font='Figtree, system-ui, sans-serif';
const wrap={display:'flex',flexDirection:'column',gap:8,minWidth:0,color:ink,fontFamily:font};
const grid={display:'grid',gridTemplateColumns:'repeat(2, minmax(0, 1fr))',gap:16,paddingRight:8,paddingBottom:8,paddingTop:8,alignItems:'stretch'};
const stackCard={position:'relative',aspectRatio:'1 / 1',minWidth:0,boxSizing:'border-box',display:'flex',flexDirection:'column',background:paper,
 border:`1px solid ${line}`,borderRadius:18,boxShadow:`4px 4px 0 -1px ${paper}, 4px 4px 0 0 ${line}, 8px 8px 0 -1px ${paper}, 8px 8px 0 0 ${line}`};
const face={flex:1,minHeight:0,minWidth:0,display:'flex',flexDirection:'column',gap:4,alignItems:'flex-start',textAlign:'left',padding:'12px 12px 6px',
 background:'none',border:0,borderRadius:18,cursor:'pointer',color:ink,fontFamily:font,overflow:'hidden'};
const kindText={fontSize:12,fontWeight:700,letterSpacing:.8,lineHeight:'15px',textTransform:'uppercase',color:accent};
const nameText={fontSize:15,fontWeight:800,lineHeight:'18px',display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden',wordBreak:'break-word'};
const smallText={fontSize:12,lineHeight:'16px',color:muted,maxWidth:'100%',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'};
const walkText={fontSize:12,lineHeight:'16px',color:muted};
const dealText={fontSize:12,lineHeight:'15px',fontWeight:700,color:good,display:'-webkit-box',WebkitLineClamp:2,WebkitBoxOrient:'vertical',overflow:'hidden'};
const badge={position:'absolute',top:-9,right:-6,fontSize:12,lineHeight:'15px',fontWeight:800,color:good,background:goodSoft,borderRadius:999,padding:'3px 8px',border:`2px solid ${paper}`};
const foot={display:'flex',justifyContent:'space-between',alignItems:'center',gap:8,padding:'0 12px 10px',minHeight:24};
const link={background:'none',border:0,padding:'2px 0',color:accent,fontWeight:700,fontSize:13,cursor:'pointer',fontFamily:font};
const css='@keyframes ml-whatnow-flip{from{transform:rotateY(70deg);opacity:.2}to{transform:none;opacity:1}}'
 +'.ml-whatnow-face{animation:ml-whatnow-flip .22s ease-out}'
 +'.ml-whatnow-next:focus-visible,.ml-whatnow-deal:focus-visible{outline:3px solid var(--ml-focus);outline-offset:3px}'
 +'@media (max-width:379px){.ml-whatnow-grid{gap:12px!important}.ml-whatnow-card{aspect-ratio:auto!important;min-height:150px}.ml-whatnow-next{padding:10px 10px 4px!important;overflow:visible!important;flex:1 0 auto!important}}'
 +'@media (prefers-reduced-motion:reduce){.ml-whatnow-face{animation:none}}';

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
 return <section className="ml-whatnow" data-testid="what-now" aria-labelledby="ml-whatnow-title" style={wrap}>
  <style>{css}</style>
  <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',gap:8,flexWrap:'wrap'}}>
   <h2 id="ml-whatnow-title" style={{fontSize:18,fontWeight:800,margin:0,color:ink,fontFamily:font}}>{view.heading||'What now?'}</h2>
   {view.has_samples&&<span style={{fontSize:12,color:muted,fontWeight:700,letterSpacing:.8,textTransform:'uppercase'}}>Sample places</span>}
  </div>
  <p style={{fontSize:13,margin:0,color:muted,lineHeight:'19px'}}>Demo suggestions around {plainName(view.origin)}. Tap a card to see the next place.</p>
  {view.note&&<p style={{fontSize:13,margin:0,color:muted,lineHeight:'19px'}}>{view.note}</p>}
  <ul className="ml-whatnow-grid" style={{...grid,listStyle:'none',margin:0,paddingLeft:0}}>
   {view.groups.map(group=>{
    const index=(at[group.kind]||0)%group.cards.length,place=group.cards[index];
    return <li key={group.kind} className="ml-whatnow-card" data-kind={group.kind} style={stackCard}>
     {place.deal&&<span aria-hidden="true" style={badge}>Deal</span>}
     <button type="button" className="ml-whatnow-next" style={face}
      aria-label={`${group.label}: ${place.name}, ${place.distance}, ${index+1} of ${group.cards.length}${place.deal?', has a deal':''}. Tap for the next place.`}
      onClick={()=>setAt(old=>({...old,[group.kind]:((old[group.kind]||0)+1)%group.cards.length}))}>
      <span style={kindText}>{group.label}{place.adults_only?' · 21+':''}</span>
      <span key={index} className="ml-whatnow-face" style={{display:'flex',flexDirection:'column',gap:3,minWidth:0,maxWidth:'100%'}}>
       <span style={nameText}>{plainName(place.name)}</span>
       {!place.deal&&<span style={smallText}>{place.what}</span>}
       <span style={walkText}>{place.distance} · {place.minutes} min walk</span>
       {place.deal&&<span style={dealText}>{place.deal}</span>}
      </span>
     </button>
     <div style={foot}>
      {place.deal_offer_id?<button type="button" className="ml-whatnow-deal" style={link} onClick={()=>onOpenDeal(place.deal_offer_id)}>See this deal</button>:<span/>}
      <span style={{fontSize:12,color:muted}}>{index+1} of {group.cards.length}</span>
     </div>
    </li>;
   })}
  </ul>
 </section>;
}
