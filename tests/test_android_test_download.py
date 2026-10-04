import hashlib
import json
import os
from pathlib import Path
import runpy
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from tools import upload_launcher_release


class AndroidTestDownloadTests(unittest.TestCase):
    def exercise(self, mode, corrupt=False, missing_catalog=False, changed_active=False):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            build = 'a' * 40 + '-123-1'
            apk_name = f'game-{build}-android.apk'
            game = {'buildId': build, 'version': '0.3.90', 'versionCode': 7, 'testCompatibleBuildId': 'published-6',
                    'url': 'https://updates.pokeaether.com/game/' + apk_name,
                    'sizeBytes': 3, 'sha256': hashlib.sha256(b'apk').hexdigest()}
            (root / 'release').mkdir()
            (root / 'release' / apk_name).write_bytes(b'apk')
            (root / 'release/manifest-android.json').write_text(json.dumps({'game': game}))
            payload = {'home-icons/catalog.json': b'{}', 'home-icons/icon.png': b'png',
                       'login-media/world.ogv': b'video',
                       'browser-audio/assets/audio/sfx/pokemon_cries/PIKACHU.ogg': b'ogg'}
            catalog = {}
            for relative, body in payload.items():
                path = root / 'android-assets' / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(body)
                catalog[relative] = {'size': len(body), 'sha256': hashlib.sha256(body).hexdigest()}
            catalog_bytes = json.dumps(catalog).encode()
            (root / 'android-assets/mobile-assets').mkdir()
            (root / 'android-assets/mobile-assets/catalog.json').write_bytes(catalog_bytes)
            if corrupt:
                (root / 'android-assets/home-icons/icon.png').write_bytes(b'bad')
            previous = b'{"game":{"version":"0.3.89","versionCode":6,"buildId":"published-6"}}'
            if mode in ('--repair-active-assets', '--plan-active-assets'):
                active_game = dict(game)
                if changed_active:
                    active_game['sha256'] = 'b' * 64
                previous = json.dumps({'game': active_game}).encode()
            origin = f'https://web-assets.pokeaether.com/android/releases/{build}/'
            responses = {origin + relative: body for relative, body in payload.items()}
            responses[origin + 'mobile-assets/catalog.json'] = catalog_bytes
            if missing_catalog:
                del responses[origin + 'mobile-assets/catalog.json']
            responses[game['url']] = b'apk'
            responses['https://updates.pokeaether.com/manifest-android.json'] = previous
            source = Path(__file__).resolve().parents[1] / 'tools/prepare_android_test_download.py'
            with patch.dict('sys.modules', {'upload_launcher_release': upload_launcher_release}):
                module = runpy.run_path(str(source), run_name='android_review_test')
            original = Path.cwd()
            try:
                os.chdir(root)
                globals_ = module['main'].__globals__
                def public_bytes(url):
                    if url not in responses:
                        raise SystemExit('Public Android download is unavailable: HTTP 404')
                    return responses[url]
                with patch.dict(os.environ, {'GITHUB_SHA': ('a' if mode in ('--assets-only', '--apk-only') else 'b') * 40,
                                             'CANDIDATE_SOURCE_SHA': 'a' * 40, 'BUILD_RUN_ID': '123',
                                             'BUILD_RUN_ATTEMPT': '1'}), \
                        patch('sys.argv', ['prepare', mode]), \
                        patch.dict(globals_, {'public_bytes': public_bytes,
                                              '_load_config': unittest.mock.Mock(return_value=object())}), \
                        patch.dict(globals_, {'_upload_file': unittest.mock.Mock()}) as patched:
                    upload = patched['_upload_file']
                    if corrupt:
                        with self.assertRaisesRegex(SystemExit, 'checksum differs'):
                            module['main']()
                        upload.assert_not_called()
                        return
                    if missing_catalog:
                        with self.assertRaisesRegex(SystemExit, 'HTTP 404'):
                            module['main']()
                        upload.assert_not_called()
                        return
                    if changed_active:
                        with self.assertRaisesRegex(SystemExit, 'exact active Android release'):
                            module['main']()
                        upload.assert_not_called()
                        globals_['_load_config'].assert_not_called()
                        return
                    module['main']()
                    keys = [call.args[2] for call in upload.call_args_list]
                    self.assertNotIn('manifest-android.json', keys)
                    self.assertNotIn('manifest-web.json', keys)
                    self.assertNotIn('web-release-config.json', keys)
                    if mode in ('--assets-only', '--repair-active-assets'):
                        self.assertEqual(len(keys), 5)
                        self.assertEqual(keys[-1], f'android/releases/{build}/mobile-assets/catalog.json')
                        evidence = json.loads(Path('android-test-download.json').read_text())
                        self.assertEqual(evidence['activeAssetsRepaired'], mode == '--repair-active-assets')
                        self.assertFalse(evidence['apkDownloadReady'])
                    elif mode == '--apk-only':
                        self.assertEqual(keys, ['game/' + apk_name])
                        self.assertTrue(json.loads(Path('android-test-download.json').read_text())['apkDownloadReady'])
                    else:
                        upload.assert_not_called()
                        globals_['_load_config'].assert_not_called()
                        self.assertFalse(Path('android-test-download.json').exists())
                        if mode == '--plan-active-assets':
                            plan = json.loads(Path('android-active-asset-repair-plan.json').read_text())
                            self.assertEqual(plan['destinationPrefix'], f'android/releases/{build}/')
                            self.assertEqual(plan['assetCount'], 4)
            finally:
                os.chdir(original)

    def test_assets_only_keeps_active_manifests_unchanged(self):
        self.exercise('--assets-only')

    def test_apk_only_keeps_active_manifests_unchanged(self):
        self.exercise('--apk-only')

    def test_corrupt_asset_prevents_all_uploads(self):
        self.exercise('--assets-only', corrupt=True)

    def test_publication_preflight_verifies_assets_without_uploading(self):
        self.exercise('--verify-assets-only')

    def test_missing_public_asset_catalog_blocks_publication(self):
        self.exercise('--verify-assets-only', missing_catalog=True)

    def test_corrupt_local_payload_blocks_publication(self):
        self.exercise('--verify-assets-only', corrupt=True)

    def test_active_repair_uploads_only_exact_active_build_assets(self):
        self.exercise('--repair-active-assets')

    def test_active_repair_rejects_changed_manifest_before_reading_upload_credentials(self):
        self.exercise('--repair-active-assets', changed_active=True)

    def test_active_repair_plan_does_not_upload_or_require_credentials(self):
        self.exercise('--plan-active-assets')

    def test_active_repair_rejects_corrupt_payload(self):
        self.exercise('--repair-active-assets', corrupt=True)

    def test_missing_download_explains_required_preparation(self):
        source = Path(__file__).resolve().parents[1] / 'tools/prepare_android_test_download.py'
        with patch.dict('sys.modules', {'upload_launcher_release': upload_launcher_release}):
            module = runpy.run_path(str(source), run_name='android_review_test')
        error = HTTPError('https://example.invalid/catalog.json', 404, 'Not Found', {}, None)
        try:
            with patch.dict(module['public_bytes'].__globals__, {'urlopen': unittest.mock.Mock(side_effect=error)}):
                with self.assertRaisesRegex(SystemExit, 'Run Prepare Android test download'):
                    module['public_bytes']('https://example.invalid/catalog.json')
        finally:
            error.close()
