// Interactive local rendered-battle probe. NO mocked API or WebSocket routes.
// Invoke only inside the slot-C disposable runtime wrapper. Commands on stdin
// control the canvas; reports contain counters/timings, never account payloads.
const {chromium}=require('playwright');
const fs=require('node:fs'), path=require('node:path'), readline=require('node:readline');
const assert=require('node:assert/strict');
(async()=>{
  assert.equal(process.env.POKEAETHER_WEB_MEMORY_DISPOSABLE_RUNTIME,'1','Disposable runtime required');
  const origin=process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8061';
  assert(['127.0.0.1','localhost'].includes(new URL(origin).hostname),'Loopback only');
  const output=path.resolve(__dirname,'../builds/web-real-battle-memory');
  fs.mkdirSync(output,{recursive:true});
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const context=await browser.newContext({viewport:{width:1440,height:900}});
  const page=await context.newPage(), cdp=await context.newCDPSession(page);
  await cdp.send('Performance.enable');
  const api=[], markers=[], snapshots=[], errors=[];
  let battleStarts=0, battleTurns=0, battleEnds=0, screenshot=0;
  const starts=new Map();
  page.on('request',req=>{if(req.url().startsWith(origin+'/api/')) starts.set(req,Date.now());});
  page.on('response',response=>{
    const req=response.request(), url=new URL(response.url());
    if(url.origin!==origin || !url.pathname.startsWith('/api/')) return;
    const endpoint=url.pathname.replace(/\/battle\/[^/]+\//,'/battle/[id]/');
    api.push({endpoint,status:response.status(),elapsedMs:Date.now()-(starts.get(req)||Date.now())});
    if(response.status()===200 && url.pathname==='/api/battle/dev/wild') battleStarts++;
    if(response.status()===200 && url.pathname.includes('/choice-and-resolve')) battleTurns++;
    if(response.status()===200 && url.pathname.endsWith('/forfeit')) battleEnds++;
    starts.delete(req);
  });
  page.on('pageerror',()=>errors.push('pageerror'));
  await page.exposeFunction('recordMemoryMarker',sample=>{if(sample.label!=='sample') markers.push(sample);});
  await context.addInitScript(()=>{
    const attach=setInterval(()=>{
      const probe=window.pokeaetherMemoryProbe;
      if(!probe || probe.liveMarkerObserver) return;
      probe.liveMarkerObserver=true;
      const record=probe.record.bind(probe);
      probe.record=sample=>{record(sample); if(sample.label!=='sample') window.recordMemoryMarker(probe.samples.at(-1));};
      clearInterval(attach);
    },100);
  });
  const snapshot=async label=>{
    await page.waitForTimeout(1500);
    snapshots.push({label,memory:await page.evaluate(()=>window.pokeaetherMemoryProbe?.samples.at(-1)),
      jsMetrics:(await cdp.send('Performance.getMetrics')).metrics.filter(x=>['JSHeapUsedSize','JSHeapTotalSize','Nodes'].includes(x.name))});
    await page.screenshot({path:path.join(output,`state-${++screenshot}.png`)});
    console.log(JSON.stringify({state:screenshot,battleStarts,battleTurns,battleEnds,markers:markers.map(x=>x.label)}));
  };
  let success=false;
  try {
    await page.goto(origin+'/?memory-probe');
    await page.getByRole('button',{name:'Play now'}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    await page.waitForTimeout(2000);
    await page.mouse.click(600,494);
    await page.keyboard.type('memorytrainer'); await page.keyboard.press('Enter');
    const loginResponse=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/auth/web/login',{timeout:30000});
    await page.keyboard.type('disposable-memory-test-only'); await page.keyboard.press('Enter');
    assert.equal((await loginResponse).status(),200,'Real disposable account login succeeds');
    for(let i=0;i<20 && !(await page.evaluate(()=>window.pokeaetherPreview?.worldReady));i++) {
      await page.mouse.click(850,524); await page.waitForTimeout(500);
    }
    await page.waitForFunction(()=>window.pokeaetherPreview?.worldReady,null,{timeout:120000});
    await page.waitForTimeout(10000);
    await snapshot('world_idle');
    for await(const line of readline.createInterface({input:process.stdin})) {
      const command=JSON.parse(line);
      if(command.click) await page.mouse.click(...command.click);
      // Canvas TextEdit consumes keyboard events, not DOM insertText input.
      if(command.text) await page.keyboard.type(command.text);
      if(command.key) await page.keyboard.press(command.key);
      if(command.wait) await page.waitForTimeout(Math.min(command.wait,30000));
      if(command.finish) {
        assert(battleStarts>=3,'At least three real dev wild battles');
        assert(battleTurns>=1,'At least one real resolved turn');
        assert(markers.filter(x=>x.label==='battle_teardown_begin').length>=3,'Three teardowns');
        assert.equal(errors.length,0,'No page errors');
        success=true; break;
      }
      await snapshot(command.label || 'canvas_step');
    }
    assert(success,'Finish and validate the real battle run');
  } finally {
    fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({success,softwareWebGL:true,viewport:'1440x900',api,markers,snapshots,errors,battleStarts,battleTurns,battleEnds},null,2));
    await page.screenshot({path:path.join(output,'last-state.png')}).catch(()=>{});
    await browser.close();
    process.stdin.pause();
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
