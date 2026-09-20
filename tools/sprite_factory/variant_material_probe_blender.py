"""Inspect imported sprite materials without modifying or saving the source blend.

Run through Blender with ``--factory-startup --disable-autoexec``.  This is a
benchmark/probe helper; it is not part of the production sprite renderer.
"""

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def describe_material(material):
    nodes = []
    if material.node_tree:
        for node in material.node_tree.nodes:
            item = {
                "name": node.name,
                "type": node.type,
                "label": node.label,
            }
            if node.type == "TEX_IMAGE":
                item["image"] = node.image.name if node.image else None
            nodes.append(item)
    return {
        "name": material.name,
        "use_nodes": material.use_nodes,
        "nodes": nodes,
    }


def inspect(job):
    meshes = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        slot_counts = [0] * len(obj.material_slots)
        for polygon in obj.data.polygons:
            if polygon.material_index < len(slot_counts):
                slot_counts[polygon.material_index] += 1
        meshes.append({
            "name": obj.name,
            "materials": [
                {
                    "slot": index,
                    "name": slot.material.name if slot.material else None,
                    "polygons": slot_counts[index],
                }
                for index, slot in enumerate(obj.material_slots)
            ],
            "uv_layers": [layer.name for layer in obj.data.uv_layers],
        })
    report = {
        "blender": bpy.app.version_string,
        "meshes": meshes,
        "materials": [describe_material(material) for material in bpy.data.materials],
        "images": [
            {
                "name": image.name,
                "size": list(image.size),
                "channels": image.channels,
                "packed": bool(image.packed_file or image.packed_files),
            }
            for image in bpy.data.images
            if image.type != "RENDER_RESULT"
        ],
    }
    return report


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def id_material(name, value):
    material = bpy.data.materials.new("VariantID_" + name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    emission = tree.nodes.new("ShaderNodeEmission")
    color = value / 255.0
    emission.inputs["Color"].default_value = (color, color, color, 1.0)
    emission.inputs["Strength"].default_value = 1.0
    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    return material


def render_ids(job):
    cfg = job.get("manifest")
    if cfg is None:
        provenance = json.loads(Path(job["provenance"]).read_text())
        cfg = provenance["identity"]["manifest"]
    scene = bpy.context.scene
    rig = scene.objects[cfg["rig"]]
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for obj in list(scene.objects):
        if obj.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(obj, do_unlink=True)

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.fps = cfg["render"]["fps"]
    scene.render.fps_base = 1.0
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 1
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1

    names = sorted({
        slot.material.name
        for obj in scene.objects if obj.type == "MESH"
        for slot in obj.material_slots if slot.material
    })
    if len(names) > 254:
        raise ValueError("Material-ID probe supports at most 254 materials")
    # Wide spacing keeps IDs distinguishable after the configured display
    # transform and at antialiased material boundaries.
    values = {name: (index + 1) * (255 // (len(names) + 1)) for index, name in enumerate(names)}
    replacements = {name: id_material(name, value) for name, value in values.items()}
    for obj in scene.objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            if slot.material:
                slot.material = replacements[slot.material.name]

    camera_data = bpy.data.cameras.new("VariantIDCamera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    output = Path(job["output"])
    rendered = {}
    for view in job["views"]:
        cam = cfg["cameras"][view]
        camera.location = cam["position"]
        camera_data.ortho_scale = cam["ortho_scale"]
        aim(camera, cam["target"])
        rendered[view] = {}
        for category in job["actions"]:
            spec = cfg["actions"][category]
            action = bpy.data.actions[spec["action"]]
            rig.animation_data.action = action
            if spec.get("slot"):
                rig.animation_data.action_slot = next(
                    slot for slot in action.slots if slot.identifier == spec["slot"])
            elif len(action.slots) == 1:
                rig.animation_data.action_slot = action.slots[0]
            destination = output / view / category
            destination.mkdir(parents=True, exist_ok=True)
            for index, frame in enumerate(spec["frames"]):
                scene.frame_set(int(frame), subframe=frame - int(frame))
                for bone_name in spec.get("neutral_bones", []):
                    rig.pose.bones[bone_name].matrix_basis.identity()
                scene.render.filepath = str(destination / f"{index:04}.png")
                bpy.ops.render.render(write_still=True)
            rendered[view][category] = len(spec["frames"])
    return {
        "blender": bpy.app.version_string,
        "material_ids": values,
        "rendered": rendered,
        "resolution": [512, 512],
    }


def main(job_path):
    job = json.loads(Path(job_path).read_text())
    report = render_ids(job) if job.get("mode") == "render_ids" else inspect(job)
    Path(job["report"] if "report" in job else job["output"]).write_text(
        json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1])
