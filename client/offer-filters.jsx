import React, {useId, useRef, useState} from 'react';
import {ui, uiFont, formButton, formSecondary} from './ui.jsx';

const PRICE_MAX = 20;
const TIMES = [['any', 'Any time'], ['now', 'Right now'], ['today', 'Today']];
const DIETS = [['vegetarian', 'Vegetarian'], ['vegan', 'Vegan'], ['gluten-free', 'Gluten-free'], ['halal', 'Halal']];

function parseMaximum(value) {
  const match = /^(\d+)-(\d+)$/.exec(value || '');
  return match ? Math.min(Number(match[2]), PRICE_MAX) : PRICE_MAX;
}

function Section({title, children}) {
  return <fieldset style={{border:0, margin:0, padding:0, minWidth:0, flexShrink:0}}>
    <legend style={{padding:0, marginBottom:10, fontSize:12, fontWeight:800, letterSpacing:.8, textTransform:'uppercase', color:ui.muted}}>{title}</legend>
    {children}
  </fieldset>;
}

export function OfferFilters({price, time, diets, onApply}) {
  const [open, setOpen] = useState(false);
  const [maximum, setMaximum] = useState(parseMaximum(price));
  const [when, setWhen] = useState(time || 'any');
  const [picked, setPicked] = useState(diets || []);
  const [panelHeight, setPanelHeight] = useState(540);
  const trigger = useRef(null);
  const panelId = useId();
  const count = (price ? 1 : 0) + ((time && time !== 'any') ? 1 : 0) + (diets || []).length;
  const maximumLabel = maximum === PRICE_MAX ? 'Any price' : `$${maximum} or less`;
  const summary = [price ? `$${parseMaximum(price)} or less` : 'Any price', TIMES.find(([key]) => key === time)?.[1] || 'Any time'].join(' · ');

  function toggle() {
    // Each opening starts from the filters currently applied to the feed.
    if (!open) {
      setMaximum(parseMaximum(price)); setWhen(time || 'any'); setPicked(diets || []);
      const bottom = document.querySelector('[data-testid="app-tabbar"]')?.getBoundingClientRect().top || window.innerHeight;
      setPanelHeight(Math.max(180, Math.min(540, bottom - trigger.current.getBoundingClientRect().bottom - 12)));
    }
    setOpen(!open);
  }
  function close() {setOpen(false); trigger.current?.focus();}
  function apply() {
    // Keep the existing numeric-range API. Zero includes free offers; the last
    // slider position removes the ceiling instead of silently excluding $20+.
    onApply(maximum === PRICE_MAX ? '' : `0-${maximum}`, when, picked);
    close();
  }
  function clearAll() {onApply('', 'any', []); close();}
  function toggleDiet(diet) {setPicked(picked.includes(diet) ? picked.filter(d => d !== diet) : [...picked, diet]);}

  return <div className="ml-filters" style={{fontFamily:uiFont, color:ui.ink, minWidth:0, position:'relative', zIndex:open?50:1}} onKeyDown={event => {
    if (open && event.key === 'Escape') {event.preventDefault(); close();}
  }}>
    <style>{`
      .ml-filter-option{box-sizing:border-box;display:flex;align-items:center;gap:6px;min-height:44px;padding:8px;border:1px solid ${ui.line};border-radius:10px;cursor:pointer;font-size:13px;background:${ui.white}}
      .ml-filter-option:has(input:checked){border-color:${ui.navy};background:#E3ECF7;color:${ui.navy};font-weight:700}
      .ml-filter-option input{width:16px;height:16px;flex-shrink:0;accent-color:${ui.navy};margin:0}
      .ml-filter-time{justify-content:center;border:0;padding:8px 3px;background:transparent;font-size:13px;min-width:0;white-space:nowrap}
      .ml-filter-time input{position:absolute;width:1px;height:1px;opacity:0}
      .ml-filter-time:has(input:checked){background:${ui.white};box-shadow:0 1px 4px #02305C12}
      .ml-filter-time:focus-within{outline:3px solid #2365A0;outline-offset:1px}
      .ml-price-slider{box-sizing:border-box;width:100%;height:44px;margin:0;accent-color:${ui.navy};cursor:pointer}
    `}</style>
    <button ref={trigger} type="button" aria-expanded={open} aria-controls={panelId} onClick={toggle}
      style={{...formSecondary, display:'flex', alignItems:'center', justifyContent:'space-between', gap:12, minHeight:50, padding:'12px 16px', borderRadius:open?'14px 14px 0 0':14}}>
      <span style={{display:'flex', alignItems:'center', gap:10}}>
        <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M4 7h16M4 17h16"/><circle cx="9" cy="7" r="3" fill={ui.white}/><circle cx="15" cy="17" r="3" fill={ui.white}/></svg>
        Filters
        {count > 0 && <span style={{borderRadius:6, background:ui.maize, color:ui.navy, fontSize:12, padding:'2px 6px'}}>{count}<span style={{position:'absolute',width:1,height:1,overflow:'hidden'}}> active</span></span>}
      </span>
      <span style={{flex:1,minWidth:0,textAlign:'left',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',fontSize:12,fontWeight:500,color:ui.muted}}>{summary}</span>
      <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{transform:open?'rotate(180deg)':undefined}}><path d="m6 9 6 6 6-6"/></svg>
    </button>
    {open && <div id={panelId} role="region" aria-label="Offer filters" style={{boxSizing:'border-box',position:'absolute',top:'100%',left:0,right:0,maxHeight:panelHeight,overflow:'hidden', border:`1px solid ${ui.line}`, borderTop:0, borderRadius:'0 0 14px 14px', boxShadow:'0 18px 40px -12px #02305C55', background:ui.white, display:'flex', flexDirection:'column'}}>
      <div style={{overflowY:'auto',minHeight:0,padding:16,display:'flex',flexDirection:'column',gap:16}}>
      <Section title="Maximum price">
        <div style={{display:'flex', justifyContent:'space-between', alignItems:'baseline', gap:12}}>
          <span style={{fontSize:13, color:ui.muted}}>Per offer</span>
          <output style={{fontSize:20, fontWeight:800, color:ui.navy, fontVariantNumeric:'tabular-nums'}}>{maximumLabel}</output>
        </div>
        <input className="ml-price-slider" type="range" min={0} max={PRICE_MAX} step={1} value={maximum} aria-label="Maximum price" aria-valuetext={maximumLabel} onChange={event => setMaximum(Number(event.target.value))}/>
        <div style={{display:'flex', justifyContent:'space-between', fontSize:12, color:ui.muted}}><span>$0</span><span>Any price</span></div>
      </Section>
      <Section title="When">
        <div style={{display:'grid', gridTemplateColumns:'repeat(3,minmax(0,1fr))', gap:3, padding:3, borderRadius:12, background:ui.inset}}>
          {TIMES.map(([key, label]) => <label key={key} className="ml-filter-option ml-filter-time"><input type="radio" name={`${panelId}-when`} checked={when === key} onChange={() => setWhen(key)}/>{label}</label>)}
        </div>
      </Section>
      <Section title="Diet preferences">
        <div style={{display:'grid', gridTemplateColumns:'repeat(auto-fit,minmax(110px,1fr))', gap:8}}>
          {DIETS.map(([key, label]) => <label key={key} className="ml-filter-option"><input type="checkbox" checked={picked.includes(key)} onChange={() => toggleDiet(key)}/>{label}</label>)}
        </div>
      </Section>
      </div>
      <div style={{display:'flex',gap:8,background:ui.white,padding:12,borderTop:`1px solid ${ui.line}`,flexShrink:0}}>
        <button type="button" onClick={clearAll} style={{...formSecondary, flex:1, padding:'12px 8px'}}>Clear all</button>
        <button type="button" onClick={apply} style={{...formButton, flex:1, padding:'12px 8px'}}>Show deals</button>
      </div>
    </div>}
  </div>;
}
