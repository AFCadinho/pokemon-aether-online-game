const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const shell = fs.readFileSync(path.join(__dirname, '../infrastructure/web/shell.html'), 'utf8');
  const script = shell.match(/<script id="pokeaether-fullscreen">([\s\S]*?)<\/script>/)[1];
  const browser = await chromium.launch({executablePath:'/usr/bin/chromium', headless:true});
  try {
    const page = await browser.newPage();
    const errors=[];
    page.on('pageerror', e=>errors.push(e.message));
    await page.setContent(`<canvas id="canvas" tabindex="0"></canvas><button id="enter">Enter</button><button id="leave">Leave</button><script>${script}</script>`);
    await page.evaluate(() => {
      document.getElementById('enter').onclick = () => window.pokeaetherFullscreen.request(true);
      document.getElementById('leave').onclick = () => window.pokeaetherFullscreen.request(false);
    });
    assert(await page.evaluate(()=>window.pokeaetherFullscreen.supported()));
    assert.equal(await page.evaluate(()=>window.pokeaetherFullscreen.active()),false);
    // No user gesture: offer an explicit click rather than silently fail.
    await page.evaluate(()=>{
      // Playwright evaluate grants user activation; explicitly model its absence.
      Object.defineProperty(navigator,'userActivation',{value:{isActive:false},configurable:true});
      window.pokeaetherFullscreen.request(true);
      delete navigator.userActivation;
    });
    await page.getByRole('button',{name:'Enter fullscreen',exact:true}).click();
    await page.waitForFunction(()=>window.pokeaetherFullscreen.active());
    assert.equal(await page.evaluate(()=>document.fullscreenElement.id),'canvas');
    // Escape/window-manager exits use the same fullscreenchange state path.
    await page.evaluate(()=>document.exitFullscreen());
    await page.waitForFunction(()=>!window.pokeaetherFullscreen.active());
    assert.equal(await page.evaluate(()=>document.activeElement.id),'canvas');
    await page.getByRole('button',{name:'Enter',exact:true}).click();
    await page.waitForFunction(()=>window.pokeaetherFullscreen.active());
    await page.evaluate(()=>window.pokeaetherFullscreen.request(false));
    await page.waitForFunction(()=>!window.pokeaetherFullscreen.active());
    // A denied request leaves the state off and exposes a usable retry.
    await page.evaluate(()=>{
      document.getElementById('canvas').requestFullscreen=()=>Promise.reject(new Error('Denied'));
    });
    await page.getByRole('button',{name:'Enter',exact:true}).click();
    await page.getByRole('button',{name:'Enter fullscreen',exact:true}).waitFor({state:'visible'});
    assert.equal(await page.evaluate(()=>window.pokeaetherFullscreen.active()),false);
    assert(await page.evaluate(()=>Boolean(window.pokeaetherFullscreen.error())));
    await page.evaluate(()=>window.pokeaetherFullscreen.request(false));
    await page.getByRole('button',{name:'Enter fullscreen',exact:true}).waitFor({state:'hidden'});
    assert.deepEqual(errors,[]);
    console.log('web_fullscreen_smoke: PASS (real browser enter/exit, external exit, denied request and gesture retry)');
  } finally { await browser.close(); }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
