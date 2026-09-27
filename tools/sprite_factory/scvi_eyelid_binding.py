"""Restore official eye lid maps skipped by the pinned All/Upper branches."""
from pathlib import Path

from scvi_material_probe import inspect_materials


def source_layers(row):
    kinds = {shader.get('values', {}).get('EyelidType') for shader in row['shaders']}
    if len(kinds) != 1 or not kinds <= {'All', 'Upper', 'Lower', 'None'}:
        raise ValueError('Unknown or mixed source eyelid layers')
    kind = next(iter(kinds))
    layers = []
    if kind in ('All', 'Upper'):
        layers.append(('UpEye', 3, 'UpperEyelidColorMap', 'BaseColorLayer7'))
    if kind in ('All', 'Lower'):
        layers.append(('LowEye', 4, 'LowerEyelidColorMap', 'BaseColorLayer8'))
    return layers


def restore(model_dir, identity):
    import bpy

    model_dir = Path(model_dir)
    rows = inspect_materials(model_dir / (identity + '.trmtr'))
    selected = [row for row in rows if row['shaders']
                and row['shaders'][0]['name'] == 'EyeClearCoat'
                and all(shader['name'] in ('EyeClearCoat', 'Eye')
                        and shader['values'].get('EyelidType') in ('All', 'Upper')
                        for shader in row['shaders'])
                and len({s['values']['EyelidType'] for s in row['shaders']}) == 1]
    if not selected:
        raise ValueError('No official EyeClearCoat/EyelidType=All/Upper source materials')
    restored = []
    for row in selected:
        material = bpy.data.materials.get(row['name'])
        if material is None or material.node_tree is None:
            raise ValueError('Imported eye material missing: ' + row['name'])
        tree = material.node_tree
        channels = [(prefix, channel) for prefix, _, channel, _ in source_layers(row)]
        sockets = tuple(prefix + suffix for prefix, _ in channels for suffix in ('_alpha', '_alb'))
        groups = [node for node in tree.nodes if node.type == 'GROUP'
                  and all(name in node.inputs for name in sockets)]
        if len(groups) != 1 or any(groups[0].inputs[name].is_linked for name in sockets):
            raise ValueError('Ambiguous or already bound eye lid inputs: ' + row['name'])
        for prefix, channel in channels:
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
