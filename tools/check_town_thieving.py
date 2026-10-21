#!/usr/bin/env python3
"""Check ordinary outdoor town dialogue NPCs against the paired Thieving authority.

Usage: python tools/check_town_thieving.py ../backend
New town dialogue placements must join the shared catalog before integration.
"""
import json
from pathlib import Path
import re
import sys


def properties(text):
    return dict(re.findall(r'^(\w+) = "([^"]*)"', text, re.M))


def resource_paths(text):
    return dict((key, value) for value, key in re.findall(
        r'\[ext_resource [^\n]*path="([^"]+)" id="([^"]+)"\]', text))


def check(backend):
    frontend = Path(__file__).resolve().parents[1]
    targets = json.loads((backend / 'game-content/data/thieving/targets.json').read_text())["targets"]
    npcs = {npc['id']: npc for path in (backend / 'game-content/data/npcs').rglob('*.json')
            for npc in json.loads(path.read_text()).get('npcs', [])}

    def scene_script(resource):
        text = (frontend / resource.removeprefix('res://')).read_text()
        refs = resource_paths(text)
        root = re.split(r'(?=^\[node )', text, flags=re.M)[1]
        match = re.search(r'^script = ExtResource\("([^"]+)"\)', root, re.M)
        return refs[match[1]] if match else ''

    placed = set()
    errors = []
    for path in (frontend / 'scenes/overworld/kanto/towns').glob('*/*.tscn'):
        if path.stem != path.parent.name:
            continue  # Only the town's outdoor map, never buildings.
        text = path.read_text()
        refs = resource_paths(text)
        map_id = properties(text).get('map_id', 'kanto_' + path.stem)
        for block in re.split(r'(?=^\[node )', text, flags=re.M)[1:]:
            props = properties(block)
            npc_id = props.get('npc_id', '')
            if npcs.get(npc_id, {}).get('type') not in ('dialogue', 'item_gift'):
                continue
            script = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
            instance = re.search(r'instance=ExtResource\("([^"]+)"\)', block.splitlines()[0])
            script_path = refs[script[1]] if script else scene_script(refs[instance[1]]) if instance else ''
            if script_path != 'res://scripts/world/npcs/dialogue_npc.gd':
                continue  # Quest handlers, services and trainers have specialized roles.
            placed.add(npc_id)
            profile = targets.get(npc_id, {})
            if map_id != profile.get('mapId'):
                errors.append(f'{path.name}: {npc_id} missing Thieving map {map_id}')
    for npc_id, profile in targets.items():
        if npc_id not in placed:
            errors.append(f'{npc_id}: catalog target has no town dialogue placement')
    for locale in ('en', 'nl', 'pt_BR', 'zh_CN'):
        translations = json.loads((frontend / f'localization/{locale}.json').read_text())
        for profile in targets.values():
            for field in ('nameKey', 'townKey', 'locationKey'):
                if not translations.get(profile[field]):
                    errors.append(f'{locale}: missing {profile[field]}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'TOWN_THIEVING PASS: {len(placed)} ordinary outdoor dialogue NPCs; four locales complete')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
