#!/usr/bin/env python3
"""Compare only this task's two hash-pinned packs on the fixed debug emulator.
Serve owned assets on loopback with adb reverse; never modify the normal game.
"""
import argparse
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
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sdk', type=Path, default=Path.home() / 'Android/Sdk')
    parser.add_argument('--lighting-mode', choices=['baseline', 'hdr', 'sun-only'], default='baseline')
    parser.add_argument('--expect-renderer', choices=['gl_compatibility', 'mobile'])
    parser.add_argument('--variant', choices=['desktop-art', 'android-etc2-art'])
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    if not 60 <= args.timeout <= 1800:
        parser.error('Timeout must be 60..1800 seconds')
    assets, apk, output = [p.resolve() for p in [args.assets, args.apk, args.output]]
    for p in [assets, apk, output]:
        p.relative_to(ROOT / '.tmp')
    if not (assets / '.android-arena-export').exists():
        raise ValueError('Expected owned arena export')
    report = json.loads((assets / 'report.json').read_text())
    pins = {k: {key: v[key] for key in ['bytes', 'sha256']} for k, v in report['candidates'].items()}
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
    def device(*cmd, check=True, binary=False):
        return subprocess.run([adb, '-s', SERIAL, *cmd], timeout=45, check=check,
                              capture_output=True, text=not binary)
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
        device('reverse', 'tcp:8799', 'tcp:8799')
        device('install', '--no-incremental', '-r', str(apk))
        for variant in ([args.variant] if args.variant else ['desktop-art', 'android-etc2-art']):
            folder = output / variant
            folder.mkdir(exist_ok=True)
            device('shell', 'am', 'force-stop', PACKAGE)
            device('shell', 'run-as', PACKAGE, 'rm', '-f', 'files/android-arena-details.json', 'files/android-arena-results.json', 'files/android-arena-capture.png')
            # Literal controlled names only; no user text in a remote shell.
            device('shell', 'run-as', PACKAGE, 'mkdir', '-p', 'files')
            device('shell', 'run-as', PACKAGE, 'sh', '-c', f"'echo {variant} > files/android-arena-variant'")
            device('shell', 'run-as', PACKAGE, 'sh', '-c', f"'echo {args.lighting_mode} > files/android-arena-lighting'")
            device('shell', 'am', 'start', '-n', PACKAGE + '/com.godot.game.GodotAppLauncher')
            deadline = time.monotonic() + args.timeout
            memory = []
            while time.monotonic() < deadline:
                done = device('shell', 'run-as', PACKAGE, 'cat', 'files/android-arena-results.json', check=False)
                if done.returncode == 0:
                    break
                pid = device('shell', 'pidof', PACKAGE, check=False).stdout.strip()
                if pid:
                    log = device('logcat', '--pid=' + pid, '-d', '-v', 'brief', 'godot:V', '*:S').stdout
                    (folder / 'native.log').write_text(log)
                status = device('shell', 'dumpsys', 'meminfo', PACKAGE, check=False).stdout
                pss = re.search(r'TOTAL PSS:\s*(\d+)', status)
                rss = re.search(r'TOTAL RSS:\s*(\d+)', status)
                memory.append({'time': time.time(), 'pss_kib': int(pss[1]) if pss else 0, 'rss_kib': int(rss[1]) if rss else 0})
                (folder / 'memory.json').write_text(json.dumps(memory, indent=2))
                time.sleep(2)
            else:
                raise TimeoutError('Arena test timed out: ' + variant)
            details = json.loads(device('shell', 'run-as', PACKAGE, 'cat', 'files/android-arena-details.json').stdout)
            (folder / 'details.json').write_text(json.dumps(details, indent=2))
            (folder / 'result.json').write_text(done.stdout)
            pid = device('shell', 'pidof', PACKAGE).stdout.strip()
            log = device('logcat', '--pid=' + pid, '-d', '-v', 'brief', 'godot:V', '*:S').stdout
            (folder / 'native.log').write_text(log)
            (folder / 'capture.png').write_bytes(device('exec-out', 'run-as', PACKAGE, 'cat', 'files/android-arena-capture.png', binary=True).stdout)
            native_errors = [line for line in log.splitlines() if 'SCRIPT ERROR:' in line or '): ERROR:' in line]
            codes = json.loads(done.stdout)
            success = (not native_errors and details.get('success', False) and bool(codes) and all(v == 0 for v in codes.values())
                       and (not args.expect_renderer or details.get('renderer') == args.expect_renderer))
            summary = {'variant': variant, 'success': success, 'peak_pss_kib': max((m['pss_kib'] for m in memory), default=0),
                       'peak_rss_kib': max((m['rss_kib'] for m in memory), default=0), 'expected_renderer': args.expect_renderer, 'native_errors': native_errors, 'details': details}
            summaries.append(summary)
            (output / 'summary.json').write_text(json.dumps(summaries, indent=2))
            print(json.dumps(summary), flush=True)
            if not success:
                raise RuntimeError('Diagnostic failed: ' + variant)
    finally:
        try:
            device('shell', 'am', 'force-stop', PACKAGE, check=False)
            device('reverse', '--remove', 'tcp:8799', check=False)
        finally:
            server.shutdown()
            server.server_close()

if __name__ == '__main__':
    main()
