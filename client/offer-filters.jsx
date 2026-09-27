import React, {useEffect, useState} from 'react';

const PRICE_MAX = 20;
const TIMES = [['any', 'Any time'], ['now', 'Right now'], ['today', 'Today']];
const DIETS = [['vegetarian', 'Vegetarian'], ['vegan', 'Vegan'], ['gluten-free', 'Gluten-free'], ['halal', 'Halal']];

const font = 'system-ui, sans-serif';
const ink = '#1d1a16';
const muted = '#7a7064';
const border = '#e7dfd3';
const accent = '#d9480f';

const css = `
.mlf-range{position:relative;height:22px}
.mlf-range input[type=range]{position:absolute;left:0;top:0;width:100%;height:22px;margin:0;background:none;pointer-events:none;-webkit-appearance:none;appearance:none}
.mlf-range input[type=range]::-webkit-slider-thumb{pointer-events:auto;-webkit-appearance:none;width:18px;height:18px;border-radius:50%;background:#fff;border:2px solid ${accent};cursor:pointer;box-shadow:0 1px 3px rgba(0,0,0,.2)}
.mlf-range input[type=range]::-moz-range-thumb{pointer-events:auto;width:14px;height:14px;border-radius:50%;background:#fff;border:2px solid ${accent};cursor:pointer}
.mlf-range input[type=range]::-webkit-slider-runnable-track{background:transparent}
.mlf-range input[type=range]::-moz-range-track{background:transparent}
.mlf-range input[type=range]:focus-visible::-webkit-slider-thumb{outline:3px solid #1f3a5f;outline-offset:2px}
.mlf-check{display:flex;align-items:center;gap:6px;min-height:32px;padding:4px 8px;border:1px solid ${border};border-radius:8px;cursor:pointer;font-size:13px;color:${ink};background:#fff}
.mlf-check:has(input:checked){border-color:${ink};background:#f3eee6;font-weight:600}
.mlf-check input{width:15px;height:15px;accent-color:${accent};margin:0}
`;

function parseRange(value) {
  const m = /^(\d+)-(\d+)$/.exec(value || '');
  return m ? [Number(m[1]), Math.min(Number(m[2]), PRICE_MAX)] : [0, PRICE_MAX];
}

function Section({title, children}) {
  return <fieldset style={{border: 0, margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 6, minWidth: 0}}>
    <legend style={{padding: 0, marginBottom: 6, fontSize: 11, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: muted}}>{title}</legend>
    {children}
  </fieldset>;
}

