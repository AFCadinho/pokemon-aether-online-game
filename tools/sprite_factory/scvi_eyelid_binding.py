"""Restore both official eye lid maps when the pinned importer skips EyelidType=All."""
from pathlib import Path

from scvi_material_probe import inspect_materials


def restore(model_dir, identity):
    import bpy

    model_dir = Path(model_dir)
    rows = inspect_materials(model_dir / (identity + '.trmtr'))
    selected = [row for row in rows if row['shaders']
                and row['shaders'][0]['name'] == 'EyeClearCoat'
                and all(shader['name'] in ('EyeClearCoat', 'Eye')
                        and shader['values'].get('EyelidType') == 'All'
                        for shader in row['shaders'])]
    if not selected:
        raise ValueError('No official EyeClearCoat/EyelidType=All source materials')
    restored = []
    for row in selected:
        material = bpy.data.materials.get(row['name'])
        if material is None or material.node_tree is None:
            raise ValueError('Imported eye material missing: ' + row['name'])
        tree = material.node_tree
        sockets = ('UpEye_alpha', 'UpEye_alb', 'LowEye_alpha', 'LowEye_alb')
        groups = [node for node in tree.nodes if node.type == 'GROUP'
                  and all(name in node.inputs for name in sockets)]
        if len(groups) != 1 or any(groups[0].inputs[name].is_linked for name in sockets):
            raise ValueError('Ambiguous or already bound eye lid inputs: ' + row['name'])
        for prefix, channel in (('UpEye', 'UpperEyelidColorMap'),
                                ('LowEye', 'LowerEyelidColorMap')):
            source = row['textures'].get(channel)
            if not source or Path(source).name != source or not source.endswith('.bntx'):
                raise ValueError('Official eye lid channel missing: ' + row['name'] + '/' + channel)
            path = model_dir / Path(source).with_suffix('.png')
            if not path.is_file():
                raise ValueError('Official eye lid PNG missing: ' + str(path))
            image = bpy.data.images.load(str(path), check_existing=True)
            node = tree.nodes.new('ShaderNodeTexImage')
            node.label = 'Official ' + channel
            node.image = image
            tree.links.new(node.outputs['Alpha'], groups[0].inputs[prefix + '_alpha'])
            tree.links.new(node.outputs['Color'], groups[0].inputs[prefix + '_alb'])
            restored.append({'material': row['name'], 'channel': channel, 'image': str(path)})
    return restored
