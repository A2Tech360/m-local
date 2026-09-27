import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import test from 'node:test';
import { createShareProxy } from '../../scripts/phone-share-proxy.mjs';

test('phone link forwards app/auth traffic but never development files or admin APIs', async t => {
  const seen = [];
  const upstream = http.createServer((req, res) => {
    seen.push(req.url);
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({ authorization: req.headers.authorization, path: req.url }));
  }).listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const proxy = createShareProxy({ upstreamHost: '127.0.0.1', upstreamPort: upstream.address().port });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  t.after(() => { proxy.closeAllConnections(); proxy.close(); upstream.closeAllConnections(); upstream.close(); });
  const origin = `http://127.0.0.1:${proxy.address().port}`;
  for (const path of ['/', '/static/client.js?hash=abc', '/assets/index-Ab12.js', '/assets/index-Ab12.css']) {
    assert.equal((await fetch(origin + path)).status, 200, path);
  }
  for (const path of ['/function/list_offers', '/function/current_session', '/user/login']) {
    const response = await fetch(origin + path, { method: 'POST', body: '{}', headers: { authorization: 'Bearer test-only' } });
    assert.equal(response.status, 200, path);
    assert.equal((await response.json()).authorization, 'Bearer test-only');
  }
  const before = seen.length;
  for (const path of ['/graph/data', '/docs', '/openapi.json', '/.env', '/@fs/etc/passwd',
    '/node_modules/foo', '/compiled/main.js', '/assets/private.map', '/assets/%2e%2e/.env',
    '/function/internal_admin', '/user/register', '/user/delete']) {
    assert.equal((await fetch(origin + path, { method: 'POST', body: '{}' })).status, 403, path);
    assert.equal((await fetch(origin + path)).status, 403, path);
  }
  assert.equal(seen.length, before, 'blocked traffic never reaches Jac');
});

test('offline app returns a recoverable 502 without filesystem details', async t => {
  const unused = http.createServer().listen(0, '127.0.0.1');
  await once(unused, 'listening');
  const port = unused.address().port;
  await new Promise(resolve => unused.close(resolve));
  const proxy = createShareProxy({ upstreamHost: '127.0.0.1', upstreamPort: port });
  proxy.listen(0, '127.0.0.1');
  await once(proxy, 'listening');
  t.after(() => { proxy.closeAllConnections(); proxy.close(); });
  const response = await fetch(`http://127.0.0.1:${proxy.address().port}/`);
  assert.equal(response.status, 502);
  assert.match(await response.text(), /starting|unavailable/i);
});
