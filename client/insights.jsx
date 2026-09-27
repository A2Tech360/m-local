import React, {useEffect, useRef, useState} from 'react';
import {PERIODS, normalizeInsights, selectCutoff, chartSeries, money, count, displayDate, createRequestGate, buildRecapHtml} from './insights-support.mjs';

const styles = `
.bi{--bi-ink:#182d45;--bi-muted:#6d645b;--bi-orange:#aa3712;--bi-rule:#ded5c8;--bi-paper:#fffdf9;color:var(--bi-ink);font:14px/1.5 system-ui,sans-serif;min-width:0;padding:8px 0 24px}.bi *{box-sizing:border-box}.bi button,.bi select{font:600 13px system-ui;min-height:42px;border:1px solid var(--bi-rule);border-radius:8px;background:var(--bi-paper);color:var(--bi-ink);padding:8px 13px;cursor:pointer}.bi button:hover:not(:disabled){border-color:#ab7958}.bi button:disabled{opacity:.5;cursor:default}.bi button:focus-visible,.bi select:focus-visible,.bi input:focus-visible,.bi summary:focus-visible{outline:3px solid #3874a8;outline-offset:3px}.bi .bi-primary{background:var(--bi-orange);color:#fff;border-color:var(--bi-orange)}.bi-header{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;flex-wrap:wrap;border-bottom:1px solid var(--bi-rule);padding-bottom:20px}.bi-eyebrow{font-size:11px;letter-spacing:.12em;text-transform:uppercase;font-weight:800;color:var(--bi-orange);margin:0 0 8px}.bi h2{font:normal clamp(29px,4vw,42px)/1.1 Georgia,serif;margin:0 0 8px}.bi h3{font-size:16px;margin:0 0 12px;letter-spacing:-.01em}.bi p{margin:0}.bi-note{color:var(--bi-muted);font-size:12px;line-height:1.55}.bi-toolbar{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin:20px 0}.bi-periods{display:flex;gap:4px;flex-wrap:wrap;padding:4px;background:#eee7dc;border-radius:10px}.bi-periods button{border-color:transparent;background:transparent;min-height:38px;padding:8px 12px}.bi-periods button[aria-pressed=true]{background:var(--bi-paper);box-shadow:0 1px 3px #182d4517}.bi-actions{display:flex;gap:8px;flex-wrap:wrap}.bi-badge{display:inline-block;border:1px solid #c7b697;padding:3px 8px;border-radius:20px;font-size:11px;font-weight:700;color:#745621;margin-bottom:6px}.bi-metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;padding:8px 0 26px}.bi-metric strong{display:block;font-size:clamp(28px,3.7vw,40px);line-height:1.2;letter-spacing:-.045em;font-weight:650;font-variant-numeric:tabular-nums;margin:4px 0 8px;overflow-wrap:anywhere}.bi-metric h3{font-size:12px;line-height:1.4;color:var(--bi-muted);font-weight:600;margin:0}.bi-timeline{padding:22px;background:var(--bi-paper);border:1px solid var(--bi-rule);border-radius:14px}.bi-timeline-top{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap}.bi-timeline h3{font:normal 24px/1.2 Georgia,serif;margin-bottom:5px}.bi-chart{width:100%;height:auto;display:block;overflow:visible;margin:8px 0}.bi-chart-meta{display:flex;justify-content:space-between;gap:12px;font-size:11px;color:var(--bi-muted)}.bi-chart-toggle{display:flex;gap:3px}.bi-chart-toggle button{font-size:11px;padding:6px 10px;min-height:34px}.bi-chart-toggle button[aria-pressed=true]{color:var(--bi-orange);background:#faf0e8;border-color:#d1a083}.bi-seek{width:100%;accent-color:var(--bi-orange);min-height:32px;margin:12px 0 6px;cursor:pointer}.bi-transport{display:flex;gap:8px;align-items:center;flex-wrap:wrap}.bi-transport .bi-progress{margin-left:auto;font-variant-numeric:tabular-nums}.bi-snapshot{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;font-size:12px;color:var(--bi-muted);margin:12px 0 22px}.bi-columns{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:32px;padding:4px 0 20px}.bi-outcome{margin-bottom:12px}.bi-outcome-line{display:flex;gap:8px;justify-content:space-between;font-size:12px;margin-bottom:6px}.bi-outcome-bar{height:7px;border-radius:5px;background:#ede7de;overflow:hidden}.bi-outcome-bar span{display:block;height:100%;border-radius:5px}.bi-rate{font-size:28px;line-height:1.2;font-weight:650;letter-spacing:-.035em;margin:0 0 12px}.bi-offers{list-style:none;margin:0;padding:0}.bi-offers li{display:flex;justify-content:space-between;gap:16px;padding:11px 0;border-bottom:1px solid var(--bi-rule)}.bi-offers li:first-child{padding-top:0}.bi-offer-title{font-size:13px;min-width:0;overflow-wrap:anywhere}.bi-offer-amount{text-align:right;white-space:nowrap;font-size:12px;font-variant-numeric:tabular-nums}.bi-offer-amount strong{display:block}.bi-story{border-top:1px solid var(--bi-rule);padding:22px 0}.bi-story blockquote{font:normal 24px/1.45 Georgia,serif;margin:0 0 12px;max-width:760px}.bi-footer{border-top:1px solid var(--bi-rule);padding-top:16px}.bi-footer summary{cursor:pointer;font-size:12px;font-weight:650;min-height:32px}.bi-footer ul{padding-left:20px;font-size:12px;line-height:1.6;color:var(--bi-muted)}.bi-notice{padding:14px 16px;border:1px solid #d5bd9e;border-radius:10px;background:#fff8e9;font-size:13px;margin:0 0 18px}.bi-error{border-color:#d9a599;background:#fff2ed;color:#82341e}.bi-empty{padding:34px 22px;border:1px dashed #c8bba8;border-radius:12px;text-align:center;margin-bottom:20px}.bi-empty h3{font:normal 23px Georgia,serif;margin-bottom:10px}.bi-loading{padding:42px 18px;border-block:1px solid var(--bi-rule);color:var(--bi-muted)}.bi-sr{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}@media(max-width:620px){.bi-metrics{grid-template-columns:repeat(2,minmax(0,1fr));gap:22px 16px}.bi-columns{grid-template-columns:minmax(0,1fr);gap:26px}.bi-timeline{padding:16px}.bi-actions{width:100%}.bi-actions button{flex:1}.bi-story blockquote{font-size:22px}.bi-transport .bi-progress{width:100%;margin:3px 0 0}.bi-header h2{font-size:34px}}@media(prefers-reduced-motion:reduce){.bi *{scroll-behavior:auto;transition:none!important;animation:none!important}}
`;

