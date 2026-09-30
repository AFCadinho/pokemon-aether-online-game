import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import zipfile
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import upload_web_release
from upload_launcher_release import _load_updates_config


class PackageWebReleaseTests(unittest.TestCase):
    def test_extended_kanto_preset_covers_every_module_map(self):
        presets = (ROOT / 'export_presets.cfg').read_text()
        extended = presets.split('[preset.8]\n', 1)[1].split('[preset.8.options]', 1)[0]
        for scene in (
            'scenes/overworld/kanto/routes/kanto_route_5.tscn',
            'scenes/overworld/kanto/routes/kanto_route_9.tscn',
            'scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn',
            'scenes/overworld/kanto/routes/route_10_pokemon_center.tscn',
        ):
            with self.subTest(scene=scene):
                self.assertIn(f'res://{scene}', extended)

    def test_update_manifest_publisher_uses_a_separate_bucket_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'web-release.json').write_text(json.dumps({'buildId': 'candidate', 'objects': []}))
            (root / 'manifest-web.json').write_text('{"gameBuildId":"candidate"}')
            update_config = SimpleNamespace(bucket='pokeaether-updates')
            with patch.object(upload_web_release, '_load_config', side_effect=AssertionError('asset bucket must not be loaded')):
                with patch.object(upload_web_release, '_load_updates_config', return_value=update_config):
                    with patch.object(upload_web_release, '_upload_file') as upload:
                        with patch('sys.argv', ['upload_web_release.py', str(root), '--manifest-only', '--publish-manifest']):
                            upload_web_release.main()
            upload.assert_called_once_with(update_config, root / 'manifest-web.json', 'manifest-web.json')

    def test_browser_runtime_upload_uses_verified_object_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'index.wasm'
            source.write_bytes(b'webassembly')
            import hashlib
            release = {
                'buildId': 'candidate-123',
                'objects': [{
                    'source': 'index.wasm',
                    'key': 'web/releases/candidate-123/index.wasm',
                    'bytes': source.stat().st_size,
                    'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                }],
            }
            (root / 'web-release.json').write_text(json.dumps(release))
            config = SimpleNamespace(bucket='pokeaether-web')
            with patch.object(upload_web_release, '_load_config', return_value=config):
                with patch.object(upload_web_release, '_upload_file') as upload:
                    with patch('sys.argv', ['upload_web_release.py', str(root)]):
                        upload_web_release.main()
            self.assertCountEqual(upload.call_args_list, [
                unittest.mock.call(config, source, 'web/releases/candidate-123/index.wasm'),
                unittest.mock.call(config, root / 'web-release.json', 'web/releases/candidate-123/web-release.json'),
            ])

    def test_browser_runtime_uploads_verified_objects_with_bounded_parallelism(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            objects = []
            for index in range(24):
                source = root / f'asset-{index}.bin'
                source.write_bytes(f'asset-{index}'.encode())
                objects.append({
                    'source': source.name,
                    'key': f'web/releases/candidate-123/{source.name}',
                    'bytes': source.stat().st_size,
                    'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                })
            (root / 'web-release.json').write_text(json.dumps({'buildId': 'candidate-123', 'objects': objects}))
            config = SimpleNamespace(bucket='pokeaether-web')
            lock = threading.Lock()
            active = 0
            maximum_active = 0

            def fake_upload(_config, _source, _key):
                nonlocal active, maximum_active
                with lock:
                    active += 1
                    maximum_active = max(maximum_active, active)
                time.sleep(0.01)
                with lock:
                    active -= 1

            with patch.object(upload_web_release, '_load_config', return_value=config):
                with patch.object(upload_web_release, '_upload_file', side_effect=fake_upload) as upload:
                    with patch('sys.argv', ['upload_web_release.py', str(root)]):
                        upload_web_release.main()

            self.assertEqual(upload.call_count, len(objects) + 1)
            self.assertGreater(maximum_active, 1)
            self.assertLessEqual(maximum_active, upload_web_release.MAX_UPLOAD_WORKERS)

    def test_update_manifest_bucket_uses_its_own_credentials(self):
        values = {
            'UPDATE_R2_ACCOUNT_ID': 'update-account',
            'UPDATE_R2_BUCKET': 'pokeaether-updates',
            'UPDATE_R2_ACCESS_KEY_ID': 'update-access',
            'UPDATE_R2_SECRET_ACCESS_KEY': 'update-secret',
        }
        with patch.dict(os.environ, values, clear=True):
            config = _load_updates_config()
        self.assertEqual(config.account_id, 'update-account')
        self.assertEqual(config.bucket, 'pokeaether-updates')
        self.assertEqual(config.access_key_id, 'update-access')
        self.assertEqual(config.secret_access_key, 'update-secret')
        self.assertEqual(config.endpoint, 'https://update-account.r2.cloudflarestorage.com')

    def test_browser_workflow_uses_noninteractive_source_asset_restore(self):
        source = (ROOT / '.github/workflows/deploy-web-cloudflare.yml').read_text()
        self.assertIn('size_exception:', source)
        self.assertIn('default: false', source)
        self.assertIn('inputs.size_exception_reason', source)
        self.assertIn('--allow-size-exception --size-exception-reason', source)
        self.assertIn('A size exception requires an audit reason', source)
        self.assertIn('default: https://web-assets.pokeaether.com', source)
        self.assertIn('python3 tools/upload_web_release.py builds/web-r2', source)
        self.assertNotIn('rclone copy builds/web-r2', source)
        self.assertIn('${SOURCE_ASSET_BASE_URL}/assets/${POKEMON_HOME_ASSET_VERSION}.zip', source)
        self.assertIn('${SOURCE_ASSET_BASE_URL}/assets/${version}.zip', source)
        self.assertEqual(source.count('unzip -oq /tmp/'), 3)
        upload = source.index('- name: Upload immutable runtime to R2')
        cors = source.index('- name: Verify R2 CORS is ready')
        self.assertGreater(cors, upload)
        self.assertIn('${ASSET_BASE_URL}/web/releases/${WEB_BUILD_ID}/index.wasm', source)
        self.assertIn('deadline=$((SECONDS + 180))', source)
        self.assertIn('grep -Fq "${WEB_BUILD_ID}" "${public_index}"', source)
        self.assertIn('curl --retry 6 --retry-all-errors --retry-delay 2', source)
        self.assertIn('${WEB_URL}/pokemon-assets/battle/${POKEMON_FRONT_ASSET_VERSION}/pikachu/animation.json', source)
        self.assertIn('${WEB_URL}/pokemon-assets/battle/${POKEMON_FRONT_ASSET_VERSION}/pikachu/sheet.png', source)
        self.assertIn('${WEB_URL}/pokemon-assets/gen5/${POKEMON_GEN5_FRONT_ASSET_VERSION}/pikachu/animation.json', source)
        self.assertIn('${WEB_URL}/pokemon-assets/gen5/${POKEMON_GEN5_FRONT_ASSET_VERSION}/pikachu/sheet.png', source)
        self.assertIn('PAGES_BRANCH=rc', source)
        self.assertIn('PREVIEW_CLIENT_BUILD_ID=', source)
        self.assertIn('actions/upload-artifact@v6', source)
        self.assertNotIn('inputs.publish_manifest', source)
        publish = (ROOT / '.github/workflows/publish-browser-candidate.yml').read_text()
        self.assertIn('candidate_run_id', publish)
        self.assertIn('Publish the tested browser manifest', publish)
        self.assertIn("run.get('head_branch') != 'main'", publish)
        self.assertIn('UPDATE_R2_BUCKET', publish)
        self.assertIn('https://updates.pokeaether.com', publish)
        build_source = (ROOT / 'tools/build_web_preview.py').read_text()
        self.assertIn("b'assets/fonts/DejaVuSans.ttf'", build_source)
        self.assertIn("b'assets/sprites/pokemon/front/pikachu/sheet.png.import'", build_source)
        self.assertIn("b'assets/sprites/pokemon/gen5/front/pikachu/sheet.png.import'", build_source)

    def test_browser_uses_the_same_battle_sprite_releases_as_desktop(self):
        import re
        def versions(name):
            source = (ROOT / '.github/workflows' / name).read_text()
            return dict(re.findall(
                r'^  (POKEMON_(?:(?:GEN5_)?(?:FRONT|BACK|SHINY_FRONT|SHINY_BACK))_ASSET_VERSION): (\S+)$',
                source, re.M,
            ))
        browser = versions('deploy-web-cloudflare.yml')
        self.assertEqual(len(browser), 8)
        self.assertEqual(browser, versions('deploy-desktop-r2.yml'))

    def test_split_release_uses_versioned_r2_urls_and_pages_headers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            export = root / 'export'
            pages = root / 'pages'
            r2 = root / 'r2'
            (export / 'browser-audio/music').mkdir(parents=True)
            (export / 'modules').mkdir(parents=True)
            (export / 'index.html').write_text(
                '<!-- POKEAETHER_RELEASE_CONFIG --><script src="index.js"></script>', encoding='utf-8')
            for name, body in {
                'index.js': b'js', 'index.wasm': b'wasm', 'index.pck': b'pck',
                'pokeaether-logo.webp': b'logo',
                'pokeaether-world-preview.webp': b'preview',
                'browser-audio/music/theme.ogg': b'audio',
                'build-receipt.json': b'{}',
                'modules/manifest.json': b'{"schemaVersion":1,"modules":{}}',
                'modules/aether-clash-maps.pck': b'module',
                'modules/kanto-through-misty-maps.pck': b'misty module',
                'modules/kanto-extended-maps.pck': b'extended module',
                'modules/export.log': b'private build diagnostics',
            }.items():
                path = export / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(body)
            command = [
                'python3', str(ROOT / 'tools/package_web_release.py'),
                '--build-id', 'build-123', '--release-version', '0.4.0',
                '--asset-base-url', 'https://assets.example.test',
                '--web-url', 'https://play.example.test',
                '--client-build-id', 'active-build-456',
                '--sprite-animated-front-version', 'front-v1',
                '--sprite-animated-back-version', 'back-v1',
                '--sprite-animated-shiny-front-version', 'shiny-front-v1',
                '--sprite-animated-shiny-back-version', 'shiny-back-v1',
                '--sprite-pixel-front-version', 'pixel-front-v1',
                '--sprite-pixel-back-version', 'pixel-back-v1',
                '--sprite-pixel-shiny-front-version', 'pixel-shiny-front-v1',
                '--sprite-pixel-shiny-back-version', 'pixel-shiny-back-v1',
                '--export-dir', str(export), '--pages-dir', str(pages), '--r2-dir', str(r2),
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
            html = (pages / 'index.html').read_text(encoding='utf-8')
            self.assertIn('https://assets.example.test', html)
            self.assertIn('build-123', html)
            self.assertIn('https://play.example.test/pokemon-assets/battle/front-v1', html)
            self.assertIn('https://play.example.test/pokemon-assets/battle/back-v1', html)
            self.assertIn('https://play.example.test/pokemon-assets/gen5/pixel-front-v1', html)
            self.assertNotIn('https://assets.example.test/web/assets/front-v1', html)
            config = json.loads((pages / 'web-release-config.json').read_text(encoding='utf-8'))
            self.assertEqual(config['buildId'], 'build-123')
            self.assertEqual(config['clientBuildId'], 'active-build-456')
            self.assertEqual(
                config['spriteStyles']['animated']['front'],
                'https://play.example.test/pokemon-assets/battle/front-v1',
            )
            self.assertFalse((pages / 'index.pck').exists())
            self.assertTrue((r2 / 'index.pck').is_file())
            self.assertTrue((pages / 'pokeaether-logo.webp').is_file())
            self.assertTrue((pages / 'pokeaether-world-preview.webp').is_file())
            self.assertTrue((pages / 'modules/aether-clash-maps.pck').is_file())
            self.assertTrue((pages / 'modules/kanto-through-misty-maps.pck').is_file())
            self.assertFalse((pages / 'modules/export.log').exists())
            release = json.loads((r2 / 'web-release.json').read_text(encoding='utf-8'))
            self.assertEqual(release['objects'][0]['key'].split('/')[0:3], ['web', 'releases', 'build-123'])
            headers = (pages / '_headers').read_text(encoding='utf-8')
            self.assertIn("connect-src 'self' https://assets.example.test", headers)
            self.assertIn('Cross-Origin-Embedder-Policy: require-corp', headers)

            production_command = command.copy()
            client_build_option = production_command.index('--client-build-id')
            del production_command[client_build_option:client_build_option + 2]
            subprocess.run(production_command, check=True, capture_output=True, text=True)
            production_config = json.loads((pages / 'web-release-config.json').read_text(encoding='utf-8'))
            self.assertEqual(production_config['clientBuildId'], 'build-123')

    def test_sprite_pack_extraction_keeps_only_safe_runtime_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'front.zip'
            output = root / 'output'
            prefix = 'assets/sprites/pokemon/front/pikachu/'
            with zipfile.ZipFile(archive, 'w') as package:
                package.writestr(prefix + 'animation.json', '{"frames":[{}]}')
                package.writestr(prefix + 'sheet.png', b'png')
                package.writestr(prefix + 'ignored.txt', b'private')
                package.writestr('assets/sprites/pokemon/back/pikachu/sheet.png', b'wrong side')
            subprocess.run([
                'python3', str(ROOT / 'tools/extract_web_sprite_pack.py'), str(archive),
                '--style', 'animated', '--side', 'front', '--output', str(output),
            ], check=True, capture_output=True, text=True)
            self.assertTrue((output / 'pikachu/animation.json').is_file())
            self.assertTrue((output / 'pikachu/sheet.png').is_file())
            self.assertFalse((output / 'pikachu/ignored.txt').exists())

    def test_pixel_sprite_pack_extraction_uses_gen5_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / 'pixel-front.zip'
            output = root / 'output'
            prefix = 'assets/sprites/pokemon/gen5/front/pikachu/'
            with zipfile.ZipFile(archive, 'w') as package:
                package.writestr(prefix + 'animation.json', '{"frames":[{}]}')
                package.writestr(prefix + 'sheet.png', b'png')
                package.writestr('assets/sprites/pokemon/front/pikachu/sheet.png', b'wrong style')
            subprocess.run([
                'python3', str(ROOT / 'tools/extract_web_sprite_pack.py'), str(archive),
                '--style', 'pixel', '--side', 'front', '--output', str(output),
            ], check=True, capture_output=True, text=True)
            self.assertEqual((output / 'pikachu/sheet.png').read_bytes(), b'png')


if __name__ == '__main__':
    unittest.main()
