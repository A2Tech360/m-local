import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import { gzipSync } from 'node:zlib';
import test from 'node:test';
import { createShareProxy } from '../../scripts/phone-share-proxy.mjs';

async function serve(t, handler, options = {}) {
  const upstream = http.createServer(handler).listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const proxy = createShareProxy({ upstreamHost: '127.0.0.1', upstreamPort: upstream.address().port, ...options });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  t.after(() => {
    proxy.closeAllConnections(); proxy.close();
    upstream.closeAllConnections(); upstream.close();
  });
  return `http://127.0.0.1:${proxy.address().port}`;
}

test('host readiness reflects the backend and does not expose its diagnostics', async t => {
  let ready = false;
  const origin = await serve(t, (req, res) => {
    assert.equal(req.url, '/ready');
    res.writeHead(ready ? 200 : 503, { 'content-type': 'application/json' });
    res.end('{"private":"backend diagnostics"}');
  }, { healthCheck: true });
  let response = await fetch(origin + '/healthz');
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { ready: false });
  ready = true;
  response = await fetch(origin + '/healthz');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ready: true });
  assert.equal((await fetch(origin + '/ready')).status, 403);
});

test('compressed API responses retain their encoding and parse correctly on a phone', async t => {
  const origin = await serve(t, (req, res) => {
    res.writeHead(200, { 'content-type': 'application/json', 'content-encoding': 'gzip' });
    res.end(gzipSync('{"ok":true,"data":[{"title":"Lunch special"}]}'));
  });
  const response = await fetch(origin + '/function/list_offers', { method: 'POST', body: '{}' });
  assert.match(response.headers.get('content-type'), /application\/json/);
  assert.equal(response.headers.get('content-encoding'), 'gzip');
  assert.deepEqual(await response.json(), { ok: true, data: [{ title: 'Lunch special' }] });
});

test('direct hosting cannot bypass signup limits by spoofing edge headers', async t => {
  const origin = await serve(t, (_req, res) => res.end('{}'), { trustCloudflare: false });
  for (let i = 0; i < 4; i++) {
    const response = await fetch(origin + '/function/request_email_code', {
      method: 'POST', body: '{}', headers: { 'cf-connecting-ip': `192.0.2.${i + 1}`, 'x-forwarded-for': `198.51.100.${i + 1}` },
    });
    assert.equal(response.status, i < 3 ? 200 : 429);
  }
});

test('trusted Render edge keeps different phones signup limits separate', async t => {
  const origin = await serve(t, (_req, res) => res.end('{}'), { trustCloudflare: true });
  for (let i = 0; i < 4; i++) {
    const response = await fetch(origin + '/function/request_email_code', {
      method: 'POST', body: '{}', headers: { 'cf-connecting-ip': '192.0.2.1' },
    });
    assert.equal(response.status, i < 3 ? 200 : 429);
  }
  assert.equal((await fetch(origin + '/function/request_email_code', {
    method: 'POST', body: '{}', headers: { 'cf-connecting-ip': '192.0.2.2' },
  })).status, 200);
});

test('Funnel uses its overwritten client IP and ignores spoofed Cloudflare headers', async t => {
  const origin = await serve(t, (_req, res) => res.end('{}'), { trustFunnel: true, trustCloudflare: false });
  for (let i = 0; i < 4; i++) {
    const response = await fetch(origin + '/function/request_email_code', {
      method: 'POST', body: '{}',
      headers: { 'x-forwarded-for': '192.0.2.1', 'cf-connecting-ip': `198.51.100.${i + 1}` },
    });
    assert.equal(response.status, i < 3 ? 200 : 429);
  }
  assert.equal((await fetch(origin + '/function/request_email_code', {
    method: 'POST', body: '{}', headers: { 'x-forwarded-for': '192.0.2.2' },
  })).status, 200, 'another phone has its own request budget');
});
