// Interactive local rendered-battle probe. NO mocked API or WebSocket routes.
// Invoke only inside the slot-C disposable runtime wrapper. Commands on stdin
// control the canvas; reports contain counters/timings, never account payloads.
const {chromium}=require('playwright');
const fs=require('node:fs'), path=require('node:path'), readline=require('node:readline');
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
const {createHash}=require('node:crypto');
const {attest}=require('./support/disposable_runtime_guard.cjs');
const sha=value=>createHash('sha256').update(value).digest('hex');
const frontend=path.resolve(__dirname,'..');
const git=(cwd,...args)=>execFileSync('git',args,{cwd,encoding:'utf8'}).trim();
function provenance() {
  const interiors=process.env.POKEAETHER_MEMORY_PALLET_INTERIORS==='1';
  const scene='scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn';
  const oldVisual='res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn';
  const newVisual='res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn';
  const text=fs.readFileSync(path.join(frontend,scene),'utf8');
  assert(text.includes(oldVisual)!==text.includes(newVisual),'One Pallet variant');
  const normalized=text.replace(newVisual,oldVisual);
  const interiorPaths=['generated/tiled_visuals/players_house/','generated/tiled_visuals/pokemon_laboratory/'];
  const index=git(frontend,'ls-files','-s').split('\n').filter(line=>!interiors ||
    !interiorPaths.some(prefix=>line.split('\t')[1]?.startsWith(prefix))).map(line=>
    line.endsWith('\t'+scene) ? 'NORMALIZED '+sha(normalized)+'\t'+scene : line).join('\n');
  const receipt=JSON.parse(fs.readFileSync(path.join(frontend,'builds/web/build-receipt.json'),'utf8'));
  assert.equal(receipt.dirty,false,'Clean export required for paired timing');
  const changed=git(frontend,'diff','--name-only',receipt.commit,'HEAD').split('\n').filter(Boolean);
  assert(changed.every(p=>['tests/','tools/','docs/'].some(prefix=>p.startsWith(prefix))),
    'Export must match gameplay source; only excluded test/tool/docs changes allowed');
  assert.equal(git(frontend,'status','--porcelain'),'','Clean task source required');
  const backend=path.resolve(frontend,'../backend');
  const marked=interiorPaths.map(prefix=>fs.readFileSync(path.join(frontend,prefix,path.basename(prefix.slice(0,-1))+'.visual.tileset.tres'),'utf8').includes('metadata/tiled_compact_atlas_version = 1'));
  if(interiors) assert(marked.every(x=>x===marked[0]),'Both interior atlases must use the same variant');
  return {scope:interiors?'pallet_interiors':'pallet_exterior',variant:interiors?(marked[0]?'compact':'original'):(text.includes(newVisual)?'compact':'original'),normalizedTreeSHA256:sha(index),
    sourceCommit:receipt.commit,pckSHA256:receipt.files.find(x=>x.name==='index.pck').sha256,
    godot:receipt.engine,driverSHA256:sha(fs.readFileSync(__filename)),
    backendCommit:git(backend,'rev-parse','HEAD'),
    fixtureSHA256:sha(fs.readFileSync(path.join(backend,'ops/web_battle_memory_fixture.py')))};
}
(async()=>{
  assert.equal(process.env.POKEAETHER_WEB_MEMORY_DISPOSABLE_RUNTIME,'1','Disposable runtime required');
  attest();
  const origin=process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8061';
  assert(['127.0.0.1','localhost'].includes(new URL(origin).hostname),'Loopback only');
  const tag=process.env.POKEAETHER_MEMORY_RUN_TAG || '';
  assert(!tag || /^[a-z0-9_-]{1,80}$/.test(tag),'Safe local report tag');
  const output=path.resolve(__dirname,'../builds/web-real-battle-memory',tag);
  const scenario=process.env.POKEAETHER_WEB_MEMORY_SCENARIO || 'electric';
  assert(['electric','grass'].includes(scenario),'Supported fixed scenario required');
  fs.mkdirSync(output,{recursive:true});
  const evidence=provenance(), commandHash=createHash('sha256');
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  let runtimeLost=false;
  const runtimeWatch=setInterval(()=>{
    if(runtimeLost) return;
    try {attest();} catch {runtimeLost=true;browser.close().catch(()=>{});}
  },1000);
  const context=await browser.newContext({viewport:{width:1440,height:900}});
  evidence.chromium=browser.version();
  const textureAudit=process.env.POKEAETHER_MEMORY_TEXTURE_AUDIT==='1';
  const worldTextureAudit=process.env.POKEAETHER_MEMORY_WORLD_TEXTURE_AUDIT==='1';
  const mapOnly=process.env.POKEAETHER_MEMORY_MAP_ONLY==='1';
  if(worldTextureAudit) {
    const inventory=JSON.parse(execFileSync('python3',[path.resolve(__dirname,'../tools/audit_web_texture_memory.py')],{maxBuffer:16*1024*1024}));
    const prefixes=['assets/ui/','assets/tilesets/','assets/background/','assets/battles/capture/',
      'assets/battles/mechanics/','assets/battles/effect/','assets/sprites/battle_buttons/'];
    const visual='generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn';
    const embedded=[...fs.readFileSync(path.resolve(__dirname,'../'+visual),'utf8')
      .matchAll(/^\[sub_resource type="PortableCompressedTexture2D" id="([a-zA-Z0-9_]+)"\]$/gm)]
      .map(match=>'res://'+visual+'::'+match[1]);
    assert.equal(embedded.length,7,'Seven fixed candidate atlas subresources');
    const mapPaths=[...embedded,...inventory.portableMapResources.map(x=>'res://'+x.source)];
    const paths=[...new Set(inventory.textures.filter(x=>prefixes.some(prefix=>x.source.startsWith(prefix)))
      .map(x=>'res://'+x.source))].slice(0,96)
      .concat(mapPaths.slice(0,160));
    assert(paths.length<=256,'Bounded world texture audit');
    await context.addInitScript(paths=>{window.pokeaetherMemoryWorldTexturePaths=paths;},paths);
  }
  if(textureAudit) {
    const inventory=JSON.parse(execFileSync('python3',[path.resolve(__dirname,'../tools/audit_web_texture_memory.py')],{maxBuffer:16*1024*1024}));
    const paths=inventory.identicalBattleEffectPayloads.flatMap(group=>group.sources.map(source=>'res://'+source));
    assert(paths.length<=256,'Bounded effect texture audit');
    await context.addInitScript(paths=>{window.pokeaetherMemoryTexturePaths=paths;},paths);
  }
  const page=await context.newPage(), cdp=await context.newCDPSession(page);
  await cdp.send('Performance.enable');
  const api=[], markers=[], snapshots=[], errors=[];
  let battleStarts=0, battleTurns=0, battleEnds=0, screenshot=0;
  let latestPosition=null;
  const mapTransitions=[];
  page.on('websocket',socket=>socket.on('framesent',({payload})=>{
    if(typeof payload!=='string' || payload.length>16384) return;
    let message; try { message=JSON.parse(payload); } catch { return; }
    if(message.type!=='position' || !/^kanto_[a-z0-9_]+$/.test(message.mapId || '') ||
      !Number.isFinite(message.position?.x) || !Number.isFinite(message.position?.y)) return;
    if(latestPosition?.mapId!==message.mapId) mapTransitions.push(message.mapId);
    // Keep only the disposable player's public map/coordinates in memory.
    // Never retain or report appearance, roles, followers or session payloads.
    latestPosition={mapId:message.mapId,position:{x:message.position.x,y:message.position.y}};
  }));
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
    assert(!runtimeLost,'Disposable runtime lost');attest();
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
      commandHash.update(line+'\n');
      const command=JSON.parse(line);
      assert(!runtimeLost,'Disposable runtime lost');attest();
      if(command.click) await page.mouse.click(...command.click);
      // Canvas TextEdit consumes keyboard events, not DOM insertText input.
      if(command.text) await page.keyboard.type(command.text);
      if(command.key) await page.keyboard.press(command.key);
      if(command.steps) {
        assert(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(command.steps.key));
        assert(Number.isInteger(command.steps.count) && command.steps.count>0 && command.steps.count<=10);
        for(let i=0;i<command.steps.count;i++) {
          await page.keyboard.press(command.steps.key,{delay:80});
          await page.waitForTimeout(900);
        }
      }
      if(command.walk) {
        const {key,axis,limit,direction,mapId}=command.walk;
        assert(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(key));
        assert(mapId || (['x','y'].includes(axis) && Number.isFinite(limit) && [1,-1].includes(direction)));
        const deadline=Date.now()+20000;
        await page.keyboard.down(key);
        try {
          while(!(mapId ? latestPosition?.mapId===mapId :
            latestPosition && direction*(latestPosition.position[axis]-limit)>=0)) {
            assert(Date.now()<deadline,'Real map walk timed out');
            await page.waitForTimeout(50);
          }
        } finally { await page.keyboard.up(key); }
      }
      if(command.wait) await page.waitForTimeout(Math.min(command.wait,30000));
      if(command.finish) {
        if(!mapOnly) {
          assert(battleStarts>=3,'At least three real dev wild battles');
          assert(battleTurns>=1,'At least one real resolved turn');
          assert(markers.filter(x=>x.label==='battle_teardown_begin').length>=3,'Three teardowns');
        } else assert(command.mapCycle,'Map-only run must validate a real cycle');
        assert.equal(errors.length,0,'No page errors');
        if(command.mapCycle) assert(mapTransitions.join(',').includes(
          'kanto_pallet_town,kanto_players_house,kanto_pallet_town'),'Real house entry and return');
        if(command.mapCycle && evidence.scope==='pallet_interiors') assert(mapTransitions.join(',').includes(
          'kanto_players_house,kanto_pallet_town,kanto_oaks_lab,kanto_pallet_town'),'Real house and lab cycles');
        if(textureAudit) assert(markers.some(x=>x.label==='battle_actions_ready' &&
          x.cachedEffectTextures?.uniqueTextures>0),'Rendered cached-effect audit captured');
        if(worldTextureAudit && !mapOnly) assert(markers.some(x=>x.label==='battle_actions_ready' &&
          x.cachedWorldTextures?.uniqueTextures>0),'Rendered world texture audit captured');
        success=true; break;
      }
      await snapshot(command.label || 'canvas_step');
    }
    assert(success,'Finish and validate the real battle run');
  } finally {
    clearInterval(runtimeWatch);
    evidence.commandsSHA256=commandHash.digest('hex');
    fs.writeFileSync(path.join(output,'report.json'),JSON.stringify({success:success&&!runtimeLost,runtimeLost,evidence,scenario,mapOnly,textureAudit,worldTextureAudit,timingComparable:!runtimeLost&&!mapOnly&&!textureAudit&&!worldTextureAudit,softwareWebGL:true,viewport:'1440x900',mapTransitions,api,markers,snapshots,errors,battleStarts,battleTurns,battleEnds},null,2));
    await page.screenshot({path:path.join(output,'last-state.png')}).catch(()=>{});
    await browser.close();
    process.stdin.pause();
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
