"""Prepare source-atlas sleep eyes and explicit Cramorant head/prey bindings."""
from io import BytesIO
import os
from pathlib import Path

from PIL import Image
from catalog_galar_birds_candidates import read, write, sha
from catalog_remaining_eye_bake import chunks

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
OLD = ROOT/'.tmp/remaining-colour-visibility-v1'
WORK = ROOT/'.tmp/remaining-forms-sleep-v1'
NAMES = ['burmy-sandy','burmy-trash','wormadam-sandy','wormadam-trash',
         'cramorant-gorging','cramorant-gulping']


def closed_atlas(image):
    """Explicitly reviewed top-right source cell, repeated without resampling."""
    assert image.width % 2 == image.height % 2 == 0
    width, height = image.width//2, image.height//2
    cell = image.crop((width,0,image.width,height))
    closed = Image.new(image.mode,image.size)
    for x in (0,width):
        for y in (0,height): closed.paste(cell,(x,y))
    return closed


def setup():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    prior = HERE/'remaining_forms_preview_result.json'
    accepted = read(prior)
    assert accepted['forms']==14 and accepted['newly_admitted']==0
    entries = []
    probe_path = ROOT/'.tmp/alternate-forms-recovery-v1/probes-v2/Gen8/pm0917.json'
    probe = read(probe_path)
    for folder in ['colour-review-v2','visibility-review-v2']:
        for entry in read(OLD/folder/'catalog.json')['entries']:
            name = entry['base_species']
            if name not in NAMES: continue
            approved = accepted['entries'][entry['species']]
            assert sha(entry['runtime_path']) == approved['runtime_sha256'] == entry['runtime_sha256']
            assert sha(entry['path']) == entry['glb_sha256']
            entry = dict(entry)
            entry['approved_runtime_path'] = entry['runtime_path']
            entry['approved_runtime_sha256'] = entry['runtime_sha256']
            doc,binary = chunks(entry['path'])
            eye_states = {}
            for material in doc['materials']:
                label = material['name']
                if label not in ('l_eye','r_eye'): continue
                textures = {}
                pbr = material['pbrMetallicRoughness']
                for key,info in [('albedo_texture',pbr.get('baseColorTexture')),
                                 ('normal_texture',material.get('normalTexture')),
                                 ('roughness_texture',pbr.get('metallicRoughnessTexture')),
                                 ('metallic_texture',pbr.get('metallicRoughnessTexture')),
                                 ('emission_texture',material.get('emissiveTexture'))]:
                    if not info: continue
                    assert not info.get('extensions') and info.get('texCoord',0)==0
                    image = doc['images'][doc['textures'][info['index']]['source']]
                    view = doc['bufferViews'][image['bufferView']]
                    start = view.get('byteOffset',0)
                    data = bytes(binary[start:start+view['byteLength']])
                    original = Image.open(BytesIO(data)).convert('RGBA')
                    closed = closed_atlas(original)
                    target = WORK/'eyes'/entry['species']/(label+'-'+key+'.png')
                    target.parent.mkdir(parents=True,exist_ok=True);closed.save(target)
                    textures[key] = {'path':str(target),'sha256':sha(target),'size':list(original.size),
                        'original_image_sha256':__import__('hashlib').sha256(data).hexdigest(),
                        'source_cell':[1,0],'grid':[2,2],'resampled':False}
                assert 'albedo_texture' in textures
                eye_states[label] = textures
            assert set(eye_states)=={'l_eye','r_eye'}
            entry['eye_states'] = eye_states
            if name.startswith('cramorant-'):
                resource = 'pm0917_13_00' if name.endswith('gorging') else 'pm0917_12_00'
                rig, = [r for r in probe['rigs'] if r['name']==resource]
                bones = rig['bones']
                root = 'waist_c' if name.endswith('gorging') else 'waist_b'
                chosen = {root,'head_a'}
                while True:
                    selected = chosen | {n for n,b in bones.items() if b['parent'] in chosen}
                    if chosen == selected: break
                    chosen = selected
                entry['sleep_attachment'] = {'anchor':'head_a','bones':sorted(chosen),
                    'source_probe':str(probe_path),'source_probe_sha256':sha(probe_path),
                    'source_blend_sha256':probe['source_sha256'],
                    'keep_idle_head_orientation':True,
                    'policy':'Keep source sleeping body and head position; retain own idle head orientation, beak opening and head/prey-relative pose, sampled at 60 Hz. This prevents the prey hanging below the feet.'}
            entry['runtime_approved'] = False
            entry['material_limitations'] = 'Closed eye atlas cell is original source art; source selection timing is an explicit sleep-state proposal.'
            entries.append(entry)
    assert len(entries)==12
    write(WORK/'stage.json',{'runtime_approved':False,'entries':entries})
    write(HERE/'remaining_forms_visual_approval.json',{
        'schema':1,'user_message':'zien er goed uit','approved_preview_sha256':sha(prior),
        'scope':'Visual approval of the 14 displayed colour and form-state proposals; known sleep-eye and Cramorant sleep defects remain excluded.',
        'forms':14,'runtime_approved':False,'battle_approved':False,'publication_approved':False,
        'excluded_known_defects':NAMES})
    print('SLEEP_STAGE_READY',len(entries))


if __name__ == '__main__': setup()
