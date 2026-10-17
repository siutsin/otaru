// Never print the token or the proxy URL.
import WebSocket from 'ws';
import { HttpsProxyAgent } from 'https-proxy-agent';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const TOKEN_FILE = `${process.env.HOME}/.cache/mcp-cli/token-muse.json`;
const MCP_CLI = `${process.env.HOME}/workspace/custom-skills/local-mcp/bin/mcp-cli`;
export const HOST = process.env.BROWSERLESS_HOST;

export function getToken() {
  let t = JSON.parse(readFileSync(TOKEN_FILE, 'utf8'));
  if (!t.expires_at || t.expires_at * 1000 < Date.now() + 60000) {
    execFileSync(MCP_CLI, ['status'], { stdio: 'ignore' });
    t = JSON.parse(readFileSync(TOKEN_FILE, 'utf8'));
  }
  return t.access_token;
}

function tunnelProxyUrl() {
  return process.env.HTTPS_PROXY.replace(/:\d+\/?$/, ':3130');
}

export class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    this.listeners = [];
    ws.on('message', (data) => {
      const m = JSON.parse(data);
      if (m.id && this.pending.has(m.id)) {
        const { resolve, reject } = this.pending.get(m.id);
        this.pending.delete(m.id);
        if (m.error) reject(new Error(`${m.error.message || 'CDP error'} (${m.error.code})`));
        else resolve(m.result);
      } else if (m.method) {
        for (const f of this.listeners) f(m);
      }
    });
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    const msg = { id, method, params };
    if (sessionId) msg.sessionId = sessionId;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify(msg));
    });
  }

  on(fn) {
    this.listeners.push(fn);
  }

  waitFor(method, sessionId, timeoutMs = 45000) {
    return new Promise((resolve, reject) => {
      const to = setTimeout(() => reject(new Error(`timeout waiting for ${method}`)), timeoutMs);
      this.listeners.push((m) => {
        if (m.method === method && (!sessionId || m.sessionId === sessionId)) {
          clearTimeout(to);
          resolve(m.params);
        }
      });
    });
  }

  close() {
    try { this.ws.close(); } catch {}
  }
}

// headers: pass {} for no Authorization header; that is the refusal control.
export async function connect({ query = '', headers } = {}) {
  const hdrs = headers !== undefined ? headers : { Authorization: `Bearer ${getToken()}` };
  const ws = new WebSocket(`wss://${HOST}/chromium${query}`, {
    agent: new HttpsProxyAgent(tunnelProxyUrl()),
    headers: hdrs,
    handshakeTimeout: 30000,
  });
  await new Promise((resolve, reject) => {
    ws.once('open', resolve);
    ws.once('error', reject);
    ws.once('unexpected-response', (req, res) => reject(new Error(`HTTP ${res.statusCode}`)));
  });
  return new Cdp(ws);
}

export async function newPage(cdp) {
  const { targetId } = await cdp.send('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await cdp.send('Target.attachToTarget', { targetId, flatten: true });
  await cdp.send('Page.enable', {}, sessionId);
  await cdp.send('Runtime.enable', {}, sessionId);
  await cdp.send('Network.enable', {}, sessionId);
  return sessionId;
}

export async function evaluate(cdp, sessionId, expression) {
  const r = await cdp.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }, sessionId);
  if (r.exceptionDetails) throw new Error('evaluate failed: ' + JSON.stringify(r.exceptionDetails).slice(0, 300));
  return r.result ? r.result.value : undefined;
}

export async function navigate(cdp, sessionId, url, timeoutMs = 45000) {
  let status = null;
  const detach = (m) => {
    if (m.method === 'Network.responseReceived' && m.sessionId === sessionId &&
        m.params.type === 'Document' && m.params.response.url.startsWith(url.split('#')[0])) {
      status = m.params.response.status;
    }
  };
  cdp.on(detach);
  const loaded = cdp.waitFor('Page.loadEventFired', sessionId, timeoutMs).catch(() => null);
  const r = await cdp.send('Page.navigate', { url }, sessionId);
  await loaded;
  return { status, errorText: r.errorText || null };
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
