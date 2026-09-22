"""Read-only Blender source diagnostic; does not export or approve models.

Run in Blender with --python THIS_FILE -- EXPORT_JOB_DIRECTORY OUTPUT_JSON.
Uses the existing six-model source jobs and compares every listed alternative
against the chosen battle idle, without changing the production mapper.
"""
import hashlib
import json
import re
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_action_state import select_action
from scvi_import_worker import load_importer

SPECIES = ('garchomp', 'azumarill', 'flareon', 'gardevoir', 'forretress', 'gyarados')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pose(rig, action, fraction):
    select_action(rig, action)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj.animation_data:
            obj.animation_data_clear()
    frame = float(action.frame_range[0]) + fraction * float(action.frame_range[1] - action.frame_range[0])
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    result = []
    for obj in sorted(bpy.context.scene.objects, key=lambda x: x.name):
        if obj.type != 'MESH':
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        result.extend(evaluated.matrix_world @ vertex.co for vertex in mesh.vertices)
        evaluated.to_mesh_clear()
    return result


def delta(a, b):
    assert len(a) == len(b) and a
    return max((x - y).length for x, y in zip(a, b))


def main(directory, output):
    assert not output.exists(), 'Fresh output required'
    reports = []
    protected = {}
    importer_loaded = False
    for species in SPECIES:
        job_path = directory / species / 'job.json'
        job = json.loads(job_path.read_text())
        intake = job['identity_intake']
        blend = Path(job['source'])
        source_job = json.loads(blend.with_name('job.json').read_text())
        if not importer_loaded:
            sys.path.insert(0, source_job['python_deps'])
            load_importer(Path(source_job['importer']))
            importer_loaded = True
        from pokeaether_scvi_importer.gfbanm_importer import import_animation
        protected[str(blend)] = sha(blend)
        bpy.ops.wm.open_mainfile(filepath=str(blend))
        rigs = [obj for obj in bpy.data.objects if obj.type == 'ARMATURE']
        assert len(rigs) == 1
        rig = rigs[0]
        bpy.ops.object.select_all(action='DESELECT')
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        clips = {}
        for category, names in intake['alternatives'].items():
            for name in names:
                path = Path(intake['motion_dir']) / name
                protected[str(path)] = sha(path)
                if path.stem not in bpy.data.actions:
                    import_animation(bpy.context, str(path), False, 0, False, False)
                clips[path.stem] = category
        idle = pose(rig, bpy.data.actions[job['actions']['idle']], 0)
        height = max(v.z for v in idle) - min(v.z for v in idle)
        assert height > 0
        entries = []
        endpoints = {}
        for name, category in clips.items():
            action = bpy.data.actions[name]
            start, middle, end = [pose(rig, action, f) for f in (0, .5, 1)]
            endpoints[name] = (start, end)
            entries.append(dict(category=category, clip=name, selected=job['actions'][category] == name,
                                bank=int(re.search(r'_(\d)\d{4}_', name)[1]),
                                frame_range=list(action.frame_range),
                                entry_delta_per_height=delta(idle, start) / height,
                                exit_delta_per_height=delta(idle, end) / height,
                                movement_per_height=delta(start, middle) / height))
        idle_bank = int(re.search(r'_(\d)\d{4}_', job['actions']['idle'])[1])
        candidate = {}
        for category in job['actions']:
            matches = [e for e in entries if e['category'] == category and e['bank'] == idle_bank]
            if category == 'idle':
                candidate[category] = job['actions']['idle']
            elif len(matches) == 1:
                candidate[category] = matches[0]['clip']
            else:
                candidate[category] = None  # Never borrow another bank to fill a gap.
        joins = []
        for start in entries:
            if start['category'] != 'faint_start':
                continue
            for loop in entries:
                if loop['category'] == 'faint_loop' and loop['bank'] == start['bank']:
                    joins.append(dict(bank=start['bank'], max_vertex_delta_per_height=
                                      delta(endpoints[start['clip']][1], endpoints[loop['clip']][0]) / height))
        reports.append(dict(species=species, idle=job['actions']['idle'], clips=entries,
                            advisory_candidate=candidate, faint_joins=joins))
        print('POSTURE_REVIEW', species, flush=True)
    assert all(sha(path) == digest for path, digest in protected.items()), 'Source changed'
    output.write_text(json.dumps(dict(scope='Blender skeletal source diagnosis only; no model export',
                                     entries=reports, source_sha256=protected), indent=2) + '\n')


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    main(Path(args[0]), Path(args[1]))
