#!/usr/bin/env python3
"""Destructive-boundary tests for exact v11 retirement and recoverable backups."""
import copy
import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

import retire_v11_model_objects as tool


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.old = tool.read(tool.ROOT / 'release/approved_3d_bundles_v11.json')
        self.current = tool.read(tool.ROOT / 'release/approved_3d_bundles_v13.json')

    def test_only_old_exclusive_payloads_and_exact_saving(self):
        rows = tool.selection(self.old, self.current)
        self.assertEqual(len(rows), 1145)
        self.assertEqual(sum(row['size_bytes'] for row in rows), 12_716_839_877)
        self.assertFalse({row['object_key'] for row in rows}
                         & {row['object_key'] for row in self.current['bundles']})
        self.assertEqual(len(self.old['bundles']) - len(rows), 55)

    def test_changed_key_and_duplicate_inventories_refused(self):
        for mode in ('traversal', 'unowned', 'wrong_hash', 'duplicate'):
            old = copy.deepcopy(self.old)
            if mode == 'duplicate':
                old['bundles'].append(old['bundles'][0])
            else:
                old['bundles'][0]['object_key'] = {
                    'traversal': '../outside.zip', 'unowned': 'game/old-linux.zip',
                    'wrong_hash': old['bundles'][0]['object_key'].replace(old['bundles'][0]['sha256'], '0' * 64),
                }[mode]
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                tool.selection(old, self.current)
        current = copy.deepcopy(self.current)
        current['bundles'].append(current['bundles'][0])
        with self.assertRaises(ValueError):
            tool.selection(self.old, current)


