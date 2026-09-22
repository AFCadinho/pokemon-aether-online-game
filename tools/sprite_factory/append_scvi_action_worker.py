"""Append one hash-pinned SCVI action to a copied prepared Blender source.

Run only through Blender in an isolated Flatpak.  The input source is opened
read-only and the result is always written to a different path.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _load_importer(path: Path):
    spec = importlib.util.spec_from_file_location(
        "pokeaether_scvi_importer", path / "__init__.py",
        submodule_search_locations=[str(path)],
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _action_summary(action) -> dict:
    return {
        "name": action.name,
        "frame_range": [float(value) for value in action.frame_range],
        "slots": [slot.identifier for slot in action.slots],
    }


def run(job: dict) -> None:
    source = Path(job["source"])
    output = Path(job["output"])
    report_path = Path(job["report"])
    motion = Path(job["motion"])
    motion_channel = Path(job["motion_channel"]) if job.get("motion_channel") else None
    source_import = Path(job["source_import"])
    importer = Path(job["importer"])
    if output == source or output.exists() or report_path.exists():
        raise ValueError("Output and report must be new paths distinct from source")
    pinned = [(source, job["source_sha256"]),
              (source_import, job["source_import_sha256"]),
              (motion, job["motion_sha256"])]
    if motion_channel is not None:
        pinned.append((motion_channel, job["motion_channel_sha256"]))
    for path, expected in pinned:
        if not path.is_file() or _digest(path) != expected:
            raise ValueError("Pinned input changed: " + str(path))

    sys.path.insert(0, job["python_deps"])
    _load_importer(importer)
    from pokeaether_scvi_importer.gfbanm_importer import import_animation
    from pokeaether_scvi_importer.GFLib.Anim.Animation import AnimationT

    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    arms = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(arms) != 1:
        raise ValueError(f"Expected one armature, got {len(arms)}")
    rig = arms[0]
    before = {action.name: _action_summary(action) for action in bpy.data.actions}
    expected_name = motion.stem
    if expected_name in before:
        raise ValueError("Action already exists: " + expected_name)

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.animation_data_create()
    import_animation(bpy.context, str(motion), False, 0, False, False)
    actions = {action.name: action for action in bpy.data.actions}
    if expected_name not in actions:
        raise ValueError("Importer did not create expected action: " + expected_name)
    from source_clip_timing import preserve_constant_pose
    native = AnimationT.InitFromPackedBuf(bytearray(motion.read_bytes()), 0)
    fixed_pose = preserve_constant_pose(
        actions[expected_name], native.info,
        bpy.context.scene.render.fps / bpy.context.scene.render.fps_base,
    )
    for action in bpy.data.actions:
        action.use_fake_user = True
    after_existing = {name: _action_summary(actions[name]) for name in before}
    if after_existing != before:
        raise ValueError("Existing action metadata changed while appending action")

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    if _digest(source) != job["source_sha256"]:
        raise ValueError("Source changed during append")
    prepared_sha256 = _digest(output)
    source_metadata = json.loads(source_import.read_text())
    source_metadata["prepared_sha256"] = prepared_sha256
    source_metadata["actions"][job["category"]] = _action_summary(actions[expected_name])
    source_metadata["source_files"][str(motion)] = job["motion_sha256"]
    if motion_channel is not None:
        source_metadata["source_files"][str(motion_channel)] = job["motion_channel_sha256"]
    source_metadata["appended_action_provenance"] = {
        "schema": 1,
        "category": job["category"],
        "base_prepared_sha256": job["source_sha256"],
        "motion_sha256": job["motion_sha256"],
        "existing_action_metadata_unchanged": True,
    }
    output.with_name("import.json").write_text(json.dumps(source_metadata, indent=2) + "\n")
    report = {
        "schema": 1,
        "source": str(source),
        "source_sha256": job["source_sha256"],
        "output": str(output),
        "output_sha256": prepared_sha256,
        "motion": str(motion),
        "motion_sha256": job["motion_sha256"],
        "action": _action_summary(actions[expected_name]),
        "existing_action_count": len(before),
        "existing_action_metadata_unchanged": True,
        "constant_pose_duration_preserved": bool(fixed_pose),
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print("SCVI_ACTION_APPEND_OK", expected_name, flush=True)


if __name__ == "__main__":
    run(json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text()))
