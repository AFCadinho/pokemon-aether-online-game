"""Read local SCVI resource metadata; bind review inputs to explicit identities.

Resource IDs and internal species IDs are distinct. National-number conversion
is separately pinned to pkNX; it is never inferred from a model directory.
See SCVI_IDENTITY.md for schemas, provenance and coverage limitations.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path, PurePosixPath

POLICY = 'scvi-resource-identity-v1'
SCHEMA_SOURCE = 'https://github.com/pkZukan/PokeDocs/blob/de20b28d82d5d8b473905eb2c24e5d8b47841ca8/SV/Flatbuffers/resources/trpmcatalog.fbs'
NATIONAL_SOURCE = 'https://github.com/kwsch/pkNX/blob/d191cd0e5c05f2af81d9a41c1f1d82e6621b351a/FlatBuffers/SV/Shared/Gen9/SpeciesConverterSV.cs'
# Factual ID offsets from the pinned Gen9 internal-to-national mapping.
NATIONAL_OFFSETS = (
    65, -1, -1, -1, -1, 31, 31, 47, 47, 29, 29, 53, 31,
    31, 46, 44, 30, 30, -7, -7, -7, 13, 13, -2, -2, 23, 23, 24,
    -21, -21, 27, 27, 47, 47, 47, 26, 14, -33, -33, -33, -17, -17, 3,
    -29, 12, -12, -31, -31, -31, 3, 3, -24, -24, -44, -44, -30, -30,
    -28, -28, 23, 23, 6, 7, 29, 8, 3, 4, 4, 20, 4, 23, 6, 3,
    3, 4, -1, 13, 9, 7, 5, 7, 9, 9, -43, -43, -43, -68, -68, -68,
    -58, -58, -25, -29, -31, 6, -1, 6, 0, 0, 0, 3, 3, 4, 2, 3, 3,
    -5, -12, -12,
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def national_id(internal):
    if not 1 <= internal <= 1025:
        raise ValueError('Internal species outside pinned mapping coverage')
    return internal if internal < 917 else internal + NATIONAL_OFFSETS[internal - 917]


class Buffer:
    """Bounded FlatBuffers subset. Reject malformed pointers and strings."""
    def __init__(self, data):
        self.data = data

    def number(self, offset, fmt='I'):
        size = struct.calcsize('<' + fmt)
        if offset < 0 or offset + size > len(self.data):
            raise ValueError('Catalog offset outside buffer')
        return struct.unpack_from('<' + fmt, self.data, offset)[0]

    def field(self, table, slot):
        v = table - self.number(table, 'i')
        length = self.number(v, 'H')
        if length < 4 or length % 2 or v + length > len(self.data):
            raise ValueError('Invalid catalog vtable')
        if 4 + slot * 2 >= length:
            return None
        delta = self.number(v + 4 + slot * 2, 'H')
        return table + delta if delta else None

    def scalar(self, table, slot, fmt='H'):
        p = self.field(table, slot)
        return self.number(p, fmt) if p is not None else 0

    def pointer(self, table, slot):
        p = self.field(table, slot)
        if p is None:
            raise ValueError('Missing required catalog field')
        target = p + self.number(p)
        self.number(target)
        return target

    def tables(self, table, slot):
        p = self.pointer(table, slot)
        count = self.number(p)
        if count > 10000 or p + 4 + count * 4 > len(self.data):
            raise ValueError('Invalid catalog vector')
        return [p + 4 + i * 4 + self.number(p + 4 + i * 4) for i in range(count)]

    def string(self, table, slot):
        p = self.pointer(table, slot)
        return self.string_value(p)

    def string_value(self, p):
        length = self.number(p)
        if length > 4096 or p + 4 + length >= len(self.data) or self.data[p + 4 + length] != 0:
            raise ValueError('Invalid catalog string')
        return self.data[p + 4:p + 4 + length].decode('utf-8')

    def strings(self, table, slot):
        return [self.string_value(p) for p in self.tables(table, slot)]


def resource_path(value):
    path = PurePosixPath(value)
    if path.is_absolute() or '..' in path.parts or '\\' in value or not re.fullmatch(
            r'pm\d{4}/pm\d{4}_\d{2}_\d{2}/[a-zA-Z0-9_.]+', value):
        raise ValueError('Unsafe or unsupported resource path: ' + value)
    return path


def read_catalog(path):
    data = Path(path).read_bytes()
    b = Buffer(data)
    root = b.number(0)
    version = b.scalar(b.pointer(root, 0), 0, 'I')
    if version != 6:
        raise ValueError('Unreviewed catalog version: ' + str(version))
    rows, keys = [], set()
    for table in b.tables(root, 1):
        info = b.pointer(table, 0)
        internal, form, gender = (b.scalar(info, 0), b.scalar(info, 1), b.scalar(info, 2, 'B'))
        model, material, config, icon = [b.string(table, slot) for slot in (1, 2, 3, 6)]
        model_path = resource_path(model)
        for value in (material, config, icon):
            if resource_path(value).parent != model_path.parent:
                raise ValueError('Cross-identity catalog resource')
        identity = model_path.parent.name
        if model_path.name != identity + '.trmdl' or model_path.parts[0] != identity.split('_')[0]:
            raise ValueError('Inconsistent catalog model path')
        animations = [b.string(t, 1) for t in b.tables(table, 4)]
        if not animations:
            raise ValueError('Missing animation catalog')
        for p in animations:
            resource_path(p)
        # Catalog contains explicit null/egg sentinels, excluded from species lookup.
        if (internal, identity) in ((0, 'pm0000_00_00'), (9999, 'pm9999_00_00')):
            continue
        key = (internal, form, gender)
        if key in keys:
            raise ValueError('Duplicate/ambiguous catalog identity')
        keys.add(key)
        rows.append({'internal_species_id': internal, 'national_dex_id': national_id(internal),
                     'form': form, 'gender_code': gender, 'resource_id': identity,
                     'model_path': model, 'material_table_path': material, 'config_path': config,
                     'animation_catalog_paths': animations, 'icon_path': icon})
    return {'policy': POLICY, 'catalog_path': str(Path(path).resolve()),
            'catalog_sha256': hashlib.sha256(data).hexdigest(), 'catalog_version': version,
            'schema_source': SCHEMA_SOURCE, 'national_mapping_source': NATIONAL_SOURCE, 'entries': rows}


def resolve(catalog, species, dex, form=0, gender=0):
    matches = [r for r in catalog['entries'] if (r['national_dex_id'], r['form'], r['gender_code']) == (dex, form, gender)]
    if len(matches) != 1:
        raise ValueError('Identity absent or ambiguous in supplied catalog: ' + species)
    return {**matches[0], 'species': species, 'variant': 'normal'}


def animation_resources(directory, identity):
    """Read extracted TRACN -> TRACR references, including named base bundles."""
    files, tracks = {}, set()
    bundles = sorted(directory.glob(identity + '*.tracn'))
    if not bundles:
        raise ValueError('No extracted animation catalog for resource')
    for path in bundles:
        b = Buffer(path.read_bytes())
        files[str(path)] = sha(path)
        for t in b.tables(b.number(0), 0):
            filename = b.string(t, 1)
            if Path(filename).name != filename or not filename.startswith(identity + '_'):
                raise ValueError('Cross-resource animation bundle reference')
            if not filename.endswith('.tracr'):
                continue
            resource = directory / filename
            r = Buffer(resource.read_bytes())
            files[str(resource)] = sha(resource)
            for track in r.tables(r.pointer(r.number(0), 0), 0):
                resources = r.pointer(track, 3)
                for slot in (0, 1):
                    if r.field(resources, slot) is None:
                        continue
                    name = r.string(r.pointer(resources, slot), 0)
                    if Path(name).name != name or not name.startswith(identity + '_'):
                        raise ValueError('Cross-resource animation track reference')
                    tracks.add(str(directory / name))
    if not tracks:
        raise ValueError('Animation resource catalog has no tracks')
    return files, tracks


def bind(entry, identity, catalog, model_root, motion_root, species_path):
    """Check selected model/materials against the catalog's ROMFS resource tree."""
    model_root, motion_root = Path(model_root).resolve(), Path(motion_root).resolve()
    if sum(r['model_path'] == identity['model_path'] for r in catalog['entries']) != 1:
        raise ValueError('Shared form resource needs material/variant selector review')
    if any(PurePosixPath(p).parent != PurePosixPath(identity['model_path']).parent
           for p in identity['animation_catalog_paths']):
        raise ValueError('Cross-form animation catalogs need selector review')
    model_dir = model_root / PurePosixPath(identity['model_path']).parent
    motion_dir = motion_root / PurePosixPath(identity['model_path']).parent
    if Path(entry['model_dir']).resolve() != model_dir or Path(entry['motion_dir']).resolve() != motion_dir:
        raise ValueError('Selected model/motion directory differs from catalog')
    rid = identity['resource_id']
    if entry['identity'] != rid:
        raise ValueError('Resource identity differs from selection')
    model = Buffer((model_dir / (rid + '.trmdl')).read_bytes())
    root = model.number(0)
    materials = model.strings(root, 3)
    if materials != [rid + '.trmtr']:
        raise ValueError('Default material reference needs explicit selector review')
    references = [model.string(t, 0) for t in model.tables(root, 1)]
    references += [model.string(model.pointer(root, 2), 0)] + materials
    if any(Path(p).name != p or not p.startswith(rid) or not (model_dir / p).is_file() for p in references):
        raise ValueError('Model references missing or cross-resource mesh/skeleton/material')
    files = {}
    for relative in [identity['model_path'], identity['material_table_path'], identity['config_path']]:
        local, original = model_root / relative, motion_root / relative
        if not local.is_file() or not original.is_file() or sha(local) != sha(original):
            raise ValueError('Model resource differs from catalog ROMFS: ' + relative)
        files[str(local)] = sha(local)
        files[str(original)] = sha(original)
    animation_files, tracks = animation_resources(motion_dir, rid)
    files.update(animation_files)
    # Bind the entire selected source directory, including meshes, skeleton,
    # material definitions and texture assets, to the review evidence.
    for p in sorted(model_dir.iterdir()):
        if p.is_file():
            files[str(p)] = sha(p)
            if p.suffix in ('.trskl', '.trmsh', '.trmbf', '.trmtr'):
                original = motion_dir / p.name
                if not original.is_file() or sha(original) != files[str(p)]:
                    raise ValueError('Mesh/material/skeleton differs from ROMFS: ' + p.name)
                files[str(original)] = sha(original)
    for p in sorted(motion_dir.glob(rid + '_*')):
        if p.suffix in ('.tranm', '.tracm'):
            files[str(p)] = sha(p)
    for p in [v for v in entry['motions'].values() if v] + [v for v in entry['motion_channels'].values() if v]:
        if str(Path(p).resolve()) not in files or str(Path(p).resolve()) not in tracks:
            raise ValueError('Motion selected outside verified resource')
    return {'policy': POLICY, 'status': 'verified', 'identity': identity,
            'catalog_path': catalog['catalog_path'], 'catalog_sha256': catalog['catalog_sha256'],
            'species_path': str(Path(species_path).resolve()), 'species_sha256': sha(species_path),
            'source_sha256': files, 'model_root': str(model_root), 'motion_root': str(motion_root),
            'runtime_approved': False}


