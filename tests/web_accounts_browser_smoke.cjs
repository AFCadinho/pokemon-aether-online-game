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
	const previewUrl = process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8060';
	assert(['127.0.0.1', 'localhost'].includes(new URL(previewUrl).hostname), 'browser test only targets loopback');
  const python = process.env.POKEAETHER_TEST_PYTHON;
  assert(python, 'Set POKEAETHER_TEST_PYTHON to the account-service test Python');
  const bridge = spawn(python, ['tests/web_browser_bridge.py', frontend], {
    cwd: path.join(backend, 'account-service'), stdio: ['pipe', 'pipe', 'pipe'],
		env: { ...process.env, POKEAETHER_WEB_BROWSER_TEST: '1', POKEAETHER_WEB_PREVIEW_ORIGIN: previewUrl },
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
  const errors = [], external = [], api = [], pokemonAssets = [];
  const output = path.join(frontend, 'builds/web-accounts-qa');
  fs.mkdirSync(output, { recursive: true });
  await context.route('**/*', async route => {
    const req = route.request(), url = new URL(req.url());
		if (url.origin !== new URL(previewUrl).origin) { external.push(url.origin); return route.abort(); }
		if (url.pathname.startsWith('/pokemon-assets/gen5/')) pokemonAssets.push(url.pathname);
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
  const waitForApi = async (predicate, timeoutMs) => {
    const deadline = Date.now() + timeoutMs;
    while (!api.some(predicate)) {
      if (Date.now() >= deadline) throw new Error('Timed out waiting for browser demo API state');
      await page.waitForTimeout(100);
    }
  };
  try {
		await page.goto(previewUrl);
    await start();
    await page.mouse.click(537, 682); // Godot's Create your account link.
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
    await page.mouse.click(600, 494); // Return focus to the Godot username field.
    await page.screenshot({ path: path.join(output, 'login.png') });
    await page.keyboard.type('browsertrainer');
    await page.keyboard.press('Enter');
    await page.keyboard.type('test-only correct horse');
    // Remember me using the Godot focus chain, then submit from password.
    await page.keyboard.press('Tab');
    await page.keyboard.press('Space');
    await page.keyboard.press('Shift+Tab');
    await page.keyboard.press('Enter');
		await waitForApi(item => item.path === '/api/auth/web/login' && item.status === 200, 30000);
		await waitForApi(item => item.path === '/api/auth/web/world' && item.status === 200, 120000);
		await waitForApi(item => item.path === '/api/auth/web/profile' && item.status === 200, 30000);
		await waitForApi(item => item.path === '/api/auth/web/world/story' && item.status === 200, 30000);
		await page.waitForTimeout(3000);
    await page.screenshot({ path: path.join(output, 'world.png') });
    assert(api.some(item => item.path === '/api/auth/web/world' && item.status === 200), 'browser world position loads');
    assert(api.some(item => item.path === '/api/auth/web/world/story' && item.status === 200), 'shared story loads through the browser boundary');
		assert(api.some(item => item.path.startsWith('/api/npcs/') && item.status !== 403), 'demo NPC metadata crosses the browser boundary');
		await page.mouse.click(207, 72); // Browser PvP shortcut opens AI Sparring directly.
		await waitForApi(item => item.path === '/api/battle/pvp/training/ai/teams' && item.status === 200, 30000);
		await page.waitForTimeout(2000);
		await page.screenshot({ path: path.join(output, 'ai-sparring.png') });
		assert(api.some(item => item.path === '/api/battle/pvp/training/ai/teams' && item.status === 200), 'AI Sparring catalog loads');
		await page.mouse.click(550, 436);
		await page.waitForTimeout(500);
		await page.mouse.click(450, 495); // Catalog team in Godot's popup menu.
		await page.waitForTimeout(1000);
		await page.mouse.click(975, 739);
		await waitForApi(item => item.path === '/api/battle/pvp/training/ai/battles' && item.status === 200, 30000);
		await waitForApi(item => item.path === '/api/battle/web-ai-e2e/npc/lead' && item.status === 200, 30000);
		await page.waitForTimeout(60000);
		await page.screenshot({ path: path.join(output, 'ai-battle-turn.png') });
		assert(api.some(item => item.path === '/api/battle/web-ai-e2e/lead' && item.status === 200), 'browser submits its AI Sparring lead');
		assert(api.some(item => item.path === '/api/battle/web-ai-e2e/npc/lead' && item.status === 200), 'AI lead resolves');
		assert(pokemonAssets.some(pathname => pathname.includes('/back/pikachu/')), 'player battle animation loads on demand');
		assert(pokemonAssets.some(pathname => pathname.includes('/front/eevee/')), 'opponent battle animation loads on demand');
		await page.mouse.click(1084, 481); // Thunderbolt in the battle move grid.
		await waitForApi(item => item.path === '/api/battle/web-ai-e2e/choice-and-resolve' && item.status === 200, 30000);
		await page.waitForTimeout(10000);
		await page.screenshot({ path: path.join(output, 'ai-battle-result.png') });
		assert(api.some(item => item.path === '/api/battle/web-ai-e2e/choice-and-resolve' && item.status === 200), 'browser resolves an AI Sparring turn');
    assert.deepEqual(external, []);
    assert(!api.some(item => item.path === '/api/game/player-position' && item.status < 400), 'desktop position endpoint is never used');
		assert(!errors.some(item => item.includes('generated/tiled_visuals')), 'browser map resources load without runtime errors');
		fs.writeFileSync(path.join(output, 'result.json'), JSON.stringify({ api, errors, external, pokemonAssets, registration: true, world: true, aiSparring: true }, null, 2));
		console.log('web_accounts_browser_smoke: PASS (registration, login, browser world, completed AI Sparring turn, no desktop position/external requests)');
  } finally {
    fs.writeFileSync(path.join(output, 'requests.json'), JSON.stringify(api, null, 2));
		fs.writeFileSync(path.join(output, 'pokemon-assets.json'), JSON.stringify(pokemonAssets, null, 2));
		fs.writeFileSync(path.join(output, 'errors.json'), JSON.stringify(errors, null, 2));
    await page.screenshot({ path: path.join(output, 'last-state.png') }).catch(() => {});
    await browser.close();
    bridge.stdin.end();
    bridge.kill();
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
