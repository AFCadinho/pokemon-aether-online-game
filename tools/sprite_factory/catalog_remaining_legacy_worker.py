"""Inspect one archived Biochao source without rendering or executing blend scripts."""

import hashlib
import json
import re
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from phase5_review_actions import candidates
from source_review_rigs import equivalent_action_names, isolate


def main(job_path):
    job = json.loads(job_path.read_text())
    source = Path(job["source"])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job["source_sha256"]:
        raise ValueError("Archived source hash changed before inspection")
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    if job.get('diagnostic_variant_inventory'):
        from source_review_rigs import material_images, image_identity
        variants=[]
        for rig in [o for o in bpy.context.scene.objects if o.type=='ARMATURE']:
            meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers)]
            images={n for o in meshes for m in o.data.materials if m for n in material_images(m.node_tree)}
            variants.append({'rig':rig.name,'textures':sorted({image_identity(n) for n in images if image_identity(n)}),
                             'meshes':[o.name for o in meshes],'parent':rig.parent.name if rig.parent else None,
                             'constraints':[str(c.type) for c in rig.constraints]})
        Path(job['output']).write_text(json.dumps({'source_sha256':job['source_sha256'],'variants':variants},indent=2)+'\n')
        return
    rig, selection = isolate(source, job.get('diagnostic_rig_selection'))
    names = equivalent_action_names(bpy.data.actions)
    possible = candidates(names, bank=job.get("animation_bank"))
    bank_candidates = {str(bank): candidates(names, bank=bank) for bank in range(3)}
    second_physical = [name for name in names if re.search(r"_(?:attack02|ba20_buturi02)(?:\.|$)", name, re.I)]
    materials = sorted({slot.material.name for mesh in bpy.data.objects if mesh.type == "MESH"
                        for slot in mesh.material_slots if slot.material})
    images = sorted(image.name for image in bpy.data.images if image.type == "IMAGE")
    report = {
        "schema": 1,
        "species": job["species"],
        "source_sha256": job["source_sha256"],
        "source_archive": job["archive"],
        "source_member": job["member"],
        "scope": "source_structure_only_no_visual_or_runtime_approval",
        "rig_selection": selection,
        "rig_name": rig.name,
        "mesh_count": sum(obj.type == "MESH" for obj in bpy.data.objects),
        "material_count": len(materials),
        "image_count": len(images),
        "image_names": images,
        "action_count": len(names),
        "action_names": names,
        "action_candidates": possible,
        "action_candidates_by_bank": bank_candidates,
        "second_physical_candidates": second_physical,
        "unambiguous_actions": {key: value[0] for key, value in possible.items() if len(value) == 1},
        "missing_or_ambiguous_actions": [key for key, value in possible.items() if len(value) != 1],
    }
    Path(job["output"]).write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[sys.argv.index("--") + 1]))