def validate_entry(entry):
    proof = entry.get('identity_evidence', {})
    if proof.get('policy') != POLICY or proof.get('status') != 'verified':
        raise ValueError('SCVI import requires verified identity evidence')
    if sha(proof['catalog_path']) != proof['catalog_sha256'] or sha(proof['species_path']) != proof['species_sha256']:
        raise ValueError('Identity metadata changed since inventory')
    identity = proof['identity']
    species = json.loads(Path(proof['species_path']).read_text())
    if entry['species'] != identity['species'] or species['species_id'] != entry['species'] or species['id'] != identity['national_dex_id']:
        raise ValueError('Species name/number differs from identity evidence')
    catalog = read_catalog(proof['catalog_path'])
    actual = resolve(catalog, entry['species'], species['id'], identity['form'], identity['gender_code'])
    if actual != identity:
        raise ValueError('Claimed identity differs from catalog')
    if entry.get('form', 0) != identity['form'] or entry.get('gender_code', 0) != identity['gender_code']:
        raise ValueError('Form/gender selection differs from identity evidence')
    if entry.get('pm') != int(identity['resource_id'][2:6]):
        raise ValueError('Model resource number differs from identity evidence')
    if entry.get('variant', 'normal') != 'normal':
        raise ValueError('Variant requires separate identity verification')
    if species.get('catch_rate_source', {}).get('pokemon_species', entry['species']) != entry['species'] and 'form' not in entry:
        raise ValueError('Named form requires an explicit catalog form selection')
    rebound = bind(entry, actual, catalog, proof['model_root'], proof['motion_root'], proof['species_path'])
    if rebound != proof:
        raise ValueError('Source evidence changed since inventory')
    return proof


