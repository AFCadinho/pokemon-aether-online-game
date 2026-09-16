const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
  const origin='http://127.0.0.1:8061';
  const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--enable-unsafe-swiftshader']});
  const page=await browser.newPage();
  const audio=[];
  page.on('response',r=>{if(new URL(r.url()).pathname.startsWith('/browser-audio/'))audio.push({path:new URL(r.url()).pathname,status:r.status()});});
  await page.route('**/*',route=>{
    const url=new URL(route.request().url());
    if(url.origin!==origin)return route.abort();
    if(url.pathname.startsWith('/api/'))return route.fulfill({status:200,contentType:'application/json',body:'{"success":true,"status":"ok","available":true,"mode":"open","onlineUsers":0}'});
    if(url.pathname==='/news.json')return route.fulfill({status:200,contentType:'application/json',body:'{"items":[]}'});
    return route.continue();
  });
  try{
    await page.goto(origin);
    await page.getByRole('button',{name:'Play now'}).click();
    await page.waitForFunction(()=>window.pokeaetherPreview?.loginReady,null,{timeout:120000});
    await page.mouse.click(500,400);
    await page.waitForFunction(()=>window.pokeaetherAudioDiagnostics.events.some(e=>e.event==='native-music-playing'&&e.track.includes('/music/login/')));
    await page.evaluate(()=>window.pokeaetherBrowserAudio.playMusic('res://assets/music/battle/wild/Kanto Wild Battle.ogg',0.1));
    await page.waitForFunction(()=>window.pokeaetherAudioDiagnostics.events.some(e=>e.event==='native-music-playing'&&e.track.includes('/music/battle/')));
    await page.evaluate(()=>window.pokeaetherBrowserAudio.playSfx('res://assets/audio/sfx/ui/ranked_match_found.ogg',0.1));
    await page.waitForTimeout(1000);
    assert(audio.some(r=>r.path.includes('/music/login/')&&r.status<400));
    assert(audio.some(r=>r.path.includes('/music/battle/')&&r.status<400));
    assert(audio.some(r=>r.path.includes('/audio/sfx/')&&r.status<400));
    assert.deepEqual(audio.filter(r=>r.status>=400),[]);
    console.log('web_external_music_smoke: PASS (real login music, external battle-track playback and effect resource)');
  }finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
