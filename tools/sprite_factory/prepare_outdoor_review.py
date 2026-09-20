"""Fetch a pinned GDQuest outdoor scene into a disposable standalone project.

Art is CC-BY-NC-SA-4.0: local noncommercial evaluation only, not game assets.
No upstream scripts are executed. Generated project has no plugins/autoloads.
"""
import argparse
import concurrent.futures
import hashlib
import json
import re
import urllib.request
from pathlib import Path

REV = '844195660246ed6b232a0e0fe7e48c94072f24ea'
REPO = 'gdquest-demos/godot-4-new-features'


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.is_relative_to(Path(__file__).resolve().parents[2]):
        raise ValueError('Keep noncommercial environment assets outside the frontend project')
    output.mkdir(parents=True, exist_ok=False)
    tree = json.loads(fetch(f'https://api.github.com/repos/{REPO}/git/trees/{REV}?recursive=1'))
    assert not tree.get('truncated')
    selected = [e for e in tree['tree'] if e['type'] == 'blob' and
                (e['path'].startswith('outdoor_environment/') or e['path'] == 'LICENSE')]

    def download(entry):
        path = entry['path']
        assert '..' not in Path(path).parts and not Path(path).is_absolute()
        content = fetch(f'https://raw.githubusercontent.com/{REPO}/{REV}/{path}')
        assert hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest() == entry['sha'], path
        destination = output / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
        return dict(path=path, sha256=hashlib.sha256(content).hexdigest(), bytes=len(content))

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        records = list(pool.map(download, selected))
    scene = output / 'outdoor_environment/outdoor_environment.tscn'
    content = scene.read_text()
    # Remove the playable Sophie controller and all upstream script attachments.
    content = re.sub(r'^\[ext_resource[^\n]*(?:type="Script"|sophie_character_controller)[^\n]*\n', '', content, flags=re.M)
    content = re.sub(r'^script = ExtResource\([^\n]*\n', '', content, flags=re.M)
    blocks = re.split(r'(?=^\[node )', content, flags=re.M)
    content = ''.join(b for b in blocks if 'instance=ExtResource("16_qfqdn")' not in b.split('\n')[0])
    content = re.sub(r' uid="[^"]+"', '', content, count=1)
    scene.rename(scene.with_suffix('.tscn.upstream'))
    # Upstream grass OBJ names an absent MTL; Godot scene supplies its material.
    for obj in output.rglob('*.obj'):
        lines = obj.read_text().splitlines(keepends=True)
        obj.write_text(''.join(line for line in lines if not
            (line.startswith('mtllib ') and not (obj.parent / line[7:].strip()).exists())))
    (output / 'outdoor_review.tscn').write_text(content)
    (output / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="PokeAether Outdoor Study (noncommercial)"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (output / 'provenance.json').write_text(json.dumps(dict(repository=REPO, revision=REV,
        license='Code MIT; art CC-BY-NC-SA-4.0', files=records,
        modifications=['Outdoor root scene: removed Sophie and script attachments; upstream preserved as .tscn.upstream',
                       'Removed OBJ references to absent MTL files']), indent=2))
    print(f'Prepared {len(records)} verified files ({sum(e["bytes"] for e in records)/1048576:.2f} MiB) in {output}')


if __name__ == '__main__':
    main()
