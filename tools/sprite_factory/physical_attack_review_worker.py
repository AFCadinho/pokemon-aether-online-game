"""Isolated Blender worker for physical-attack review loops and motion metrics."""
from __future__ import annotations

import hashlib
import itertools
import json
import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).parent))
from blender_worker import bounds
from blender_action_state import select_action
from source_review_rigs import isolate


REGIONS = {
    "jaw": re.compile(r"jaw|mouth|muzzle|beak|mandible|fang", re.I),
    "wing": re.compile(r"wing|feather", re.I),
    "arm": re.compile(r"arm|hand|claw|finger|wrist|elbow|shoulder|palm", re.I),
    "leg": re.compile(r"leg|foot|toe|ankle|knee|thigh|heel", re.I),
    "tail": re.compile(r"tail", re.I),
    "body": re.compile(r"root|hips?|waist|body|spine|chest|torso|neck|head", re.I),
}


def region(name: str) -> str:
    for label, pattern in REGIONS.items():
        if pattern.search(name):
            return label
    return "unknown"


def local_motion(rig, action, idle, samples=13):
    select_action(rig, idle)
    bpy.context.scene.frame_set(int(idle.frame_range[0]))
    references = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    scores = {name: 0.0 for name in (*REGIONS, "unknown")}
    bone_scores = {}
    span = action.frame_range[1] - action.frame_range[0]
    for index in range(samples):
        select_action(rig, action)
        frame = action.frame_range[0] + span * index / max(1, samples - 1)
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        for bone in rig.pose.bones:
            current = bone.matrix_basis
            reference = references[bone.name]
            translation = (current.to_translation() - reference.to_translation()).length
            angle = current.to_quaternion().rotation_difference(reference.to_quaternion()).angle / math.pi
            scale = (current.to_scale() - reference.to_scale()).length
            score = translation + angle + scale
            bone_scores[bone.name] = max(bone_scores.get(bone.name, 0.0), score)
    for name, score in bone_scores.items():
        scores[region(name)] += score
    total = sum(scores.values())
    named = total - scores["unknown"]
    ranked = sorted(bone_scores.items(), key=lambda item: (-item[1], item[0]))[:12]
    return {"region_scores": {key: round(value, 6) for key, value in scores.items()},
            "named_coverage": round(named / total, 6) if total else 0.0,
            "top_bones": [{"name": name, "region": region(name), "score": round(score, 6)}
                          for name, score in ranked]}


def set_pose(rig, action, fraction):
    select_action(rig, action)
    frame = action.frame_range[0] + fraction * (action.frame_range[1] - action.frame_range[0])
    bpy.context.scene.frame_set(int(frame), subframe=frame % 1)


def setup_scene(low, high):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        if obj.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(obj, do_unlink=True)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 320
    scene.render.resolution_y = 320
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PhysicalAttackReviewWorld")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.1, 0.13, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    scene.view_settings.view_transform = "Standard"
    for rotation, energy in (((0.7, -0.5, -0.5), 2.1), ((-0.8, 0.2, 0.5), 0.9)):
        data = bpy.data.lights.new("PhysicalAttackReviewSun", "SUN")
        data.energy = energy
        light = bpy.data.objects.new("PhysicalAttackReviewSun", data)
        scene.collection.objects.link(light)
        light.rotation_euler = rotation
    data = bpy.data.cameras.new("PhysicalAttackReviewCamera")
    camera = bpy.data.objects.new("PhysicalAttackReviewCamera", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    data.type = "ORTHO"
    center = (low + high) / 2
    direction = Vector((3, -7, 2)).normalized()
    right = Vector((-direction.y, direction.x, 0)).normalized()
    up = direction.cross(right).normalized()
    corners = [Vector(values) for values in itertools.product(
        (low.x, high.x), (low.y, high.y), (low.z, high.z))]
    horizontal = [point.dot(right) for point in corners]
    vertical = [point.dot(up) for point in corners]
    target = center + right * ((min(horizontal) + max(horizontal)) / 2 - center.dot(right))
    target += up * ((min(vertical) + max(vertical)) / 2 - target.dot(up))
    size = max(max(horizontal) - min(horizontal), max(vertical) - min(vertical), 0.1) * 1.15
    data.ortho_scale = size
    data.clip_end = max(1000, size * 20)
    camera.location = target + direction * size * 3
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def run(job):
    source = Path(job["source"])
    if job.get("prepared_sha256") and hashlib.sha256(source.read_bytes()).hexdigest() != job["prepared_sha256"]:
        raise ValueError("Prepared source changed after import")
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rig, selection = isolate(source)
    actions = {name: bpy.data.actions.get(value or "") for name, value in job["actions"].items()}
    if any(actions.get(name) is None for name in ("idle", "physical_attack", "physical_attack_2")):
        raise ValueError("Review requires idle and both physical attacks")
    sampled_bounds = []
    for action_name in ("idle", "physical_attack", "physical_attack_2"):
        action = actions[action_name]
        for fraction in (0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0):
            set_pose(rig, action, fraction)
            sampled_bounds.append(bounds())
    low = Vector([min(box[axis][0] for box in sampled_bounds) for axis in range(3)])
    high = Vector([max(box[axis][1] for box in sampled_bounds) for axis in range(3)])
    setup_scene(low, high)
    output = Path(job["output"])
    timeline = {}
    analysis = {}
    for action_name in ("physical_attack", "physical_attack_2"):
        action = actions[action_name]
        analysis[action_name] = local_motion(rig, action, actions["idle"])
        fractions = [None] * 2 + [index / 7 for index in range(8)] + [None] * 2
        attack_duration = (action.frame_range[1] - action.frame_range[0]) / 60.0 / 1.5
        durations = [140] * 2 + [max(25, round(attack_duration * 1000 / 8))] * 8 + [140] * 2
        directory = output / "frames" / action_name
        directory.mkdir(parents=True, exist_ok=True)
        for index, fraction in enumerate(fractions):
            if fraction is None:
                set_pose(rig, actions["idle"], 0.0)
            else:
                set_pose(rig, action, fraction)
            bpy.context.scene.render.filepath = str(directory / f"{index:02d}.png")
            bpy.ops.render.render(write_still=True)
        timeline[action_name] = {"frames": len(fractions), "durations_ms": durations,
                                 "source_frames": list(action.frame_range), "source_fps": 60,
                                 "review_speed": 1.5}
    report = {"schema": 1, "species": job["species"], "scope": "review_only_not_runtime_mapping",
              "runtime_approved": False, "rig_selection": selection,
              "camera_bounds": [list(low), list(high)], "motion_analysis": analysis,
              "timeline": timeline}
    (output / "review.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    run(json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text()))
