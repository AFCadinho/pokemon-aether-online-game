#!/usr/bin/env python3
"""Build the web client; run through ops/worktrees/slot-env SLOT."""
from __future__ import annotations

import argparse
from fnmatch import fnmatchcase
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import struct
import time
try:
    from .build_web_on_demand import prepare_home_icons, prepare_login_media, prepare_mobile_assets
except ImportError:
    from build_web_on_demand import prepare_home_icons, prepare_login_media, prepare_mobile_assets

ROOT = Path(__file__).resolve().parents[1]
# Browser audio is external; only its availability catalog stays bundled.
MAX_INITIAL_BYTES = 312 * 1024 * 1024
# A one-release exception may be used for a candidate that narrowly exceeds
# the normal phase-5 limit. This ceiling is deliberately bounded and opt-in.
MAX_EXCEPTION_BYTES = 328 * 1024 * 1024
WEB_AUDIO_SOURCE_DIRS = (
    ROOT / "assets/music",
    ROOT / "assets/audio",
    ROOT / "assets/battles/animations",
)
WEB_AUDIO_SUFFIXES = {".ogg", ".wav", ".mp3"}
WEB_SHELL_ASSETS = (
    ROOT / "infrastructure/web/pokeaether-logo.webp",
    ROOT / "infrastructure/web/pokeaether-world-preview.webp",
)
ANSI_ESCAPE = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
EXPORT_PROGRESS = re.compile(r'^\[\s*(\d+)%\s*\]\s*([A-Za-z0-9_-]+)')


def validate_world_map_export_partition(root: Path) -> None:
    """Reject stale map presets before preparing assets or running Godot."""
    presets = {}
    source = (root / 'export_presets.cfg').read_text()
    for match in re.finditer(r'\[preset\.(\d+)\]\n(.*?)\n\[preset\.\1\.options\]', source, re.S):
        fields = dict(re.findall(r'^(\w+)=(.*)$', match[2], re.M))
        presets[json.loads(fields['name'])] = fields
    catalog = json.loads((root / 'generated/world_access_catalog.json').read_text())
    full_scope = json.loads((root / 'docs/browser-full-world-scope.json').read_text())
    misty_scope = json.loads((root / 'docs/browser-misty-scope.json').read_text())
    covered = set(full_scope['coreMapIds'] + full_scope['extendedMapIds'] + misty_scope['additionalMapIds'])
    missing = [map_id for map_id, area in catalog['areas'].items()
               if map_id.startswith('kanto_') and area.get('scenePath') and map_id not in covered]
    if missing:
        raise RuntimeError(f'Browser map partition misses current Kanto maps: {missing}')
    core = presets['Web Local Preview']
    excluded = json.loads(core['exclude_filter']).split(',')
    for preset_name, map_ids in (
        ('Web Misty Maps Trial', misty_scope['additionalMapIds']),
        ('Web Extended Kanto Maps', full_scope['extendedMapIds']),
    ):
        selected = {json.loads(value) for value in re.findall(r'"[^"\n]*"', presets[preset_name]['export_files'])}
        for map_id in map_ids:
            path = catalog['areas'][map_id]['scenePath']
            if not any(fnmatchcase(path.removeprefix('res://'), pattern) for pattern in excluded):
                raise RuntimeError(f'Web core export exclusion missing for on-demand world map: {map_id}')
            if path not in selected:
                raise RuntimeError(f'{preset_name} export selection missing on-demand world map: {map_id}')


def parse_export_progress(line: str) -> tuple[int, str] | None:
    """Extract Godot's concise percentage and phase from a console line."""
    match = EXPORT_PROGRESS.match(ANSI_ESCAPE.sub('', line).strip())
    if not match:
        return None
    return int(match.group(1)), match.group(2)


