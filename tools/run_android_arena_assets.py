#!/usr/bin/env python3
"""Compare only this task's two hash-pinned packs on the fixed debug emulator.
Serve owned assets on loopback with adb reverse; never modify the normal game.
"""
import argparse
import hashlib
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = 'com.pokeaether.androidarenapilot'
SERIAL = 'emulator-5580'

class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    suites = parser.add_mutually_exclusive_group()
    suites.add_argument('--texture-residency', action='store_true', help='Controlled native/compressed allocation and byte readback in the separate arena app')
    suites.add_argument('--battle-budget', action='store_true', help='Full battle suite in the existing dedicated 3D debug app; never clear its cache')
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Android/Sdk')
    parser.add_argument('--lighting-mode', choices=['baseline', 'hdr', 'sun-only', 'shadow-colour'], default='baseline')
    parser.add_argument('--hour', type=float, default=12.0)
    parser.add_argument('--camera-view', choices=['default', 'side'], default='default')
    parser.add_argument('--shadow-casters', action='store_true')
    parser.add_argument('--no-caster-shadows', action='store_true')
    parser.add_argument('--expect-renderer', choices=['gl_compatibility', 'mobile'])
    parser.add_argument('--variant', choices=['desktop-art', 'android-etc2-art'])
    parser.add_argument('--battle-resolution', choices=['960x540','960x432','1920x1080','2400x1080'], default='960x540', help='Bounded GLES full-battle raster comparison; baseline stays 960x540')
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if not 0 <= args.hour < 24:
        parser.error('Hour must be finite and in [0, 24)')
    if args.lighting_mode == 'shadow-colour' and args.expect_renderer != 'gl_compatibility':
        parser.error('Shadow colour prototype requires Compatibility')
    if (args.texture_residency or args.battle_budget) and (args.hour != 12.0 or args.camera_view != 'default' or args.shadow_casters or args.no_caster_shadows):
        parser.error('Render options are limited to the arena diagnostic')
    if args.battle_resolution != '960x540' and not (args.battle_budget and args.expect_renderer == 'gl_compatibility'):
        parser.error('Custom resolution is limited to the full GLES battle diagnostic')
    global PACKAGE
    prefix = 'android-texture-residency' if args.texture_residency else ('android-battle-budget' if args.battle_budget else 'android-arena')
    if args.texture_residency and (args.expect_renderer != 'mobile' or args.lighting_mode != 'baseline'):
        parser.error('Texture residency requires Mobile and baseline lighting')
    if args.battle_budget:
        if args.variant != 'android-etc2-art' or args.expect_renderer not in {'mobile', 'gl_compatibility'} or args.lighting_mode != 'baseline':
            parser.error('Battle budget requires ETC2, an explicit renderer and baseline lighting')
        PACKAGE = 'com.pokeaether.android3dpilot'
    if not 60 <= args.timeout <= 1800:
        parser.error('Timeout must be 60..1800 seconds')
    assets, apk, output = [p.resolve() for p in [args.assets, args.apk, args.output]]
    for p in [assets, apk, output]:
        p.relative_to(ROOT / '.tmp')
    if not (assets / '.android-arena-export').exists():
        raise ValueError('Expected owned arena export')
    report = json.loads((assets / 'report.json').read_text())
    pins = {k: {key: v[key] for key in ['bytes', 'sha256']} for k, v in report['candidates'].items()}
    if args.texture_residency:
        for name, pin in pins.items():
            pin['textures'] = report['candidates'][name]['textures']
    (assets / 'fixture.json').write_text(json.dumps(pins))
    aapt = sorted((args.sdk / 'build-tools').glob('*/aapt2'))[-1]
    metadata = subprocess.check_output([str(aapt), 'dump', 'badging', str(apk)], text=True)
    if "package: name='" + PACKAGE + "'" not in metadata or 'application-debuggable' not in metadata:
        raise ValueError('Only the separate arena debug APK is allowed')
    with ZipFile(apk) as archive:
        libs = [n for n in archive.namelist() if n.startswith('lib/')]
        if not libs or any(not n.startswith('lib/x86_64/') for n in libs):
            raise ValueError('Requires the local x86_64 emulator APK')
    output.mkdir(parents=True, exist_ok=True)
    adb = str(args.sdk / 'platform-tools/adb')
    def device(*cmd, check=True, binary=False, input=None):
        return subprocess.run([adb, '-s', SERIAL, *cmd], timeout=45, check=check,
                              capture_output=True, text=not binary, input=input)
    if device('emu', 'avd', 'name').stdout.splitlines()[0] != 'PokeAether_Android13':
        raise ValueError('Refusing another device')
    handler = partial(QuietHandler, directory=str(assets))
    server = ThreadingHTTPServer(('127.0.0.1', 8799), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt('Arena diagnostic interrupted; removing loopback fixture')
    signal.signal(signal.SIGTERM, interrupted)
    summaries = []
    try:
        if args.battle_budget or args.texture_residency:
            capabilities = device('shell', 'cmd', 'gpu', 'vkjson', check=False)
            if capabilities.returncode == 0:
                (output / 'vulkan-capabilities.json').write_text(capabilities.stdout)
        device('reverse', 'tcp:8799', 'tcp:8799')
        # Repeated image probes need not stage another identical large APK.
        # Reuse only the exact verified debug package, never a version match.
        with apk.open('rb') as stream:
            apk_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
        installed = device('shell', 'pm', 'path', PACKAGE, check=False).stdout.strip().splitlines()
        reuse_apk = False
        if len(installed) == 1 and installed[0].startswith('package:/data/app/'):
            installed_path = installed[0].removeprefix('package:')
            if '/' + PACKAGE + '-' in installed_path and installed_path.endswith('/base.apk'):
                digest = device('shell', 'sha256sum', installed_path, check=False)
                words = digest.stdout.split()
                reuse_apk = digest.returncode == 0 and bool(words) and words[0] == apk_hash
        if not reuse_apk:
            install = device('install', '--no-incremental', '-r', str(apk), check=False)
            if install.returncode != 0:
                raise RuntimeError('Debug APK install failed: ' + install.stdout.strip() + ' ' + install.stderr.strip())
        (output / 'installation.json').write_text(json.dumps({'package': PACKAGE, 'apk_sha256': apk_hash, 'reused_exact_apk': reuse_apk}, indent=2))
        for variant in ([args.variant] if args.variant else ['desktop-art', 'android-etc2-art']):
            folder = output / variant
            folder.mkdir(exist_ok=True)
            device('shell', 'am', 'force-stop', PACKAGE)
            captures = [] if args.texture_residency else (['normal', 'shiny', 'sleep', 'effect', 'large', 'reused'] if args.battle_budget else ['capture'])
            if args.battle_budget and args.expect_renderer == 'gl_compatibility':
                captures += ['evening', 'night']
            stale = [f'files/{prefix}-{name}' for name in ['details.json','results.json','phase']] + [f'files/{prefix}-{name}.png' for name in captures]
            device('shell', 'run-as', PACKAGE, 'rm', '-f', *stale)
            # Literal controlled names only; no user text in a remote shell.
            device('shell', 'run-as', PACKAGE, 'mkdir', '-p', 'files')
            device('shell', 'run-as', PACKAGE, 'sh', '-c', f"'echo {variant} > files/android-arena-variant'")
            device('shell', 'run-as', PACKAGE, 'sh', '-c', f"'echo {args.lighting_mode} > files/android-arena-lighting'")
            if args.battle_budget:
                device('shell', 'run-as', PACKAGE, 'tee', 'files/android-battle-budget-resolution.json', input=json.dumps(args.battle_resolution))
            if not (args.texture_residency or args.battle_budget):
                options = {'hour': args.hour, 'camera': args.camera_view, 'shadow_casters': args.shadow_casters, 'caster_shadows': not args.no_caster_shadows}
                device('shell', 'run-as', PACKAGE, 'tee', 'files/android-arena-probe-options.json', input=json.dumps(options))
            device('shell', 'am', 'start', '-n', PACKAGE + '/com.godot.game.GodotAppLauncher')
            deadline = time.monotonic() + args.timeout
            memory = []
            while time.monotonic() < deadline:
                done = device('shell', 'run-as', PACKAGE, 'cat', f'files/{prefix}-results.json', check=False)
                if done.returncode == 0:
                    break
                pid = device('shell', 'pidof', PACKAGE, check=False).stdout.strip()
                if pid:
                    log = device('logcat', '--pid=' + pid, '-d', '-v', 'brief', 'godot:V', '*:S').stdout
                    (folder / 'native.log').write_text(log)
                    if any('SCRIPT ERROR:' in line or '): ERROR:' in line for line in log.splitlines()):
                        raise RuntimeError('Native diagnostic errors; see ' + str(folder / 'native.log'))
                status = device('shell', 'dumpsys', 'meminfo', PACKAGE, check=False).stdout
                pss = re.search(r'TOTAL PSS:\s*(\d+)', status)
                rss = re.search(r'TOTAL RSS:\s*(\d+)', status)
                phase = device('shell', 'run-as', PACKAGE, 'cat', f'files/{prefix}-phase', check=False).stdout.strip() if (args.battle_budget or args.texture_residency) else ''
                memory.append({'phase': phase, 'time': time.time(), 'pss_kib': int(pss[1]) if pss else 0, 'rss_kib': int(rss[1]) if rss else 0})
                (folder / 'memory.json').write_text(json.dumps(memory, indent=2))
                time.sleep(2)
            else:
                raise TimeoutError('Arena test timed out: ' + variant)
            details = json.loads(device('shell', 'run-as', PACKAGE, 'cat', f'files/{prefix}-details.json').stdout)
            (folder / 'details.json').write_text(json.dumps(details, indent=2))
            (folder / 'result.json').write_text(done.stdout)
            pid = device('shell', 'pidof', PACKAGE).stdout.strip()
            log = device('logcat', '--pid=' + pid, '-d', '-v', 'brief', 'godot:V', '*:S').stdout
            (folder / 'native.log').write_text(log)
            missing_captures = []
            for name in captures:
                capture = device('exec-out', 'run-as', PACKAGE, 'cat', f'files/{prefix}-{name}.png', binary=True, check=False)
                if capture.returncode == 0 and capture.stdout.startswith(b'\x89PNG'):
                    (folder / (name + '.png')).write_bytes(capture.stdout)
                else:
                    missing_captures.append(name)
            native_errors = [line for line in log.splitlines() if 'SCRIPT ERROR:' in line or '): ERROR:' in line]
            codes = json.loads(done.stdout)
            success = (not missing_captures and not native_errors and details.get('success', False) and bool(codes) and all(v == 0 for v in codes.values())
                       and (not args.expect_renderer or details.get('renderer') == args.expect_renderer))
            if args.battle_budget:
                expected = ['autoloads','forest-resources','arena-main','arena-response','arena-suspended',
                            'battle-normal','battle-shiny','battle-sleep','battle-mega','battle-after-effect',
                            'battle-large','battle-released','battle-reused']
                if args.expect_renderer == 'gl_compatibility':
                    expected[6:6] = ['battle-evening', 'battle-night']
                requested = [int(value) for value in args.battle_resolution.split('x')]
                success = success and details.get('requested_render_size') == requested
                success = success and all(p.get('render_size') == requested and (not p.get('response_size') or p['response_size'] == requested) for p in details.get('phases', []) if p['label'].startswith('battle-') and p['label'] != 'battle-released')
                success = success and details.get('suite') == 'android-battle-budget' and [p['label'] for p in details.get('phases', [])] == expected
            if args.texture_residency:
                cases = details.get('cases', [])
                success = success and details.get('suite') == 'android-texture-residency' and len(cases) == 42
                if cases:
                    success = success and all(row.get('rgba_control', {}).get('roundtrip_exact') and row.get('rgba_control', {}).get('released_delta_bytes') == 0 for row in cases)
                    success = success and all(not row.get('supported') or (row.get('encoded', {}).get('roundtrip_exact') and row.get('encoded', {}).get('released_delta_bytes') == 0) for row in cases)
                    success = success and all(row.get('supported') for row in cases)
            summary = {'variant': variant, 'success': success, 'peak_pss_kib': max((m['pss_kib'] for m in memory), default=0),
                       'peak_rss_kib': max((m['rss_kib'] for m in memory), default=0), 'expected_renderer': args.expect_renderer, 'native_errors': native_errors, 'missing_captures': missing_captures, 'details': details}
            summaries.append(summary)
            (output / 'summary.json').write_text(json.dumps(summaries, indent=2))
            brief = {key: value for key, value in summary.items() if key != "details"}
            brief["cases"] = len(details.get("cases", details.get("phases", [])))
            print(json.dumps(brief), flush=True)
            if not success:
                raise RuntimeError('Diagnostic failed: ' + variant)
    finally:
        try:
            for command in [('shell', 'am', 'force-stop', PACKAGE), ('reverse', '--remove', 'tcp:8799')]:
                try:
                    device(*command, check=False)
                except subprocess.TimeoutExpired:
                    print('Emulator unavailable during cleanup:', command[0], flush=True)
        finally:
            server.shutdown()
            server.server_close()

if __name__ == '__main__':
    main()
