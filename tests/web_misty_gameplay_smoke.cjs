// Real rendered browser world + canonical account handlers, isolated SQLite.
const { chromium } = require('playwright');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

(async () => {
  const frontend = path.resolve(__dirname, '..'), backend = path.resolve(frontend, '../backend');
  const origin = process.env.POKEAETHER_WEB_PREVIEW_URL || 'http://127.0.0.1:8061';
  assert.equal(new URL(origin).hostname, '127.0.0.1');
  const bridge = spawn(path.join(backend, 'ops/web_browser_test_python'), ['tests/web_browser_bridge.py', frontend], {
    env: {...process.env, POKEAETHER_WEB_BROWSER_TEST:'1', POKEAETHER_WEB_PREVIEW_ORIGIN:origin}, stdio:['pipe','pipe','pipe'],
  });
  const pending = [], api = [], errors = [], external = [], positions = [], modules = [];
  let stderr = '', closing = false;
  bridge.stderr.on('data', data => { stderr += data; });
  readline.createInterface({input:bridge.stdout}).on('line', line => pending.shift()?.resolve(JSON.parse(line)));
  bridge.on('exit', () => { for (const task of pending.splice(0)) task.reject(new Error('Fixture exited')); });
  const request = data => new Promise((resolve,reject) => { pending.push({resolve,reject}); bridge.stdin.write(JSON.stringify(data)+'\n'); });
  const output = path.join(frontend,'builds/web-misty-gameplay-qa'); fs.mkdirSync(output,{recursive:true});
  const browser = await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const context = await browser.newContext({viewport:{width:1440,height:900}});
  await context.routeWebSocket('**/api/ws/**', socket => socket.onMessage(raw => {
    const message = JSON.parse(raw);
    if (message.type === 'ping') socket.send(JSON.stringify({type:'pong'}));
    if (message.type === 'position') positions.push({mapId:message.mapId,position:message.position});
  }));
  await context.route('**/*', async route => {
    const req = route.request(), url = new URL(req.url());
    if (url.origin !== origin) { external.push(url.origin); return route.abort(); }
    if (url.pathname === '/news.json') return route.fulfill({status:200,contentType:'application/json',body:'{"items":[]}'});
    if (url.pathname.startsWith('/modules/')) modules.push(url.pathname);
    if (!url.pathname.startsWith('/api/')) return route.continue();
    const result = await request({method:req.method(),path:url.pathname,body:req.postData()||'',headers:req.headers()});
    const body=req.postData()?JSON.parse(req.postData()):{};
    api.push({path:url.pathname,status:result.status,interactionId:body.interactionId,mapId:body.mapId});
    return route.fulfill({status:result.status,contentType:'application/json',body:result.body});
  });
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type()==='error' && !message.text().includes('Failed to load resource')) errors.push(message.text()); });
  const wait = async (predicate, label, timeout=30000) => {
    const deadline=Date.now()+timeout;
    while(!predicate()) { assert(Date.now()<deadline,label); await page.waitForTimeout(100); }
  };
  const walk = async (key, predicate) => {
    await page.keyboard.down(key);
    try { await wait(()=>predicate(positions.at(-1)?.position || {}),'Walk '+key,10000); }
    finally { await page.keyboard.up(key); }
    await page.waitForTimeout(250);
  };
  const finishDialogue = async (suffix, start, count=40) => {
    for(let i=0;i<count && !api.slice(start).some(row=>row.path.endsWith(suffix) && row.status===200);i++) {
      await page.waitForTimeout(450); await page.keyboard.press('Space');
    }
    assert(api.slice(start).some(row=>row.path.endsWith(suffix) && row.status===200),'Dialogue completes: '+suffix);
    await page.waitForTimeout(750);
  };
  const login = async scenario => {
    console.log('Preparing active browser map '+scenario.mapId);
    assert.equal((await request({command:'prepare_misty_map',...scenario})).status,200);
    positions.length=0;
    await page.goto(origin);
    await page.getByRole('button',{name:'Play now'}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    console.log('Browser login ready');
    await page.waitForTimeout(2000);
    await page.screenshot({path:path.join(output,'login-ready.png')});
    await page.mouse.click(600,494);
    await page.keyboard.type('browsertrainer'); await page.keyboard.press('Enter');
    await page.keyboard.type('test-only correct horse'); await page.keyboard.press('Enter');
    await wait(()=>api.some(row=>row.path==='/api/auth/web/login' && row.status===200),'Login response');
    for(let attempt=0;attempt<20 && !(await page.evaluate(()=>Boolean(window.pokeaetherPreview?.worldReady)));attempt++) {
      await page.mouse.click(850,524); await page.waitForTimeout(500);
    }
    await page.waitForFunction(()=>window.pokeaetherPreview?.worldReady,null,{timeout:120000});
    await wait(()=>positions.some(row=>row.mapId===scenario.mapId),'Requested map becomes active');
    await page.waitForTimeout(1500);
    await page.screenshot({path:path.join(output,scenario.mapId+'.png')});
  };
  try {
    const signup=await request({command:'create_test_account'});
    assert.equal(signup.status,201,signup.body);
    assert.equal((await request({command:'verify_test_email'})).status,200);
    await login({mapId:'kanto_route_25_bills_house',checkpoint:'help_bill',position:{x:464,y:304},facingDirection:'up'});
    const before=api.length;
    await page.keyboard.press('Space');
    await finishDialogue('/kanto_bills_house_meet_bill/complete',before,18);
    await page.screenshot({path:path.join(output,'bill-after-meeting.png')});
    assert(api.slice(before).some(row=>row.path.endsWith('/kanto_bills_house_meet_bill/complete') && row.status===200),'Bill meeting completes through browser UI');
    console.log('Bill meeting completed');
    await walk('ArrowLeft',p=>p.x<=272);
    await page.keyboard.down('ArrowUp'); await page.waitForTimeout(120); await page.keyboard.up('ArrowUp');
    const computerStart=api.length;
    await page.keyboard.press('Space');
    await finishDialogue('/kanto_bills_house_activate_cell_separator/complete',computerStart,50);
    await wait(()=>api.some(row=>row.path.endsWith('/kanto_bills_house_completion_reward/claim') && row.status===200),'Bill ticket reward');
    await page.waitForTimeout(2000);
    await page.screenshot({path:path.join(output,'bill-restored-with-ticket.png')});
    console.log('Bill computer sequence and ticket completed');
    assert.equal(external.length,0,'No external traffic');
    assert.equal(errors.length,0,'No runtime errors: '+errors.join('\n'));
    fs.writeFileSync(path.join(output,'result.json'),JSON.stringify({success:true,api,errors,external,positions,modules},null,2));
    console.log('web_misty_gameplay_smoke: PASS (active Bill meeting, cell separation and ticket)');
  } finally {
    closing=true;
    fs.writeFileSync(path.join(output,'api.json'),JSON.stringify(api,null,2));
    fs.writeFileSync(path.join(output,'errors.json'),JSON.stringify(errors,null,2));
    fs.writeFileSync(path.join(output,'fixture-stderr.log'),stderr);
    await page.screenshot({path:path.join(output,'last-state.png')}).catch(()=>{});
    await browser.close(); bridge.stdin.end();
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
