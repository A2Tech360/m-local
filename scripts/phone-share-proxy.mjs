// Public demo ingress: compiled assets and the app's exact RPCs only.
// Never place the development relay or the raw Jac server behind a tunnel.
import http from 'node:http';
import { pathToFileURL } from 'node:url';

const functions = new Set(['list_offers', 'get_offer', 'claim_offer', 'merchant_portal',
  'update_profile', 'save_offer', 'set_offer_status', 'resolve_claim', 'redeem_claim',
  'cancel_claim', 'offer_defaults', 'current_session']);

export function createShareProxy({ upstreamHost = 'localhost', upstreamPort = 8200 } = {}) {
  return http.createServer((req, res) => {
    const path = req.url.split('?')[0];
    const read = ['GET', 'HEAD'].includes(req.method);
    const allowed = read && (path === '/' || path === '/index.html' || path === '/favicon.ico' || path === '/static/client.js'
      || /^\/assets\/[\w-]+\.(js|css|png|svg|ico|webp|woff2?)$/.test(path))
      || req.method === 'POST' && (functions.has(path.replace(/^\/function\//, '')) && path.startsWith('/function/')
        || path === '/user/login');
    res.setHeader('x-content-type-options', 'nosniff');
    res.setHeader('referrer-policy', 'no-referrer');
    res.setHeader('permissions-policy', 'camera=(self), microphone=(), geolocation=()');
    res.setHeader('cache-control', 'no-store');
    if (!allowed) { res.writeHead(403); res.end('Not available through the team demo.'); return; }
    const upstream = http.request({ hostname: upstreamHost, port: upstreamPort,
      path: req.url, method: req.method,
      headers: { ...req.headers, host: `${upstreamHost}:${upstreamPort}` },
    }, response => {
      // Keep credentials and dynamic responses out of intermediary caches.
      res.writeHead(response.statusCode, { ...response.headers, 'cache-control': 'no-store' });
      response.pipe(res);
    });
    upstream.setTimeout(30000, () => upstream.destroy(new Error('timeout')));
    upstream.on('error', () => {
      if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain' });
      res.end('M-Local is starting or unavailable. Ask the host to check the launcher, then reload.');
    });
    req.on('aborted', () => upstream.destroy());
    res.on('close', () => { if (!res.writableEnded) upstream.destroy(); });
    req.pipe(upstream);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const proxy = createShareProxy();
  proxy.on('error', error => { console.error(error.message); process.exitCode = 1; });
  proxy.listen(8280, '127.0.0.1', () => console.log('M-Local sharing gateway ready on 127.0.0.1:8280.'));
  const stop = () => { proxy.closeAllConnections(); proxy.close(); };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}
