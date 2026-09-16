// Real rendered Misty battle against the slot-C disposable backend. The only
// shortcut is the test-only account checkpoint; no battle API is mocked.
const {chromium}=require('playwright');
const {execFileSync}=require('node:child_process');
const fs=require('node:fs'), path=require('node:path');
const assert=require('node:assert/strict');
const {attest}=require('./support/disposable_runtime_guard.cjs');

(async()=>{
  assert.equal(process.env.POKEAETHER_WEB_MEMORY_DISPOSABLE_RUNTIME,'1');
  assert.equal(process.env.POKEAETHER_WEB_MEMORY_SCENARIO,'misty');
  const origin=process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8062';
  assert.equal(new URL(origin).hostname,'127.0.0.1');
  attest();
  const frontend=path.resolve(__dirname,'..');
  const output=path.join(frontend,'builds/web-misty-real-battle');
  fs.mkdirSync(output,{recursive:true});
  const receipt=JSON.parse(fs.readFileSync(path.join(frontend,'builds/web/build-receipt.json'),'utf8'));
  assert.equal(receipt.dirty,false,'Clean browser export required');
  const git=(...args)=>execFileSync('git',args,{cwd:frontend,encoding:'utf8'}).trim();
  assert.equal(git('status','--porcelain'),'','Clean task source required');
  const changed=git('diff','--name-only',receipt.commit,'HEAD').split('\n').filter(Boolean);
  assert(changed.every(p=>['tests/','tools/','docs/'].some(prefix=>p.startsWith(prefix))),
    'Browser export must match gameplay source');
  const sourceIndex=git('ls-files','-s');
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,
    args:['--enable-unsafe-swiftshader']});
  let lost=false;
  const watch=setInterval(()=>{try{attest();}catch{lost=true;browser.close().catch(()=>{});}},1000);
  const context=await browser.newContext({viewport:{width:1440,height:900}});
  const page=await context.newPage();
  const api=[], errors=[], maps=[];
  let latestPosition=null;
  page.on('pageerror',()=>errors.push('pageerror'));
  page.on('websocket',socket=>socket.on('framesent',({payload})=>{
    if(typeof payload!=='string'||payload.length>16384)return;
    let message;try{message=JSON.parse(payload);}catch{return;}
    if(message.type==='position'&&/^kanto_[a-z0-9_]+$/.test(message.mapId||'')){
      if(maps.at(-1)!==message.mapId)maps.push(message.mapId);
      latestPosition={mapId:message.mapId,x:message.position?.x,y:message.position?.y};
    }
  }));
  page.on('response',async response=>{
    const url=new URL(response.url());
    if(url.origin!==origin||!url.pathname.startsWith('/api/'))return;
    if(/\/battle\/trainer|choice-and-resolve|trainer-battle|world\/story|\/trainers\/|\/dialogues\//.test(url.pathname)){
      const entry={path:url.pathname.replace(/\/battle\/[^/]+\//,'/battle/[id]/'),status:response.status()};
      if(url.pathname==='/api/battle/trainer'&&response.status()!==200){
        try{
          const payload=await response.json();
          const code=String(payload?.detail?.code||payload?.code||'unknown');
          if(/^[A-Za-z0-9_]{1,80}$/.test(code))entry.code=code;
        }catch{}
      }
      api.push(entry);
    }
  });
  let success=false, battleStart=false, battleTeardown=false, moves=0;
  try{
    await page.goto(origin+'/?memory-probe');
    await page.getByRole('button',{name:'Play now'}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    await page.waitForTimeout(2000);
    await page.mouse.click(600,494);
    await page.keyboard.type('memorytrainer');await page.keyboard.press('Enter');
    const login=page.waitForResponse(r=>new URL(r.url()).pathname==='/api/auth/web/login',{timeout:30000});
    await page.keyboard.type('disposable-memory-test-only');await page.keyboard.press('Enter');
    assert.equal((await login).status(),200);
    for(let i=0;i<20&&!(await page.evaluate(()=>Boolean(window.pokeaetherPreview?.worldReady)));i++){
      await page.mouse.click(850,524);await page.waitForTimeout(500);
    }
    await page.waitForFunction(()=>window.pokeaetherPreview?.worldReady,null,{timeout:120000});
    await page.waitForTimeout(3000);
    assert(maps.includes('kanto_cerulean_city_gym'),'Misty gym rendered from disposable save');
    await page.screenshot({path:path.join(output,'gym-ready.png')});
    await page.screenshot({path:path.join(output,'before-interaction.png')});
    for(let i=0;i<40&&!api.some(x=>x.path==='/api/battle/trainer');i++){
      assert(!lost,'Disposable runtime changed during dialogue');attest();
      await page.keyboard.press('Space');await page.waitForTimeout(700);
    }
    battleStart=api.some(x=>x.path==='/api/battle/trainer'&&x.status===200);
    if(!battleStart)await page.screenshot({path:path.join(output,'interaction-failed.png')});
    assert(battleStart,'Real Misty trainer battle did not start');
    await page.waitForFunction(()=>window.pokeaetherMemoryProbe?.samples.some(s=>s.label==='battle_actions_ready'),
      null,{timeout:120000});
    await page.screenshot({path:path.join(output,'battle-ready.png')});
    for(let i=0;i<32;i++){
      assert(!lost,'Disposable runtime changed during Misty battle');attest();
      await page.mouse.click(1080,480);
      await page.waitForTimeout(6500);
      moves++;
      battleTeardown=await page.evaluate(()=>Boolean(window.pokeaetherMemoryProbe?.samples.some(s=>s.label==='battle_teardown_begin')));
      if(battleTeardown)break;
    }
    await page.screenshot({path:path.join(output,'after-battle.png')});
    assert(battleTeardown,'Misty battle did not reach teardown');
    assert(api.some(x=>x.path.includes('choice-and-resolve')&&x.status===200),'A real turn resolves');
    assert.equal(errors.length,0,'No page errors');
    success=true;
  }finally{
    clearInterval(watch);
    const sourceUnchanged=git('status','--porcelain')===''&&git('ls-files','-s')===sourceIndex;
    fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({success:success&&!lost&&sourceUnchanged,
      runtimeLost:lost,sourceUnchanged,battleStart,battleTeardown,moves,api,maps,latestPosition,errors,
      sourceCommit:receipt.commit,pckSHA256:receipt.files.find(x=>x.name==='index.pck').sha256,
      fixture:'developer checkpoint challenge_misty; not a fresh-account playthrough'},null,2));
    await browser.close();
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