function RedemptionChart({data, cutoff, mode}) {
  const series = chartSeries(data, cutoff, mode), points = series.points.map(point => `${point.x},${point.y}`).join(' ');
  const last = series.points.at(-1);
  return <>
    <svg className="bi-chart" viewBox="0 0 720 174" role="img" aria-label={`${mode === 'daily' ? 'Daily' : 'Cumulative'} redemptions through ${cutoff ? displayDate(data.frames[cutoff].date) : 'the start of the period'}`}>
      {[22, 88, 154].map(y => <line key={y} x1="12" x2="708" y1={y} y2={y} stroke="#e9e1d6" strokeDasharray={y === 154 ? undefined : '3 5'}/>)}
      {mode === 'cumulative' ? <><polygon points={`12,154 ${points} ${last.x},154`} fill="#aa3712" fillOpacity="0.07"/><polyline points={points} fill="none" stroke="#aa3712" strokeWidth="2.7" strokeLinecap="round" strokeLinejoin="round"/><circle cx={last.x} cy={last.y} r="4" fill="#aa3712"/></> : series.points.slice(1).map(point => <rect key={point.day} x={point.x - Math.min(12, 560 / data.period_days) / 2} y={point.y} width={Math.min(12, 560 / data.period_days)} height={154 - point.y} rx="1" fill="#aa3712"/>)}
    </svg>
    <div className="bi-chart-meta"><span>{displayDate(data.start_date)}</span><span>0–{count(series.maximum)} redemptions</span><span>{displayDate(data.end_date)}</span></div>
  </>;
}