class BackupTest(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        data = b'original verified bytes'
        digest = hashlib.sha256(data).hexdigest()
        self.old = {'revision': 'approved-pokemon-3d-v11', 'bundles': [
            {'asset_id': 'pokemon_3d:test:base', 'object_key': 'optional-assets/pokemon_3d/test/base/v2-' + digest + '.zip',
             'sha256': digest, 'size_bytes': len(data)}],
            'index': {'object_key': 'optional-assets/pokemon_3d/index/test.json',
                      'sha256': digest, 'size_bytes': len(data)}}
        for row in tool.backup_rows(self.old):
            path = self.root / row['backup_path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        tool.write_json(self.root / 'backup-manifest.json',
                        {'revision': self.old['revision'], 'objects': tool.backup_rows(self.old)})
        tool.write_json(self.root / 'legacy-release.json', self.old)
        tool.write_json(self.root / 'restore-archives-report.json', {'assets': [
            {'candidate_asset': row, 'candidate_archive': str(self.root / 'objects' / row['object_key'])}
            for row in self.old['bundles']]})

    def test_complete_backup_can_be_rehashed(self):
        self.assertEqual(tool.verify_backup(self.root, self.old), tool.sha(self.root / 'backup-manifest.json'))

    def test_missing_corrupt_and_linked_objects_refuse_retirement(self):
        path = self.root / tool.backup_rows(self.old)[0]['backup_path']
        original = path.read_bytes()
        for mode in ('missing', 'corrupt', 'link'):
            path.unlink(missing_ok=True)
            if mode == 'corrupt':
                path.write_bytes(b'x' * len(original))
            elif mode == 'link':
                outside = self.root / 'outside.zip'
                outside.write_bytes(original)
                path.symlink_to(outside)
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                tool.verify_backup(self.root, self.old)
        path.unlink(missing_ok=True)
        path.write_bytes(original)

    def test_omitted_inventory_and_wrong_restore_report_refused(self):
        manifest = tool.read(self.root / 'backup-manifest.json')
        manifest['objects'].pop()
        tool.write_json(self.root / 'backup-manifest.json', manifest)
        with self.assertRaises(ValueError):
            tool.verify_backup(self.root, self.old)
        manifest['objects'] = tool.backup_rows(self.old)
        tool.write_json(self.root / 'backup-manifest.json', manifest)
        tool.write_json(self.root / 'restore-archives-report.json', {'assets': []})
        with self.assertRaises(ValueError):
            tool.verify_backup(self.root, self.old)

    def test_atomic_record_does_not_follow_link(self):
        outside = self.root / 'outside'
        outside.write_text('keep')
        (self.root / 'record.json.partial').symlink_to(outside)
        with self.assertRaises(ValueError):
            tool.write_json(self.root / 'record.json', {})
        self.assertEqual(outside.read_text(), 'keep')


class LiveProtectionTest(unittest.TestCase):
    def setUp(self):
        self.current = tool.read(tool.ROOT / 'release/approved_3d_bundles_v13.json')
        self.descriptor = {'revision': self.current['revision'], 'sha256': self.current['index']['sha256'],
                           'sizeBytes': self.current['index']['size_bytes'],
                           'url': tool.BASE + self.current['index']['object_key'],
                           'objectBaseUrl': tool.BASE.rstrip('/'),
                           'requiredAssetIds': [row['asset_id'] for row in self.current['bundles']]}
        self.index = (tool.ROOT / 'release/approved_3d_bundles_v13_index.json').read_bytes()

    def snapshot(self, descriptor):
        def fetch(key):
            if key == self.current['index']['object_key']:
                return self.index
            if key in tool.REQUIRED_MANIFESTS:
                return json.dumps({'assetBundleIndex': descriptor}).encode()
            return None
        with patch.object(tool, 'fetch', side_effect=fetch):
            return tool.live_snapshot(self.current)

    def test_exact_live_pins_pass(self):
        self.assertIsNotNone(self.snapshot(self.descriptor)['manifest-linux.json'])

    def test_changed_revision_digest_key_size_ids_or_missing_descriptor_refused(self):
        for field, value in [('revision', 'approved-pokemon-3d-v11'), ('sha256', '0' * 64),
                             ('url', tool.BASE + 'other-index.json'), ('sizeBytes', 1),
                             ('requiredAssetIds', []), ('objectBaseUrl', 'https://wrong.example')]:
            descriptor = copy.deepcopy(self.descriptor)
            descriptor[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.snapshot(descriptor)
        with self.assertRaises(ValueError):
            self.snapshot(None)

    def test_missing_or_changed_active_payload_inventory_refused(self):
        current = {'bundles': [{'object_key': 'active-pack', 'size_bytes': 20}],
                   'index': {'object_key': 'index', 'size_bytes': 10}}
        for items in [[SimpleNamespace(key='index', size=10)],
                      [SimpleNamespace(key='index', size=10), SimpleNamespace(key='active-pack', size=21)]]:
            with patch.object(tool, '_list_release_objects', return_value=items), self.assertRaises(ValueError):
                tool.inventory('config', current)


class DeleteBoundaryTest(unittest.TestCase):
    def test_only_exact_key_and_confirmed_absence(self):
        request = Mock(side_effect=[(200, '', b''), (204, '', b''), (404, '', b'')])
        with patch.object(tool, '_signed_request', request):
            self.assertEqual(tool.retire_one('config', {'object_key': 'exact-key'})['outcome'], 'deleted')
        self.assertEqual([call.args[1:] for call in request.call_args_list],
                         [('HEAD', 'exact-key'), ('DELETE', 'exact-key'), ('HEAD', 'exact-key')])

    def test_already_absent_and_network_failure_are_not_delete_authority(self):
        for response, outcome in [([(404, '', b'')], 'already_absent'), ([(403, '', b'')], None)]:
            request = Mock(side_effect=response)
            with patch.object(tool, '_signed_request', request):
                if outcome:
                    self.assertEqual(tool.retire_one('config', {'object_key': 'key'})['outcome'], outcome)
                else:
                    with self.assertRaises(ValueError):
                        tool.retire_one('config', {'object_key': 'key'})
            self.assertFalse(any(call.args[1] == 'DELETE' for call in request.call_args_list))

    def test_failed_delete_or_still_present_refused(self):
        for responses in [[(200, '', b''), (500, '', b'')],
                          [(200, '', b''), (204, '', b''), (200, '', b'')]]:
            with patch.object(tool, '_signed_request', side_effect=responses), self.assertRaises(ValueError):
                tool.retire_one('config', {'object_key': 'key'})

    def test_reviewed_plan_and_backup_changes_never_delete(self):
        with TemporaryDirectory() as tmp:
            plan = Path(tmp) / 'plan.json'
            tool.write_json(plan, {'backup_directory': tmp, 'active_manifests': {'old': True}})
            with patch.object(tool, 'retire_one') as delete:
                with self.assertRaises(ValueError):
                    tool.apply_plan('config', plan, Path(tmp) / 'receipt.json', '0' * 64, {}, {}, [])
                with patch.object(tool, 'make_plan', return_value={'active_manifests': {'new': True}}):
                    with self.assertRaises(ValueError):
                        tool.apply_plan('config', plan, Path(tmp) / 'receipt.json', tool.sha(plan), {}, {}, [])
                delete.assert_not_called()

    def test_successes_are_journaled_when_another_delete_fails(self):
        with TemporaryDirectory() as tmp:
            plan = Path(tmp) / 'plan.json'
            receipt = Path(tmp) / 'receipt.json'
            saved = {'backup_directory': tmp, 'active_manifests': {'live': True}}
            tool.write_json(plan, saved)
            def retire(config, row):
                if row['object_key'] == 'failed':
                    raise ValueError('request failed')
                return {'object_key': row['object_key'], 'outcome': 'deleted'}
            with patch.object(tool, 'make_plan', return_value=saved), \
                 patch.object(tool, 'live_snapshot', return_value=saved['active_manifests']), \
                 patch.object(tool, 'retire_one', side_effect=retire), self.assertRaises(ValueError):
                tool.apply_plan('config', plan, receipt, tool.sha(plan), {}, {},
                                [{'object_key': 'failed'}, {'object_key': 'success'}])
            rows = [json.loads(line) for line in (Path(tmp) / 'retirement-journal.jsonl').read_text().splitlines()]
            self.assertEqual([row['object_key'] for row in rows], ['success'])
            self.assertFalse(receipt.exists())

    def test_live_manifest_change_at_batch_boundary_stops_before_delete(self):
        with TemporaryDirectory() as tmp:
            plan = Path(tmp) / 'plan.json'
            saved = {'backup_directory': tmp, 'active_manifests': {'old': True}}
            tool.write_json(plan, saved)
            with patch.object(tool, 'make_plan', return_value=saved), \
                 patch.object(tool, 'live_snapshot', return_value={'new': True}), \
                 patch.object(tool, 'retire_one') as delete:
                with self.assertRaises(ValueError):
                    tool.apply_plan('config', plan, Path(tmp) / 'receipt.json', tool.sha(plan), {}, {},
                                    [{'object_key': 'not-deleted'}])
                delete.assert_not_called()


if __name__ == '__main__':
    unittest.main()
