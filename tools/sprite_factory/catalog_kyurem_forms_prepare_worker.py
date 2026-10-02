"""Isolate one source-pinned Kyurem rig in a disposable Blender document."""
import hashlib
import json
from pathlib import Path
import re
import sys

import bpy

sys.path.insert(0, str(Path(__file__).parent))
from source_review_rigs import isolate


def main(job):
    source = Path(job['source'])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job['source_sha256']:
        raise ValueError('Kyurem archived source changed')
    bpy.ops.wm.open_mainfile(filepath=str(source), load_ui=False, use_scripts=False)
    rig, selection = isolate(source, job['diagnostic_rig_selection'])
    used = {material for obj in bpy.context.scene.objects if obj.type == 'MESH'
            for material in obj.data.materials if material}
    expected = set(job['material_names'])
    names = [re.sub(r'\.\d{3}$', '', material.name) for material in used]
    if len(set(names)) != len(names) or set(names) != expected:
        raise ValueError('Selected rig materials do not match its official table')
    for material in list(bpy.data.materials):
        if material not in used:
            bpy.data.materials.remove(material, do_unlink=True)
    for material in used:
        material.name = re.sub(r'\.\d{3}$', '', material.name)
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    output = Path(job['output'])
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)
    Path(job['report']).write_text(json.dumps({
        'source_sha256': job['source_sha256'], 'rig_selection': selection,
        'material_names': sorted(material.name for material in used),
        'prepared_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'runtime_approved': False, 'appearance_approved': False,
    }, indent=2) + '\n')


if __name__ == '__main__':
    main(json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text()))