function Outcomes({metrics, rate}) {
  const outcomes = [['Redeemed', metrics.cohort_redeemed, '#224769'], ['Cancelled', metrics.cancelled, '#af633c'], ['Expired', metrics.expired, '#a8987e']];
  return <section aria-label="Claim outcomes"><h3>What happened to claims</h3><div className="bi-rate">{rate.percent === null ? 'No resolved claims' : `${rate.percent}% redeemed`}</div>
    <p className="bi-note" style={{marginBottom:16}}>{count(rate.denominator)} resolved claims in this period.</p>
    {outcomes.map(([label, total, color]) => <div className="bi-outcome" key={label}><div className="bi-outcome-line"><span>{label}</span><strong>{count(total)}</strong></div><div className="bi-outcome-bar" aria-hidden="true"><span style={{width:`${metrics.claims ? Math.min(100, total / metrics.claims * 100) : 0}%`, background:color}}/></div></div>)}
  </section>;
}

/** Private merchant analytics. The parent keys this component by authenticated actor. */
export function BusinessInsights({getInsights}) {
  const [period,setPeriod] = useState(30), [data,setData] = useState(null), [cutoff,setCutoff] = useState(0);
  const [loading,setLoading] = useState(true), [refreshing,setRefreshing] = useState(false), [error,setError] = useState('');
  const [frozen,setFrozen] = useState(false), [playing,setPlaying] = useState(false), [speed,setSpeed] = useState(1), [mode,setMode] = useState('cumulative'), [exportError,setExportError] = useState('');
  const mounted = useRef(false), api = useRef(getInsights), gate = useRef(createRequestGate()), frozenRef = useRef(false), periodRef = useRef(period), loadRef = useRef(null);
  api.current = getInsights;
  periodRef.current = period;

  useEffect(() => {
    mounted.current = true; frozenRef.current = false;
    setData(null); setCutoff(0); setPlaying(false); setFrozen(false); setLoading(true); setError(''); setExportError('');
    let activeRequest = null;
    async function load(background = false) {
      if (background && (document.hidden || frozenRef.current || activeRequest !== null)) return;
      const token = gate.current.begin();
      activeRequest = token;
      setRefreshing(true);
      try {
        const reply = await api.current(period);
        if (!mounted.current || !gate.current.accepts(token) || periodRef.current !== period) return;
        const clean = normalizeInsights(reply, period);
        setData(clean); setCutoff(clean.period_days); setError('');
      } catch (failure) {
        if (mounted.current && gate.current.accepts(token) && periodRef.current === period) setError(failure instanceof Error ? failure.message : 'Insights could not be loaded. Check your connection and retry.');
      } finally {
        if (activeRequest === token) activeRequest = null;
        if (mounted.current && gate.current.accepts(token) && periodRef.current === period) { setLoading(false); setRefreshing(false); }
      }
    }
    loadRef.current = load;
    load();
    const interval = setInterval(() => load(true), 30000);
    const visible = () => { if (!document.hidden) load(true); else setPlaying(false); };
    document.addEventListener('visibilitychange', visible);
    return () => { mounted.current = false; gate.current.invalidate(); clearInterval(interval); document.removeEventListener('visibilitychange', visible); };
  }, [period]);

  useEffect(() => {
    if (!playing || !data) return;
    const interval = setInterval(() => setCutoff(current => {
      const next = Math.min(data.period_days, current + 1);
      if (next === data.period_days) setPlaying(false);
      return next;
    }), 150 / speed);
    return () => clearInterval(interval);
  }, [playing, speed, data]);

  function freeze() { gate.current.invalidate(); frozenRef.current = true; setFrozen(true); setRefreshing(false); }
  function seek(day) { freeze(); setPlaying(false); setCutoff(day); }
  function play() { if (playing) { setPlaying(false); return; } freeze(); if (cutoff >= data.period_days) setCutoff(0); setPlaying(true); }
  function latest() { setPlaying(false); frozenRef.current = false; setFrozen(false); setError(''); loadRef.current?.(); }
  function download() {
    setExportError('');
    try {
      const blob = new Blob([buildRecapHtml(data)], {type:'text/html;charset=utf-8'}), url = URL.createObjectURL(blob), anchor = document.createElement('a');
      anchor.href = url; anchor.download = `M-Local-${period}-day-recap-${data.end_date}.html`; document.body.appendChild(anchor); anchor.click(); anchor.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch { setExportError('The recap could not be prepared. Refresh this period and try again.'); }
  }

  const view = data ? selectCutoff(data, cutoff) : null, totals = view?.frame.totals;
  const empty = data && data.frames.at(-1).totals.claims === 0 && data.frames.at(-1).totals.redemptions === 0;
  const collected = data ? new Intl.DateTimeFormat('en-US', {hour:'numeric', minute:'2-digit', timeZone:'America/Detroit'}).format(new Date(data.as_of * 1000)) : '';
  return <section className="bi" aria-label="Business insights"><style>{styles}</style>
    <header className="bi-header"><div><p className="bi-eyebrow">Business insights</p><h2>{period === 365 ? 'Your year in review' : 'See your business in motion'}</h2><p className="bi-note">Recorded activity, one day at a time.</p></div>{data && <div>{data.is_demo && <div className="bi-badge">Demo business · demo activity</div>}<p style={{fontWeight:650,overflowWrap:'anywhere'}}>{data.business_name}</p></div>}</header>
    <div className="bi-toolbar"><div className="bi-periods" role="group" aria-label="Insights period">{PERIODS.map(days => <button type="button" key={days} aria-pressed={period === days} onClick={() => { if (days !== period) { gate.current.invalidate(); setPeriod(days); } }}>{days === 365 ? 'Year' : `${days} days`}</button>)}</div><div className="bi-actions"><button type="button" onClick={latest} disabled={loading || refreshing}>{refreshing ? 'Refreshing…' : frozen ? 'Return to latest' : 'Refresh'}</button><button type="button" onClick={download} disabled={!data || loading}>Download recap</button></div></div>
    {error && <div className="bi-notice bi-error" role="alert">{error} {data ? 'The last loaded recording is still shown.' : 'Use Refresh to try again.'}</div>}
    {exportError && <div className="bi-notice bi-error" role="alert">{exportError}</div>}
    {loading && <div className="bi-loading" role="status">Loading your business’s recorded activity…</div>}
    {data && !loading && <>
      {empty && <div className="bi-empty"><h3>Your next redemption starts the story.</h3><p className="bi-note">There are no recorded claims or redemptions in this period. Publish an offer, then return here as customers claim and redeem it.</p></div>}
      <div className="bi-metrics" aria-label={`Metrics through ${view.frame.date}`}>
        {[['Claims',count(totals.claims),'Created in this period'],['Redemptions',count(totals.redemptions),'Completed in this period'],['Returning accounts',count(totals.returning_customers),'Redeemed on an earlier day'],['Redeemed offer value',money(totals.value_cents),'At the recorded claim price']].map(([label,value,note]) => <div className="bi-metric" key={label}><h3>{label}</h3><strong>{value}</strong><p className="bi-note">{note}</p></div>)}
      </div>
      <section className="bi-timeline" aria-label="Activity replay"><div className="bi-timeline-top"><div><h3>{cutoff ? displayDate(view.frame.date, true) : 'Before the first day'}</h3><p className="bi-note">{frozen ? 'Replay recording' : 'Latest recording'} · {displayDate(data.start_date, data.start_date.slice(0,4) !== data.end_date.slice(0,4))} to {displayDate(data.end_date, true)}</p></div><div className="bi-chart-toggle" role="group" aria-label="Chart totals"><button type="button" aria-pressed={mode === 'cumulative'} onClick={() => setMode('cumulative')}>Cumulative</button><button type="button" aria-pressed={mode === 'daily'} onClick={() => setMode('daily')}>Daily</button></div></div>
        <RedemptionChart data={data} cutoff={cutoff} mode={mode}/>
        <label className="bi-sr" htmlFor="bi-replay-date">Replay date</label><input id="bi-replay-date" className="bi-seek" type="range" min="0" max={data.period_days} step="1" value={cutoff} aria-valuetext={cutoff ? displayDate(view.frame.date,true) : 'Before the period begins'} onChange={event => seek(Number(event.target.value))}/>
        <div className="bi-transport"><button type="button" className="bi-primary" onClick={play}>{playing ? 'Pause replay' : cutoff === data.period_days ? 'Replay this period' : 'Play'}</button><button type="button" onClick={() => seek(0)}>Reset</button><label className="bi-sr" htmlFor="bi-replay-speed">Replay speed</label><select id="bi-replay-speed" value={speed} onChange={event => setSpeed(Number(event.target.value))}><option value="1">1× speed</option><option value="3">3× speed</option><option value="8">8× speed</option></select><span className="bi-note bi-progress">Day {cutoff} / {data.period_days}</span></div>
      </section>
      <div className="bi-snapshot"><span>{frozen ? 'Updates paused while you explore. Return to latest to refresh.' : 'Refreshes every 30 seconds while this tab is visible.'}</span><span>Collected {collected} · Ann Arbor time</span></div>
      <div className="bi-columns"><Outcomes metrics={totals} rate={view.rate}/><section aria-label="Most-redeemed offers"><h3>Most-redeemed offers</h3>{view.frame.offers.length ? <ol className="bi-offers">{view.frame.offers.slice(0,5).map((offer,index) => <li key={`${index}-${offer.title}`}><span className="bi-offer-title">{offer.title}</span><span className="bi-offer-amount"><strong>{count(offer.redemptions)} redeemed</strong><span className="bi-note">{money(offer.value_cents)} value</span></span></li>)}</ol> : <p className="bi-note">Redeemed offers appear here as this period unfolds.</p>}<p className="bi-note" style={{marginTop:16}}>{count(totals.unique_customers)} distinct redeeming accounts so far.</p>{totals.savings_known > 0 && <p className="bi-note" style={{marginTop:8}}>{money(totals.savings_cents)} in recorded discounts across {count(totals.savings_known)} redemptions with a known regular price.</p>}</section></div>
      <section className="bi-story" aria-label="Your period story"><p className="bi-eyebrow">Your story so far</p><blockquote>{view.busiest ? <>{displayDate(view.busiest.date)} brought {count(view.busiest.daily.redemptions)} redemption{view.busiest.daily.redemptions === 1 ? '' : 's'}, your busiest day in this period so far.</> : 'The first recorded redemption will begin this story.'}</blockquote>{view.first && <p className="bi-note">The first redemption in this period was on {displayDate(view.first.date)}.{view.top ? ` ${view.top.title} leads with ${count(view.top.redemptions)} redemptions through this date.` : ''}</p>}</section>
      <footer className="bi-footer"><details><summary>How these numbers are counted</summary><ul><li>Claims and outcomes follow claims created in the selected period. Redemptions and value follow redemption dates, including offers claimed before the period.</li><li>The redemption rate is redeemed claims divided by redeemed, cancelled, and expired claims.</li><li>A returning account redeemed at this business on an earlier Ann Arbor calendar date. Multiple redemptions on a first day do not create a returning account.</li><li>Redeemed offer value uses the price saved when the customer claimed the offer. It is not payment revenue. Discounts are included only when a regular price was recorded.</li><li>Views, nearby selections, and verified visits are not yet included. Customer identities and travel paths are not shown or exported.</li><li>Downloads include this entire recorded period, including dates beyond the replay cursor, and contain business-level aggregate metrics and offer titles.</li>{data.coverage_start_date && <li>Earliest supported activity: {displayDate(data.coverage_start_date,true)}.</li>}{data.warnings.map((warning,index) => <li key={index}>{warning}</li>)}</ul></details><p className="bi-note">Private business insights. Your downloaded recap contains aggregate results only.</p></footer>
    </>}
  </section>;
}
