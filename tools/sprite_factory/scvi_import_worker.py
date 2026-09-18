"""Trusted Blender entry point for one read-only Scarlet/Violet source import.

The importer is pinned by the host-side batch driver; this script never invokes
the add-on's registration, dependency installer, or network code.
"""

import importlib.util
import json
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def load_importer(path):
    spec = importlib.util.spec_from_file_location(
        "pokeaether_scvi_importer", path / "__init__.py",
        submodule_search_locations=[str(path)],
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def projected_extent(rig, action, direction, frames):
    rig.animation_data.action = action
    if len(action.slots) == 1:
        rig.animation_data.action_slot = action.slots[0]
    # The factory uses these same orthographic front/back directions.
    look = Vector([-value for value in direction]).to_track_quat("-Z", "Y")
    inverse = look.to_matrix().inverted()
    extent = [float("inf"), float("inf"), float("-inf"), float("-inf")]
    for frame in frames:
        bpy.context.scene.frame_set(frame)
        graph = bpy.context.evaluated_depsgraph_get()
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH" or obj.hide_render:
                continue
            evaluated = obj.evaluated_get(graph)
            mesh = evaluated.to_mesh()
            for vertex in mesh.vertices:
                point = inverse @ (evaluated.matrix_world @ vertex.co)
                extent[0] = min(extent[0], point.x)
                extent[1] = min(extent[1], point.y)
                extent[2] = max(extent[2], point.x)
                extent[3] = max(extent[3], point.y)
            evaluated.to_mesh_clear()
    return extent


def main(job):
    importer = Path(job["importer"])
    sys.path.insert(0, job["python_deps"])
    load_importer(importer)
    from pokeaether_scvi_importer.PokemonSwitch import from_trmdlsv
    from pokeaether_scvi_importer.gfbanm_importer import import_animation

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.world = bpy.data.worlds.new("PokeAether SCVI review")
    with bpy.data.libraries.load(str(importer / "SCVIShader.blend"), link=False) as (source, dest):
        assert "PokemonShader" in source.materials
        dest.materials = ["PokemonShader"]
    model_dir = Path(job["model_dir"])
    identity = job["identity"]
    from_trmdlsv(str(model_dir), identity + ".trmdl", job["variant"] == "shiny",
                  False, True, False, True, False)
    arms = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    assert len(arms) == 1, f"Expected one armature, got {len(arms)}"
    rig = arms[0]
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.animation_data_create()
    for category, path in job["motions"].items():
        if path is not None:
            import_animation(bpy.context, path, False, 0, False, False)
    for action in bpy.data.actions:
        action.use_fake_user = True
    images = []
    for item in bpy.data.images:
        if item.source != "FILE":
            continue
        resolved = bpy.path.abspath(item.filepath)
        images.append({"name": item.name, "path": resolved,
                       "exists": os.path.isfile(resolved), "packed": item.packed_file is not None})
    missing = [item for item in images if not item["exists"] and not item["packed"]]
    assert not missing, f"Missing textures: {missing}"
    bpy.ops.file.pack_all()
    assert all(item.packed_file is not None for item in bpy.data.images if item.source == "FILE")
    actions = {action.name: action for action in bpy.data.actions}
    mapping = {}
    for category, path in job["motions"].items():
        if path is None:
            mapping[category] = None
            continue
        name = Path(path).stem
        assert name in actions, f"Imported action missing: {name}"
        action = actions[name]
        mapping[category] = {"name": name, "range": list(action.frame_range),
                             "slots": [slot.identifier for slot in action.slots]}
    bounds = {}
    for view, direction in {"front": (3, -7, 2), "back": (-3, 7, 2)}.items():
        per_action = {}
        for category, spec in mapping.items():
            if spec is None:
                continue
            lo, hi = [int(value) for value in spec["range"]]
            # Sample every source frame, so a broad attack cannot be missed.
            per_action[category] = projected_extent(rig, actions[spec["name"]], direction,
                                                     range(lo, hi + 1))
        bounds[view] = per_action
    output = Path(job["output"])
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    report = {"species": job["species"], "identity": identity, "variant": job["variant"],
              "blender": bpy.app.version_string, "rig": rig.name,
              "meshes": [obj.name for obj in bpy.data.objects if obj.type == "MESH"],
              "materials": [mat.name for mat in bpy.data.materials],
              "actions": mapping, "projected_bounds": bounds, "images": images,
              "source_files": job["source_files"], "importer_commit": job["importer_commit"],
              "shader_sha256": job["shader_sha256"]}
    Path(job["report"]).write_text(json.dumps(report, indent=2) + "\n")
    print("SCVI_REVIEW_IMPORT_OK", job["species"], job["variant"], len(images), flush=True)


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text()))
