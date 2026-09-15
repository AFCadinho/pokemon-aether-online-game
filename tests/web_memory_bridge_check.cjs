const fs=require('node:fs'), path=require('node:path'), vm=require('node:vm'), assert=require('node:assert/strict');
const source=fs.readFileSync(path.join(__dirname,'../infrastructure/web/shell.html'),'utf8')
  .match(/<script id="pokeaether-memory-probe">([\s\S]*?)<\/script>/)[1];
const create=enabled=>{
  const wasm={Memory:WebAssembly.Memory,instantiate:WebAssembly.instantiate};
  const context={URLSearchParams,location:{search:enabled?'?memory-probe':''},window:{},
    performance:{now:()=>123},WebAssembly:wasm};
  vm.runInNewContext(source,context);
  return context;
};
(async()=>{
  const inactive=create(false);
  assert.equal(inactive.WebAssembly.instantiate,WebAssembly.instantiate);
  assert.equal(inactive.window.pokeaetherMemoryProbe,undefined);
  const active=create(true);
  const moduleBytes=Uint8Array.from([0,97,115,109,1,0,0,0,5,3,1,0,1,7,10,1,6,109,101,109,111,114,121,2,0]);
  const result=await active.WebAssembly.instantiate(moduleBytes,{});
  const probe=active.window.pokeaetherMemoryProbe;
  probe.record({label:'first'});
  assert.equal(probe.samples[0].wasmCapacityBytes,65536);
  assert.equal(probe.samples[0].jsHeapUsedBytes,null);
  result.instance.exports.memory.grow(1);
  for(let i=0;i<300;i++)probe.record({label:'sample'});
  assert.equal(probe.samples.length,240);
  assert.equal(probe.samples.at(-1).wasmCapacityBytes,131072);
  console.log('web_memory_bridge_check: PASS (opt-in only, actual Wasm capacity/growth, bounded samples)');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
