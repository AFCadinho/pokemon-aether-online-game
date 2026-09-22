const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const url = 'http://127.0.0.1:8063/';
  const output = path.resolve(__dirname, '../builds/web-misty-trial');
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true,
    args: ['--enable-unsafe-swiftshader'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
    const errors = [], warnings = [], failed = [], external = [];
    await context.route('**/*', route => {
      if (new URL(route.request().url()).origin !== new URL(url).origin) {
        external.push(new URL(route.request().url()).origin);
        return route.abort();
      }
      return route.continue();
    });
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    let uidWarningContinuation = false;
    page.on('console', m => {
      if (m.type() !== 'error') return;
      const text = m.text();
      // The bare probe has no game UID registry. Retain, don't conceal, the
      // exact successful path-fallback warning; all other errors fail QA.
      if (/^WARNING: 'res:\/\/generated\/tiled_visuals\/[^']+': In external resource #0, invalid UID: '[^']+' - using text path instead: 'res:\/\/generated\/tiled_visuals\/[^']+'\.$/.test(text)) {
        warnings.push(text); uidWarningContinuation = true; return;
      }
      if (uidWarningContinuation && /^   at: open \(core\/io\/resource_format_binary\.cpp:\d+\)$/.test(text)) {
        warnings.push(text); uidWarningContinuation = false; return;
      }
      uidWarningContinuation = false; errors.push(text);
    });
    page.on('response', r => { if (r.status() >= 400) failed.push(new URL(r.url()).pathname); });
    const cdp = await context.newCDPSession(page);
    await cdp.send('Performance.enable');
    await page.goto(url);
    await page.waitForFunction(() => window.mistyProbe, null, { timeout: 120000 });
    const report = await page.evaluate(() => window.mistyProbe);
    report.browserMetrics = (await cdp.send('Performance.getMetrics')).metrics;
    report.networkResources = await page.evaluate(() => performance.getEntriesByType('resource').map(r => ({
      path: new URL(r.name).pathname, transferSize: r.transferSize,
      encodedBodySize: r.encodedBodySize, decodedBodySize: r.decodedBodySize,
      durationMs: r.duration,
    })));
    report.browserErrors = errors; report.browserWarnings = warnings;
    report.failedRequests = failed; report.externalRequests = external;
    fs.writeFileSync(path.join(output, 'browser-report.json'), JSON.stringify(report, null, 2));
    await page.screenshot({ path: path.join(output, 'bills-house.png') });
    assert.equal(report.success, true);
    assert.equal(report.visuals.length, 12);
    assert.deepEqual(errors, []);
    assert.deepEqual(failed, []);
    assert.deepEqual(external, []);
    console.log('web_misty_asset_probe: PASS (12 visuals, isolated browser, network/memory report)');
  } finally { await browser.close(); }
})().catch(e => { console.error(e.message); process.exitCode = 1; });
