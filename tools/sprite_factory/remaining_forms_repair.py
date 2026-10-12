"""Recover the selected 2 + 13 + 3 forms, keeping earlier approval receipts immutable."""
import argparse
import importlib
import os
from pathlib import Path

from alternate_forms_batch import ROOT, HERE, SOURCE, MODELS, read, write, sha
from catalog_shiny_za_17_probe import run_flatpak

WORK = ROOT / '.tmp/remaining-forms-repair-v1'
INTAKE = HERE / 'remaining_forms_repair_intake.json'
DONORS = ROOT.parents[1] / 'slot-a/frontend/.tmp/remaining-dlc-15-v1'
IMPORTER = ROOT.parent / '.tmp/scvi-importer'
DEPS = ROOT.parent / '.tmp/scvi-python-deps'


def setup():
    rows = [r for r in read(HERE/'remaining_forms_investigation.json')['entries'] if r['category'] in
            ('corrected_source_mapping', 'identity_or_scale', 'renderer_or_state_work')]
    original = {r["species"]: r for r in read(HERE/"alternate_forms_source_intake.json")["entries"]}
    for row in rows: row["national_dex"] = original[row["species"]]["national_dex"]
    assert len(rows) == 18
    write(INTAKE, {'schema': 1, 'investigation_sha256': sha(HERE/'remaining_forms_investigation.json'),
                   'runtime_approved': False, 'entries': rows})
    WORK.mkdir(parents=True, exist_ok=True)


def tea(row):
    name = row['species']; base = name.split('-')[0]; ident = row['resource_candidate']
    directory = MODELS/ident[:6]/ident
    output = WORK/'export'/name; output.mkdir(parents=True, exist_ok=True)
    bound = WORK/'bound'/name; bound.mkdir(parents=True, exist_ok=True)
    donor_row, = [r for r in read(HERE/'catalog_remaining_dlc_motion_intake.json')['entries'] if r['species'] == base]
    donor = DONORS/'converted-v2'/base/'prepared.blend'
    assert sha(donor) == donor_row['prepared_sha256']
    old_job = read(DONORS/'flat-motion-v1'/base/'job.json')
    assert old_job['source_sha256'] == sha(donor)
    old_report = read(DONORS/'flat-motion-v1'/base/'export.json')
    comparison = read(HERE/'remaining_forms_evidence.json')['skeleton_comparisons'][ident[:6]]
    assert comparison['bone_records_equal'] and comparison['only_transform_names_differ']
    for key in ('base', 'variant'):
        assert sha(comparison[key]['path']) == comparison[key]['sha256']
    assert all(c['rig_indices'] == [-1, -1] and set(c['changes']) == {'name'} for c in comparison['transform_changes'])
    remap = {c['changes']['name'][0]: c['changes']['name'][1] for c in comparison['transform_changes']}
    rates = {r['fps'] for r in old_report['animations'].values()}; fps, = rates
    sources = {str(p): sha(p) for p in (MODELS/ident[:6]).rglob('*') if p.is_file()}
    job = {'species': name, 'identity': ident, 'variant': 'normal', 'model_dir': str(directory),
           'motions': {}, 'motion_channels': {}, 'output': str(output/'imported.blend'),
           'report': str(output/'import.json'), 'importer': str(IMPORTER), 'python_deps': str(DEPS),
           'importer_commit': 'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04',
           'shader_sha256': sha(IMPORTER/'SCVIShader.blend'), 'source_files': sources,
           'donor': str(donor), 'donor_sha256': sha(donor), 'donor_rig': donor_row['identity'],
           'actions': old_job['actions'], 'fps': int(fps), 'prepared': str(bound/'prepared.blend'),
           'donor_to_own_nodes': remap,
           'binding_report': str(output/'binding.json')}
    write(output/'import-job.json', job)
    if not (output/'binding.json').exists():
        run_flatpak(HERE/'remaining_forms_tea_worker.py', output/'import-job.json',
                    [(MODELS, ':ro'), (DONORS, ':ro'), (IMPORTER, ':ro'), (DEPS, ':ro'),
                     (HERE, ':ro'), (WORK, '')], output/'import.log')
    binding = read(output/'binding.json')
    assert sha(bound/'prepared.blend') == binding['prepared_sha256']
    assert sha(output/'import.json') == binding['source_import_sha256']
    assert binding['source_files'] == sources and binding['donor_sha256'] == sha(donor)
    assert binding['actions'] == old_job['actions'] and binding['donor_to_own_nodes'] == remap
    # Like the reviewed Galar pipeline, export geometry/motion separately from
    # material reconstruction. The native material tables remain mandatory,
    # hash-bound inputs to tea_materials; this GLB is never runtime approved.
    tables = [directory/(ident + suffix + '.trmtr') for suffix in ('', '_rare')]
    assert all(str(p) in sources and sha(p) == sources[str(p)] for p in tables)
    export_job = {'species': name, 'source': str(bound/'prepared.blend'),
                  'source_sha256': binding['prepared_sha256'], 'actions': old_job['actions'],
                  'output': str(output), 'scvi_pbr_probe': False, 'native_flatten_bone_hierarchy_diagnostic': True}
    write(output/'job.json', export_job)
    if not (output/'export.json').exists():
        run_flatpak(HERE/'phase5_godot_export_worker.py', output/'job.json',
                    [(HERE, ':ro'), (WORK, '')], output/'export.log')
    print('TEA_EXPORT', name, flush=True)


