const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

(async () => {
  const browser = await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const results = [];
  try {
    for (const scenario of ['success', 'missing-module', 'bad-hash', 'pack-failure']) {
      const context = await browser.newContext();
      try {
        const page = await context.newPage();
        const errors = [], warnings = [], external = [];
        let packDownloads = 0;
        await context.route('**/*', async route => {
          const url = new URL(route.request().url());
          if (url.origin !== 'http://127.0.0.1:8064') {
            external.push(url.origin); return route.abort();
          }
          if (url.pathname === '/modules/manifest.json' && scenario === 'missing-module')
            return route.fulfill({json:{modules:{}}});
          if (url.pathname === '/modules/manifest.json' && scenario === 'bad-hash') {
            const response = await route.fetch(); const json = await response.json();
            json.modules['kanto-through-misty-maps'].sha256 = '0'.repeat(64);
            return route.fulfill({json});
          }
          if (url.pathname === '/modules/misty-maps.pck') {
            packDownloads++;
            if (scenario === 'success') await new Promise(resolve => setTimeout(resolve, 500));
            if (scenario === 'pack-failure') return route.fulfill({status:503,body:'QA unavailable'});
          }
          return route.continue();
        });
        page.on('pageerror', e=>errors.push(e.message));
        let warningContinuation = false;
        page.on('console', m=>{
          if(m.type()!=='error') return;
          const text = m.text();
          if(text.startsWith('WARNING:')) {warnings.push(text);warningContinuation=true;return;}
          if(warningContinuation && /^\s+(at:|GDScript backtrace|\[\d+\])/.test(text)) {warnings.push(text);return;}
          warningContinuation=false;
          if(scenario==='pack-failure' && /Failed to load resource:.*503/.test(text)) return;
          errors.push(text);
        });
        await page.goto('http://127.0.0.1:8064/');
        await page.waitForFunction(()=>window.mistyCoreProbe,null,{timeout:180000});
        const result = await page.evaluate(()=>window.mistyCoreProbe);
        if (scenario === 'success') {
          result.audio = await page.evaluate(async () => {
            const paths = ['/browser-audio/music/overworld/kanto/caves/mt_moon.ogg',
              '/browser-audio/music/overworld/kanto/towns/cerulean_city.ogg'];
            const decoded = [];
            const audioContext = new AudioContext();
            try {
              for (const path of paths) {
                const response = await fetch(path);
                if (!response.ok) throw new Error('QA audio unavailable');
                const buffer = await audioContext.decodeAudioData(await response.arrayBuffer());
                decoded.push({path, duration:buffer.duration, channels:buffer.numberOfChannels});
              }
            } finally { await audioContext.close(); }
            return decoded;
          });
          assert.equal(result.audio.length,2);
        }
        results.push({scenario, result, errors, warnings, external, packDownloads});
        fs.writeFileSync(path.resolve(__dirname,'../builds/web-misty-trial/core-results.json'),JSON.stringify(results,null,2));
        assert.deepEqual(errors,[],`${scenario}: runtime errors`);
        assert.deepEqual(external,[],`${scenario}: external requests`);
        if (scenario === 'success') {
          assert.equal(result.success,true);
          assert.equal(result.maps.length,16);
          assert.equal(packDownloads,1,'one download across all maps and repeated loads');
          const last = result.samples.at(-1), first = result.samples[0];
          assert(last.resources <= first.resources + 10,'resources do not accumulate across repeated loads');
          assert(last.textureBytes <= first.textureBytes + 8*1024*1024,'textures do not accumulate across repeated loads');
        } else {
          assert.equal(result.success,false);
          assert.equal(result.maps.length,0,'failed module is not used');
          assert.equal(result.errors.length,1);
        }
        console.log(`web_misty_core_probe: ${scenario} PASS`);
      } finally { await context.close(); }
    }
  } finally {await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
