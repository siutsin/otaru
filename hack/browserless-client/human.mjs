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

async function mouseTo(cdp, s, x, y, steps = 14) {
  const from = await evaluate(cdp, s, 'window.__blMouse || [640, 400]').catch(() => [640, 400]);
  const bend = (Math.random() - 0.5) * 160;
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const px = from[0] + (x - from[0]) * t + Math.sin(t * Math.PI) * bend * (1 - t);
    const py = from[1] + (y - from[1]) * t + Math.cos(t * Math.PI) * bend * 0.4 * (1 - t);
    await cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py }, s);
    await sleep(16 + Math.random() * 30);
  }
  await evaluate(cdp, s, `window.__blMouse = [${x}, ${y}]; true`).catch(() => {});
}

async function clickAt(cdp, s, x, y) {
  await mouseTo(cdp, s, x, y);
  await sleep(120 + Math.random() * 200);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 }, s);
  await sleep(60 + Math.random() * 120);
  await cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 }, s);
}

export async function scrollSteps(cdp, s, times = 3) {
  for (let i = 0; i < times; i++) {
    await evaluate(cdp, s, `window.scrollBy(0, ${Math.round(380 + Math.random() * 320)}); true`).catch(() => {});
    await humanDelay(700, 1600);
  }
}

export async function acceptCookies(cdp, s) {
  const box = await evaluate(cdp, s, `(() => {
    const rx = /^(accept|accept all|allow all|agree|i agree|got it|ok)$/i;
    for (const el of document.querySelectorAll('button, [role="button"], a')) {
      if (rx.test((el.innerText || '').trim())) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.height > 0) return [r.x + r.width / 2, r.y + r.height / 2];
      }
    }
    return null;
  })()`).catch(() => null);
  if (box) { await clickAt(cdp, s, box[0], box[1]); await humanDelay(); return true; }
  return false;
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