def validate_prepared_source(source, imported):
    source = Path(source)
    expected = imported.get('prepared_sha256')
    if expected is None:
        # Read-only migration for existing reviewed imports. Never bless the
        # current bytes as a new baseline when an older digest is missing.
        prior = source.parents[3] / 'review' / imported['species'] / 'review.json'
        if not prior.is_file():
            raise ValueError('Prepared model has no recorded import/review hash; reimport')
        review = json.loads(prior.read_text())
        if review.get('species') != imported['species']:
            raise ValueError('Prior source review identity differs')
        expected = review.get('source_sha256')
    if sha(source) != expected:
        raise ValueError('Prepared model changed since import/review')


def validate_export_job(job):
    """Require a source import bound to the same reviewed identity and clips."""
    entry = job.get('identity_intake', {})
    validate_entry(entry)
    source = Path(job['source'])
    imported = json.loads(source.with_name('import.json').read_text())
    validate_prepared_source(source, imported)
    if (imported.get('species'), imported.get('identity'), imported.get('variant')) != (
            entry['species'], entry['identity'], 'normal'):
        raise ValueError('Imported species/form/variant differs from verified intake')
    if source.name != entry['identity'] + '-ready.blend' or sha(source) != job['source_sha256']:
        raise ValueError('Prepared model differs from verified source')
    expected = {name: Path(p).stem if p else None for name, p in entry['motions'].items()}
    actual = {name: a['name'] if a else None for name, a in imported['actions'].items()}
    if actual != expected or any(expected.get(name) != value for name, value in job['actions'].items()):
        raise ValueError('Prepared animation mapping differs from identity evidence')
    if job.get('effect_motion_dir') != entry['motion_dir'] or job['material_source'] != str(Path(entry['model_dir']) / (entry['identity'] + '.trmtr')):
        raise ValueError('Export materials/motions differ from verified identity')
    if not imported.get('source_files'):
        raise ValueError('Imported source provenance missing')
    for p, expected_hash in imported['source_files'].items():
        if sha(p) != expected_hash:
            raise ValueError('Imported source changed')
        if entry['identity_evidence']['source_sha256'].get(str(Path(p).resolve())) != expected_hash:
            raise ValueError('Imported source was not part of verified identity evidence')
    return entry['identity_evidence']


