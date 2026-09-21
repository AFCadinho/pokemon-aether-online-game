import copy
import json
import struct
import tempfile
import unittest
from pathlib import Path

from scvi_identity import (Buffer, bind, build_inventory, national_id, read_catalog,
                           resolve, sha, validate_entry, validate_export_job, validate_prepared_source)


class Fixture:
    """Tiny forward-built FlatBuffers fixtures, independent of production reader."""
    def __init__(self):
        self.data = bytearray(4)

    def put(self, p, value, fmt='I'):
        struct.pack_into('<' + fmt, self.data, p, value)

    def align(self):
        self.data += b'\0' * (-len(self.data) % 4)

    def table(self, count, present=None):
        self.align()
        v = len(self.data)
        present = set(range(count)) if present is None else set(present)
        self.data += struct.pack('<HH', 4 + count * 2, 4 + count * 4)
        self.data += b''.join(struct.pack('<H', 4 + i * 4 if i in present else 0) for i in range(count))
        self.align()
        t = len(self.data)
        self.data += struct.pack('<i', t - v) + bytes(count * 4)
        return t

    def field(self, t, slot):
        return t + 4 + slot * 4

    def pointer(self, p, target):
        self.put(p, target - p)

    def string(self, p, text):
        self.align()
        target = len(self.data)
        data = text.encode()
        self.data += struct.pack('<I', len(data)) + data + b'\0'
        self.pointer(p, target)

    def vector(self, p, count):
        self.align()
        t = len(self.data)
        self.data += struct.pack('<I', count) + bytes(count * 4)
        self.pointer(p, t)
        return [t + 4 + 4 * i for i in range(count)]

    def finish(self, root):
        self.put(0, root)
        return bytes(self.data)


def catalog_fixture(rows):
    f = Fixture()
    root = f.table(2)
    version = f.table(1)
    f.put(f.field(version, 0), 6)
    f.pointer(f.field(root, 0), version)
    for pointer, (internal, form, gender, rid) in zip(f.vector(f.field(root, 1), len(rows)), rows):
        t = f.table(7)
        f.pointer(pointer, t)
        info = f.table(3)
        f.pointer(f.field(t, 0), info)
        for slot, value in enumerate((internal, form, gender)):
            f.put(f.field(info, slot), value)
        prefix = rid[:6] + '/' + rid + '/' + rid
        for slot, suffix in [(1, '.trmdl'), (2, '.trmmt'), (3, '.trpokecfg'), (6, '_00.bntx')]:
            f.string(f.field(t, slot), prefix + suffix)
        p = f.vector(f.field(t, 4), 1)[0]
        a = f.table(2)
        f.pointer(p, a)
        f.string(f.field(a, 1), prefix + '.tracn')
    return f.finish(root)


def animation_fixture(directory, rid):
    name = rid + '_00001_battlewait01_loop.tranm'
    material = name.replace('.tranm', '.tracm')
    f = Fixture()
    root = f.table(1)
    p = f.vector(f.field(root, 0), 1)[0]
    e = f.table(2)
    f.pointer(p, e)
    f.string(f.field(e, 0), 'resource')
    f.string(f.field(e, 1), rid + '_base.tracr')
    (directory / (rid + '_base.tracn')).write_bytes(f.finish(root))
    f = Fixture()
    root = f.table(1)
    tracks = f.table(1)
    f.pointer(f.field(root, 0), tracks)
    p = f.vector(f.field(tracks, 0), 1)[0]
    track = f.table(4)
    f.pointer(p, track)
    resources = f.table(2)
    f.pointer(f.field(track, 3), resources)
    for slot, value in enumerate((name, material)):
        item = f.table(1)
        f.pointer(f.field(resources, slot), item)
        f.string(f.field(item, 0), value)
    (directory / (rid + '_base.tracr')).write_bytes(f.finish(root))
    (directory / name).write_bytes(b'animation')
    (directory / material).write_bytes(b'material channel')


