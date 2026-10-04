"""Publish immutable Android test files without changing any active manifest."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
from urllib.parse import quote
from urllib.error import URLError
from urllib.request import Request, urlopen

from upload_launcher_release import _load_config, _upload_file


def public_bytes(url: str) -> bytes:
    try:
        with urlopen(Request(url, headers={'User-Agent': 'PokeAetherAndroidReview/1.0',
                                          'Cache-Control': 'no-cache'}), timeout=90) as response:
            return response.read()
    except (URLError, TimeoutError) as error:
        raise SystemExit(f'Public Android download is unavailable: {url}: {error}. '
                         'Run Prepare Android test download for this candidate before publication.') from error


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--assets-only', action='store_true')
    mode.add_argument('--apk-only', action='store_true')
    mode.add_argument('--verify-assets-only', action='store_true',
                      help='Check the matching public asset payload before activating the updater; uploads nothing')
    args = parser.parse_args()
    game = json.loads(Path('release/manifest-android.json').read_text())['game']
    build = game['buildId']
    source_sha = os.environ.get('CANDIDATE_SOURCE_SHA', os.environ['GITHUB_SHA'])
    expected = f"{source_sha}-{os.environ['BUILD_RUN_ID']}-{os.environ['BUILD_RUN_ATTEMPT']}"
    if not re.fullmatch(r'[0-9a-f]{40}-[0-9]+-[0-9]+', build) or build != expected:
        raise SystemExit('Candidate identity does not match the selected main build')
    apk = Path('release') / f'game-{build}-android.apk'
    expected_url = f'https://updates.pokeaether.com/game/{apk.name}'
    if game['url'] != expected_url or apk.stat().st_size != game['sizeBytes']:
        raise SystemExit('Candidate APK URL or byte size differs')
    with apk.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != game['sha256']:
            raise SystemExit('Candidate APK checksum differs')
    assets = Path('android-assets').resolve()
    catalog_path = assets / 'mobile-assets/catalog.json'
    catalog = json.loads(catalog_path.read_text())
    if not catalog or 'home-icons/catalog.json' not in catalog or 'login-media/world.ogv' not in catalog:
        raise SystemExit('Required native assets are missing')
    files = []
    for relative, entry in catalog.items():
        parts = Path(relative).parts
        if not parts or parts[0] not in ('home-icons', 'browser-audio', 'login-media') or '..' in parts:
            raise SystemExit('Unsafe native asset path')
        path = (assets / relative).resolve()
        if not path.is_relative_to(assets) or not path.is_file() or path.stat().st_size != entry['size']:
            raise SystemExit('Missing or changed native asset')
        with path.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != entry['sha256']:
                raise SystemExit('Native asset checksum differs')
        files.append((path, relative))
    config = _load_config() if not args.verify_assets_only else None
    manifest_url = 'https://updates.pokeaether.com/manifest-android.json'
    previous_manifest = public_bytes(manifest_url)
    previous_game = json.loads(previous_manifest)['game']
    if game['versionCode'] <= previous_game['versionCode']:
        raise SystemExit('Test version code must exceed the active Android release')
    if game.get('testCompatibleBuildId') != previous_game.get('buildId'):
        raise SystemExit('Active Android build changed since the candidate was built')
    prefix = f'android/releases/{build}/'
    def upload(item):
        path, relative = item
        _upload_file(config, path, prefix + relative)
    if args.assets_only:
        print(f'Uploading {len(files)} verified native assets for {build}', flush=True)
        with ThreadPoolExecutor(max_workers=32) as executor:
            for _ in executor.map(upload, files):
                pass
        # Catalog last: only expose a complete native asset set.
        _upload_file(config, catalog_path, prefix + 'mobile-assets/catalog.json')
    origin = 'https://web-assets.pokeaether.com/' + prefix
    if public_bytes(origin + 'mobile-assets/catalog.json') != catalog_path.read_bytes():
        raise SystemExit('Public native asset catalog differs')
    samples = ['home-icons/catalog.json', 'login-media/world.ogv']
    samples += [next(name for name in catalog if name.startswith('home-icons/') and name.endswith('.png'))]
    samples += [next(name for name in catalog if name.endswith('/PIKACHU.ogg'))]
    for relative in samples:
        encoded = '/'.join(quote(part, safe='') for part in relative.split('/'))
        body = public_bytes(origin + encoded)
        if len(body) != catalog[relative]['size'] or hashlib.sha256(body).hexdigest() != catalog[relative]['sha256']:
            raise SystemExit('Public native asset sample differs')
    if args.apk_only:
        _upload_file(config, apk, 'game/' + apk.name)
        # Download once to verify exactly the bytes that the device tester receives.
        body = public_bytes(expected_url)
        if len(body) != game['sizeBytes'] or hashlib.sha256(body).hexdigest() != game['sha256']:
            raise SystemExit('Public test APK differs from the signed candidate')
    if public_bytes(manifest_url) != previous_manifest:
        raise SystemExit('Active Android updater manifest changed during test preparation')
    if args.verify_assets_only:
        print(f'Verified matching public Android assets for {build}; no uploads or active manifest changes', flush=True)
        return
    evidence = {'game': game, 'assetCatalogUrl': origin + 'mobile-assets/catalog.json',
                'assetCount': len(files), 'activeAndroidVersion': previous_game['version'],
                'updaterManifestChanged': False, 'apkDownloadReady': args.apk_only}
    Path('android-test-download.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(f"Android {game['version']} test download: {expected_url}", flush=True)


if __name__ == '__main__':
    main()
