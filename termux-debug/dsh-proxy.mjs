// Logging proxy for dsh web (debug sessions). Node built-ins only.
//
//   node dsh-proxy.mjs --listen 3080 --target 3180 --log /path/events.log
//
// Every HTTP request and every WebSocket text frame that goes through the proxy is
// written as one line to the log, with secrets redacted. Traffic is forwarded
// unchanged; the proxy only copies bytes for logging.

import http from 'node:http';
import net from 'node:net';
import { appendFileSync } from 'node:fs';
import zlib from 'node:zlib';

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, a) => {
  if (v.startsWith('--')) acc.push([v.slice(2), a[i + 1]]);
  return acc;
}, []));
const LISTEN = Number(args.listen || 3080);
const TARGET = Number(args.target || 3180);
const LOG = args.log || 'events.log';
const HOST = '127.0.0.1';
const BODY_LOG_LIMIT = 4096;      // bytes of each body kept in the log
const BODY_RAW_LIMIT = 262144;    // compressed bytes copied for decoding (log copy only)

// Decode a compressed body for the log copy. Returns null if it cannot be decoded.
function decodeBody(buf, encoding) {
  try {
    if (encoding === 'gzip' || encoding === 'x-gzip') return zlib.gunzipSync(buf);
    if (encoding === 'deflate') return zlib.inflateSync(buf);
    if (encoding === 'br') return zlib.brotliDecompressSync(buf);
    return buf;
  } catch {
    return null;
  }
}
const WS_LOG_LIMIT = 2048;        // characters of each WebSocket text frame kept

