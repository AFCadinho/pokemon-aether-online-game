"""Read-only Blender evidence for Zygarde's core; never exports a model."""
import hashlib
import json
from pathlib import Path
import sys


def inspect(job):
    import bpy

    source = Path(job['source'])
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != job['source_sha256']:
        raise ValueError('Reference Blend changed')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    material = bpy.data.materials[job['material']]
    images, groups, seen = [], [], set()

    def walk(tree):
        if tree.as_pointer() in seen:
            return
        seen.add(tree.as_pointer())
        # Include even disconnected nodes: absence from this conservative
        # inventory proves that the image is not bound anywhere in the graph.
        for node in tree.nodes:
            image = getattr(node, 'image', None)
            if image:
                images.append({'tree': tree.name, 'node': node.name,
                               'name': image.name, 'filepath': image.filepath,
                               'packed': image.packed_file is not None})
            child = getattr(node, 'node_tree', None)
            if child:
                groups.append(child.name)
                walk(child)

    walk(material.node_tree)
    result = {'source': str(source), 'source_sha256': digest,
              'material': material.name, 'groups': sorted(set(groups)),
              'image_nodes_including_disconnected': images,
              'runtime_approved': False}
    Path(job['output']).write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    inspect(json.loads(Path(sys.argv[-1]).read_text()))