def run_export(command: list[str], console_log: Path) -> int:
    """Run Godot quietly while relaying useful progress to the terminal."""
    last_progress = None
    last_output_at = time.monotonic()
    with console_log.open('w') as console:
        process = subprocess.Popen(command, stdout=console, stderr=subprocess.STDOUT)
        with console_log.open(errors='replace') as progress:
            while True:
                line = progress.readline()
                if not line:
                    if process.poll() is not None:
                        break
                    if time.monotonic() - last_output_at >= 15:
                        print('Godot export is still working...', flush=True)
                        last_output_at = time.monotonic()
                    time.sleep(0.2)
                    continue
                parsed = parse_export_progress(line)
                if parsed is not None and parsed != last_progress:
                    percent, phase = parsed
                    print(f'Godot export: {percent}% ({phase})', flush=True)
                    last_progress = parsed
                    last_output_at = time.monotonic()
    return process.wait()


def copy_browser_audio(output: Path) -> list[dict[str, object]]:
    """Expose raw browser-playable audio outside Godot's silent web mixer."""
    destination = output / "browser-audio"
    if destination.exists():
        shutil.rmtree(destination)
    copied: list[dict[str, object]] = []
    for source_root in WEB_AUDIO_SOURCE_DIRS:
        for source in source_root.rglob("*"):
            if not source.is_file() or source.suffix.lower() not in WEB_AUDIO_SUFFIXES:
                continue
            relative = source.relative_to(ROOT / "assets")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied.append({"name": str(relative), "bytes": source.stat().st_size})
    if not copied:
        raise RuntimeError("No browser audio files were copied.")
    return copied


