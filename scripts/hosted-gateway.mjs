import { createShareProxy } from './phone-share-proxy.mjs';

const port = Number(process.env.PORT || 10000);
const upstreamPort = Number(process.env.MLOCAL_BACKEND_PORT || 8200);
const ingress = process.env.MLOCAL_INGRESS || 'direct';
if (!Number.isInteger(port) || port < 1 || port > 65535 ||
    !Number.isInteger(upstreamPort) || upstreamPort < 1 || upstreamPort > 65535 ||
    !['direct', 'render', 'funnel'].includes(ingress)) {
  throw new Error('Invalid hosting port or MLOCAL_INGRESS (direct, render, or funnel).');
}
const proxy = createShareProxy({
  upstreamHost: '127.0.0.1', upstreamPort,
  trustCloudflare: ingress === 'render', trustFunnel: ingress === 'funnel', healthCheck: true,
});
proxy.on('error', error => { console.error(error.message); process.exitCode = 1; });
proxy.listen(port, ingress === 'funnel' ? '127.0.0.1' : '0.0.0.0', () => console.log(`M-Local gateway listening on port ${port}.`));
const stop = () => { proxy.closeAllConnections(); proxy.close(); };
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
