"""Build local diagnostic GLBs from downloaded Pokémon HOME FBX models.

Run with Blender's Python. The source FBX and texture folder are never changed.
Generated motion is explicitly provisional until battle review and floor checks.
"""

import argparse
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion


ACTION_NAMES = {
    "ba02_roar01": "roar",
    "ba10_waitA01": "idle",
    "ba20_buturi01": "physical_attack",
    "ba21_tokusyu01": "special_attack",
    "eye01": "facial_eyes",
    "mouth01": "facial_mouth",
    "loop01": "loop_source",
}


def curves(action):
    return action.layers[0].strips[0].channelbags[0].fcurves


def translate(action, bone, axis, offset):
    path = f'pose.bones["{bone}"].location'
    selected = [curve for curve in curves(action) if curve.data_path == path and curve.array_index == axis]
    assert len(selected) == 1, (action.name, bone, axis)
    for key in selected[0].keyframe_points:
        delta = offset(key.co.x)
        key.co.y += delta
        key.handle_left.y += delta
        key.handle_right.y += delta
    selected[0].update()


def rotate(action, bone, axis, radians):
    path = f'pose.bones["{bone}"].rotation_quaternion'
    selected = {curve.array_index: curve for curve in curves(action) if curve.data_path == path}
    assert set(selected) == set(range(4)), (action.name, bone)
    count = len(selected[0].keyframe_points)
    assert all(len(curve.keyframe_points) == count for curve in selected.values())
    basis = [(1, 0, 0), (0, 1, 0), (0, 0, 1)][axis]
    for index in range(count):
        points = [selected[component].keyframe_points[index] for component in range(4)]
        frame = points[0].co.x
        assert all(abs(point.co.x - frame) < 0.001 for point in points)
        original = Quaternion([point.co.y for point in points])
        result = original @ Quaternion(basis, radians(frame))
        for component, point in enumerate(points):
            delta = result[component] - point.co.y
            point.co.y += delta
            point.handle_left.y += delta
            point.handle_right.y += delta
    for curve in selected.values():
        curve.update()


def make_provisional_actions(species):
    actions = {action.name: action for action in bpy.data.actions}
    idle = actions["idle"]
    last = idle.frame_range[1]

    def copy(source, name):
        duplicate = actions[source].copy()
        duplicate.name = name
        assert duplicate.name == name
        return duplicate

    # All additions are clearly labelled as authored diagnostics. Native source
    # actions remain byte-for-byte unchanged inside the source archives.
    secondary = copy("roar", "physical_attack_2")
    rotate(secondary, "waist", 2, lambda frame: -0.10 * math.sin(math.pi * frame / secondary.frame_range[1]))

    damage = copy("idle", "damage")
    translate(damage, "waist", 2, lambda frame: -0.18 * math.sin(math.pi * (frame - 1) / (last - 1)) ** 2)
    rotate(damage, "head", 0, lambda frame: 0.25 * math.sin(math.pi * (frame - 1) / (last - 1)) ** 2)

    sleep = copy("idle", "sleep")
    translate(sleep, "waist", 1, lambda frame: -0.18 if species == "walking-wake" else -0.08)
    rotate(sleep, "head", 0, lambda frame: 0.35 if species == "walking-wake" else 0.25)

    faint_start = copy("idle", "faint_start")
    translate(faint_start, "waist", 1, lambda frame: -(0.41 if species == "walking-wake" else 0.526) * min(1, (frame - 1) / (last - 1)))
    rotate(faint_start, "waist", 0, lambda frame: 1.25 * min(1, (frame - 1) / (last - 1)))
    faint_loop = copy("idle", "faint_loop")
    translate(faint_loop, "waist", 1, lambda frame: -0.41 if species == "walking-wake" else -0.526)
    rotate(faint_loop, "waist", 0, lambda frame: 1.25)
    return ["physical_attack_2", "damage", "sleep", "faint_start", "faint_loop"]


def substitute_shiny():
    substitutions = []
    for image in list(bpy.data.images):
        path = Path(bpy.path.abspath(image.filepath))
        if path.suffix.lower() != ".png":
            continue
        stem = path.stem
        candidates = [path.with_name(stem + "_rare.png")]
        if stem.endswith(" merged"):
            candidates.insert(0, path.with_name(stem[:-7] + "_rare merged.png"))
        rare = next((candidate for candidate in candidates if candidate.exists()), None)
        if rare is None:
            continue
        replacement = bpy.data.images.load(str(rare), check_existing=True)
        for material in bpy.data.materials:
            if not material.use_nodes:
                continue
            for node in material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image == image:
                    node.image = replacement
                    substitutions.append([image.name, replacement.name, material.name])
    return substitutions


def run(source, output, species_filter=None, variant_filter=None):
    output.mkdir(parents=True, exist_ok=False)
    report = {}
    for species in ("walking-wake", "iron-leaves"):
        if species_filter and species != species_filter:
            continue
        directory = source / species
        fbx = next(directory.glob("*with animation.fbx"))
        for variant in ("normal", "shiny"):
            if variant_filter and variant != variant_filter:
                continue
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.fbx(filepath=str(fbx), use_anim=True)
            for action in list(bpy.data.actions):
                matches = [name for suffix, name in ACTION_NAMES.items() if suffix in action.name]
                assert len(matches) == 1, action.name
                action.name = matches[0]
            generated = make_provisional_actions(species)
            substitutions = substitute_shiny() if variant == "shiny" else []
            target = output / f"{species}-{variant}.glb"
            bpy.ops.export_scene.gltf(
                filepath=str(target), export_format="GLB", export_animations=True,
                export_animation_mode="ACTIONS", export_materials="EXPORT",
                export_skins=True, export_texcoords=True,
            )
            report[f"{species}-{variant}"] = {
                "fbx": str(fbx), "output": str(target), "bytes": target.stat().st_size,
                "authored_diagnostic_actions": generated,
                "shiny_texture_substitutions": substitutions,
                "status": "diagnostic_only_not_battle_qualified",
            }
    (output / "report.json").write_text(json.dumps(report, indent=2))


if __name__ == "__main__":
    args = __import__("sys").argv
    args = args[args.index("--") + 1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--species", choices=("walking-wake", "iron-leaves"))
    parser.add_argument("--variant", choices=("normal", "shiny"))
    parsed = parser.parse_args(args)
    run(parsed.source.resolve(), parsed.output.resolve(), parsed.species, parsed.variant)
