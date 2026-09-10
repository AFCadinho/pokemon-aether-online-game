// Real account HTTP handlers + in-memory SQLite over a private subprocess pipe.
// No backend port, Compose change, production traffic or saved test credentials.
const { chromium } = require('playwright');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const frontend = path.resolve(__dirname, '..');
  const backend = path.resolve(frontend, '../backend');
  const python = process.env.POKEAETHER_TEST_PYTHON;
  assert(python, 'Set POKEAETHER_TEST_PYTHON to the account-service test Python');
  const bridge = spawn(python, ['tests/web_browser_bridge.py', frontend], {
    cwd: path.join(backend, 'account-service'), stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, POKEAETHER_WEB_BROWSER_TEST: '1' },
  });
  bridge.stderr.on('data', () => {}); // Never print private payloads from a traceback.
  const pending = [];
  readline.createInterface({ input: bridge.stdout }).on('line', line => pending.shift()?.resolve(JSON.parse(line)));
  bridge.on('exit', () => { for (const task of pending.splice(0)) task.reject(new Error('Isolated account fixture exited')); });
  const request = data => new Promise((resolve, reject) => {
    pending.push({ resolve, reject }); bridge.stdin.write(JSON.stringify(data) + '\n');
  });
  const browser = await chromium.launch({ executablePath: process.env.POKEAETHER_CHROME_PATH || undefined, headless: true, args: ['--enable-unsafe-swiftshader'] });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const errors = [], external = [], api = [];
  const output = path.join(frontend, 'builds/web-accounts-qa');
  fs.mkdirSync(output, { recursive: true });
  await context.route('**/*', async route => {
    const req = route.request(), url = new URL(req.url());
    if (url.origin !== 'http://127.0.0.1:8060') { external.push(url.origin); return route.abort(); }
    if (!url.pathname.startsWith('/api/')) return route.continue();
    const result = await request({ method: req.method(), path: url.pathname, body: req.postData() || '', headers: req.headers() });
    api.push({ path: url.pathname, status: result.status });
    return route.fulfill({ status: result.status, contentType: 'application/json', body: result.body });
  });
  page.on('pageerror', () => errors.push('pageerror'));
  page.on('console', message => {
    if (message.type() === 'error' && !message.text().includes('Failed to load resource')) errors.push(message.text());
  });
  const start = async () => {
    await page.getByRole('button', { name: 'Open browser preview' }).click();
    await page.waitForFunction(() => window.pokeaetherPreview?.loginReady, null, { timeout: 120000 });
    await page.waitForTimeout(2500);
  };
  try {
    await page.goto('http://127.0.0.1:8060');
    await page.evaluate(() => window.pokeaetherOpenRegistration());
    await page.getByLabel('Username', { exact: true }).fill('browsertrainer');
    await page.getByLabel('Email', { exact: true }).fill('browsertrainer@example.test');
    await page.getByLabel('Password', { exact: true }).fill('test-only correct horse');
    await page.getByLabel('Confirm password', { exact: true }).fill('test-only correct horse');
    await page.getByRole('checkbox').nth(0).check();
    await page.getByRole('checkbox').nth(1).check();
    await page.getByRole('button', { name: 'Create account', exact: true }).click();
    await page.getByText('Account created. Check your email', { exact: false }).waitFor();
    await page.screenshot({ path: path.join(output, 'registration.png') });
    assert.equal((await request({ command: 'verify_test_email' })).status, 200);
    await page.getByRole('button', { name: 'Back to login' }).click();
    await start();
    await page.screenshot({ path: path.join(output, 'login.png') });
    await page.keyboard.type('browsertrainer');
    await page.keyboard.press('Enter');
    await page.keyboard.type('test-only correct horse');
    // Remember me using the Godot focus chain, then submit from password.
    await page.keyboard.press('Tab');
    await page.keyboard.press('Space');
    await page.keyboard.press('Shift+Tab');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated, null, { timeout: 30000 });
    await page.waitForTimeout(1000);
    await page.screenshot({ path: path.join(output, 'authenticated.png') });
    assert(await page.evaluate(() => !!localStorage.getItem('pokeaether.web.session.v1')), 'remembered login is persisted');
    await page.reload();
    await start();
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated, null, { timeout: 30000 });
    await page.screenshot({ path: path.join(output, 'restored.png') });
    assert(api.some(item => item.path === '/api/auth/web/me' && item.status === 200));
    await page.mouse.click(620, 695); // Godot saved-session Logout button at this viewport.
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated === false);
    assert(await page.evaluate(() => !localStorage.getItem('pokeaether.web.session.v1') && !sessionStorage.getItem('pokeaether.web.session.v1')));
    // Non-remembered login survives refresh in this tab but does not use localStorage.
    await page.keyboard.type('browsertrainer');
    await page.keyboard.press('Enter');
    await page.keyboard.type('test-only correct horse');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated, null, { timeout: 30000 });
    assert(await page.evaluate(() => !localStorage.getItem('pokeaether.web.session.v1') && !!sessionStorage.getItem('pokeaether.web.session.v1')));
    await page.reload();
    await start();
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated, null, { timeout: 30000 });
    await page.mouse.click(620, 695);
    await page.waitForFunction(() => window.pokeaetherPreview?.authenticated === false);
    await page.reload();
    await start();
    assert.equal(await page.evaluate(() => window.pokeaetherPreview.authenticated), false);
    await page.screenshot({ path: path.join(output, 'logged-out.png') });
    assert.deepEqual(external, []);
    assert.deepEqual(errors, []);
    assert(!api.some(item => item.path.startsWith('/api/game/')), 'no world reads or writes');
    fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ api, errors, external, registration: true, refreshRestore: true, tabSessionRestore: true, logout: true }, null, 2));
    console.log('web_accounts_browser_smoke: PASS (registration, verified login, remembered/tab refresh, logout, no world/external requests)');
  } finally {
    fs.writeFileSync(path.join(output, 'requests.json'), JSON.stringify(api, null, 2));
    await page.screenshot({ path: path.join(output, 'last-state.png') }).catch(() => {});
    await browser.close();
    bridge.stdin.end();
    bridge.kill();
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
