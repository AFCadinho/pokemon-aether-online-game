const {test}=require('node:test'), assert=require('node:assert/strict');
const {compare}=require('../tools/compare_pallet_battle_runs.cjs');
function run(variant,timings=[4000,1300,1300]) {
  return {success:true,evidence:{variant,normalizedTreeSHA256:'tree',godot:'engine',driverSHA256:'driver',
    backendCommit:'backend',fixtureSHA256:'fixture',chromium:'browser',commandsSHA256:'commands'},
    timingComparable:true,textureAudit:false,worldTextureAudit:false,mapOnly:false,
    scenario:'grass',viewport:'1440x900',softwareWebGL:true,battleStarts:3,battleTurns:4,errors:[],
    mapTransitions:['kanto_pallet_town','kanto_players_house','kanto_pallet_town'],
    markers:timings.flatMap((ms,i)=>[{label:'battle_start_requested',engineTicksMs:i*10000},
      {label:'battle_actions_ready',engineTicksMs:i*10000+ms},{label:'battle_teardown_begin',engineTicksMs:i*10000+ms+1}]),
    snapshots:['cold_post_idle','warm1_post_idle','warm2_post_idle','pallet_returned'].map(label=>
      ({label,memory:{textureCounterBytes:variant==='original'?400:200,orphanNodeCount:0}}))};
}
test('matched stable runs pass with exact deltas',()=>{
  const result=compare(run('original'),run('compact',[4050,1310,1290]));
  assert.equal(result.noObservedMaterialSlowdown,true);
  assert.equal(result.postIdleTextureCounterSavingBytes,200);
  assert.deepEqual(result.rows.map(x=>x.deltaMs),[50,10,-10]);
});
test('material warm regression requires review',()=>assert.equal(
  compare(run('original'),run('compact',[4000,1500,1500])).noObservedMaterialSlowdown,false));
test('interior scope requires both cycles, stable battle idle and matching map epochs',()=>{
  const interior=variant=>{
    const r=run(variant);r.evidence.scope='pallet_interiors';
    r.mapTransitions.push('kanto_oaks_lab','kanto_pallet_town');
    for(const label of ['house_entered','lab_entered','lab_returned']) {
      r.snapshots.push({label,memory:{textureCounterBytes:variant==='original'?450:230,orphanNodeCount:0}});
    }
    return r;
  };
  const result=compare(interior('original'),interior('compact'));
  assert.equal(result.noObservedMaterialSlowdown,true);
  assert.equal(result.mapTextureCounterSavings.at(-1).savingBytes,220);
  for(const mutate of [r=>r.mapTransitions.pop(),r=>r.snapshots.pop(),
    r=>r.snapshots.at(-1).memory.textureCounterBytes=NaN,r=>r.snapshots[1].memory.textureCounterBytes++,
    r=>r.snapshots.at(-1).memory.orphanNodeCount++,r=>r.evidence.scope='pallet_exterior']) {
    const r=interior('compact');mutate(r);assert.throws(()=>compare(interior('original'),r));
  }
});
test('reject every mismatched provenance field',()=>{
  for(const key of ['normalizedTreeSHA256','godot','driverSHA256','backendCommit','fixtureSHA256','chromium','commandsSHA256']) {
    const candidate=run('compact'); candidate.evidence[key]='different';
    assert.throws(()=>compare(run('original'),candidate));
  }
});
test('reject audits, failures, missing cycles, errors, and unstable residency',()=>{
  const mutations=[r=>r.success=false,r=>r.textureAudit=true,r=>r.worldTextureAudit=true,
    r=>r.mapOnly=true,r=>r.errors.push('error'),r=>r.markers.pop(),
    r=>r.mapTransitions.pop(),r=>r.snapshots[3].memory.textureCounterBytes++,
    r=>r.snapshots[0].memory.orphanNodeCount++];
  for(const mutate of mutations) { const candidate=run('compact'); mutate(candidate);
    assert.throws(()=>compare(run('original'),candidate)); }
});
