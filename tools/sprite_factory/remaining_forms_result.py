"""Summarize all 53 original holds after the explicitly selected recovery work."""
import copy
import json
import subprocess
from remaining_forms_repair import ROOT,HERE,WORK,read,write,sha


def canonical(value):
    import hashlib
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def main():
    receipt=read(HERE/'remaining_forms_repair_qualification.json')
    assert receipt['admitted_registry_check_passed']
    restored=set(receipt['forms']);shared=set(receipt['shared_forms']['forms'])
    rows=copy.deepcopy(read(HERE/'remaining_forms_investigation.json')['entries'])
    for row in rows:
        name=row['species']
        row['runtime_approved']=name in restored|shared
        if name in restored:row['status']='qualified_pair'
        elif name in shared:row['status']='qualified_shared_model'
        elif name=='zygarde-10':row.update(read(WORK/'renderer-holds/zygarde-10.json'));row['status']='renderer_held'
        else:row['status']='held_outside_selected_scope'
    old=read(HERE/'alternate_forms_recovery_qualification.json')
    registry=read(ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json')
    # The immutable task base defines all pre-existing records, not a moving
    # development branch or the now-expanded current catalog.
    before=json.loads(subprocess.check_output(['git','show','63f231592a40f112e88608e00624ab6e735e98a8:scripts/battle/battle_ui/reviewed_model_catalog.json'],cwd=ROOT))
    for kind in ('models','profiles'):
        assert all(registry[kind][k]==v for k,v in before[kind].items())
    previous=['tools/sprite_factory/alternate_forms_qualification.json','tools/sprite_factory/alternate_forms_recovery_qualification.json',
              'tools/sprite_factory/remaining_forms_investigation.json','release/approved_3d_alternate_forms_index.json',
              'release/approved_3d_alternate_forms_recovery_index.json','release/approved_3d_bundles_v13_index.json']
    write(HERE/'remaining_forms_repair_result.json',{'schema':1,'selected_forms':18,'restored_forms':len(restored|shared),
          'new_pair_packs':len(restored),'shared_existing_forms':len(shared),'remaining_forms':sum(not r['runtime_approved'] for r in rows),
          'restored_forms_across_original_229':120+len(old['forms'])+len(restored|shared),
          'runtime_approved':True,'release_approved':False,'published':False,
          'qualification_sha256':sha(HERE/'remaining_forms_repair_qualification.json'),
          'previous_registry':{k+'_sha256':canonical(before[k]) for k in ('models','profiles')},
          'previous_approvals':{p:sha(ROOT/p) for p in previous},'entries':rows})
    print('REMAINING_FORMS_RESULT',len(restored|shared),'restored;',sum(not r['runtime_approved'] for r in rows),'remaining')


if __name__=='__main__':main()
