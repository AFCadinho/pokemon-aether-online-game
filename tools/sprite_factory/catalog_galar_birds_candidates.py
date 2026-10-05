"""Pinned Galar bird candidates. Produces review artifacts, never admission."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from catalog_shiny_za_17_probe import run_flatpak, write
from catalog_shiny_151_material_probe import rebuild
from catalog_dlc_layer_emission import restore
from PIL import Image
from catalog_remaining_eye_bake import chunks, append_png, write_glb, linear_to_srgb
from scvi_material_probe import inspect_materials
from material_effect_export import prepare as prepare_effects
from phase5_variant_parity import compare
from scvi_tracm import inspect_tracm, inspect_visibility
from visibility_export import keys
from visibility_variants import mesh_name
from scvi_eye_motion import prepare as prepare_eyes

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INTAKE = HERE / 'catalog_galar_birds_source_intake.json'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def verify(row, source_root):
    for file in row['scvi_files'] + row['selected_motion_files']:
        path = source_root / file['path']
        if path.stat().st_size != file['bytes'] or sha(path) != file['sha256']:
            raise ValueError('Source changed: ' + str(path))
    for pair in row['rare_texture_replacements']:
        for variant in ('normal', 'rare'):
            if sha(source_root / pair[variant]) != pair[variant + '_sha256']:
                raise ValueError('Rare texture pair changed')


def export(row, source_root, work):
    importer = ROOT.parent / '.tmp/scvi-importer'
    deps = ROOT.parent / '.tmp/scvi-python-deps'
    commit = 'b0c98d9fcaab85a04ad35e2d111bae4cad6c1e04'
    if subprocess.check_output(['git', '-C', str(importer), 'rev-parse', 'HEAD'], text=True).strip() != commit:
        raise ValueError('Importer revision changed')
    model = next(source_root / r['path'] for r in row['scvi_files']
                 if r['path'].endswith(row['resource'] + '.trmdl'))
    motion_dir = next(source_root / r['path'] for r in row['selected_motion_files']).parent
    motions = {a: str(motion_dir / (s.removesuffix('.gfbanm') + '.tranm'))
               for a, s in row['actions'].items()}
    folder = work / 'import' / row['species']
    folder.mkdir(parents=True, exist_ok=True)
    source = folder / 'prepared.blend'
    files = {str(p): sha(p) for p in model.parent.iterdir() if p.is_file()}
    if row.get('restore_source_albedo_bindings', False):
        files.update({str(source_root / r['path']): r['sha256'] for r in row['scvi_files']})
    files.update({p: sha(p) for p in motions.values()})
    import_job = {'species': row['species'], 'identity': row['resource'], 'variant': 'normal',
                  'model_dir': str(model.parent), 'motions': motions, 'motion_channels': {},
                  'restore_all_eyelids': False, 'output': str(source),
                  'report': str(folder / 'import.json'), 'source_files': files,
                  'importer': str(importer), 'python_deps': str(deps),
                  'importer_commit': commit, 'shader_sha256': sha(importer / 'SCVIShader.blend')}
    write(folder / 'job.json', import_job)
    if not (folder / 'import.json').exists():
        run_flatpak(HERE / 'scvi_import_worker.py', folder / 'job.json',
                    [(work, ''), (HERE, ':ro'), (source_root.resolve(), ':ro'),
                     (importer, ':ro'), (deps, ':ro')], folder / 'import.log')
    imported = read(folder / 'import.json')
    if sha(source) != imported['prepared_sha256'] or any(sha(p) != h for p, h in files.items()):
        raise ValueError('Native import or source provenance changed')
    output = work / 'export' / row['species']
    output.mkdir(parents=True, exist_ok=True)
    isolated = output / 'input.blend'
    if not isolated.exists():
        shutil.copyfile(source, isolated)
    if sha(source) != sha(isolated):
        raise ValueError('Disposable export input differs from native import')
    job = {'species': row['species'], 'source': str(isolated),
           'source_sha256': sha(isolated),
           'actions': {a: spec['name'] for a, spec in imported['actions'].items() if spec},
           'output': str(output), 'scvi_pbr_probe': False,
           'native_flatten_bone_hierarchy_diagnostic': True}
    write(output / 'job.json', job)
    if not (output / 'export.json').exists():
        run_flatpak(HERE / 'phase5_godot_export_worker.py', output / 'job.json',
                    [(work, ''), (HERE, ':ro')], output / 'export.log')
    report = read(output / 'export.json')
    if report['glb_sha256'] != sha(output / 'model.glb'):
        raise ValueError('Export digest changed')
    if set(report['animations']) != set(row['actions']):
        raise ValueError('Export did not retain all selected clips')
    return report


def visibility(row, entry, motion_dir):
    doc, _ = chunks(Path(entry['path']))
    meshes = {n['name'] for n in doc['nodes'] if 'mesh' in n}
    result = {'schema': 1, 'glb_sha256': entry['glb_sha256'], 'clips': {}}
    for action, source_action in row['actions'].items():
        path = motion_dir / (source_action.removesuffix('.gfbanm') + '.tracm')
        spec = inspect_tracm(path)
        clip = entry['animations'][action]
        if abs((spec['frames'] - 1) / spec['fps'] - clip['duration']) > 1e-5:
            raise ValueError('Raw visibility clock differs: ' + action)
        tracks = [{'mesh': mesh_name(t['target']), 'source_target': t['target'],
                   'keys': keys(t, spec['frames'], spec['fps'],
                                dynamic_review=row.get('dynamic_visibility_review', False),
                                full_frame_review=row.get('dynamic_visibility_review', False))}
                  for t in inspect_visibility(path)
                  if t['target'] not in row.get('excluded_visibility_targets', [])]
        if len(tracks) != len(meshes) or {t['mesh'] for t in tracks} != meshes:
            raise ValueError('Visibility does not identify every exported mesh')
        result['clips'][action] = {'duration': clip['duration'], 'loop': clip['loop'],
                                  'source_path': str(path), 'source_sha256': sha(path),
                                  'tracks': tracks}
    return result


def fire_colour(material, directory):
    """Reconstruct white-base fire layers in linear light before PNG encoding."""
    base = Image.open(directory / Path(material['textures']['BaseColorMap']).with_suffix('.png')).convert('RGBA')
    if base.getextrema() != ((255, 255),) * 4:
        raise ValueError('Fire colour reconstruction requires the pinned white base')
    mask = Image.open(directory / Path(material['textures']['LayerMaskMap']).with_suffix('.png')).convert('RGBA')
    pixels = []
    for rgba in mask.getdata():
        colour = [1.0, 1.0, 1.0]
        for i, channel in enumerate(rgba, 1):
            tint = material['colors'][f'BaseColorLayer{i}']
            strength = min(1.0, channel / 255.0 * 2 * material['floats'][f'LayerMaskScale{i}'])
            colour = [a * (1 - strength) + b * strength for a, b in zip(colour, tint[:3])]
        pixels.append(tuple(linear_to_srgb(v) for v in colour) + (255,))
    result = Image.new('RGBA', mask.size)
    result.putdata(pixels)
    output = BytesIO()
    result.save(output, format='PNG')
    return output.getvalue()


def material(row, source_root, work):
    source = work / 'export' / row['species'] / 'model.glb'
    exported = read(source.with_name('export.json'))
    export_job = read(source.with_name('job.json'))
    if sha(source) != exported['glb_sha256']:
        raise ValueError('Raw export changed')
    if sha(export_job['source']) != export_job['source_sha256']:
        raise ValueError('Native Blender input changed after export')
    normal = next(source_root / r['path'] for r in row['scvi_files']
                  if r['path'].endswith(row['resource'] + '.trmtr'))
    motions = next(source_root / r['path'] for r in row['selected_motion_files']).parent
    variants = []
    # The glTF exporter cannot follow the custom fire graph. Give the
    # source-table reconstruction an explicit colour binding for those exact
    # effect materials; the runtime shader later replaces this static surface.
    doc, binary = chunks(source)
    tables = {m['name']: m for m in inspect_materials(normal)}
    effect_names = {p['material'] for p in row['material_profiles'] if p.get('requires_effect_payload')}
    for m in doc['materials']:
        if m['name'] not in effect_names and not row.get('restore_source_albedo_bindings', False):
            continue
        name = tables[m['name']]['textures']['BaseColorMap']
        texture = normal.parent / Path(name).with_suffix('.png')
        m.setdefault('pbrMetallicRoughness', {})['baseColorTexture'] = {
            'index': append_png(doc, binary, texture.read_bytes(), texture.stem, 0)}
    seeded = work / 'material-input' / row['species'] / 'source-bound.glb'
    seeded.parent.mkdir(parents=True, exist_ok=True)
    write_glb(seeded, doc, binary)
    if sha(source) != sha(seeded):
        compare(source, seeded)
    for variant in ('normal', 'shiny'):
        folder = work / 'materials' / row['species'] / variant
        folder.mkdir(parents=True, exist_ok=True)
        table = normal if variant == 'normal' else normal.with_stem(normal.stem + '_rare')
        base = folder / 'albedo.glb'
        colours = rebuild(seeded, base, table)
        target = folder / 'model.glb'
        emission = restore(base, target, table)
        clips = exported['animations']
        entry = {'species': row['species'] + ('-shiny' if variant == 'shiny' else ''),
                 'path': str(target), 'glb_sha256': sha(target), 'animations': clips,
                 'source_sha256': export_job['source_sha256'], 'runtime_schema': 1,
                 'native_export_receipt_sha256': sha(source.with_name('export.json')),
                 'action_timing': {a: {'frames': c['duration'] * 60, 'speed': 1,
                                      'loop': c['loop']} for a, c in clips.items()},
                 'placement': {'scale': 1, 'yaw_degrees': 0},
                 'complete_pose_channels': True, 'status': 'exported_for_review',
                 'runtime_approved': False, 'appearance_approved': False,
                 'battle_approved': False, 'maximum_pose_extent': 12,
                 'material_receipt': colours, 'layer_emission': emission,
                 'material_table_sha256': sha(table),
                 'material_limitations': 'Source material reconstruction; pending visual approval',
                 'review_poses': [['idle', 0, 'front'], ['idle', .5, 'back'],
                     ['idle', .5, 'side'], ['physical_attack', .5, 'front'],
                     ['physical_attack_2', .5, 'front'], ['special_attack', .5, 'front'],
                     ['sleep', .5, 'front'], ['faint_start', 1, 'front'],
                     ['faint_loop', .5, 'front']]}
        entry['visibility'] = visibility(row, entry, motions)
        channels = {a: str(motions / (s.removesuffix('.gfbanm') + '.tracm'))
                    for a, s in row['actions'].items()}
        eye_job = {'material_source': str(table), 'identity_intake': {
            'source_eye_material_diagnostic': 'eyelid_source_uv',
            'motion_channels': channels,
            'identity_evidence': {'source_sha256': {p: sha(p) for p in channels.values()}}}}
        eye_motion = prepare_eyes(eye_job, clips, entry['glb_sha256'])
        if eye_motion.get('materials'):
            entry['eye_motion'] = eye_motion
        effects = prepare_effects({'material_source': str(table),
                                  'material_source_sha256': sha(table),
                                  'effect_motion_dir': str(motions),
                                  'identity_intake': {**row.get('effect_review_options', {}),
                                      'motion_channels': channels,
                                      'identity_evidence': {'source_sha256': {
                                          str(p): sha(p) for p in motions.glob('*.tracm')}}}})
        if effects:
            doc, binary = chunks(target)
            material_rows = {m['name']: m for m in inspect_materials(table)}
            for effect in effects:
                material = next(m for m in doc['materials'] if m['name'] == effect['material'])
                png = folder / (effect['material'] + '-color.png')
                png.write_bytes(fire_colour(material_rows[effect['material']], table.parent))
                effect['color'] = {'path': str(png), 'sha256': sha(png)}
                # The generic normal-displacement approximation tears these
                # thin, skinned flame surfaces. Retain their native skeletal
                # movement and source UV colour animation for visual review.
                effect['authored_surface_review'] = {
                    'mode': 'native_skeletal_fire_without_auxiliary_normal_displacement',
                    'source_height': effect['height'],
                    'reason': 'Height-zero diagnostic retains connected flames; double-sided rendering does not',
                    'visual_approved': False}
                effect['height'] = 0.0
                matches = [p for m in doc['meshes'] for p in m['primitives']
                           if p.get('material') == doc['materials'].index(material)]
                if not matches or any('TEXCOORD_1' not in p['attributes'] for p in matches):
                    raise ValueError('Native effect second UV is missing')
            entry['material_effects'] = {'schema': 1, 'glb_sha256': entry['glb_sha256'],
                                         'records': effects,
                                         'scope': 'source-driven effects; pending visual approval'}
        write(folder / 'receipt.json', entry)
        variants.append(entry)
    if row.get('identical_source_variant_review', False):
        from phase5_variant_parity import signature
        rare = normal.with_stem(normal.stem + '_rare')
        if inspect_materials(normal) != inspect_materials(rare):
            raise ValueError('Identical variant exception requires identical parsed source materials')
        if variants[0]['glb_sha256'] != variants[1]['glb_sha256']:
            raise ValueError('Identical source variant unexpectedly changed')
        parity = signature(Path(variants[0]['path']))
        for entry in variants:
            entry['variant_limitation'] = 'Normal and rare source materials are identical; no invented shiny recolour'
    else:
        parity = compare(Path(variants[0]['path']), Path(variants[1]['path']))
    return {'species': row['species'], 'variants': variants, 'geometry_motion_parity': parity}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('export', 'material', 'stage'))
    parser.add_argument('--work', type=Path, default=ROOT / '.tmp/galar-birds-candidates-v3')
    parser.add_argument('--source-root', type=Path, default=Path('/home/adinho/Documents/3d_models'))
    args = parser.parse_args()
    args.source_root = args.source_root.resolve()
    work = args.work.resolve()
    if not work.is_relative_to(ROOT / '.tmp'):
        raise ValueError('Evidence must stay in this assigned frontend .tmp')
    intake = read(INTAKE)
    if args.phase == 'stage':
        report = read(work / 'material-status.json')
        if len(report['entries']) != 3 or any(r['status'] != 'review_candidate' for r in report['entries']):
            raise ValueError('All three pairs must be complete')
        rows = [v for r in report['entries'] for v in r['variants']]
        for row in rows:
            if sha(row['path']) != row['glb_sha256']:
                raise ValueError('Material candidate changed')
        write(work / 'stage.json', rows)
        print('STAGED six normal/shiny review candidates')
        return
    work.mkdir(parents=True, exist_ok=True)
    operation = export if args.phase == 'export' else material

    def one(row):
        try:
            verify(row, args.source_root)
            return {'species': row['species'], 'status': 'review_candidate',
                    **operation(row, args.source_root, work)}
        except Exception as error:
            import traceback
            traceback.print_exc()
            return {'species': row['species'], 'status': 'held', 'reason': str(error)}

    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(one, intake['entries']):
            results.append(result)
            write(work / (args.phase + '-status.json'),
                  {'schema': 1, 'intake_sha256': sha(INTAKE), 'runtime_approved': False,
                   'appearance_approved': False, 'entries': results})
            print(args.phase, result['species'], result['status'], result.get('reason', ''), flush=True)
    if any(r['status'] == 'held' for r in results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
