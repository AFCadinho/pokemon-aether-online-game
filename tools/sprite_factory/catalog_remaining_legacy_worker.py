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
    rig, selection = isolate(source)
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
