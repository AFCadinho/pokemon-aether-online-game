// Read-only paired-run analysis. Raw local reports are not committed.
const assert=require('node:assert/strict');
const fs=require('node:fs');
function validate(run,variant) {
  assert.equal(run.success,true,'Run must have completed');
  assert(run.sourceUnchanged!==false && !run.runtimeLost,'Source and disposable runtime must remain stable');
  assert.equal(run.evidence?.variant,variant,'Correct atlas variant');
  assert.equal(run.timingComparable,true,'Comparable timing required');
  assert(!run.textureAudit && !run.worldTextureAudit && !run.mapOnly,'Audits/map-only are not timing runs');
  assert.equal(run.battleStarts,3); assert(run.battleTurns>=1); assert.equal(run.errors.length,0);
  assert.deepEqual(run.mapTransitions,run.evidence.scope==='pallet_interiors' ?
    ['kanto_pallet_town','kanto_players_house','kanto_pallet_town','kanto_oaks_lab','kanto_pallet_town'] :
    ['kanto_pallet_town','kanto_players_house','kanto_pallet_town']);
  const events=run.markers.filter(x=>['battle_start_requested','battle_actions_ready','battle_teardown_begin'].includes(x.label));
  assert.deepEqual(events.map(x=>x.label),Array.from({length:3},()=>
    ['battle_start_requested','battle_actions_ready','battle_teardown_begin']).flat(),'Three ordered battle cycles');
  const timings=[0,3,6].map(i=>events[i+1].engineTicksMs-events[i].engineTicksMs);
  assert(timings.every(x=>Number.isFinite(x) && x>0),'Valid engine timestamps');
  const labels=['cold_post_idle','warm1_post_idle','warm2_post_idle','pallet_returned'];
  if(run.evidence.scope==='pallet_interiors') labels.push('lab_returned');
  const post=labels.map(label=>{
    const sample=run.snapshots.find(x=>x.label===label)?.memory;
    assert(sample && Number.isFinite(sample.textureCounterBytes),'Complete post-idle samples');
    assert.equal(sample.orphanNodeCount,0); return sample;
  });
  assert.equal(new Set(post.map(x=>x.textureCounterBytes)).size,1,'Stable texture counter after battles/map return');
  return {timings,textureCounterBytes:post[0].textureCounterBytes};
}
function compare(control,candidate) {
  const old=validate(control,'original'), compact=validate(candidate,'compact');
  assert.equal(control.evidence.scope,candidate.evidence.scope,'Matched map scope');
  for(const key of ['normalizedTreeSHA256','godot','driverSHA256','backendCommit','fixtureSHA256','chromium','commandsSHA256']) {
    assert(control.evidence[key],'Missing provenance '+key);
    assert.equal(control.evidence[key],candidate.evidence[key],'Matched '+key);
  }
  for(const key of ['scenario','viewport','softwareWebGL']) assert.equal(control[key],candidate[key],'Matched '+key);
  const rows=old.timings.map((ms,i)=>({cycle:['cold','warm1','warm2'][i],controlMs:ms,
    candidateMs:compact.timings[i],deltaMs:compact.timings[i]-ms,
    reviewThresholdMs:Math.max(i===0?500:100,ms*.1)}));
  return {rows,noObservedMaterialSlowdown:rows.every(x=>x.deltaMs<=x.reviewThresholdMs),
    postIdleTextureCounterSavingBytes:old.textureCounterBytes-compact.textureCounterBytes,
    sampleSizePerVariant:3,softwareWebGL:control.softwareWebGL,
    limitation:'One fixed scenario; not an SLA, statistical proof or physical GPU/RAM measurement.'};
}
if(require.main===module) {
  try {
    assert.equal(process.argv.length,4,'Usage: node tools/compare_pallet_battle_runs.cjs CONTROL.json CANDIDATE.json');
    console.log(JSON.stringify(compare(...process.argv.slice(2).map(p=>JSON.parse(fs.readFileSync(p,'utf8')))),null,2));
  } catch(error) { console.error(error.message); process.exitCode=1; }
}
module.exports={compare};
