"""Prepare the pinned MIT forest in an isolated Godot project, excluding audio.

No player/editor plugins, source blend files, easter egg or upstream game scripts.
TerraBrush is required by the authored terrain and stays in this isolated project.
"""
import argparse
import concurrent.futures
import hashlib
import json
import re
import urllib.request
from pathlib import Path

REPO = 'Scaryrocker8/godot-stylized-forest'
REV = 'e2b6b26b9efb65615071ca3b7b4e4cd573af74b7'

def fetch(url):
    with urllib.request.urlopen(url, timeout=45) as response:
        return response.read()

def selected(path):
    if path.endswith(('.import', '.depren')):
        return False
    if path in ('LICENSE', 'CREDITS', 'scenes/levels/forest.tscn'):
        return True
    return (path.startswith(('assets/glb/tree/', 'assets/glb/rocks/', 'assets/glb/grass/',
                             'assets/glb/lavender/', 'resources/', 'scenes/objects/rocks/'))
            or path in ('scenes/objects/tree.tscn', 'assets/jpg/rock.jpg',
                        'assets/blend/tree/textures/leaves_albedo.png')
            or (path.startswith('addons/terrabrush/') and not path.startswith('addons/terrabrush/CSharpWrapper/')
                and ('/bin/' not in path or 'linux.debug.x86_64.so' in path)))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    source = Path(__file__).resolve().parents[2]
    if output.is_relative_to(source):
        raise ValueError('Keep the environment and native dependency outside the client')
    output.mkdir(parents=True, exist_ok=False)
    tree = json.loads(fetch(f'https://api.github.com/repos/{REPO}/git/trees/{REV}?recursive=1'))
    assert not tree.get('truncated')
    entries = [e for e in tree['tree'] if e['type'] == 'blob' and selected(e['path'])]
    def download(entry):
        path = entry['path']
        assert not Path(path).is_absolute() and '..' not in Path(path).parts
        data = fetch(f'https://raw.githubusercontent.com/{REPO}/{REV}/{path}')
        assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest() == entry['sha']
        target = output/path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return {'path': path, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        records = list(pool.map(download, entries))
    # Remove unused external resources, executable script blocks and demo nodes.
    forest = output/'scenes/levels/forest.tscn'
    text = forest.read_text()
    blocks = re.split(r'(?=^\[)', text, flags=re.M)
    kept = []
    for block in blocks:
        header = block.split('\n', 1)[0]
        if header.startswith('[ext_resource') and any(s in header for s in ['type="Script"', 'type="AudioStream"', 'jonnies_first_person', 'butterfly']):
            continue
        if header.startswith('[sub_resource type="GDScript"') or header.startswith('[connection'):
            continue
        if header.startswith('[node') and not any(f'name="{name}"' in header for name in ['Forest', 'TerraBrush']):
            continue
        if header.startswith('[node name="Forest"'):
            block = '[node name="Forest" type="Node3D"]\n\n'
        kept.append(block)
    # Bird-only resources are not used by the retained terrain.
    text = ''.join(kept)
    text = re.sub(r'\[sub_resource type="(?:ParticleProcessMaterial|ShaderMaterial|PlaneMesh)"[^\n]*\n.*?(?=\[|\Z)', '', text, flags=re.S)
    forest.write_text(text)
    for path in output.rglob('*.tscn'):
        path.write_text(re.sub(r' uid="[^"]+"', '', path.read_text()))
    # Explicit source-code packaging, not cache/userdata copying.
    for relative in ['scripts/battle/battle_ui/material_response.gd',
                     'scripts/battle/battle_ui/material_response.gdshader',
                     'scripts/battle/battle_ui/material_irradiance.gdshader',
                     'tools/sprite_factory/forest_battle_review.gd']:
        target = output/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text((source/relative).read_text())
    (output/'TERRABRUSH-LICENSE').write_bytes(fetch('https://raw.githubusercontent.com/spimort/TerraBrush/master/LICENSE'))
    (output/'ROCKS-LICENSE.txt').write_text('Low Poly Rocks — Michael Hooper\nhttps://sketchfab.com/3d-models/low-poly-rocks-9823ec262054408dbe26f6ddb9c0406e\nCC BY 4.0 — https://creativecommons.org/licenses/by/4.0/\nMaterials/placement adapted by upstream; PokeAether review uses neutral lighting.\n')
    (output/'project.godot').write_text('config_version=5\n[application]\nconfig/name="PokeAether Forest Review"\nconfig/features=PackedStringArray("4.6", "Forward Plus")\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="forward_plus"\n')
    (output/'provenance.json').write_text(json.dumps({'repository': REPO, 'revision': REV,
        'files': records, 'excluded': ['audio', 'player plugin', 'upstream scripts', 'easter egg', 'source blends'],
        'notes': ['MIT scene; CC0 leaf shader by Emerson Rowland; CC-BY rocks by Michael Hooper; MIT TerraBrush',
                  'Scene terrain preserved; neutral lighting supplied by review; not a game integration']}, indent=2))
    print(f'Prepared {len(records)} verified source files, {sum(e["bytes"] for e in records)/1048576:.2f} MiB: {output}')

if __name__ == '__main__':
    main()
