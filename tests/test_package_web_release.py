import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]


class PackageWebReleaseTests(unittest.TestCase):
    def test_browser_workflow_uses_noninteractive_source_asset_restore(self):
        source = (ROOT / '.github/workflows/deploy-web-cloudflare.yml').read_text()
        self.assertIn('default: https://updates.pokeaether.com', source)
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
