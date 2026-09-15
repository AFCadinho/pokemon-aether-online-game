// Local exported Godot baseline; no account data or backend writes.
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
(async()=>{
  const origin=process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8061';
  assert.equal(new URL(origin).hostname,'127.0.0.1','Local preview only');
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const worldTextureAudit=process.env.POKEAETHER_MEMORY_WORLD_TEXTURE_AUDIT==='1';
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  if(worldTextureAudit){
    const inventory=JSON.parse(execFileSync('python3',[path.resolve(__dirname,'../tools/audit_web_texture_memory.py')],{maxBuffer:16*1024*1024}));
    const prefixes=['assets/ui/','assets/tilesets/','assets/background/','assets/battles/capture/',
      'assets/battles/mechanics/','assets/battles/effect/','assets/sprites/battle_buttons/'];
    const paths=[...new Set(inventory.textures.filter(x=>prefixes.some(prefix=>x.source.startsWith(prefix)))
      .map(x=>'res://'+x.source))].slice(0,128);
    await page.addInitScript(paths=>{window.pokeaetherMemoryWorldTexturePaths=paths;},paths);
  }
  const system=await browser.newBrowserCDPSession();
  const metrics=await page.context().newCDPSession(page);
  await metrics.send('Performance.enable');
  const output=path.resolve(__dirname,'../builds/web-memory-baseline');
  fs.mkdirSync(output,{recursive:true});
  await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==origin)return route.abort();
    if(url.pathname.startsWith('/api/'))return route.fulfill({status:200,contentType:'application/json',body:'{"success":true,"status":"ok","available":true,"mode":"open","onlineUsers":0}'});
    if(url.pathname==='/news.json')return route.fulfill({status:200,contentType:'application/json',body:'{"items":[]}'});
    return route.continue();
  });
  const resident=[];
  try{
    await page.goto(origin+'/?memory-probe');
    await page.getByRole('button',{name:'Play now'}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    for(let i=0;i<12;i++){
      await page.waitForTimeout(1000);
      const processes=(await system.send('SystemInfo.getProcessInfo')).processInfo;
      const rss=processes.map(p=>{
        try{
          assert(Number.isSafeInteger(p.id)&&p.id>0);
          const status=fs.readFileSync('/proc/'+p.id+'/status','utf8');
          return {type:p.type,residentBytes:Number(status.match(/^VmRSS:\s+(\d+) kB/m)?.[1]||0)*1024};
        }catch(_){return {type:p.type,residentBytes:null};}
      });
      resident.push({timeMs:i*1000,processes:rss,jsMetrics:(await metrics.send('Performance.getMetrics')).metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize'].includes(m.name))});
    }
    const samples=await page.evaluate(()=>window.pokeaetherMemoryProbe.samples);
    assert(samples.length>=5);
    assert(samples.every(s=>s.spriteCache.entries===0));
    if(worldTextureAudit)assert(samples.some(x=>x.cachedWorldTextures?.uniqueTextures>0),'Cached login texture audit captured');
    const report={scenario:'login_idle',worldTextureAudit,timingComparable:!worldTextureAudit,viewport:'1440x900',softwareWebGL:true,samples,resident,
      limits:['Wasm capacity is not live allocation usage','Texture counter is not complete GPU-driver memory',
        'Per-process RSS includes shared pages; summing is not unique physical RAM','No logged-in map or real battle was played']};
    fs.writeFileSync(path.join(output,'login-idle.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify({scenario:report.scenario,samples:samples.length,last:samples.at(-1)},null,2));
  }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