def model_fixture(rid):
    f = Fixture()
    root = f.table(4, [1, 2, 3])
    p = f.vector(f.field(root, 1), 1)[0]
    mesh = f.table(1)
    f.pointer(p, mesh)
    f.string(f.field(mesh, 0), rid + '.trmsh')
    skeleton = f.table(1)
    f.pointer(f.field(root, 2), skeleton)
    f.string(f.field(skeleton, 0), rid + '.trskl')
    p = f.vector(f.field(root, 3), 1)[0]
    f.string(p, rid + '.trmtr')
    return f.finish(root)


class IdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog = self.root / 'resource.trpmcatalog'
        self.catalog.write_bytes(catalog_fixture([(747, 0, 0, 'pm0801_00_00')]))

    def test_catalog_maps_resource_to_species_and_preserves_form_gender(self):
        self.catalog.write_bytes(catalog_fixture([(747, 0, 0, 'pm0801_00_00'), (25, 9, 1, 'pm0025_18_00')]))
        rows = read_catalog(self.catalog)['entries']
        self.assertEqual(747, rows[0]['national_dex_id'])
        self.assertEqual('pm0801_00_00', rows[0]['resource_id'])
        self.assertEqual((9, 1), (rows[1]['form'], rows[1]['gender_code']))

    def test_national_mapping_is_bijective_and_controls_are_known(self):
        self.assertEqual(set(range(1, 1026)), {national_id(i) for i in range(1, 1026)})
        self.assertEqual(1005, national_id(985))
        self.assertEqual(937, national_id(1005))
        self.assertEqual(1024, national_id(1021))
        for number in (0, 1026, 9999):
            with self.assertRaises(ValueError):
                national_id(number)

    def test_missing_and_duplicate_identity_fail(self):
        with self.assertRaisesRegex(ValueError, 'absent'):
            resolve(read_catalog(self.catalog), 'magearna', 801)
        self.catalog.write_bytes(catalog_fixture([(747, 0, 0, 'pm0801_00_00')] * 2))
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            read_catalog(self.catalog)

    def test_malformed_buffers_and_paths_fail(self):
        payload = self.catalog.read_bytes()
        for data in (b'', b'\xff' * 12, payload[:24], payload[:-1]):
            self.catalog.write_bytes(data)
            with self.assertRaises((ValueError, UnicodeError)):
                read_catalog(self.catalog)
        from scvi_identity import resource_path
        for path in ('/etc/passwd', '../source', 'pm0801/../../x', 'pm0801\\pm0801_00_00/x'):
            with self.assertRaises(ValueError):
                resource_path(path)

    def inventory(self):
        rid = 'pm0801_00_00'
        self.models, self.motions = self.root / 'models', self.root / 'motions'
        for base in (self.models, self.motions):
            folder = base / 'pm0801' / rid
            folder.mkdir(parents=True)
            for suffix in ('.trmsh', '.trmmt', '.trpokecfg', '.trmtr', '.trskl'):
                (folder / (rid + suffix)).write_bytes(b'fixture' + suffix.encode())
            (folder / (rid + '.trmdl')).write_bytes(model_fixture(rid))
        animation_fixture(self.motions / 'pm0801' / rid, rid)
        self.species = self.root / 'species'
        self.species.mkdir()
        (self.species / 'mareanie.json').write_text(json.dumps({'id': 747, 'species_id': 'mareanie'}))
        batch = self.root / 'batch.json'
        batch.write_text(json.dumps({'entries': [{'species': 'mareanie', 'pm': 747}]}))
        return build_inventory(batch, self.catalog, self.models, self.motions, self.species)['entries'][0]

    def test_inventory_corrects_requested_resource_from_metadata(self):
        row = self.inventory()
        self.assertEqual('scvi_candidate', row['review_route'])
        self.assertEqual(747, row['requested_pm'])
        self.assertEqual(801, row['pm'])
        self.assertEqual('verified', validate_entry(row)['status'])
        self.assertFalse(row['review_approved'])

    def test_stale_and_relabelled_proof_fail(self):
        row = self.inventory()
        for key, value in [('species', 'magearna'), ('form', 9), ('gender_code', 1),
                           ('identity', 'pm0747_00_00'), ('pm', 747), ('variant', 'shiny')]:
            edited = {**row, key: value}
            with self.assertRaises(ValueError):
                validate_entry(edited)
        with self.assertRaises(ValueError):
            validate_entry({})
        (Path(row['model_dir']) / (row['identity'] + '.trmdl')).write_bytes(b'changed')
        with self.assertRaises(ValueError):
            validate_entry(row)

    def test_external_motion_and_registry_change_fail(self):
        row = self.inventory()
        edited = copy.deepcopy(row)
        edited['motions']['idle'] = str(self.root / 'another_species.tranm')
        with self.assertRaises(ValueError):
            validate_entry(edited)
        (self.species / 'mareanie.json').write_text(json.dumps({'id': 801, 'species_id': 'mareanie'}))
        with self.assertRaisesRegex(ValueError, 'metadata changed'):
            validate_entry(row)

    def test_shared_form_resource_is_not_implicitly_approved(self):
        row = self.inventory()
        self.catalog.write_bytes(catalog_fixture([(747, 0, 0, 'pm0801_00_00'), (747, 1, 0, 'pm0801_00_00')]))
        catalog = read_catalog(self.catalog)
        identity = resolve(catalog, 'mareanie', 747)
        with self.assertRaisesRegex(ValueError, 'Shared form'):
            bind(row, identity, catalog, self.models, self.motions, self.species / 'mareanie.json')

    def test_export_requires_identity_before_opening_model(self):
        with self.assertRaisesRegex(ValueError, 'verified identity'):
            validate_export_job({'source': 'untrusted.blend'})

    def test_export_checks_prepared_identity_actions_and_source(self):
        row = self.inventory()
        source = self.root / (row['identity'] + '-ready.blend')
        source.write_bytes(b'prepared fixture')
        actions = {k: {'name': Path(p).stem} if p else None for k, p in row['motions'].items()}
        imported = {'species': row['species'], 'identity': row['identity'], 'variant': 'normal',
                    'prepared_sha256': sha(source),
                    'actions': actions, 'source_files': row['identity_evidence']['source_sha256']}
        source.with_name('import.json').write_text(json.dumps(imported))
        job = {'identity_intake': row, 'source': str(source), 'source_sha256': sha(source),
               'actions': {'idle': actions['idle']['name']}, 'effect_motion_dir': row['motion_dir'],
               'material_source': str(Path(row['model_dir']) / (row['identity'] + '.trmtr'))}
        self.assertEqual('verified', validate_export_job(job)['status'])
        for key, value in [('actions', {'idle': 'foreign_idle'}), ('material_source', '/other.trmtr'),
                           ('effect_motion_dir', '/other')]:
            with self.assertRaises(ValueError):
                validate_export_job({**job, key: value})
        imported['species'] = 'magearna'
        source.with_name('import.json').write_text(json.dumps(imported))
        with self.assertRaisesRegex(ValueError, 'species/form/variant'):
            validate_export_job(job)

    def test_cached_prepared_bytes_cannot_be_silently_rebaselined(self):
        source = self.root / 'sources/mareanie/normal/pm0801_00_00-ready.blend'
        source.parent.mkdir(parents=True)
        source.write_bytes(b'original prepared source')
        imported = {'species': 'mareanie'}
        with self.assertRaisesRegex(ValueError, 'no recorded'):
            validate_prepared_source(source, imported)
        prior = self.root / 'review/mareanie/review.json'
        prior.parent.mkdir(parents=True)
        prior.write_text(json.dumps({'species': 'mareanie', 'source_sha256': sha(source)}))
        validate_prepared_source(source, imported)
        source.write_bytes(b'replaced model with matching filename')
        with self.assertRaisesRegex(ValueError, 'changed since'):
            validate_prepared_source(source, imported)


if __name__ == '__main__':
    unittest.main()
