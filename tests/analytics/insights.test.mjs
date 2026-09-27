import test from 'node:test';
import assert from 'node:assert/strict';
import {METRIC_KEYS, normalizeInsights, selectCutoff, chartSeries, resolvedRate, createRequestGate, recapPayload, buildRecapHtml} from '../../client/insights-support.mjs';

export function fixture() {
  const zero = () => Object.fromEntries(METRIC_KEYS.map(key => [key, 0]));
  const frames = [];
  for (let day = 0; day <= 7; day++) {
    const totals = {...zero(), claims: day * 2, redemptions: day, unique_customers: Math.min(day, 2), returning_customers: day > 2 ? 1 : 0, value_cents: day * 600, savings_cents: day * 200, savings_known: day, cohort_redeemed: day, expired: day, actor_id: 'SECRET-METRIC-ACCOUNT'};
    const daily = {...zero(), claims: day ? 2 : 0, redemptions: day ? 1 : 0};
    frames.push({day, date: `2026-09-${String(day + 20).padStart(2,'0')}`, totals, daily, offers: day ? [{id:'SECRET-OFFER-ID',title: day > 3 ? 'Later offer title' : 'Earlier offer title', redemptions: day, value_cents:day * 600, customer_email:'SECRET-OFFER-EMAIL'}] : [], actor_id:'SECRET-FRAME-ACCOUNT'});
  }
  return {ok:true, business_name:'Fixture café', is_demo:true, period_days:7, timezone:'America/Detroit',start_date:'2026-09-21',end_date:'2026-09-27',as_of:1790553600,coverage_start_date:'2026-09-21',warnings:[],frames,totals:frames.at(-1).totals, offers:frames.at(-1).offers, actor_id:'SECRET-ROOT-ACCOUNT',qr_token:'SECRET-QR-TOKEN', emails:['SECRET-EMAIL']};
}

test('historical cutoff controls every metric, offer, story and chart scale', () => {
  const data = normalizeInsights(fixture(), 7), zero = selectCutoff(data, 0), earlier = selectCutoff(data, 2);
  assert.equal(zero.frame.totals.claims, 0);
  assert.equal(zero.top, null);
  assert.equal(zero.busiest, null);
  assert.equal(earlier.frame.totals.redemptions, 2);
  assert.equal(earlier.top.title, 'Earlier offer title');
  assert.equal(earlier.history.length, 3);
  assert.equal(earlier.busiest.date, '2026-09-21');
  assert.equal(chartSeries(data, 2).maximum, 2);
  assert.equal(chartSeries(data, 2, 'daily').maximum, 1);
  assert.equal(selectCutoff(data, 999).index, 7);
  assert.equal(selectCutoff(data, -4).index, 0);
});

test('resolved claim rate excludes pending, unknown, and carried-over redemptions', () => {
  assert.deepEqual(resolvedRate({cohort_redeemed:3,cancelled:1,expired:2,pending:20,unknown_outcomes:30,redemptions:50}),{denominator:6,percent:50});
  assert.deepEqual(resolvedRate({cohort_redeemed:0,cancelled:0,expired:0,pending:3}),{denominator:0,percent:null});
});

test('normalization rejects malformed metrics, wrong range and missing chronology', () => {
  assert.throws(() => normalizeInsights(fixture(), 30), /different period/);
  const wrong = fixture(); wrong.frames[4].totals.redemptions = -1;
  assert.throws(() => normalizeInsights(wrong), /invalid total/);
  const gap = fixture(); gap.frames[4].date = gap.frames[3].date;
  assert.throws(() => normalizeInsights(gap), /missing date/);
  const baseline = fixture(); baseline.frames[0].totals.claims = 1;
  assert.throws(() => normalizeInsights(baseline), /zero baseline/);
  const impossible = fixture(); impossible.frames[4].date = '2026-02-31';
  assert.throws(() => normalizeInsights(impossible), /invalid date/);
  const invalidExport = fixture(); invalidExport.period_days = '<script>unsafe</script>';
  assert.throws(() => buildRecapHtml(invalidExport), /different period/);
  const invalidDay = fixture(); invalidDay.frames[2].day = {secret: 'PRIVATE'};
  assert.throws(() => buildRecapHtml(invalidDay), /out of order/);
  assert.throws(() => normalizeInsights({ok:false,message:'Access denied.'}), /Access denied/);
});

test('recap omits pending and unknown history rows', () => {
  const html = buildRecapHtml(normalizeInsights(fixture()));
  assert.match(html, /Claim outcomes/);
  assert.doesNotMatch(html, />\\d+ pending/);
  assert.doesNotMatch(html, />\\d+ unknown/);
});

test('normalization and export exclude unknown fields at every level', () => {
  const raw = fixture();
  raw.warnings = ['SECRET-PRIVATE-WARNING'];
  const clean = normalizeInsights(raw), exported = recapPayload({...clean,actor_id:'SECRET-REINTRODUCED'});
  const serialized = JSON.stringify(exported), html = buildRecapHtml({...clean, qr_token:'SECRET-REINTRODUCED-QR'});
  assert.equal(exported.has_coverage_warnings, true);
  assert.doesNotMatch(serialized, /SECRET|actor_id|qr_token|customer_email/);
  assert.doesNotMatch(html, /SECRET|actor_id|qr_token|customer_email/);
  assert.equal(exported.frames[1].offers[0].title, 'Earlier offer title');
  assert.equal(Object.keys(exported.frames[1].offers[0]).length, 3);
});

test('hostile source strings remain text in the standalone recap', () => {
  const raw = fixture();
  raw.business_name = '</title><img src=x onerror="window.PWNED=1">';
  raw.frames[7].offers[0].title = '</script><script>window.PWNED=2</script>';
  const html = buildRecapHtml(normalizeInsights(raw));
  assert.doesNotMatch(html, /<img src=x|<script>window.PWNED/);
  assert.match(html, /&lt;\/title&gt;/);
  assert.match(html, /\\u003c\/script>/);
  assert.doesNotMatch(html, /(?:src|href)=["']https?:/);
});

test('out-of-order responses, replay, range switches and unmount invalidate old requests', () => {
  const gate = createRequestGate(), old = gate.begin(), current = gate.begin();
  assert.equal(gate.accepts(old), false);
  assert.equal(gate.accepts(current), true);
  gate.invalidate();
  assert.equal(gate.accepts(current), false);
  const refreshed = gate.begin();
  assert.equal(gate.accepts(refreshed), true);
  gate.invalidate();
  assert.equal(gate.accepts(refreshed), false);
});
