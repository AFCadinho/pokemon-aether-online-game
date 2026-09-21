from copy import deepcopy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from phase5_runtime_admission import build


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog = self.root / 'catalog.json'
        self.qualification = self.root / 'qualified.json'
        self.entries, self.grounding = [], {}
        for key in ('pikachu', 'pikachu@shiny'):
            scene = self.root / (key + '.scn')
            scene.write_bytes(key.encode())
            digest = hashlib.sha256(scene.read_bytes()).hexdigest()
            self.entries.append(dict(species=key, runtime_path=str(scene), runtime_sha256=digest,
                placement={'scale': 1}, action_timing={'idle': 1}, glb_sha256='a' * 64,
                _review_motion={'sha256': digest, 'clips': {'idle': {}}}, _review_bounds={}))
            self.grounding[key] = {'sha256': digest, 'lift': 0}
        self.save()

    def save(self):
        self.catalog.write_text(json.dumps(self.entries))
        Path(str(self.catalog) + '.grounding.json').write_text(json.dumps({'entries': self.grounding}))
        self.qualification.write_text(json.dumps(dict(phase5c_complete=True,
            qualified_candidate_species=['pikachu'],
            evidence_sha256={'catalog': hashlib.sha256(self.catalog.read_bytes()).hexdigest()})))

    def test_separate_registry_and_selectable_catalog(self):
        registry, catalog = build(self.catalog, self.qualification)
        self.assertEqual(set(registry['models']), {'pikachu', 'pikachu@shiny'})
        self.assertEqual(len(registry['profiles']), 1)
        self.assertNotIn(str(self.root), json.dumps(registry))
        self.assertEqual([e['variant'] for e in catalog], ['normal', 'shiny'])
        self.assertTrue(all(e['species'] == 'pikachu' for e in catalog))
        self.assertNotIn('_review_', json.dumps(catalog))

    def test_unqualified_or_modified_catalog(self):
        self.catalog.write_text(self.catalog.read_text() + ' ')
        with self.assertRaisesRegex(ValueError, 'qualified artifact'):
            build(self.catalog, self.qualification)
        self.save()
        self.qualification.write_text('{"phase5c_complete": false}')
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            build(self.catalog, self.qualification)

    def test_incomplete_and_duplicate_cohort(self):
        for entries in ([self.entries[0]], [self.entries[0], deepcopy(self.entries[0])]):
            self.entries = entries
            self.save()
            with self.assertRaisesRegex(ValueError, 'Incomplete/duplicate'):
                build(self.catalog, self.qualification)

    def test_stale_runtime(self):
        Path(self.entries[0]['runtime_path']).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'Stale'):
            build(self.catalog, self.qualification)

    def test_stale_grounding_or_motion(self):
        for section in (self.grounding['pikachu'], self.entries[0]['_review_motion']):
            original = section['sha256']
            section['sha256'] = 'b' * 64
            self.save()
            with self.assertRaisesRegex(ValueError, 'Stale'):
                build(self.catalog, self.qualification)
            section['sha256'] = original

    def test_variants_must_share_reviewed_profiles(self):
        self.entries[1]['placement']['scale'] = 2
        self.save()
        with self.assertRaisesRegex(ValueError, 'do not share'):
            build(self.catalog, self.qualification)
