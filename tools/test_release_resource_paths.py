"""Reject redirects and malformed tables while preserving legacy main names."""
import struct
import unittest

from rebind_release_resource_paths import rebind_release_paths
from test_shared_form_textures import fixture, string


def internal_name(name):
    raw, old, new, body = fixture()
    start = raw.index(string('local://PackedScene_test'))
    header = raw[:start]
    return header + string(name) + struct.pack('<Q', len(header) + len(string(name)) + 8) + body, old, new, body


class ReleasePathChecks(unittest.TestCase):
    def test_historical_absolute_main_name_is_preserved(self):
        name = '/tmp/retained/arceus-bug.scn'
        raw, old, new, body = internal_name(name)
        result, proof = rebind_release_paths(raw, {old: new}, old.rsplit('/textures/', 1)[0], new.rsplit('/textures/', 1)[0])
        self.assertTrue(result.endswith(body))
        self.assertIn(string(name), result)
        self.assertTrue(proof['body_exact'])

    def test_namespace_internal_name_is_rebound_without_body_changes(self):
        oldroot = 'res://pokemon-pairs/' + 'a' * 64
        newroot = 'res://pokemon-pairs/' + 'c' * 64
        raw, old, new, body = internal_name(oldroot + '/models/normal.scn')
        result, proof = rebind_release_paths(raw, {old: new}, oldroot, newroot)
        self.assertIn(string(newroot + '/models/normal.scn'), result)
        self.assertTrue(result.endswith(body) and proof['body_exact'])

    def test_foreign_namespace_traversal_and_non_scene_main_rejected(self):
        for name in ['res://foreign/models/normal.scn', '/tmp/../normal.scn', '/tmp/redirect.res']:
            raw, old, new, _ = internal_name(name)
            with self.assertRaises(ValueError):
                rebind_release_paths(raw, {old: new}, old.rsplit('/textures/', 1)[0], new.rsplit('/textures/', 1)[0])

    def test_external_uid_and_missing_binding_still_fail_closed(self):
        raw, old, new, _ = fixture(uid=42)
        with self.assertRaisesRegex(ValueError, 'External UID'):
            rebind_release_paths(raw, {old: new}, old.rsplit('/textures/', 1)[0], new.rsplit('/textures/', 1)[0])
        raw, old, new, _ = fixture()
        with self.assertRaisesRegex(ValueError, 'Unbound external'):
            rebind_release_paths(raw, {}, old.rsplit('/textures/', 1)[0], new.rsplit('/textures/', 1)[0])


if __name__ == '__main__':
    unittest.main()
