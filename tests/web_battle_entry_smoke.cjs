const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  assert(process.argv[2], 'Usage: node web_battle_entry_smoke.cjs EXPORTED_DIRECTORY [--serve]');
  const directory = path.resolve(process.argv[2]);
  assert(fs.existsSync(path.join(directory, 'index.html')), 'Export the diagnostic first');
  const mime = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
  const server = http.createServer((req, res) => {
    const requestPath = new URL(req.url, 'http://localhost').pathname;
    if (requestPath.startsWith('/qa-sprites/') && requestPath.endsWith('/animation.json')) {
      setTimeout(() => {
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({image: 'sheet.png', frame_width: 4, frame_height: 4, frames: [{x: 0, y: 0, w: 4, h: 4, duration: 1}]}));
      }, 6000);
      return;
    }
    if (requestPath.startsWith('/qa-sprites/') && requestPath.endsWith('/sheet.png')) {
      res.writeHead(200, {'Content-Type': 'image/png'});
      fs.createReadStream(path.join(directory, 'qa-sheet.png')).pipe(res);
      return;
    }
    const file = path.resolve(directory, '.' + new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '/index.html'));
    if (!file.startsWith(directory + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
      res.writeHead(404).end(); return;
    }
    res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream',
      'Content-Length': fs.statSync(file).size, 'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-store' });
    fs.createReadStream(file).pipe(res);
  });
  const serveOnly = process.argv.includes('--serve');
  await new Promise(resolve => server.listen(serveOnly ? 8091 : 0, '127.0.0.1', resolve));
  if (serveOnly) { console.log('Android fixture server ready: 8091'); return; }
  const url = `http://127.0.0.1:${server.address().port}/`;
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', headless: true,
    args: ['--enable-unsafe-swiftshader'] });
  try {
    for (const viewport of [{width: 1280, height: 720}, {width: 844, height: 390}]) {
      const context = await browser.newContext({ viewport });
      const errors = [], warnings = [], consoleLines = [], external = [], failedRequests = [];
      await context.route('**/*', route => {
        if (new URL(route.request().url()).origin !== new URL(url).origin) {
          external.push(new URL(route.request().url()).origin); return route.abort();
        }
        return route.continue();
      });
      const page = await context.newPage();
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => {
        consoleLines.push(m.text());
        if (/^(SCRIPT ERROR:|ERROR:)/.test(m.text())) errors.push(m.text());
        else if (m.type() === 'error') warnings.push(m.text());
      });
      page.on('response', response => {
        if (response.status() >= 400) failedRequests.push(new URL(response.url()).pathname);
      });
      await page.goto(url);
      let results;
      try {
        await page.waitForFunction(() => window.battleEntryQA, null, { timeout: 120000 });
        results = await page.evaluate(() => window.battleEntryQA);
      } finally {
        fs.writeFileSync(path.join(directory, `report-${viewport.width}.json`), JSON.stringify({viewport, results, errors, warnings, external, failedRequests, consoleLines}, null, 2));
        await page.screenshot({ path: path.join(directory, `render-${viewport.width}.png`) });
      }
      assert.deepEqual(errors, [], 'Godot/browser runtime errors');
      assert.deepEqual(external, [], 'Diagnostic must remain offline');
      assert.deepEqual(failedRequests, [], 'All diagnostic resources must load');
      assert.deepEqual(Object.keys(results).sort(), ['battle_entry_slow_sprite_check.gd', 'fullscreen_battle_fade_check.gd', 'trainer_vision_physics_flush_check.gd'].sort());
      assert(Object.values(results).every(code => code === 0), 'Every focused check must pass');
      assert(consoleLines.some(line => /FULLSCREEN_FADE_RENDERED_LEVELS=[4-9]|FULLSCREEN_FADE_RENDERED_LEVELS=\d{2}/.test(line)), 'Actual pixels must show fade levels');
      await context.close();
      console.log(`web_battle_entry_smoke: PASS ${viewport.width}x${viewport.height}`);
    }
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
