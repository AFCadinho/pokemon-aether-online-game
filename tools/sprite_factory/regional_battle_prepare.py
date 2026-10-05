"""Rebind unchanged geometry measurements and propose regional battle placement.

Only material/eye-state revisions may reuse the baseline. Every GLB geometry,
skin and motion accessor must match. The existing independent 120 Hz runtime
scene validator remains required; this does not qualify or approve an asset.
"""
import json
from pathlib import Path
from catalog_galar_birds_candidates import sha
from phase5_variant_parity import signature
from catalog_mega_battle_calibrate import calibrate
from bake_motion_placement import bake

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.tmp/regional-production-v1'


def prepare():
    baseline_path=WORK/'battle-native-framed-v1/battle-review.json'
    report=json.loads(baseline_path.read_text())
    old=json.loads((WORK/'battle-input-v1/catalog.json').read_text())
    runtime_path=WORK/'runtime-final-v2.json'
    latest=json.loads(runtime_path.read_text())
    replacement_path=WORK/'weezing-native-repair-v1/battle-review.json'
    replacement=json.loads(replacement_path.read_text())
    assert replacement['complete'] and replacement['sample_hz']==60
    assert replacement['catalog_sha256']==sha(WORK/'weezing-smoke-v1/battle-input/catalog.json')
    assert replacement['runtime_catalog_sha256']==sha(WORK/'weezing-smoke-v1/runtime/report.json')
    fresh={r['species']:r for r in replacement['entries']if 'clips'in r}
    assert set(fresh)=={'weezing-galar','weezing-galar-shiny'}
    before={r['species']:r for r in old['entries'] if r['species']!='dragonite'}
    after={r['species']:r for r in latest}
    assert report['complete'] and report['sample_hz']==60
    assert report['catalog_sha256']==sha(WORK/'battle-input-v1/catalog.json')
    assert set(before)==set(after) and len(after)==116
    evidence=[]
    for name,a in before.items():
        b=after[name]
        assert sha(a['path'])==a['glb_sha256'] and sha(b['path'])==b['glb_sha256']
        assert sha(b['runtime_path'])==b['runtime_sha256']
        old_signature=signature(a['path'])
        if name in fresh:
            assert fresh[name]['glb_sha256']==b['glb_sha256']
        else:
            assert old_signature==signature(b['path']),name
        assert a['animations']==b['animations'],name
        evidence.append({'species':name,'old_glb_sha256':a['glb_sha256'],'glb_sha256':b['glb_sha256'],
                         'geometry_skin_motion_sha256':signature(b['path']),'runtime_sha256':b['runtime_sha256'],
                         'native_remeasurement_sha256':sha(replacement_path)if name in fresh else None})
    out=WORK/'battle-input-v3';out.mkdir(exist_ok=False)
    control=next(r for r in old['entries']if r['species']=='dragonite')
    (out/'catalog.json').write_text(json.dumps({'runtime_approved':False,'entries':[control,*latest]},indent=2)+'\n')
    report.update(catalog_sha256=sha(out/'catalog.json'),runtime_catalog_sha256=sha(runtime_path),
        source_baseline_sha256=sha(baseline_path),material_revision_geometry_parity=evidence,
        independent_motion_validation_pending=True,runtime_approved=False)
    for r in report['entries']:
        if r['species']in fresh:
            updated=fresh[r['species']];r.clear();r.update(updated)
        if r['species']in after:r['glb_sha256']=after[r['species']]['glb_sha256']
    (out/'geometry-baseline.json').write_text(json.dumps(report,indent=2)+'\n')
    proposal=calibrate(report,expected_pairs=58)
    measured={r['species']:r for r in report['entries']if 'clips'in r}
    proposal['hover']={n: .45 if n.startswith('weezing-galar') else .35 if n.startswith('geodude-alola')
        else .25 if n.startswith('raichu-alola') else 0. for n in after}
    # Exact same native mesh; Totem sizes follow the local Showdown height
    # ratios: Marowak 1.7/1.0m and Raticate 1.4/0.7m. Cap only for framing.
    for name,ratio in [('marowak-alola-totem',1.7),('raticate-alola-totem',2.)]:
        normal=name.removesuffix('-totem')
        pair=[measured[name+s]for s in ['', '-shiny']]
        wanted=proposal['readability'][normal]*ratio
        factor=min(wanted,320/max(s['screen_rect'][3] for r in pair for s in r['shots']),
                   560/max(s['screen_rect'][2] for r in pair for s in r['shots']))
        for r in pair:
            species=r['species'];proposal['readability'][species]=factor
            entry=dict(r,idle_verified=True,sha256=r['glb_sha256'],scale=r['scale']*factor,
                candidate_lift=max(0,.025-r['clips']['idle']['minimum_y']*factor),
                clips={a:dict(c,minimum_y_samples=[v*factor for v in c['minimum_y_samples']])for a,c in r['clips'].items()})
            proposal['motion'].update(bake(dict(review_schema=1,errors=[],entries={species:entry}),[species]))
    proposal['policy']='Regional review proposal; larger Totems, readable framing and native floor clearance. Independent 120 Hz runtime validation and user visual approval required.'
    (out/'placement.json').write_text(json.dumps(proposal,indent=2)+'\n')
    print('Candidates',len(after),'motion holds',proposal['motion_holds'])


if __name__=='__main__':prepare()
