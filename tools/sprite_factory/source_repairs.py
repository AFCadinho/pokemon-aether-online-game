"""Narrow, hash-bound authored repairs. Never edits the original source file."""
import json
from pathlib import Path


def decision(digest, actions):
    actions = set(actions)
    data = json.loads(Path(__file__).with_name('reviewed_source_repairs.json').read_text())
    found = [r for r in data['repairs'] if r['source_sha256'] == digest]
    if len(found) > 1:
        raise ValueError('Ambiguous source repair')
    if not found:
        return None
    repair = found[0]
    if not actions or actions - set(repair['allowed_actions']):
        raise ValueError('Source repair does not cover this animation set; explicit visibility review required')
    return repair


def apply(digest, actions):
    import bpy
    repair = decision(digest, actions)
    if repair is None:
        return None
    objects = [bpy.data.objects.get(name) for name in repair['exclude_meshes']]
    if any(o is None or o.type != 'MESH' for o in objects):
        raise ValueError('Reviewed repair meshes changed')
    for obj in objects:
        bpy.data.objects.remove(obj, do_unlink=True)
    return repair
