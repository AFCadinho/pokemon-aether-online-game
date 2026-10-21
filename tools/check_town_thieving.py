#!/usr/bin/env python3
"""Check placed town dialogue NPCs against the paired Thieving authority.

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
    classes = {}
    for script_path in (frontend / 'scripts').rglob('*.gd'):
        match = re.search(r'^class_name (\w+)', script_path.read_text(), re.M)
        if match:
            classes[match[1]] = 'res://' + str(script_path.relative_to(frontend))

    def is_dialogue_script(resource):
        if resource == 'res://scripts/world/npcs/dialogue_npc.gd':
            return True
        text = (frontend / resource.removeprefix('res://')).read_text()
        match = re.search(r'^extends (?:"([^"]+)"|(\w+))', text, re.M)
        parent = (match[1] or classes.get(match[2])) if match else None
        return bool(parent and is_dialogue_script(parent))

    def scene_script(resource):
        text = (frontend / resource.removeprefix('res://')).read_text()
        refs = resource_paths(text)
        root = re.split(r'(?=^\[node )', text, flags=re.M)[1]
        match = re.search(r'^script = ExtResource\("([^"]+)"\)', root, re.M)
        return refs[match[1]] if match else ''

    placed = set()
    errors = []
    for path in (frontend / 'scenes/overworld/kanto/towns').rglob('*.tscn'):
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
            if not script_path or not is_dialogue_script(script_path):
                continue  # Battle actors can still use dialogue-type story metadata.
            placed.add(npc_id)
            profile = targets.get(npc_id, {})
            if map_id not in profile.get('mapIds', [profile.get('mapId')]):
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
    print(f'TOWN_THIEVING PASS: {len(placed)} placed dialogue NPCs; four locales complete')


if __name__ == '__main__':
    check(Path(sys.argv[1]).resolve())
