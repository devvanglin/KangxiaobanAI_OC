'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');
const { URL } = require('url');

const root = path.resolve(process.env.WEB_ROOT || '/web');
const backend = new URL(process.env.BACKEND_URL || 'http://api:8080');
const port = Number(process.env.PORT || 8080);
const backendPrefix = String(process.env.BACKEND_PREFIX || '').replace(/\/$/, '');

const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.map': 'application/json; charset=utf-8',
};

function safeFile(requestPath) {
  let decoded;
  try {
    decoded = decodeURIComponent(requestPath.split('?')[0]);
  } catch (_error) {
    return null;
  }
  const normalized = path.normalize(decoded).replace(/^([/\\])+/, '');
  const candidate = path.resolve(root, normalized);
  if (candidate !== root && !candidate.startsWith(root + path.sep)) {
    return null;
  }
  return candidate;
}

function sendFile(req, res, filename) {
  fs.stat(filename, (error, stat) => {
    if (error || !stat.isFile()) {
      res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      res.end('Not found');
      return;
    }
    const headers = {
      'content-type': mime[path.extname(filename).toLowerCase()] || 'application/octet-stream',
      'content-length': stat.size,
      'cache-control': path.basename(filename) === 'index.html' ? 'no-cache' : 'public, max-age=86400',
    };
    res.writeHead(200, headers);
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    fs.createReadStream(filename).pipe(res);
  });
}

function proxy(req, res) {
  let upstreamPath = req.url;
  if (backendPrefix && (upstreamPath === backendPrefix || upstreamPath.startsWith(backendPrefix + '/'))) {
    upstreamPath = upstreamPath.slice(backendPrefix.length) || '/';
  }
  const options = {
    protocol: backend.protocol,
    hostname: backend.hostname,
    port: backend.port || 80,
    method: req.method,
    path: upstreamPath,
    headers: { ...req.headers, host: backend.host, 'x-forwarded-proto': 'http' },
  };
  const upstream = http.request(options, upstreamResponse => {
    res.writeHead(upstreamResponse.statusCode || 502, upstreamResponse.headers);
    upstreamResponse.pipe(res);
  });
  upstream.on('error', error => {
    res.writeHead(502, { 'content-type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify({ code: 502, message: `Backend unavailable: ${error.message}` }));
  });
  req.pipe(upstream);
}

const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  const candidate = safeFile(pathname === '/' ? '/index.html' : pathname);
  if ((req.method === 'GET' || req.method === 'HEAD') && candidate && fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
    sendFile(req, res, candidate);
    return;
  }
  const acceptsHtml = String(req.headers.accept || '').includes('text/html');
  if ((req.method === 'GET' || req.method === 'HEAD') && acceptsHtml) {
    sendFile(req, res, path.join(root, 'index.html'));
    return;
  }
  proxy(req, res);
});

server.listen(port, '0.0.0.0', () => {
  process.stdout.write(`gateway listening on ${port}, backend=${backend.href}, strip=${backendPrefix || '(none)'}\n`);
});
