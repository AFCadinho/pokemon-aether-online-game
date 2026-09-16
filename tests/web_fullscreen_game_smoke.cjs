// Real exported Godot settings UI; all API/news responses are public test stubs.
const {chromium}=require('playwright');
const path=require('node:path');
const fs=require('node:fs');
const assert=require('node:assert/strict');
(async()=>{
  const origin=process.env.POKEAETHER_WEB_PREVIEW_URL||'http://127.0.0.1:8061';
  assert.equal(new URL(origin).hostname,'127.0.0.1');
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const page=await browser.newPage({viewport:{width:1440,height:900}});
  const output=path.resolve(__dirname,'../builds/web-fullscreen-qa');
  fs.mkdirSync(output,{recursive:true});
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==origin)return route.abort();
    if(url.pathname.startsWith('/api/'))return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({success:true,status:'ok',available:true,mode:'open',onlineUsers:0})});
    if(url.pathname==='/news.json')return route.fulfill({status:200,contentType:'application/json',body:'{"items":[]}'});
    return route.continue();
  });
  try{
    await page.goto(origin);
    await page.getByRole('button',{name:'Play now',exact:true}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    await page.waitForTimeout(3000);
    await page.mouse.click(1326,755);
    await page.waitForTimeout(500);
    await page.mouse.click(444,364);
    await page.waitForTimeout(500);
    await page.screenshot({path:path.join(output,'graphics-before.png')});
    if(process.env.POKEAETHER_FULLSCREEN_INSPECT==='1')return;
    await page.mouse.click(984,490);
    await page.waitForFunction(()=>window.pokeaetherFullscreen.active(),null,{timeout:10000});
    await page.screenshot({path:path.join(output,'fullscreen.png')});
    await page.evaluate(()=>document.exitFullscreen());
    await page.waitForFunction(()=>!window.pokeaetherFullscreen.active());
    await page.waitForTimeout(500);
    await page.screenshot({path:path.join(output,'external-exit.png')});
    await page.mouse.click(984,490);
    await page.waitForFunction(()=>window.pokeaetherFullscreen.active(),null,{timeout:10000});
    await page.mouse.click(984,490);
    await page.waitForFunction(()=>!window.pokeaetherFullscreen.active(),null,{timeout:10000});
    assert.deepEqual(errors,[]);
    console.log('web_fullscreen_game_smoke: PASS (actual Godot toggle, external exit, re-enter and toggle off)');
  }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
