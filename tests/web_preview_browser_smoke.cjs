// Run with Playwright installed (or NODE_PATH pointing to an existing install).
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const url = process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8060';
  assert(['127.0.0.1', 'localhost'].includes(new URL(url).hostname), 'smoke test only targets loopback');
  const browser = await chromium.launch({
    executablePath: process.env.POKEAETHER_CHROME_PATH || undefined,
    headless: true,
    args: ['--enable-unsafe-swiftshader'],
  });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const errors = [];
  const external = [];
  const failed = [];
  await context.route('**/*', async route => {
    const requestUrl = new URL(route.request().url());
    if (requestUrl.origin !== new URL(url).origin) {
      external.push(requestUrl.origin); // no query strings or payloads
      return route.abort();
    }
    await route.continue();
  });
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('response', response => {
    if (response.status() >= 400) failed.push({path: new URL(response.url()).pathname, status: response.status()});
  });
  const output = path.resolve(__dirname, '../builds/web-qa');
  fs.mkdirSync(output, { recursive: true });
  try {
    await page.goto(url);
    await page.getByRole('button', { name: 'Open browser preview' }).click();
    await page.waitForFunction(() => window.pokeaetherPreview?.state === 'running', null, { timeout: 120000 });
    await page.waitForFunction(() => window.pokeaetherPreview?.loginReady === true, null, { timeout: 30000 });
    await page.waitForTimeout(6000);
    await page.screenshot({ path: path.join(output, 'login.png') });
    // Godot renders UI into the canvas. At this fixed viewport this is Options;
    // Escape can be consumed by the initially focused username LineEdit.
    await page.mouse.click(1326, 710);
    await page.waitForTimeout(1000);
    await page.screenshot({ path: path.join(output, 'settings.png') });
    await page.keyboard.press('Escape');
    await page.reload();
    await page.getByRole('button', { name: 'Open browser preview' }).click();
    await page.waitForFunction(() => window.pokeaetherPreview?.state === 'running', null, { timeout: 120000 });
    await page.waitForFunction(() => window.pokeaetherPreview?.loginReady === true, null, { timeout: 30000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(output, 'reload.png') });
    fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ errors, external, failed }, null, 2));
    assert.deepEqual(external, [], 'no production or external requests');
    assert.deepEqual(failed, [], 'all runtime resources load');
    assert.equal(errors.length, 0, `browser/Godot errors; see result.json. First: ${errors[0] || ''}`);
    console.log('web_preview_browser_smoke: PASS (boot, settings, refresh, no external requests)');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