function redact(text) {
  return String(text)
    .replace(/(sk-)[A-Za-z0-9_-]{6,}/g, '$1REDACTED')
    .replace(/(Bearer\s+)[A-Za-z0-9._~+/-]+/gi, '$1REDACTED')
    .replace(/(token=)[A-Za-z0-9_.-]+/g, '$1REDACTED')
    .replace(/eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.?[A-Za-z0-9_-]*/g, 'JWT_REDACTED')
    .replace(/([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g, 'EMAIL_REDACTED')
    .replace(/("?(access_token|refresh_token|id_token|api_key|apiKey|DEEPSEEK_API_KEY|OPENAI_API_KEY|password)"?\s*[:=]\s*"?)[^"\s,}]+/gi, '$1REDACTED');
}

function log(kind, detail) {
  const line = `${new Date().toISOString()} ${kind} ${redact(detail).replace(/\r?\n/g, '\\n')}\n`;
  try { appendFileSync(LOG, line); } catch { /* logging must never break dsh */ }
}

const STATIC = /\.(js|mjs|css|png|jpe?g|gif|webp|svg|ico|woff2?|ttf|map|wasm)(\?|$)/i;

function forwardHeaders(headers) {
  const out = { ...headers };
  out.host = `${HOST}:${TARGET}`;
  if (out.origin) out.origin = `http://${HOST}:${TARGET}`;
  if (out.referer) out.referer = out.referer.replace(`:${LISTEN}`, `:${TARGET}`);
  return out;
}

const server = http.createServer((req, res) => {
  const started = Date.now();
  const path = req.url || '/';
  const isStatic = STATIC.test(path);
  const reqChunks = [];
  let reqBytes = 0;

  const upstream = http.request({
    host: HOST,
    port: TARGET,
    method: req.method,
    path,
    headers: forwardHeaders(req.headers),
  }, (up) => {
    const type = String(up.headers['content-type'] || '');
    // Bodies only for JSON, plain text and event streams (not HTML, scripts or images).
    const logBody = !isStatic && /application\/json|text\/plain|event-stream/.test(type);
    const encoding = String(up.headers['content-encoding'] || '').trim().toLowerCase();
    const resChunks = [];
    let resBytes = 0;
    let rawCopied = 0;
    res.writeHead(up.statusCode || 502, up.headers);
    up.on('data', (chunk) => {
      res.write(chunk);
      if (logBody && rawCopied < BODY_RAW_LIMIT) {
        resChunks.push(chunk);
        rawCopied += chunk.length;
      }
      resBytes += chunk.length;
    });
    up.on('end', () => {
      res.end();
      let body = '';
      if (logBody && resChunks.length) {
        let buf = Buffer.concat(resChunks);
        if (encoding && encoding !== 'identity') {
          const decoded = decodeBody(buf, encoding);
          buf = decoded || buf;
          if (!decoded) body = ' body=[' + encoding + ' body, could not decode]';
        }
        if (!body) body = ' body=' + buf.subarray(0, BODY_LOG_LIMIT).toString('utf8');
      }
      log('HTTP', `${req.method} ${path} -> ${up.statusCode} ${Date.now() - started}ms ${resBytes}B ${type.split(';')[0]}${body}`);
    });
    up.on('error', (err) => { log('HTTP-ERR', `${req.method} ${path} upstream ${err.message}`); res.destroy(); });
  });

  upstream.on('error', (err) => {
    log('HTTP-ERR', `${req.method} ${path} ${err.message}`);
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain' });
    res.end('dsh backend not reachable');
  });

  req.on('data', (chunk) => {
    upstream.write(chunk);
    if (!isStatic && reqBytes < BODY_LOG_LIMIT) reqChunks.push(chunk);
    reqBytes += chunk.length;
  });
  req.on('end', () => {
    upstream.end();
    if (reqChunks.length) {
      const body = Buffer.concat(reqChunks).subarray(0, BODY_LOG_LIMIT).toString('utf8');
      log('REQ-BODY', `${req.method} ${path} ${reqBytes}B ${body}`);
    }
  });
});

// ---- WebSocket frames (RFC 6455), observed only ----
class FrameReader {
  constructor(direction, onFrame) {
    this.direction = direction;
    this.onFrame = onFrame;
    this.buf = Buffer.alloc(0);
  }
  push(chunk) {
    this.buf = this.buf.length ? Buffer.concat([this.buf, chunk]) : chunk;
    for (;;) {
      if (this.buf.length < 2) return;
      const b0 = this.buf[0];
      const b1 = this.buf[1];
      const fin = (b0 & 0x80) !== 0;
      const opcode = b0 & 0x0f;
      const masked = (b1 & 0x80) !== 0;
      let len = b1 & 0x7f;
      let offset = 2;
      if (len === 126) {
        if (this.buf.length < 4) return;
        len = this.buf.readUInt16BE(2);
        offset = 4;
      } else if (len === 127) {
        if (this.buf.length < 10) return;
        len = Number(this.buf.readBigUInt64BE(2));
        offset = 10;
      }
      const maskLen = masked ? 4 : 0;
      if (this.buf.length < offset + maskLen + len) return;
      let payload = this.buf.subarray(offset + maskLen, offset + maskLen + len);
      if (masked) {
        const key = this.buf.subarray(offset, offset + 4);
        payload = Buffer.from(payload);
        for (let i = 0; i < payload.length; i++) payload[i] ^= key[i % 4];
      }
      this.buf = this.buf.subarray(offset + maskLen + len);
      this.onFrame({ fin, opcode, length: len, payload });
    }
  }
}

function watchSocket(direction, socket, label) {
  const frames = new FrameReader(direction, (f) => {
    if (f.opcode === 1 || f.opcode === 0) {
      const text = f.payload.subarray(0, WS_LOG_LIMIT).toString('utf8');
      log('WS', `${label} ${direction} text ${f.length}B ${text}`);
    } else if (f.opcode === 2) {
      log('WS', `${label} ${direction} binary ${f.length}B`);
    } else if (f.opcode === 8) {
      log('WS', `${label} ${direction} close`);
    }
  });
  return frames;
}

server.on('upgrade', (req, clientSocket, head) => {
  const label = `${req.url}`;
  log('WS-OPEN', `${label} from browser`);
  const upSocket = net.connect(TARGET, HOST, () => {
    const headerLines = [`${req.method} ${req.url} HTTP/${req.httpVersion}`];
    for (const [k, v] of Object.entries(forwardHeaders(req.headers))) {
      headerLines.push(`${k}: ${Array.isArray(v) ? v.join(', ') : v}`);
    }
    upSocket.write(headerLines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) upSocket.write(head);   // bytes read after the upgrade headers
  });
  const toServer = watchSocket('client->server', upSocket, label);
  const toClient = watchSocket('server->client', clientSocket, label);
  if (head && head.length) toServer.push(head);
  clientSocket.on('data', (chunk) => { upSocket.write(chunk); toServer.push(chunk); });
  upSocket.on('data', (chunk) => { clientSocket.write(chunk); toClient.push(chunk); });
  const end = (why) => { log('WS-CLOSE', `${label} ${why}`); clientSocket.destroy(); upSocket.destroy(); };
  clientSocket.on('error', () => end('client error'));
  upSocket.on('error', () => end('backend error'));
  clientSocket.on('close', () => end('client closed'));
  upSocket.on('close', () => end('backend closed'));
});

server.listen(LISTEN, HOST, () => {
  log('PROXY', `listening on ${HOST}:${LISTEN} -> backend ${HOST}:${TARGET}`);
});
