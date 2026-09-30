import hashlib
import json
import os
from pathlib import Path
import runpy
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from tools import upload_launcher_release


class AndroidTestDownloadTests(unittest.TestCase):
    def exercise(self, mode, corrupt=False):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            build = 'a' * 40 + '-123-1'
            apk_name = f'game-{build}-android.apk'
            game = {'buildId': build, 'version': '0.3.90', 'versionCode': 7,
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
            previous = b'{"game":{"version":"0.3.89","versionCode":6}}'
            origin = f'https://web-assets.pokeaether.com/web/releases/{build}/'
            responses = {origin + relative: body for relative, body in payload.items()}
            responses[origin + 'mobile-assets/catalog.json'] = catalog_bytes
            responses[game['url']] = b'apk'
            responses['https://updates.pokeaether.com/manifest-android.json'] = previous
            source = Path(__file__).resolve().parents[1] / 'tools/prepare_android_test_download.py'
            with patch.dict('sys.modules', {'upload_launcher_release': upload_launcher_release}):
                module = runpy.run_path(str(source), run_name='android_review_test')
            original = Path.cwd()
            try:
                os.chdir(root)
                globals_ = module['main'].__globals__
                with patch.dict(os.environ, {'GITHUB_SHA': 'a' * 40, 'BUILD_RUN_ID': '123',
                                             'BUILD_RUN_ATTEMPT': '1'}), \
                        patch('sys.argv', ['prepare', mode]), \
                        patch.dict(globals_, {'public_bytes': lambda url: responses[url],
                                              '_load_config': lambda: object()}), \
                        patch.dict(globals_, {'_upload_file': unittest.mock.Mock()}) as patched:
                    upload = patched['_upload_file']
                    if corrupt:
                        with self.assertRaisesRegex(SystemExit, 'checksum differs'):
                            module['main']()
                        upload.assert_not_called()
                        return
                    module['main']()
                    keys = [call.args[2] for call in upload.call_args_list]
                    self.assertNotIn('manifest-android.json', keys)
                    self.assertNotIn('manifest-web.json', keys)
                    self.assertNotIn('web-release-config.json', keys)
                    if mode == '--assets-only':
                        self.assertEqual(len(keys), 5)
                        self.assertEqual(keys[-1], f'web/releases/{build}/mobile-assets/catalog.json')
                    else:
                        self.assertEqual(keys, ['game/' + apk_name])
                        self.assertTrue(json.loads(Path('android-test-download.json').read_text())['apkDownloadReady'])
            finally:
                os.chdir(original)

    def test_assets_only_keeps_active_manifests_unchanged(self):
        self.exercise('--assets-only')

    def test_apk_only_keeps_active_manifests_unchanged(self):
        self.exercise('--apk-only')

    def test_corrupt_asset_prevents_all_uploads(self):
        self.exercise('--assets-only', corrupt=True)
