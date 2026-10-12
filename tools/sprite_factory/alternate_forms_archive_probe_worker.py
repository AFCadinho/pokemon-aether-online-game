"""Read archived source objects/actions without executing embedded Blender scripts."""
import hashlib
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import material_images, image_identity, equivalent_action_names
from phase5_review_actions import candidates


def main(job):
    for item in job['sources']:
        output = Path(item['output'])
        source = Path(item['path'])
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != item['sha256']:
            raise ValueError('Archived input changed: ' + str(source))
        if output.exists():
            old = json.loads(output.read_text())
            if old.get('source_sha256') == digest and old.get('complete'):
                continue
        try:
            bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
            names = equivalent_action_names(bpy.data.actions)
            variants = []
            for rig in [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']:
                meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and
                          any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
                materials = {m for o in meshes for m in o.data.materials if m}
                images = {n for m in materials for n in material_images(m.node_tree)}
                own = rig.name.removesuffix('.trmdl').removesuffix('.gfbmdl')
                action_names = [n for n in names if n.startswith(own + '_')]
                variants.append({'rig': rig.name, 'meshes': [o.name for o in meshes],
                    'bone_count': len(rig.data.bones), 'textures': sorted(images),
                    'texture_identities': sorted({image_identity(n) for n in images if image_identity(n)}),
                    'materials': sorted(m.name for m in materials), 'parent': rig.parent.name if rig.parent else None,
                    'action_names': action_names, 'action_candidates': candidates(action_names),
                    'action_candidates_by_bank': {str(b): candidates(action_names, bank=b) for b in range(3)}})
            report = {'complete': True, 'source_sha256': digest, 'variants': variants,
                'all_action_names': names, 'runtime_approved': False}
        except Exception as error:
            report = {'complete': False, 'source_sha256': digest, 'error': str(error)}
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + '\n')
        print('ARCHIVE_PROBED', source.name, report['complete'], flush=True)


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
