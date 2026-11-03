/**
 * Web smoke test for the exported build.
 *
 * Prerequisites:
 *   npm install playwright            (from a temporary directory or tests/)
 *   python3 -m http.server 8765 --directory exports/web
 *
 * Run:
 *   node tests/web_smoke.mjs
 *   OMS_URL=http://127.0.0.1:8765 node tests/web_smoke.mjs
 *
 * Uses the locally installed Chrome channel (no browser download required).
 * Screenshots are written to tests/artifacts/.
 */
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const URL = process.env.OMS_URL || 'http://127.0.0.1:8765';
const OUT = 'tests/artifacts';
await mkdir(OUT, { recursive: true });

const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: [
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--autoplay-policy=no-user-gesture-required',
  ],
});

const errors = [];
const requests = [];
const context = await browser.newContext({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});
const page = await context.newPage();
page.on('pageerror', (error) => errors.push(`[pageerror] ${error.message}`));
page.on('request', (request) => requests.push(request.url()));
page.on('requestfailed', (request) => errors.push(`[requestfailed] ${request.url()} ${request.failure()?.errorText}`));
page.on('console', (message) => {
  if (message.type() === 'error') errors.push(`[console] ${message.text()}`);
});

try {
  await page.goto(URL, { waitUntil: 'load', timeout: 90000 });
  await page.waitForSelector('#status.is-hidden', { timeout: 90000 });
  await page.waitForTimeout(1000);
  const adStatus = await page.evaluate(() => {
    if (!window.OMSAdsBridge) return { bridge: false };
    return {
      bridge: true,
      status: JSON.parse(window.OMSAdsBridge.getStatus()),
      adScripts: document.querySelectorAll("script[data-oms-adsense]").length,
      prompt: document.querySelectorAll("#oms-reward-prompt").length,
    };
  });
  if (!adStatus.bridge) {
    errors.push("[ads] OMSAdsBridge is missing from the web shell");
  } else if (!adStatus.status.enabled) {
    const googleRequests = requests.filter((url) => url.includes("googlesyndication") || url.includes("doubleclick"));
    if (adStatus.adScripts !== 0) errors.push("[ads] disabled build loaded the AdSense script");
    if (adStatus.prompt !== 0) errors.push("[ads] disabled build created a reward prompt");
    if (googleRequests.length !== 0) errors.push(`[ads] disabled build made ${googleRequests.length} Google ad request(s)`);
  }
  console.log(`ads: ${JSON.stringify(adStatus)}`);
  await page.screenshot({ path: `${OUT}/web-menu.png` });

  // PLAY button position in the 390x844 letterboxed viewport.
  await page.touchscreen.tap(195, 552);
  await page.waitForTimeout(2200);
  await page.screenshot({ path: `${OUT}/web-gameplay.png` });

  await page.touchscreen.tap(195, 400);
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${OUT}/web-switch.png` });

  await page.touchscreen.tap(34, 109);
  await page.waitForTimeout(500);
  await page.screenshot({ path: `${OUT}/web-pause.png` });

  console.log(`title: ${await page.title()}`);
  if (errors.length > 0) {
    console.error(errors.join('\n'));
    process.exitCode = 1;
  } else {
    console.log('web smoke: PASS (no page errors, failed requests or console errors)');
  }
} finally {
  await browser.close();
}
