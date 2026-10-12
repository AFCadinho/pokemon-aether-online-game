"""Resolve explicitly named sibling textures into a read-only source projection.

Variants legitimately reference textures stored in another directory of the same
source species. Ambiguous bytes and missing references remain hard failures.
"""
from pathlib import Path
import os
import re
from catalog_remaining_eye_bake import chunks
from scvi_tracm import inspect_visibility
from visibility_variants import mesh_name
from alternate_forms_batch import MODELS, SOURCE, WORK, sha, write
from scvi_material_probe import inspect_materials
from material_profiles import classify
from scvi_identity import Buffer


def prepare(row):
    resource = row['resource']
    original = Path(row.get('source_directory', MODELS / resource[:6] / resource))
    if not any(original.resolve().is_relative_to(root.resolve()) for root in (MODELS, WORK/'za-sources')):
        raise ValueError('Unexpected native source root')
    directory = WORK / 'material-sources' / row['species']
    directory.mkdir(parents=True, exist_ok=True)
    required = set()
    relative_refs = set()
    scene_reflection_probes = set()
    for variant in ['', '_rare']:
        for material in inspect_materials(original / (resource + variant + '.trmtr')):
            for key,name in material['textures'].items():
                if key == 'LocalReflectionMap' and original.is_relative_to(WORK/'za-sources'):
                    if name != '../../../share/specular_prb/poke_metal_default_prb/poke_metal_default_prb.bntx':
                        raise ValueError('Unknown source environment probe')
                    # The battle environment supplies the reflection cubemap.
                    # This external scene probe is not a model albedo/detail map.
                    scene_reflection_probes.add(name)
                    continue
                relative_refs.add(Path(name).with_suffix('.png'))
            required.update(p.name for p in relative_refs)
    selected = {p.name: p for p in original.iterdir() if p.is_file()}
    for name in sorted(required - selected.keys()):
        candidates = sorted(original.parent.rglob(name))
        if not candidates: raise ValueError('Unresolved source texture: ' + name)
        digests = {sha(p) for p in candidates}
        if len(digests) != 1: raise ValueError('Conflicting sibling source texture: ' + name)
        selected[name] = candidates[0]
    evidence = {}
    for name, source in selected.items():
        target = directory / name
        if target.is_symlink():
            if target.resolve() != source.resolve(): raise ValueError('Projection source changed: ' + name)
        elif target.exists():
            raise ValueError('Unexpected regular file in read-only material projection: ' + name)
        else: target.symlink_to(source)
        evidence[name] = {'source': str(source.relative_to(SOURCE)) if source.is_relative_to(SOURCE) else str(source), 'sha256': sha(source)}
    for relative in relative_refs:
        if relative.parent == Path('.'): continue
        source = (original / relative).resolve()
        if not source.is_relative_to(original.parent) or not source.is_file():
            raise ValueError('Invalid explicit relative texture: ' + str(relative))
        target = Path(os.path.abspath(directory / relative))
        if not target.is_relative_to(WORK / 'material-sources'):
            raise ValueError('Texture escapes the material projection')
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink():
            if sha(target) != sha(source): raise ValueError('Conflicting projected texture')
        elif target.exists(): raise ValueError('Unexpected projection file')
        else: target.symlink_to(source)
        evidence[str(relative)] = {'source': str(source.relative_to(SOURCE)) if source.is_relative_to(SOURCE) else str(source), 'sha256': sha(source)}
    write(directory / 'source-pins.json', evidence)
    write(directory / 'scene-environment.json', {'source_local_reflection_probes':sorted(scene_reflection_probes),
        'binding':'Battle arena reflection environment; native model detail maps retained'})
    if row.get('material_selector'):
        from alternate_forms_palettes import project
        directory = project(row,directory)
    # Only the material table path changes. Motion files remain the pinned originals.
    files = [dict(r) for r in row['scvi_files']]
    for item in files:
        if item['path'].endswith(resource + '.trmtr'):
            item['path'] = str(directory / (resource + '.trmtr'))
    document, _ = chunks(WORK / 'export' / row['species'] / 'model.glb')
    meshes = {n['name'] for n in document['nodes'] if 'mesh' in n}
    aliases = {}
    # The female Oinkologne TRACM uses a different spelling from its TRMSH.
    # Bind this one explicit spelling only after checking the source shape table.
    if resource == 'pm1020_01_00':
        shape_file = original / (resource + '.trmsh')
        raw = Buffer(shape_file.read_bytes())
        shapes = {raw.string(t, 0) for t in raw.tables(raw.number(0), 1)}
        target = resource + '_body_mesh_shape'
        assert target in shapes and mesh_name(target) in meshes
        aliases[resource + '_body_meshShape'] = mesh_name(target)
    def name(target):
        lod = re.fullmatch(r'(.+)_shape_lod([1-9])',target)
        if lod and lod[1] in meshes:
            return lod[1]+'_lod'+lod[2]
        return aliases[target] if target in aliases else mesh_name(target)
    excluded = set()
    absent_lods = set()
    for motion in row['selected_motion_files']:
        if not motion['path'].endswith('.tracm'): continue
        tracks = inspect_visibility(SOURCE / motion['path'])
        assert meshes <= {name(t['target']) for t in tracks}
        for track in tracks:
            if name(track['target']) in meshes: continue
            lod = re.fullmatch(r'(.+)_shape_lod([1-9])',track['target'])
            if lod and lod[1] in meshes:
                # The pinned importer selects the highest-detail mesh table.
                # Lower detail alternatives do not exist in this exported scene.
                excluded.add(track['target']);absent_lods.add(track['target']);continue
            match = re.match(r'(pm\d{4}_\d{2}_\d{2})_', track['target'])
            if not match or match[1] == resource or match[1][:6] != resource[:6] or not (original.parent / match[1]).is_dir():
                raise ValueError('Unexplained extra visibility target: ' + track['target'])
            excluded.add(track['target'])
    write(directory / 'visibility-projection.json', {'exported_meshes': sorted(meshes),
        'explicit_source_shape_aliases': aliases,
        'absent_sibling_form_targets': sorted(excluded-absent_lods),
        'absent_lower_detail_targets': sorted(absent_lods),
        'scope': 'Only tracks for absent sibling meshes; every exported mesh retains its own source track'})
    options = {}
    if row['species'].startswith('rotom-'):
        tables = inspect_materials(original/(resource+'.trmtr'))
        effects = [m for m in tables if classify(m).get('requires_effect_payload')]
        assert effects
        # The existing effect exporter independently hashes every TRACM and
        # rejects this declaration if any material has an animated UV track.
        options['static_effect_material_diagnostic'] = [m['name'] for m in effects]
    return {**row, 'scvi_files': files, 'material_profiles': [], 'restore_source_albedo_bindings': True,
            'visibility_target_aliases': aliases, 'effect_review_options': options,
            'preserve_source_static_effects': bool(options),
            'excluded_visibility_targets': sorted(excluded)}
