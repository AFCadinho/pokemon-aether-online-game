"""Source-pinned own-rig diagnostics for the batch's archived model families."""
import argparse
import os
from pathlib import Path
import re

from alternate_forms_batch import ROOT, HERE, WORK, INTAKE, read, write, sha
from catalog_shiny_za_17_probe import run_flatpak
from catalog_remaining_normal_export import choose_actions
from phase5_review_actions import candidates

PROPOSALS = {
 'burmy-sandy':'pm0412_12_00','burmy-trash':'pm0412_13_00',
 'wormadam-sandy':'pm0413_12_00','wormadam-trash':'pm0413_13_00',
 'cherrim-sunshine':'pm0421_12_00','zygarde-10':'pm0770_12_00',
 'zygarde-complete':'pm0770_13_00','necrozma-ultra':'pm0800_14_00',
 'eternatus-eternamax':'pm0940_81_00', 'greninja-ash':'pm0725_12_00',
 'kyogre-primal':'pm0382_51','groudon-primal':'pm0383_51',
 'castform-sunny':'pm0351_12','castform-rainy':'pm0351_13','castform-snowy':'pm0351_14',
}
for index, form in enumerate(['heart','star','diamond','debutante','matron','dandy','la-reine','kabuki','pharaoh'],12):
    PROPOSALS['furfrou-'+form] = f'pm0701_{index:02}_00'
for index, form in enumerate(list('bcdefghijklmnopqrstuvwxyz')+['exclamation','question'],12):
    PROPOSALS['unown-'+form] = f'pm0201_{index:02}_00'
for index, form in enumerate(['fighting','flying','poison','ground','rock','bug','ghost','steel','fire','water',
    'grass','electric','psychic','ice','dragon','dark','fairy'],12):
    PROPOSALS['silvally-'+form] = f'pm0862_{index:02}'


def prepare():
    sources = read(WORK/'archive-probe-job.json')['sources']
    rows = []
    for row in read(INTAKE)['entries']:
        if row['status']=='native_candidate': continue
        name=row['species'];identity=row['resource'] or PROPOSALS.get(name)
        result={'species':name,'runtime_approved':False,'visual_approved':False}
        if not identity:
            rows.append({**result,'status':'mapping_hold','reason':'; '.join(row['holds'])});continue
        matches=[]
        for source in sources:
            if not any(source['archive']==a['archive'] and source['member']==a['member'] for a in row['archive_candidates']):continue
            report=read(source['output'])
            if not report['complete']:continue
            for variant in report['variants']:
                if re.sub(r'\.(trmdl|gfbmdl)$','',variant['rig'])==identity:
                    matches.append((source,variant))
        if len(matches)!=1:
            rows.append({**result,'status':'mapping_hold','reason':'Expected one own source rig; found '+str(len(matches)), 'proposed_resource':identity});continue
        source, variant=matches[0]
        if not variant['texture_identities'] or not variant['meshes']:
            rows.append({**result,'status':'source_hold','reason':'Selected rig lacks positive mesh/texture evidence','proposed_resource':identity});continue
        report={'species':name,'source_member':source['member'],'source_sha256':source['sha256'],
            'rig_selection':{'rig':variant['rig']},'action_candidates':variant['action_candidates'],
            'action_candidates_by_bank':variant['action_candidates_by_bank'],
            'unambiguous_actions':{k:v[0] for k,v in variant['action_candidates'].items() if len(v)==1},
            'second_physical_candidates':[a for a in variant['action_names'] if re.search(r'_(attack02|ba20_buturi02)(\.|$)',a)]}
        actions, bank=choose_actions(report)
        expected=next((x for x in variant['texture_identities'] if identity.startswith(x)),variant['texture_identities'][0])
        selection={'policy':'explicit_source_variant_review_v1','rig':variant['rig'],
            'rig_identity':identity,'expected_identity':expected,'source_sha256':source['sha256']}
        if variant['parent']:selection['rig_parent']=variant['parent']
        result.update(source=source,diagnostic_rig_selection=selection,resource=identity,
            status='export_candidate' if actions else 'motion_hold',actions=actions,bank=bank,
            motion_report=report,reason='' if actions else 'No complete own-source battle action set')
        rows.append(result)
    write(WORK/'legacy-intake.json',{'entries':rows,'source_intake_sha256':sha(INTAKE)})
    from collections import Counter
    print(dict(Counter(r['status'] for r in rows)))


def export_all():
    for row in read(WORK/'legacy-intake.json')['entries']:
        if row['status']!='export_candidate':continue
        name=row['species'];out=WORK/'legacy-export'/name;out.mkdir(parents=True,exist_ok=True)
        source=row['source'];job={'species':name,'source':source['path'],'source_sha256':source['sha256'],
            'diagnostic_rig_selection':row['diagnostic_rig_selection'],'actions':row['actions'],
            'output':str(out),'native_flatten_bone_hierarchy_diagnostic':True,'scvi_pbr_probe':False}
        try:
            assert sha(source['path'])==source['sha256']
            if not (out/'export.json').exists():
                write(out/'job.json',job)
                run_flatpak(HERE/'phase5_godot_export_worker.py',out/'job.json',[(WORK,''),(HERE,':ro')],out/'export.log')
            report=read(out/'export.json')
            assert sha(out/'model.glb')==report['glb_sha256']
            assert set(report['animations'])==set(row['actions'])
            result={**row,'status':'exported_for_review','export':report}
        except Exception as error:
            result={**row,'status':'held','reason':str(error)}
        write(WORK/'status/legacy-export'/(name+'.json'),result)
        print('LEGACY_EXPORT',name,result['status'],result.get('reason',''),flush=True)


if __name__=='__main__':
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['prepare','export']);a=p.parse_args()
    (prepare if a.phase=='prepare' else export_all)()