def export_read_paths(job):
    """Flatpak read grants for identity proof; source files stay read-only."""
    proof = job['identity_intake']['identity_evidence']
    paths = [proof['model_root'], proof['motion_root'], proof['catalog_path'], proof['species_path']]
    source = Path(job['source'])
    previous = source.parents[3] / 'review' / job['identity_intake']['species'] / 'review.json'
    if previous.is_file():
        paths.append(str(previous))
    return paths


def build_inventory(batch, catalog_path, model_root, motion_root, species_root):
    from scvi_batch import load_batch, source_entry
    catalog = read_catalog(catalog_path)
    rows = []
    for requested in load_batch(Path(batch)):
        if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', requested['species']):
            raise ValueError('Invalid species slug')
        row = {**requested, 'requested_pm': requested.get('pm'), 'review_approved': False,
               'legacy_candidate': None, 'review_route': 'identity_blocked'}
        try:
            if requested.get('variant', 'normal') != 'normal':
                raise ValueError('Variant requires separate identity verification')
            for key in ('form', 'gender_code'):
                if type(requested.get(key, 0)) is not int or requested.get(key, 0) < 0:
                    raise ValueError('Form/gender selectors must be explicit nonnegative integers')
            species_path = Path(species_root) / (requested['species'] + '.json')
            species = json.loads(species_path.read_text())
            if species['species_id'] != requested['species']:
                raise ValueError('Species registry label mismatch')
            if species.get('catch_rate_source', {}).get('pokemon_species', requested['species']) != requested['species'] and 'form' not in requested:
                raise ValueError('Named form requires an explicit catalog form selection')
            identity = resolve(catalog, requested['species'], species['id'], requested.get('form', 0), requested.get('gender_code', 0))
            rid = identity['resource_id']
            selected = {**requested, 'pm': int(rid[2:6]), 'resource_id': rid}
            row.update(source_entry(selected, Path(model_root), Path(motion_root)))
            proof = bind(row, identity, catalog, model_root, motion_root, species_path)
            row.update(identity_evidence=proof, review_route='scvi_candidate')
        except (ValueError, OSError, KeyError) as error:
            row['identity_error'] = str(error)
            row['review_route'] = 'identity_blocked'
        rows.append(row)
    return {'schema': 1, 'purpose': POLICY, 'runtime_approved': False,
            'catalog_sha256': catalog['catalog_sha256'], 'entries': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('batch', 'catalog', 'model-root', 'motion-root', 'species-root', 'output'):
        parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args()
    report = build_inventory(args.batch, args.catalog, args.model_root, args.motion_root, args.species_root)
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'inventory.json').write_text(json.dumps(report, indent=2) + '\n')
    for row in report['entries']:
        print(row['species'], row['review_route'], row.get('identity', ''), row.get('identity_error', ''))


if __name__ == '__main__':
    main()
