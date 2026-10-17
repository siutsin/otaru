# Browserless client — human-like browsing stack

Use this client when a task browses the web through the in-cluster
browserless. It connects by Chrome DevTools Protocol (CDP) to the
service's route host.

## Files

- `cdp.mjs` — a small CDP client. It reads the cached Hydra JWT
  from mcp-cli and connects through the tunnel proxy. It never
  prints the token or the proxy address.
- `human.mjs` — the human-like stack: `connectHuman`,
  `setupPage`, `humanDelay`, `warmVisit`. Every
  deployment-specific value lives in its exported `CONFIG`
  object.

## Setup

```shell
npm ci
```

Set `BROWSERLESS_HOST` to the route host of the in-cluster
browserless service. The client has no default for it.

Optional overrides, with the defaults in use:

- `BROWSERLESS_TZ` — time zone, default `Europe/London`
- `BROWSERLESS_LOCALE` — locale, default `en-GB`
- `BROWSERLESS_WIDTH` — window width, default `1920`
- `BROWSERLESS_HEIGHT` — window height, default `1080`

## How to browse

```js
import { connectHuman, setupPage, warmVisit } from './human.mjs';

const cdp = await connectHuman();
const page = await warmVisit(cdp, 'https://www.example.com/target');
cdp.close();
```

`warmVisit` opens the site home page first, then navigates to
the target in the same session. Pass `{ hop: true }` to follow
one same-origin link on the home page first.

For a plain page without warm-up, call `newPage` from
`cdp.mjs`, then `setupPage` from `human.mjs`, then `navigate`.
Run `setupPage` before the first navigation on every new page.

## Rules

- Keep the native user agent. The stack stays a coherent Linux
  desktop. Never spoof another platform.
- Do not use the `stealth` option. A live test showed that it
  rewrites the user agent to Windows and the WebGL renderer to a
  fake GPU string. The mix contradicts itself and scores worse
  than the honest fingerprint.
- Do not use the `humanlike` option. The server rejects the
  parameter with HTTP 400 on this image.
- Do not rely on a named `--user-data-dir` profile. State does
  not survive a reconnect on this image, in any form the client
  can pass. Build warmth inside each session instead.
- One residual stays: `navigator.languages` reads `en-US` on
  this image. Neither the `--lang` flag nor the CDP locale
  override moves it. The time zone and the rest of the
  fingerprint are coherent. Accept the residual; do not chase
  it with spoofing.
- A connection with no JWT must fail. If one ever succeeds, the
  gateway auth is broken. Stop and report it.

## Stop condition

If a site still shows a press-and-hold or similar human check
after a warm visit, stop. A human completes that check. Do not
add more flags, do not use a solving service, and do not retry
in a loop. Three attempts at one challenged site per task at
most, to protect the home address reputation.
