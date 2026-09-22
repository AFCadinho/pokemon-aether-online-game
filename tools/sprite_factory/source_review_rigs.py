"""Isolate an unambiguous source variant, never merge independent rigs.

All edits are to the disposable Blender scene. Source files are never saved.
Composite rigs and ambiguous variants remain unsupported, with useful evidence.
"""
import re
from pathlib import Path


def image_identity(name):
    match = re.match(r'^(pm\d{4}_\d{2})(?:_|\.)', Path(name).name, re.I)
    return match[1].lower() if match else None


def choose_variant(identities, expected):
    """Require positive, exclusive texture evidence; order/names aren't evidence."""
    matches = [rig for rig, values in identities.items() if set(values) == {expected}]
    if len(matches) != 1:
        raise ValueError('Ambiguous rig variants: ' + repr(identities))
    return matches[0]


def material_images(tree, visited=None):
    visited = set() if visited is None else visited
    if tree is None or tree.as_pointer() in visited:
        return set()
    visited.add(tree.as_pointer())
    result = set()
    for node in tree.nodes:
        if node.type == 'TEX_IMAGE' and node.image:
            result.add(node.image.name)
        elif node.type == 'GROUP':
            result.update(material_images(node.node_tree, visited))
    return result


def isolate(source):
    import bpy
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    if bpy.data.libraries or not rigs:
        raise ValueError('Expected self-contained source rigs')
    if len(rigs) == 1:
        return rigs[0], {'policy': 'single_rig', 'rig': rigs[0].name}
    expected = image_identity(Path(source).stem + '.')
    if expected is None:
        raise ValueError('Multiple rigs require a source variant identity')
    members = {r.name: [r] for r in rigs}
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            if obj.type not in ('ARMATURE', 'CAMERA', 'LIGHT'):
                raise ValueError('Unsupported multi-rig scene object: ' + obj.name)
            continue
        owners = {m.object for m in obj.modifiers if m.type == 'ARMATURE' and m.object}
        if len(owners) != 1 or next(iter(owners)) not in rigs:
            raise ValueError('Multi-rig mesh has ambiguous ownership: ' + obj.name)
        owner = next(iter(owners))
        if obj.parent is not owner:
            raise ValueError('Cross-rig or indirect mesh parenting: ' + obj.name)
        members[owner.name].append(obj)
    identities = {}
    for rig in rigs:
        if rig.parent or rig.constraints or any(o.constraints for o in members[rig.name]):
            raise ValueError('Constrained/composite rigs need explicit review')
        if any(o.animation_data and o.animation_data.drivers for o in members[rig.name]):
            raise ValueError('Driven multi-rig scenes need explicit review')
        images = {name for o in members[rig.name] if o.type == 'MESH'
                  for mat in o.data.materials if mat for name in material_images(mat.node_tree)}
        identities[rig.name] = sorted({identity for name in images if (identity := image_identity(name))})
    selected = choose_variant(identities, expected)
    record = {'policy': 'exclusive_texture_variant_v1', 'rig': selected,
              'expected_identity': expected, 'evidence': identities,
              'excluded_rigs': [r.name for r in rigs if r.name != selected]}
    result = bpy.data.objects[selected]
    for name, objects in members.items():
        if name != selected:
            for obj in reversed(objects):
                bpy.data.objects.remove(obj, do_unlink=True)
    return result, record


def equivalent_action_names(actions):
    """Collapse Blender copy suffixes only when complete curve data agrees."""
    def fingerprint(action):
        return (tuple(action.frame_range),
            tuple((s.target_id_type,) for s in action.slots),
            tuple((curve.data_path, curve.array_index, curve.extrapolation,
                   tuple((tuple(k.co), k.interpolation, k.easing, tuple(k.handle_left),
                          tuple(k.handle_right), k.handle_left_type, k.handle_right_type,
                          k.amplitude, k.back, k.period) for k in curve.keyframe_points))
                  for layer in action.layers for strip in layer.strips
                  for bag in strip.channelbags for curve in bag.fcurves))
    by_name = {a.name: a for a in actions}
    names = []
    for name, action in by_name.items():
        base = re.sub(r'\.\d{3}$', '', name)
        original = by_name.get(base) if base != name else None
        # Modifiers/drivers/complex layers aren't covered by this equivalence.
        simple = lambda a: len(a.layers) == 1 and len(a.layers[0].strips) == 1 and len(a.slots) == 1 and all(
            not c.modifiers and not c.sampled_points for s in a.layers[0].strips for b in s.channelbags for c in b.fcurves)
        if original is None or not simple(original) or not simple(action) or fingerprint(action) != fingerprint(original):
            names.append(name)
    return names
