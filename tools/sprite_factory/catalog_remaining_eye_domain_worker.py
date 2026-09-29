"""Bake a source Blender eye shader over its exported GLB mesh's UV domain."""

import json
import sys
from pathlib import Path

import bpy


def replace_uv(tree):
    for node in list(tree.nodes):
        if node.type == "GROUP" and node.node_tree:
            node.node_tree = node.node_tree.copy()
            replace_uv(node.node_tree)
        if node.type == "TEX_COORD":
            links = [link for link in list(tree.links)
                     if link.from_node == node and link.from_socket.name == "UV"]
            if links:
                uv = tree.nodes.new("ShaderNodeUVMap")
                uv.uv_map = "SourceUV"
                for link in links:
                    tree.links.new(uv.outputs["UV"], link.to_socket)


def bake(job):
    bpy.ops.wm.open_mainfile(filepath=job["source"])
    for item in job["materials"]:
        name = item["name"]
        material = bpy.data.materials[name].copy()
        if not material.use_nodes:
            raise ValueError(f"{name}: missing source shader")
        replace_uv(material.node_tree)
        bsdfs = [node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"]
        if len(bsdfs) != 1:
            raise ValueError(f"{name}: expected one source Principled shader")
        base_links = [link.from_socket for link in material.node_tree.links
                      if link.to_node == bsdfs[0] and link.to_socket.name == "Base Color"]
        if len(base_links) != 1:
            raise ValueError(f"{name}: expected connected source Base Color")
        outputs = [node for node in material.node_tree.nodes if node.type == "OUTPUT_MATERIAL"]
        if len(outputs) != 1:
            raise ValueError(f"{name}: expected one material output")
        emission = material.node_tree.nodes.new("ShaderNodeEmission")
        material.node_tree.links.new(base_links[0], emission.inputs["Color"])
        material.node_tree.links.new(emission.outputs["Emission"], outputs[0].inputs["Surface"])
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.mesh.primitive_plane_add()
        obj = bpy.context.object
        obj.data.materials.append(material)
        bake_uv = obj.data.uv_layers.active
        bake_uv.name = "BakeUV"
        source_uv = obj.data.uv_layers.new(name="SourceUV")
        u0, u1, v0, v1 = item["source_uv_bounds"]
        for polygon in obj.data.polygons:
            for index in polygon.loop_indices:
                uv = bake_uv.data[index].uv
                source_uv.data[index].uv = (u0 + (u1 - u0) * uv.x,
                                            v0 + (v1 - v0) * uv.y)
        obj.data.uv_layers.active = bake_uv
        image = bpy.data.images.new(name + "_source_uv", width=512, height=512, alpha=True)
        image.colorspace_settings.name = "sRGB"
        node = material.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        for other in material.node_tree.nodes:
            other.select = False
        node.select = True
        material.node_tree.nodes.active = node
        bpy.context.scene.render.engine = "CYCLES"
        bpy.context.scene.cycles.samples = 1
        bpy.ops.object.bake(type="EMIT", margin=0)
        image.filepath_raw = item["output"]
        image.file_format = "PNG"
        image.save()
        print("BAKED", name, item["output"], flush=True)


if __name__ == "__main__":
    bake(json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text()))