def write_browser_audio_catalog(files: list[dict[str, object]], destination: Path) -> None:
    """Resolve cries without depending on resources excluded from the web PCK."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    paths = sorted("res://assets/" + str(item["name"]) for item in files)
    destination.write_text(json.dumps(paths, separators=(',', ':')) + '\n')


def copy_web_shell_assets(output: Path) -> list[Path]:
    """Copy the small assets referenced directly by the custom HTML shell."""
    copied = []
    for source in WEB_SHELL_ASSETS:
        if not source.is_file() or source.stat().st_size == 0:
            raise RuntimeError(f"Web shell asset is missing: {source.relative_to(ROOT)}")
        target = output / source.name
        shutil.copy2(source, target)
        copied.append(target)
    return copied


def pack_contains(path: Path, marker: bytes) -> bool:
    overlap = b''
    with path.open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            haystack = overlap + chunk
            if marker in haystack:
                return True
            overlap = haystack[-max(0, len(marker) - 1):]
    return False


def pack_entry_names(path: Path) -> list[str]:
    """Read the unencrypted Godot PCK directory, not payload string references."""
    with path.open('rb') as stream:
        header = stream.read(40)
        magic, version = struct.unpack_from('<II', header)
        if magic != 0x43504447 or version not in (2, 3):
            raise RuntimeError('Unsupported PCK directory')
        if struct.unpack_from('<I', header, 20)[0] & 1:
            raise RuntimeError('Encrypted PCK directory cannot be audited')
        stream.seek(struct.unpack_from('<Q', header, 32)[0] if version == 3 else 96)
        count, = struct.unpack('<I', stream.read(4))
        names = []
        for _ in range(count):
            length, = struct.unpack('<I', stream.read(4))
            names.append(stream.read(length).rstrip(b'\0').decode('utf-8').removeprefix('res://'))
            stream.seek(36, 1)
        return names


def validate_external_audio_pack(path: Path) -> None:
    imported_audio = set()
    for metadata in (ROOT / 'assets').rglob('*.import'):
        if metadata.with_suffix('').suffix.lower() not in WEB_AUDIO_SUFFIXES:
            continue
        imported_audio.update(re.findall(r'res://(\.godot/imported/[^"\n]+)', metadata.read_text()))
    forbidden = [name for name in pack_entry_names(path)
                 if Path(name).suffix.lower() in WEB_AUDIO_SUFFIXES or name in imported_audio]
    if forbidden:
        raise RuntimeError(f'Web PCK embeds browser audio: {forbidden[:5]}')


def initial_size_limit(*, allow_exception: bool, reason: str | None) -> tuple[int, str | None]:
    """Return the normal or explicitly approved, bounded one-release limit."""
    if not allow_exception:
        if reason:
            raise ValueError('A size-exception reason requires --allow-size-exception.')
        return MAX_INITIAL_BYTES, None
    clean_reason = (reason or '').strip()
    if len(clean_reason) < 15:
        raise ValueError('A size exception requires a reason of at least 15 characters.')
    return MAX_EXCEPTION_BYTES, clean_reason


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--allow-size-exception', action='store_true',
                        help='Allow this candidate to exceed 312 MiB, up to 328 MiB.')
    parser.add_argument('--size-exception-reason',
                        help='Required audit reason when --allow-size-exception is set.')
    args = parser.parse_args()
    try:
        size_limit, exception_reason = initial_size_limit(
            allow_exception=args.allow_size_exception,
            reason=args.size_exception_reason,
        )
    except ValueError as error:
        parser.error(str(error))
    if ROOT.parent.name.startswith('slot-') and os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Run slot builds through ops/worktrees/slot-env SLOT -- COMMAND.')
    validate_world_map_export_partition(ROOT)
    output = ROOT / 'builds/web'
    output.mkdir(parents=True, exist_ok=True)
    browser_audio_files = copy_browser_audio(output)
    write_browser_audio_catalog(browser_audio_files, ROOT / 'generated/browser_audio_catalog.json')
    home_bytes = prepare_home_icons(ROOT, output)
    print('Preparing streamed login video at source quality...', flush=True)
    media_bytes = prepare_login_media(ROOT, output)
    mobile_bytes = prepare_mobile_assets(ROOT, output)
    console_log = output / 'export-console.log'
    # Godot treats any previously imported file below the project as an
    # exportable resource, even when an export exclude_filter names that
    # directory. Keep installed tooling and generated build environments out
    # of the PCK without requiring developers to remove local state first.
    created_ignores = []
    for ignored_root in (ROOT / 'node_modules', ROOT / 'builds'):
        if not ignored_root.is_dir():
            continue
        godot_ignore = ignored_root / '.gdignore'
        if not godot_ignore.exists():
            godot_ignore.write_text('', encoding='utf-8')
            created_ignores.append(godot_ignore)
    try:
        returncode = run_export([
            args.godot, '--headless', '--log-file', str(output / 'export.log'), '--path', str(ROOT), '--export-release',
            'Web Local Preview', str(output / 'index.html'),
        ], console_log)
    finally:
        for godot_ignore in created_ignores:
            godot_ignore.unlink(missing_ok=True)
    if returncode != 0:
        tail = console_log.read_text(errors='replace').splitlines()[-80:]
        raise RuntimeError('Godot web export failed:\n' + '\n'.join(tail))
    shell_assets = copy_web_shell_assets(output)
    files = []
    for name in ('index.html', 'index.js', 'index.wasm', 'index.pck', *(path.name for path in shell_assets)):
        path = output / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f'Export is incomplete: missing {name}')
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        files.append({'name': name, 'bytes': path.stat().st_size, 'sha256': digest})
    pck_path = output / 'index.pck'
    required_markers = (
        b'generated/tiled_visuals/route_1/route_1.visual.tscn',
        b'generated/tiled_visuals/kanto_route_22/kanto_route_22.visual.tscn',
        b'generated/tiled_visuals/kanto_route_2/kanto_route_2.visual.tscn',
        b'generated/tiled_visuals/viridian_forest/viridian_forest.visual.tscn',
        b'generated/tiled_visuals/pewter_city/pewter_city.visual.tscn',
        b'generated/tiled_visuals/pewter_gym/pewter_gym.visual.tscn',
        b'generated/tiled_visuals/lobby/lobby.visual.tscn',
        b'assets/fonts/DejaVuSans.ttf',
        b'generated/browser_audio_catalog.json',
        b'assets/ui/home_unknown.png',
    )
    forbidden_markers = (
        b'node_modules/playwright-core/',
        b'assets/sprites/pokemon/front/pikachu/sheet.png.import',
        b'assets/sprites/pokemon/gen5/front/pikachu/sheet.png.import',
        b'generated/tiled_visuals/route_3/route_3.visual.tscn',
        b'generated/tiled_visuals/waiting_area/waiting_area.visual.tscn',
        b'generated/tiled_visuals/aether_clash_duel/aether_clash_duel.visual.tscn',
        b'generated/tiled_visuals/aether_clash_battle_royale/aether_clash_battle_royale.visual.tscn',
    )
    for marker in required_markers:
        if not pack_contains(pck_path, marker):
            raise RuntimeError(f'Web pack misses required asset marker: {marker.decode()}')
    for marker in forbidden_markers:
        if pack_contains(pck_path, marker):
            raise RuntimeError(f'Web pack contains excluded asset marker: {marker.decode()}')

    initial_bytes = sum(item['bytes'] for item in files)
    validate_external_audio_pack(pck_path)
    packed_names = set(pack_entry_names(pck_path))
    excluded_sources = ('assets/sprites/pokemon/pokemon_home/', 'assets/sprites/pokemon/pokemon_home_shiny/', 'assets/video/login_background.ogv')
    if any(name.startswith(excluded_sources) for name in packed_names):
        raise RuntimeError('Web PCK embeds on-demand HOME icons or login video.')
    for folder in ('assets/sprites/pokemon/pokemon_home', 'assets/sprites/pokemon/pokemon_home_shiny'):
        for metadata in (ROOT / folder).glob('*.import'):
            imported = re.findall(r'res://(\.godot/imported/[^"\n]+)', metadata.read_text())
            if packed_names.intersection(imported):
                raise RuntimeError('Web PCK embeds imported HOME textures.')
    full_scope = json.loads((ROOT / 'docs/browser-full-world-scope.json').read_text())
    world_catalog = json.loads((ROOT / 'generated/world_access_catalog.json').read_text())
    for map_id in full_scope['extendedMapIds']:
        scene = str(world_catalog['areas'][map_id]['scenePath']).removeprefix('res://')
        if scene in packed_names or scene + '.remap' in packed_names:
            raise RuntimeError(f'Web core embeds on-demand world map: {map_id}')
    if initial_bytes > size_limit:
        raise RuntimeError(
            f'Web build is {initial_bytes / 1048576:.1f} MiB; '
            f'the permitted limit is {size_limit / 1048576:.0f} MiB.'
        )
    receipt = {
        'phase': 7, 'accounts': True, 'onlineGameplay': True,
        'chat': True, 'aiSparring': True, 'ranked': False,
        'dynamicPokemonSprites': True,
        'assetProfile': 'kanto-all-current-maps-modular',
        'maxInitialBytes': size_limit,
        'standardInitialLimitBytes': MAX_INITIAL_BYTES,
        'sizeExceptionReason': exception_reason,
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'dirty': bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True).strip()),
        'engine': subprocess.check_output([args.godot, '--version'], text=True).strip(),
        'files': files,
        'browserAudioFiles': len(browser_audio_files),
        'browserAudioBytes': sum(int(item['bytes']) for item in browser_audio_files),
        'initialBytes': initial_bytes,
        'homeIconBytes': home_bytes,
        'loginMediaBytes': media_bytes,
        'mobileAssetBytes': mobile_bytes,
    }
    (output / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(f"Web preview exported: {receipt['initialBytes'] / 1048576:.1f} MiB before HTTP compression.")
    if exception_reason:
        print(f"One-release size exception: {exception_reason}")
    print('Serve with: python3 tools/serve_web_preview.py')


if __name__ == '__main__':
    main()
