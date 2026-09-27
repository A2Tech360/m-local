// Public app ingress: compiled assets and the app's exact RPCs only.
// Never place the development relay or the raw Jac server behind a tunnel.
import http from 'node:http';
import {isIP} from 'node:net';
import { pathToFileURL } from 'node:url';
import {createOnboardingLimit} from './onboarding-ingress.mjs';

const functions = new Set(['list_offers', 'get_offer', 'claim_offer', 'merchant_portal',
  'update_profile', 'save_offer', 'set_offer_status', 'resolve_claim', 'redeem_claim',
  'cancel_claim', 'offer_defaults', 'current_session', 'request_email_code', 'verify_email_code',
  'get_business_draft', 'import_business_website', 'save_business_draft',
  'get_account_profile', 'save_account_profile']);

export function createShareProxy({ upstreamHost = 'localhost', upstreamPort = 8200,
  trustCloudflare = true, trustFunnel = false, healthCheck = false } = {}) {
  const limit=createOnboardingLimit();
  return http.createServer((req, res) => {
    const path = req.url.split('?')[0];
    const read = ['GET', 'HEAD'].includes(req.method);
    const allowed = read && (path === '/' || path === '/index.html' || path === '/favicon.ico' || path === '/static/client.js'
      || /^\/assets\/[\w-]+\.(js|css|png|svg|ico|webp|woff2?)$/.test(path))
      || req.method === 'POST' && functions.has(path.replace(/^\/function\//, '')) && path.startsWith('/function/');
    res.setHeader('x-content-type-options', 'nosniff');
    res.setHeader('referrer-policy', 'no-referrer');
    res.setHeader('permissions-policy', 'camera=(self), microphone=(), geolocation=()');
    res.setHeader('cache-control', 'no-store');
    if (healthCheck && read && path === '/healthz') {
      const finish = ready => {
        if (res.writableEnded) return;
        res.writeHead(ready ? 200 : 503, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ ready }));
      };
      const check = http.get({ hostname: upstreamHost, port: upstreamPort, path: '/ready', timeout: 5000 }, response => {
        response.resume();
        finish(response.statusCode === 200);
      });
      check.on('timeout', () => check.destroy());
      check.on('error', () => finish(false));
      return;
    }
    if (!allowed) { res.writeHead(403); res.end('This endpoint is not available.'); return; }
    // The phone launcher uses a loopback cloudflared connection. Hosted callers
    // must explicitly opt into an edge that overwrites CF-Connecting-IP (Render).
    // A direct listener must not trust caller-supplied forwarding headers.
    const cloudflareIp=req.headers['cf-connecting-ip'];
    const funnelIp=req.headers['x-forwarded-for'];
    const loopback=['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress);
    // Funnel's HTTP proxy replaces X-Forwarded-For. It does not sanitize CF IP.
    // Trust one valid address only from the local daemon, never a forwarded list.
    const client=trustFunnel
      ? (loopback&&typeof funnelIp==='string'&&isIP(funnelIp)?funnelIp:req.socket.remoteAddress)
      : (trustCloudflare&&typeof cloudflareIp==='string'&&isIP(cloudflareIp)?cloudflareIp:req.socket.remoteAddress);
    const retry=limit(client,path);
    if(retry){res.writeHead(429,{'content-type':'application/json','retry-after':String(retry)});res.end(JSON.stringify({ok:false,error:{code:'RATE_LIMITED',message:'Too many sign-in attempts. Please wait before retrying.'}}));return;}
    const upstream = http.request({ hostname: upstreamHost, port: upstreamPort,
      path: req.url, method: req.method,
      headers: { ...req.headers, host: `${upstreamHost}:${upstreamPort}` },
    }, response => {
      // Keep credentials and dynamic responses out of intermediary caches.
      res.writeHead(response.statusCode, { ...response.headers, 'cache-control': 'no-store' });
      response.pipe(res);
    });
    upstream.setTimeout(path==='/function/import_business_website'?75000:30000, () => upstream.destroy(new Error('timeout')));
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
