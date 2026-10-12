"""Import the own marked tea model and bind source-pinned identical-rig actions."""
import hashlib
import json
import re
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blender_action_state import select_action
from scvi_import_worker import main as import_source


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def bones(rig):
    return [{"name": b.name, "parent": b.parent.name if b.parent else None,
             "matrix": [list(row) for row in b.matrix_local],
             "inherit_scale": b.inherit_scale, "deform": b.use_deform}
            for b in rig.data.bones]


def run(job):
    for path, digest in job["source_files"].items():
        assert sha(path) == digest, path
    assert sha(job["donor"]) == job["donor_sha256"]
    assert not Path(job["prepared"]).exists()
    import_source(job)
    own, = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    with bpy.data.libraries.load(job["donor"], link=False) as (source, target):
        assert job["donor_rig"] in source.objects
        assert set(job["actions"].values()) <= set(source.actions)
        target.objects = [job["donor_rig"]]
        target.actions = list(job["actions"].values())
    donor, = target.objects
    own_bones = bones(own)
    donor_bones = bones(donor)
    Path(job['binding_report']).with_name('bone-comparison.json').write_text(json.dumps(
        {'own': own_bones, 'donor': donor_bones}, indent=2) + '\n')
    # The importer also creates Blender bones for native non-bone nodes.
    # Translate only the exact source-proven names, never bind by array position.
    remap = job['donor_to_own_nodes']
    normalized = [{**b, 'name': remap.get(b['name'], b['name']),
                   'parent': remap.get(b['parent'], b['parent'])} for b in donor_bones]
    assert own_bones == normalized, "Imported bones/bind matrices differ after the proven node-name mapping"
    source_bones_sha = hashlib.sha256(json.dumps(own_bones, sort_keys=True).encode()).hexdigest()
    bpy.data.objects.remove(donor, do_unlink=True)
    remapped_curves = 0
    for action in target.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        match = re.match(r'^pose\.bones\["([^"]+)"\]', curve.data_path)
                        if match and match[1] in remap:
                            curve.data_path = 'pose.bones[' + json.dumps(remap[match[1]]) + ']' + curve.data_path[match.end():]
                            remapped_curves += 1
        action.use_fake_user = True
    bpy.context.scene.render.fps = job["fps"]
    bpy.context.scene.render.fps_base = 1
    select_action(own, bpy.data.actions[job["actions"]["idle"]])
    bpy.context.scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=job["prepared"], check_existing=False)
    report = {"source_import_sha256": sha(job["report"]), "source_files": job["source_files"],
              "donor_sha256": job["donor_sha256"], "worker_sha256": sha(__file__),
              "prepared_sha256": sha(job["prepared"]), "bones_sha256": source_bones_sha,
              "bone_count": len(own_bones), "bones_and_bind_matrices_exact": True,
              "donor_to_own_nodes": remap, "renamed_non_bone_node_curves": remapped_curves,
              "actions": job["actions"], "fps": job["fps"], "runtime_approved": False}
    Path(job["binding_report"]).write_text(json.dumps(report, indent=2) + "\n")
    print("TEA_SOURCE_BINDING_OK", job["species"], len(own_bones), flush=True)


if __name__ == "__main__":
    run(json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text()))
