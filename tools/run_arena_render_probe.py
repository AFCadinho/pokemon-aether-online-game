#!/usr/bin/env python3
"""Render only the arena dependencies in a slot, with no game autoloads.
Temporary project edits are restored. Packs/caches are never copied.
"""
import argparse
import os
from pathlib import Path
import re
import signal
import subprocess
ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--texture-residency', action='store_true', help='Direct RD allocations and readbacks instead of an arena render')
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--renderer', choices=['forward_plus','mobile','gl_compatibility'], required=True)
    parser.add_argument('--lighting-mode', choices=['baseline','hdr','sun-only','unshaded-grass','diffuse-grass','ambient-only','no-shadows','ground-srgb','ground-srgb-no-shadows','smooth-grass','shadow-colour','runtime-colour'], default='baseline')
    parser.add_argument('--hour', type=float, default=12.0)
    parser.add_argument('--camera-view', choices=['default','side'], default='default')
    parser.add_argument('--shadow-casters', action='store_true', help='Calibration objects for ground and grass shadows')
    parser.add_argument('--no-caster-shadows', action='store_true', help='Disable only calibration-object shadows for a comparison')
    args = parser.parse_args()
    if args.texture_residency and args.renderer == "gl_compatibility":
        parser.error("Texture allocation probe requires Vulkan (Mobile or Forward+)")
    if not 0 <= args.hour < 24:
        parser.error('Hour must be finite and in [0, 24)')
    if (args.lighting_mode.startswith('ground-srgb') or args.lighting_mode == 'shadow-colour') and args.renderer != 'gl_compatibility':
        parser.error('Colour investigation modes require Compatibility')
    if ROOT.parent.name.startswith('slot-') and os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Run through slot-env')
    manifest, output = args.manifest.resolve(), args.output.resolve()
    for p in [manifest, output]:
        p.relative_to(ROOT / '.tmp')
    output.mkdir(parents=True, exist_ok=True)
    project = ROOT / 'project.godot'
    original = project.read_bytes()
    config = original.decode()
    config = re.sub(r'\[autoload\].*?(?=\n\[)', '', config, flags=re.S)
    # Remove EditorPlugin initialization as well; no authored resources change.
    config = re.sub(r'\[editor_plugins\].*?(?=\n\[)', '', config, flags=re.S)
    def interrupt(_signal, _frame):
        raise KeyboardInterrupt('Render probe interrupted; restoring project')
    signal.signal(signal.SIGTERM, interrupt)
    try:
        project.write_text(config)
        with (output/'render.log').open('w') as log:
            test = 'res://tests/android_texture_residency_check.gd' if args.texture_residency else 'res://tests/android_arena_asset_check.gd'
            probe_args = [str(manifest.parent/'forest.pck'), str(manifest.parent/'texture-list.json'), str(output/'details.json')] if args.texture_residency else [str(manifest),str(output/'details.json'),args.lighting_mode,str(args.hour),args.camera_view,str(args.shadow_casters).lower(),str(not args.no_caster_shadows).lower()]
            child = subprocess.Popen(['godot','--path',str(ROOT),'--rendering-method',args.renderer,
                                      '--resolution','960x540','--script',test,'--',*probe_args],stdout=log,stderr=subprocess.STDOUT)
            try:
                code = child.wait(timeout=90)
                if code:
                    raise subprocess.CalledProcessError(code,child.args)
            except BaseException:
                child.terminate()
                try:child.wait(timeout=10)
                except subprocess.TimeoutExpired:child.kill();child.wait()
                raise
        # Include late render-resource teardown errors outside the script report.
        log_text = (output/'render.log').read_text(errors='replace')
        if re.search(r'^(?:SCRIPT ERROR:|ERROR:)', log_text, re.M):
            raise RuntimeError('Render probe logged errors; inspect ' + str(output/'render.log'))
    finally:
        project.write_bytes(original)
    print('Arena-only render probe complete:',output)
if __name__ == '__main__':
    main()