def context(only):
    import alternate_forms_batch as batch
    batch.WORK = WORK
    batch.INTAKE = INTAKE
    batch.cohort_rows = lambda: [r for r in read(INTAKE)['entries'] if not only or r['species'] in only]
    return batch.cohort_rows()


def tea_materials(row):
    from catalog_shiny_151_material_probe import rebuild
    from catalog_dlc_layer_emission import restore
    from catalog_dlc_sleep_proposals import propose
    from alternate_forms_recovery import model_entry
    from phase5_variant_parity import compare
    name = row['species']; ident = row['resource_candidate']; exported = WORK/'export'/name
    report = read(exported/'export.json'); source = exported/'model.glb'
    assert sha(source) == report['glb_sha256']
    hierarchy = WORK/'hierarchical'/name; hierarchy.mkdir(parents=True, exist_ok=True)
    job = {**read(exported/'job.json'), 'output': str(hierarchy), 'native_flatten_bone_hierarchy_diagnostic': False}
    write(hierarchy/'job.json', job)
    if not (hierarchy/'export.json').exists():
        run_flatpak(HERE/'phase5_godot_export_worker.py', hierarchy/'job.json',
                    [(HERE, ':ro'), (WORK, '')], hierarchy/'export.log')
    projection = WORK/'material-sources'/name; projection.mkdir(parents=True, exist_ok=True)
    family = MODELS/ident[:6]
    pins = {}
    for p in sorted(family.rglob('*.png')) + sorted((family/ident).glob('*.trmtr')):
        target = projection/p.name
        if target.exists():
            assert sha(target) == sha(p), 'Conflicting native texture basenames'
        else: target.symlink_to(p)
        pins[str(p)] = sha(p)
    write(projection/'source-pins.json', pins)
    entries = []
    for variant in ('normal', 'shiny'):
        out = WORK/'materials'/name/variant; out.mkdir(parents=True, exist_ok=True)
        table = projection/(ident + ('_rare' if variant == 'shiny' else '') + '.trmtr')
        materials = rebuild(source, out/'albedo.glb', table)
        emission = restore(out/'albedo.glb', out/'emission.glb', table)
        rest = propose(out/'emission.glb', out/'model.glb', hierarchical_source=hierarchy/'model.glb')
        proof = {'materials': materials, 'emission': emission, 'rest': rest,
                 'source_table_sha256': sha(table), 'binding_sha256': sha(exported/'binding.json')}
        write(out/'proof.json', proof)
        clips = {**report['animations'], 'sleep': {'duration': 2, 'loop': True}, 'faint_loop': {'duration': 1, 'loop': True}}
        entry = model_entry(name, variant, out/'model.glb', {**report, 'animations': clips},
                            {'source': {'sha256': sha(WORK/'bound'/name/'prepared.blend')}},
                            {'tea_material_proof_sha256': sha(out/'proof.json')})
        entry['source_visibility_policy'] = 'Own native marked-form mesh membership; recovered base motions with explicit non-bone node mapping'
        entry['sleep_proposal'] = rest
        entries.append(entry)
    compare(Path(entries[0]['path']), Path(entries[1]['path']))
    write(WORK/'status/material'/(name+'.json'), {'species': name, 'status': 'candidate', 'variants': entries})
    print('TEA_MATERIALS', name, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['setup', 'tea', 'tea-materials', 'runtime', 'appearance', 'battle', 'delivery'])
    parser.add_argument('--only')
    args = parser.parse_args()
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    if args.phase == 'setup':
        setup(); return
    rows = context(set(args.only.split(',')) if args.only else None)
    if args.phase == 'tea':
        for row in rows:
            if row['category'] == 'corrected_source_mapping': tea(row)
    elif args.phase == 'tea-materials':
        for row in rows:
            if row['category'] == 'corrected_source_mapping': tea_materials(row)
    elif args.phase == 'runtime': importlib.import_module('alternate_forms_runtime_queue').main()
    elif args.phase == 'appearance': importlib.import_module('alternate_forms_recovery_appearance').main(rows)
    elif args.phase == 'battle': importlib.import_module('alternate_forms_recovery_battle').main()
    elif args.phase == 'delivery':
        module = importlib.import_module('alternate_forms_delivery')
        for row in rows:
            name = row['species']
            result = module.qualify(name)
            write(WORK/'status/delivery'/(name+'.json'), result)
            print('DELIVERY', name, result['status'], flush=True)


if __name__ == '__main__': main()
