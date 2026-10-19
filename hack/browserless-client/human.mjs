// No stealth: it spoofs a Windows user agent on a Linux platform and breaks fingerprint coherence.
// No humanlike option: the server rejects the parameter (HTTP 400).
// No named --user-data-dir profiles: their state does not survive a reconnect on this image.
import { connect, newPage, evaluate, navigate, sleep } from './cdp.mjs';

const envInt = (name, fallback) => {
  const v = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isNaN(v) ? fallback : v;
};

// Headful, so the user agent has no HeadlessChrome token and the window has a real frame.
// AutomationControlled disabled, so navigator.webdriver reads false.
export const CONFIG = {
  timezone: process.env.BROWSERLESS_TZ || 'Europe/London',
  locale: process.env.BROWSERLESS_LOCALE || 'en-GB',
  width: envInt('BROWSERLESS_WIDTH', 1920),
  height: envInt('BROWSERLESS_HEIGHT', 1080),
  headless: false,
  args: ['--disable-blink-features=AutomationControlled'],
};

export function connectHuman() {
  const launch = { headless: CONFIG.headless, args: [...CONFIG.args, `--window-size=${CONFIG.width},${CONFIG.height}`] };
  const q = '?launch=' + encodeURIComponent(Buffer.from(JSON.stringify(launch)).toString('base64'));
  return connect({ query: q });
}

export async function setupPage(cdp, s) {
  await cdp.send('Emulation.setTimezoneOverride', { timezoneId: CONFIG.timezone }, s);
  await cdp.send('Emulation.setLocaleOverride', { locale: CONFIG.locale }, s);
  // Height minus 40 leaves a frame delta, like a real maximized window.
  // screenWidth and screenHeight must ride along, or the emulated screen stays 1024x768.
  await cdp.send('Emulation.setDeviceMetricsOverride',
    { width: CONFIG.width, height: CONFIG.height - 40, deviceScaleFactor: 1, mobile: false, screenWidth: CONFIG.width, screenHeight: CONFIG.height }, s);
}

export function humanDelay(minMs = 1200, maxMs = 3200) {
  const base = minMs + Math.random() * (maxMs - minMs);
  const jitter = (Math.random() + Math.random() + Math.random() - 1.5) / 1.5 * 400;
  return sleep(Math.max(300, base + jitter));
}

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
// Centre-weighted random in -1..1.
const tri = () => Math.random() + Math.random() - 1;

function sampleInBox(x, y, w, h) {
  if (w <= 6 || h <= 6) return [x + w / 2, y + h / 2];
  return [
    clamp(x + w / 2 + tri() * w * 0.3, x + 2, x + w - 2),
    clamp(y + h / 2 + tri() * h * 0.3, y + 2, y + h - 2),
  ];
}

async function mouseTo(cdp, s, x, y) {
  const from = await evaluate(cdp, s, 'window.__blMouse || [640, 400]').catch(() => [640, 400]);
  const dx = x - from[0];
  const dy = y - from[1];
  const dist = Math.hypot(dx, dy);
  if (dist < 2) {
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y }, s);
    await evaluate(cdp, s, `window.__blMouse = [${x}, ${y}]; true`).catch(() => {});
    return;
  }
  const steps = clamp(Math.round(dist / 20), 6, 48);
  // sin(e * PI) is 0 at both ends, so the curve ends exactly on target.
  const bend = (Math.random() - 0.5) * Math.min(160, dist * 0.4);
  const ux = -dy / dist;
  const uy = dx / dist;
  const over = dist > 600 && Math.random() < 0.35 ? 6 + Math.random() * 14 : 0;
  const tx = x + (dx / dist) * over;
  const ty = y + (dy / dist) * over;
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const e = t * t * (3 - 2 * t);
    let px = from[0] + (tx - from[0]) * e + ux * Math.sin(e * Math.PI) * bend;
    let py = from[1] + (ty - from[1]) * e + uy * Math.sin(e * Math.PI) * bend;
    if (i < steps) {
      px += (Math.random() - 0.5) * 2;
      py += (Math.random() - 0.5) * 2;
    } else {
      px = tx;
      py = ty;
    }
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py }, s);
    await sleep(10 + Math.random() * 22);
  }
  for (let i = 1; over && i <= 4; i++) {
    const px = tx + (x - tx) * (i / 4);
    const py = ty + (y - ty) * (i / 4);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py }, s);
    await sleep(14 + Math.random() * 24);
  }
  await evaluate(cdp, s, `window.__blMouse = [${x}, ${y}]; true`).catch(() => {});
}

async function clickAt(cdp, s, x, y, rx = x, ry = y) {
  await mouseTo(cdp, s, x, y);
  await sleep(120 + Math.random() * 200);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 }, s);
  await sleep(60 + Math.random() * 120);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: rx, y: ry, button: 'left', clickCount: 1 }, s);
}

export async function scrollSteps(cdp, s, times = 3) {
  // Wheel events act on the element under the pointer.
  const [x, y] = await evaluate(cdp, s, 'window.__blMouse || [640, 400]').catch(() => [640, 400]);
  for (let i = 0; i < times; i++) {
    let left = 380 + Math.random() * 320;
    while (left > 0) {
      const chunk = Math.min(left, 60 + Math.random() * 120);
      await cdp.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x, y, deltaX: 0, deltaY: chunk }, s);
      left -= chunk;
      await sleep(40 + Math.random() * 90);
    }
    await humanDelay(700, 1600);
  }
}

export async function acceptCookies(cdp, s) {
  const rect = await evaluate(cdp, s, `(() => {
    const rx = /^(accept|accept all|allow all|agree|i agree|got it|ok)$/i;
    for (const el of document.querySelectorAll('button, [role="button"], a')) {
      if (rx.test((el.innerText || '').trim())) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.height > 0) return [r.x, r.y, r.width, r.height];
      }
    }
    return null;
  })()`).catch(() => null);
  if (!rect) return false;
  const [px, py] = sampleInBox(...rect);
  // A 7 px box on the press point: the release stays within 1.5 px and inside the element.
  const [ex, ey] = rect[2] > 6 && rect[3] > 6 ? sampleInBox(px - 3.5, py - 3.5, 7, 7) : [px, py];
  await clickAt(cdp, s, px, py, ex, ey);
  await humanDelay();
  return true;
}

export async function warmVisit(cdp, targetUrl, { hop = false } = {}) {
  const s = await newPage(cdp);
  await setupPage(cdp, s);
  const home = new URL(targetUrl).origin + '/';
  await navigate(cdp, s, home);
  await humanDelay(1800, 3600);
  await acceptCookies(cdp, s);
  await scrollSteps(cdp, s, 2);
  if (hop) {
    const link = await evaluate(cdp, s, `(() => {
      const a = [...document.querySelectorAll('a[href]')]
        .find((el) => el.href.startsWith(location.origin) && el.href !== location.href
          && el.getBoundingClientRect().width > 0);
      return a ? a.href : null;
    })()`).catch(() => null);
    if (link) {
      await navigate(cdp, s, link);
      await humanDelay(1500, 3000);
      await scrollSteps(cdp, s, 2);
    }
  }
  const nav = await navigate(cdp, s, targetUrl);
  await humanDelay(1600, 3000);
  await scrollSteps(cdp, s, 2);
  const info = await evaluate(cdp, s, `({
    title: document.title, url: location.href,
    text: (document.body ? document.body.innerText : '').slice(0, 400) })`)
    .catch((e) => ({ error: String(e).slice(0, 200) }));
  return { sessionId: s, ...nav, ...info };
}
