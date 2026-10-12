"""Reproduce the Zygarde core blocker from pinned local source data.

No texture projection, shader substitution, catalog admission or upload occurs.
Image inventory establishes missing inputs, not equivalence of shader formulas.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

from PIL import Image
from catalog_shiny_za_17_probe import run_flatpak
from scvi_material_probe import inspect_materials
from material_profiles import classify
from scvi_tracm import inspect_visibility

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PREVIOUS = ROOT / '.tmp/alternate-forms-batch-v1'
WORK = ROOT / '.tmp/zygarde-ten-core-v1'


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def source_image(directory, texture):
    path = directory / Path(texture).with_suffix('.png')
    if not path.is_file() and texture.endswith('_fresnel_prb.bntx'):
        # Inspect the explicitly numbered export. Never silently rename it or
        # treat one cube face as a complete cubemap.
        path = path.with_stem(path.stem + '_0')
    with Image.open(path) as image:
        extrema = image.convert('RGBA').getextrema()
        return {'path': str(path), 'sha256': sha(path), 'size': list(image.size),
                'rgba_extrema': [list(pair) for pair in extrema],
                'constant_white': extrema == ((255, 255),) * 4}


def missing_bindings(material, graph):
    names = {Path(node['filepath']).name
             for node in graph['image_nodes_including_disconnected']}
    missing = []
    for key, reference in material['textures'].items():
        expected = Path(reference).with_suffix('.png').name
        candidates = {expected}
        if key == 'LocalSpecularProbe':
            candidates.add(Path(expected).with_stem(Path(expected).stem + '_0').name)
        if not names.intersection(candidates):
            missing.append(key)
    return sorted(missing)


def graph(label, source, digest, material):
    job = {'source': str(source), 'source_sha256': digest,
           'material': material, 'output': str(WORK / (label + '-bindings.json'))}
    job_path = WORK / (label + '-bindings-job.json')
    write(job_path, job)
    run_flatpak(HERE / 'zygarde_core_graph_probe.py', job_path,
                [(HERE, ':ro'), (source.parent, ':ro'), (WORK, '')],
                WORK / (label + '-bindings.log'))
    return read(job['output'])


def main(output):
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        raise ValueError('Run through the assigned slot environment')
    intake = next(r for r in read(HERE / 'alternate_forms_za_intake.json')['entries']
                  if r['species'] == 'zygarde-10')
    directory = Path(intake['source_directory'])
    for record in intake['scvi_files'] + intake['selected_motion_files']:
        path = Path(record['path'])
        if path.stat().st_size != record['bytes'] or sha(path) != record['sha256']:
            raise ValueError('Native source changed: ' + str(path))
    imported = read(PREVIOUS / 'import/zygarde-10/import.json')
    native = graph('native', PREVIOUS / 'import/zygarde-10/prepared.blend',
                   imported['prepared_sha256'], 'body_b_01')
    legacy_row = next(r for r in read(PREVIOUS / 'legacy-intake.json')['entries']
                      if r['species'] == 'zygarde-10')
    archived = legacy_row['source']
    legacy = graph('archive', Path(archived['path']), archived['sha256'], 'body_b_01.001')
    variants = {}
    for variant, suffix in [('normal', ''), ('shiny', '_rare')]:
        table = directory / ('pm0770_11_00' + suffix + '.trmtr')
        materials = {m['name']: m for m in inspect_materials(table)}
        core = materials['body_b_01']
        variants[variant] = {
            'table': str(table), 'table_sha256': sha(table),
            'core': core,
            'core_images': {key: source_image(directory, path)
                            for key, path in core['textures'].items()},
            'source_profiles': [classify(m) for m in materials.values()],
            'core_inputs_absent_from_normal_reference_graphs': {
                'native_import': missing_bindings(core, native),
                'biochao_archive': missing_bindings(core, legacy)},
            'shell': {key: materials['body_a_02'][key]
                      for key in ('name', 'shaders', 'alpha_type')},
        }
    listing = PREVIOUS / 'za-listing.txt'
    shader_members = [line for line in listing.read_text().splitlines()
                      if line.lower().endswith(('.bnsh', '.trsha', '.glsl', '.hlsl', '.spv'))]
    visibility = {}
    for action, motion in intake['actions'].items():
        path = directory / (motion + '.tracm')
        targets = {'pm0770_11_00_' + name + '_mesh_shape'
                   for name in ('core', 'body01', 'offseteffb01')}
        visibility[action] = {'path': str(path), 'sha256': sha(path),
                              'tracks': [t for t in inspect_visibility(path)
                                         if t['target'] in targets]}
    result = {
        'schema': 1, 'species': 'zygarde-10', 'runtime_approved': False,
        'status': 'source_shader_reference_required',
        'source_intake_sha256': sha(HERE / 'alternate_forms_za_intake.json'),
        'code_sha256': {p.name: sha(p) for p in (Path(__file__), HERE / 'zygarde_core_graph_probe.py')},
        'reference_graphs': {'native': native, 'archive': legacy},
        'variants': variants,
        'visibility': visibility,
        'za_shader_inventory': {'listing': str(listing), 'sha256': sha(listing),
                                'shader_members': shader_members},
        'conclusion': 'Both normal reference graphs omit the secondary colour/normal domains, AO and native probe. Constant-white probe data resolves the filename question, not the Fresnel/refraction formulas. The shell also needs a qualified Thin-refraction translation. Neither reference is independent proof of the original Z-A effects.',
        'needed': 'Matching Z-A FresnelEffect and IkCharacterTransparent shader semantics, or independent original-engine reference views sufficient to qualify a visual reconstruction.',
    }
    write(output, result)
    print('ZYGARDE_CORE_PROBE', result['status'], flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=HERE / 'zygarde_core_probe_result.json')
    main(parser.parse_args().output)
