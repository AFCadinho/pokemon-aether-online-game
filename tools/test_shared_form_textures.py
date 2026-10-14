"""Adversarial checks for the narrowly scoped native external-path writer."""
import struct
import unittest

from study_shared_form_textures import rebind_external_paths


def string(value):
    data = value.encode()+b'\0'
    return struct.pack('<I', len(data))+data


def fixture(uid=2**64-1):
    old = 'res://pokemon-pairs/'+'a'*64+'/textures/'+'b'*64+'.res'
    new = 'res://pokemon-pairs/'+'c'*64+'/textures/'+'d'*64+'.res'
    header = struct.pack('<5I', 0, 0, 4, 6, 6)+string('PackedScene')
    header += struct.pack('<QI Q11I', 0, 3, 2**64-1, *([0]*11))
    header += struct.pack('<I', 1)+string('_bundled')
    header += struct.pack('<I', 1)+string('Texture2D')+string(old)+struct.pack('<Q', uid)
    table = struct.pack('<I', 1)+string('local://PackedScene_test')
    # Metadata/body contains a lookalike path, which must remain unchanged.
    body = string('PackedScene')+b'opaque-body-metadata:'+old.encode()+b'RSRC'
    raw = header+table+struct.pack('<Q', len(header)+len(table)+8)+body
    return raw, old, new, body


class ExternalPathChecks(unittest.TestCase):
    def test_actual_external_path_only_and_body_exact(self):
        raw, old, new, body = fixture()
        result, evidence = rebind_external_paths(raw, {old:new})
        self.assertEqual(len(result), len(raw))
        self.assertTrue(result.endswith(body))
        self.assertEqual(result.count(new.encode()), 1)
        self.assertEqual(result.count(old.encode()), 1)  # Lookalike stays in body.
        self.assertTrue(evidence['body_exact'])
        self.assertEqual(evidence['external_paths'], 1)

    def test_uid_cannot_override_explicit_pool_binding(self):
        raw, old, new, _ = fixture(uid=42)
        with self.assertRaisesRegex(ValueError, 'External UID'): rebind_external_paths(raw, {old:new})

    def test_unbound_or_wider_path_fails_closed(self):
        raw, old, new, _ = fixture()
        with self.assertRaisesRegex(ValueError, 'Unbound external'): rebind_external_paths(raw, {})
        with self.assertRaisesRegex(ValueError, 'length changed'): rebind_external_paths(raw, {old:new+'x'})

    def test_unknown_version_truncation_and_bad_offsets_rejected(self):
        raw, old, new, body = fixture()
        changed = bytearray(raw); struct.pack_into('<I', changed, 16, 7)
        with self.assertRaisesRegex(ValueError, 'version'): rebind_external_paths(bytes(changed), {old:new})
        with self.assertRaises(ValueError): rebind_external_paths(raw[:70], {old:new})
        changed = bytearray(raw); struct.pack_into('<Q', changed, len(raw)-len(body)-8, len(raw)+100)
        with self.assertRaisesRegex(ValueError, 'offsets'): rebind_external_paths(bytes(changed), {old:new})


if __name__ == '__main__': unittest.main()
