"""Resolve visibility target membership from catalog and source mesh tables."""
from pathlib import Path
import hashlib

from scvi_identity import Buffer, read_catalog


def binding(intake, exported_meshes, targets):
    proof = intake['identity_evidence']
    catalog = read_catalog(proof['catalog_path'])
    if catalog['catalog_sha256'] != proof['catalog_sha256']:
        raise ValueError('Visibility catalog hash changed')
    identity = proof['identity']
    selected = [r for r in catalog['entries'] if r['resource_id'] == intake['identity']]
    if len(selected) != 1 or any(selected[0][k] != identity.get(k) for k in selected[0]):
        raise ValueError('Visibility selected catalog identity differs')
    selected = selected[0]
    model_root, romfs_root = Path(proof['model_root']), Path(proof['motion_root'])
    if Path(intake['model_dir']).resolve() != (model_root / selected['model_path']).parent.resolve():
        raise ValueError('Visibility selected model directory differs')
    files = {proof['catalog_path']: proof['catalog_sha256']}

    def resource_shapes(row, require_previous_hash):
        def read(relative):
            paths = [model_root / relative, romfs_root / relative]
            payloads = [p.read_bytes() for p in paths]
            if payloads[0] != payloads[1]:
                raise ValueError('Visibility model metadata differs from ROMFS')
            digest = hashlib.sha256(payloads[0]).hexdigest()
            if require_previous_hash and proof['source_sha256'].get(str(paths[0])) != digest:
                raise ValueError('Visibility selected model metadata hash changed')
            files.update({str(p): digest for p in paths})
            return payloads[0]

        model_path = Path(row['model_path'])
        model = Buffer(read(model_path))
        references = model.tables(model.number(0), 1)
        if not references:
            raise ValueError('Visibility model has no mesh resource')
        # The pinned importer selects TRMDL.Meshes(0) with loadlods=False.
        filename = model.string(references[0], 0)
        if Path(filename).name != filename or not filename.endswith('.trmsh'):
            raise ValueError('Unsafe visibility mesh reference')
        mesh = Buffer(read(model_path.parent / filename))
        shapes = [mesh.string(t, 0) for t in mesh.tables(mesh.number(0), 1)]
        if not shapes or len(shapes) != len(set(shapes)) or any(not s.endswith('_shape') for s in shapes):
            raise ValueError('Ambiguous or unsupported source shape names')
        return set(shapes)

    active = resource_shapes(selected, True)
    if sorted(s.removesuffix('_shape') for s in active) != sorted(exported_meshes):
        raise ValueError('Exported meshes differ from selected source variant')
    extra = set(targets) - active
    owners = {target: [] for target in extra}
    if extra:
        siblings = [r for r in catalog['entries']
                    if r['internal_species_id'] == selected['internal_species_id']
                    and r['form'] == selected['form']
                    and r['gender_code'] != selected['gender_code']]
        for sibling in siblings:
            for target in resource_shapes(sibling, False) & extra:
                owners[target].append({'resource_id': sibling['resource_id'],
                                       'gender_code': sibling['gender_code']})
    if any(len(owner) != 1 for owner in owners.values()):
        raise ValueError('Unknown or ambiguous visibility variant target')
    return {'policy': 'catalog-gender-mesh-membership-v1',
            'selected_resource_id': selected['resource_id'],
            'active_targets': sorted(active),
            'excluded_targets': {t: owners[t][0] for t in sorted(owners)},
            'source_sha256': files}


def verify(binding_record):
    for path, digest in binding_record['source_sha256'].items():
        if hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest:
            raise ValueError('Visibility variant metadata changed during export')