export function OfferFilters({price, time, diets, onApply}) {
  const [open, setOpen] = useState(false);
  const [range, setRange] = useState(parseRange(price));
  const [when, setWhen] = useState(time || 'any');
  const [picked, setPicked] = useState(diets || []);

  // Reset the draft to the applied filters whenever the panel opens.
  useEffect(() => {
    if (open) { setRange(parseRange(price)); setWhen(time || 'any'); setPicked(diets || []); }
  }, [open]);

  const [lo, hi] = range;
  const count = (price ? 1 : 0) + ((time && time !== 'any') ? 1 : 0) + (diets || []).length;
  const label = (v) => v >= PRICE_MAX ? `$${PRICE_MAX}+` : `$${v}`;

  function apply() {
    const full = lo === 0 && hi === PRICE_MAX;
    // The top of the slider means "and up", so send a large ceiling.
    const value = full ? '' : `${lo}-${hi >= PRICE_MAX ? 9999 : hi}`;
    onApply(value, when, picked);
    setOpen(false);
  }
  function clearAll() {
    setRange([0, PRICE_MAX]); setWhen('any'); setPicked([]);
    onApply('', 'any', []);
    setOpen(false);
  }
  function toggleDiet(d) {
    setPicked(picked.includes(d) ? picked.filter(x => x !== d) : [...picked, d]);
  }

  const pct = (v) => `${(v / PRICE_MAX) * 100}%`;
  const action = {minHeight: 36, borderRadius: 8, fontFamily: font, fontSize: 13, fontWeight: 700, cursor: 'pointer'};

  return <div style={{fontFamily: font, color: ink, position: 'relative', zIndex: open ? 50 : 1}}>
    <style>{css}</style>
    <button
      type="button"
      aria-expanded={open}
      aria-controls="mlf-panel"
      onClick={() => setOpen(!open)}
      style={{boxSizing: 'border-box', display: 'flex', alignItems: 'center', gap: 8, minHeight: 36, padding: '6px 12px', border: `1px solid ${open ? ink : border}`, borderRadius: 999, background: '#fff', cursor: 'pointer', fontFamily: font, fontSize: 13, fontWeight: 700, color: ink}}
    >
      <span style={{display: 'flex', alignItems: 'center', gap: 6}}>
        Filters
        {count > 0 ? <span style={{minWidth: 18, height: 18, padding: '0 5px', boxSizing: 'border-box', borderRadius: 999, background: accent, color: '#fff', fontSize: 11, display: 'inline-flex', alignItems: 'center', justifyContent: 'center'}}>{count}</span> : null}
      </span>
      <span aria-hidden="true" style={{fontSize: 10, color: muted, transform: open ? 'rotate(180deg)' : 'none', transition: 'transform .15s'}}>{'\u25BC'}</span>
    </button>

    {open ? <div id="mlf-panel" role="region" aria-label="Offer filters" style={{position: 'absolute', top: 'calc(100% + 6px)', left: 0, width: 'min(340px, calc(100vw - 32px))', maxHeight: '60vh', overflowY: 'auto', boxSizing: 'border-box', padding: 12, border: `1px solid ${border}`, borderRadius: 12, background: '#fff', boxShadow: '0 6px 18px rgba(29,26,22,.12)', display: 'flex', flexDirection: 'column', gap: 12}}>
      <Section title="Price">
        <div style={{display: 'flex', justifyContent: 'space-between', fontSize: 13, fontWeight: 700}}>
          <span>{label(lo)}</span>
          <span style={{color: muted, fontWeight: 500}}>to</span>
          <span>{label(hi)}</span>
        </div>
        <div className="mlf-range">
          <div style={{position: 'absolute', left: 0, right: 0, top: 9, height: 4, borderRadius: 4, background: border}} />
          <div style={{position: 'absolute', left: pct(lo), width: `calc(${pct(hi)} - ${pct(lo)})`, top: 9, height: 4, borderRadius: 4, background: accent}} />
          <input type="range" min={0} max={PRICE_MAX} step={1} value={lo} aria-label="Minimum price"
            onChange={e => setRange([Math.min(Number(e.target.value), hi), hi])} />
          <input type="range" min={0} max={PRICE_MAX} step={1} value={hi} aria-label="Maximum price"
            onChange={e => setRange([lo, Math.max(Number(e.target.value), lo)])} />
        </div>
      </Section>

      <Section title="When">
        <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(96px,1fr))', gap: 6}}>
          {TIMES.map(([k, t]) => <label key={k} className="mlf-check">
            <input type="radio" name="mlf-when" checked={when === k} onChange={() => setWhen(k)} />{t}
          </label>)}
        </div>
      </Section>

      <Section title="Diet preferences">
        <div style={{display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(110px,1fr))', gap: 6}}>
          {DIETS.map(([k, t]) => <label key={k} className="mlf-check">
            <input type="checkbox" checked={picked.includes(k)} onChange={() => toggleDiet(k)} />{t}
          </label>)}
        </div>
      </Section>

      <div style={{display: 'flex', gap: 6, flexWrap: 'wrap'}}>
        <button type="button" onClick={clearAll} style={{...action, flex: '1 1 100px', border: `1px solid ${border}`, background: '#fff', color: ink}}>Clear all</button>
        <button type="button" onClick={apply} style={{...action, flex: '2 1 150px', border: `1px solid ${accent}`, background: accent, color: '#fff'}}>Show deals</button>
      </div>
    </div> : null}
  </div>;
}
