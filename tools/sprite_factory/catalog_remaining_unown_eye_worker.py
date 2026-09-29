"""Bake Unown A's authored Blender eye shader into a review texture.

The generic glTF exporter selects eye_msk, which is a layer mask rather than
the material's Base Color result. Run this file inside Blender with
``-- source.blend output.png``. This does not approve a shiny or runtime scene.
"""

import sys
from pathlib import Path

import bpy


def main():
    source, target = map(Path, sys.argv[sys.argv.index("--") + 1:])
    bpy.ops.wm.open_mainfile(filepath=str(source))
    material = bpy.data.materials.get("eye")
    if material is None or not material.use_nodes:
        raise ValueError("Expected Unown A eye graph")
    authored_images = {node.image.name for node in material.node_tree.nodes
                       if node.type == "TEX_IMAGE" and node.image is not None}
    if not any("eye_alb" in name for name in authored_images) or not any(
            "eye_msk" in name for name in authored_images):
        raise ValueError("Expected Unown A packed eye albedo and mask")
    material = material.copy()
    tree = material.node_tree
    principled = next(node for node in tree.nodes if node.type == "BSDF_PRINCIPLED")
    base_links = [link for link in tree.links
                  if link.to_node == principled and link.to_socket.name == "Base Color"]
    if len(base_links) != 1:
        raise ValueError("Expected one authored eye Base Color link")
    output = next(node for node in tree.nodes if node.type == "OUTPUT_MATERIAL")
    emission = tree.nodes.new("ShaderNodeEmission")
    tree.links.new(base_links[0].from_socket, emission.inputs["Color"])
    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.mesh.primitive_plane_add()
    obj = bpy.context.object
    obj.data.materials.append(material)
    obj.data.uv_layers.active.name = "UVMap"
    image = bpy.data.images.new("unown_a_authored_eye", width=256, height=256, alpha=True)
    image.colorspace_settings.name = "sRGB"
    node = tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    for item in tree.nodes:
        item.select = False
    node.select = True
    tree.nodes.active = node
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT", margin=0)
    image.filepath_raw = str(target)
    image.file_format = "PNG"
    image.save()


if __name__ == "__main__":
    main()
