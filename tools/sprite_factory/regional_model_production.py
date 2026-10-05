"""Resumable regional-form candidate batch; never approves or uploads models."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import traceback

from catalog_galar_birds_candidates import export, material, verify, sha, read
from catalog_shiny_za_17_probe import write
from material_profiles import read_profiles
from scvi_batch import source_entry

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORK = ROOT / '.tmp/regional-production-v1'
SOURCE = Path('/home/adinho/Documents/3d_models').resolve()
REQUIRED = {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'}


def intake():
    rows = []
    source_scan = WORK / 'source-scan.json'
    scans = read(source_scan) if source_scan.exists() else read(HERE / 'regional_model_batch_inputs.json')['source_scan']
    for scan in scans:
        if not (scan['scvi_model'] and scan['scvi_motions']):
            continue
        rid = scan['resource']
        source_root = Path(scan.get('source_root', SOURCE)).resolve()
        model = Path(scan['model_dir']).resolve()
        motion = Path(scan['motion_dir']).resolve()
        bank = 2 if scan['species'] == 'braviary-hisui' else 0
        overrides = {}
        for suffix in ['00001_battlewait01_loop', '00000_defaultwait01_loop']:
            name = str(bank) + suffix[1:]
            if (motion / (rid + '_' + name + '.tranm')).exists():
                overrides['idle'] = name
                break
        if bank == 2:
            overrides['sleep'] = '00281_sleep01_loop'
        selected = source_entry({'species': scan['species'], 'pm': int(rid[2:6]),
            'resource_id': rid, 'motion_overrides': overrides,
            'cross_bank_sleep_diagnostic': bank == 2}, model.parents[1], motion.parents[1])
        actions = {k: Path(v).stem + '.gfbanm' for k, v in selected['motions'].items() if v}
        holds = sorted(REQUIRED - actions.keys())
        files = sorted(p for p in model.iterdir() if p.is_file())
        if scan['species'] == 'pikachu-alola':
            # This cap form references shared body textures in sibling resource
            # directories. Pin those inputs as well as the primary resource.
            files = sorted(p for p in model.parent.rglob('*') if p.is_file())
        motion_files = sorted({Path(v) for v in [*selected['motions'].values(), *selected['motion_channels'].values()] if v})
        def receipt(path):
            return {'path': str(path.relative_to(source_root)), 'bytes': path.stat().st_size, 'sha256': sha(path)}
        row = dict(scan, source_root=str(source_root), dynamic_visibility_review=True, actions=actions, selected_bank=bank, warnings=selected['warnings'],
            scvi_files=[receipt(p) for p in files], selected_motion_files=[receipt(p) for p in motion_files],
            rare_texture_replacements=[], material_profiles=read_profiles(model / (rid + '.trmtr'), sha(model / (rid + '.trmtr'))),
            runtime_approved=False, holds=holds)
        row['effect_review_options'] = {'source_effect_uv_defaults_diagnostic': [p['material'] for p in row['material_profiles'] if p.get('requires_effect_payload')], 'source_loop_reset_diagnostic': True}
        if row['species'] == 'pikachu-alola':
            row['identical_source_variant_review'] = True
            row['restore_source_albedo_bindings'] = True
            row['excluded_visibility_targets'] = [
                'pm0025_11_00_sacap_mu_mesh_shape', 'pm0025_12_00_sacap_ag_mesh_shape',
                'pm0025_13_00_sacap_dp_mesh_shape', 'pm0025_14_00_sacap_bw_mesh_shape',
                'pm0025_15_00_sacap_xy_mesh_shape', 'pm0025_17_00_sacap_mo_mesh_shape',
                'pm0025_18_00_sacap_right_i_mesh_shape']
        if row['species'] == 'sneasel-hisui':
            row['excluded_visibility_targets'] = ['pm0215_01_41_left_ear_mesh_shape']
        rows.append(row)
    write(HERE / 'regional_model_source_intake.json', {'schema':1, 'runtime_approved':False, 'entries':rows})
    print('Native source candidates:',len(rows),'holds:',[(r['species'],r['holds'])for r in rows if r['holds']])


def process(phase, only):
    rows = read(HERE / 'regional_model_source_intake.json')['entries']
    if only:
        rows = [r for r in rows if r['species'] in only]
    status_path = WORK / (phase + '-status.json')
    prior = {r['species']:r for r in read(status_path)['entries']} if status_path.exists() else {}
    operation = export if phase == 'export' else material
    def one(row):
        try:
            if row['holds']:
                raise ValueError('Missing actions: '+str(row['holds']))
            source_root = Path(row.get('source_root', SOURCE))
            verify(row,source_root)
            result = operation(row,source_root,WORK)
            return {'species':row['species'],'status':'review_candidate',**result}
        except Exception as error:
            traceback.print_exc()
            return {'species':row['species'],'status':'held','reason':str(error)}
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(one,r) for r in rows]
        for future in as_completed(futures):
            result = future.result();prior[result['species']]=result
            write(status_path, {'schema':1,'runtime_approved':False,'entries':sorted(prior.values(), key=lambda r:r['species'])})
            print(phase,result['species'],result['status'],result.get('reason',''),flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['intake','export','material'])
    parser.add_argument('--only',nargs='*')
    args=parser.parse_args()
    intake() if args.phase=='intake' else process(args.phase,args.only)
