"""Own typed Silvally rigs with source-identical shared bones, skin and actions."""
import copy
from io import BytesIO
from pathlib import Path
from PIL import Image
from alternate_forms_batch import ROOT, HERE, WORK, read, write, sha
from catalog_shiny_za_17_probe import run_flatpak
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from phase5_variant_parity import compare


def prepare(row):
    old=ROOT/'.tmp/alternate-forms-batch-v1'
    own=read(WORK/'probes-v2/Gen7'/(Path(row['source']['member']).stem+'.json'))
    base=read(WORK/'probes-v2/Gen7/pm0862_11.json')
    assert own['source_sha256']==row['source']['sha256']
    assert own['rigs'][0]['bones']==base['rigs'][0]['bones']
    assert own['rigs'][0]['meshes']==base['rigs'][0]['meshes']
    assert own['actions']==base['actions']
    base_images={i['name']:i['packed_sha256'] for i in base['images']}
    for image in own['images']:
        if image['name'] in base_images:assert image['packed_sha256']==base_images[image['name']]
    # Every material graph and numeric input must equal the reviewed base graph;
    # only the two explicitly typed image identities are allowed to differ.
    typed={'BodyCIncVco11':'BodyC','Eye11':'Eye'}
    for name,tree in own['materials'].items():
        if not tree:continue
        normalized=copy.deepcopy(tree)
        for n in normalized['nodes']:
            if 'image' in n and name in typed:
                assert n['image']==row['resource']+'_'+typed[name]+'_col.png'
                n['image']='pm0862_11_'+typed[name]+'_col.png'
        assert normalized==base['materials'][name], name
    from catalog_remaining_normal_export import choose_actions
    diagnostic=read(old/'archive-probes/Gen7/pm0862_11.json')['variants'][0]
    actions,bank=choose_actions({'species':'silvally','rig_selection':{'rig':diagnostic['rig']},
        'action_candidates':diagnostic['action_candidates'],'action_candidates_by_bank':diagnostic['action_candidates_by_bank'],
        'unambiguous_actions':{k:v[0] for k,v in diagnostic['action_candidates'].items() if len(v)==1},
        'second_physical_candidates':[a for a in diagnostic['action_names'] if 'buturi02' in a]})
    assert actions
    out=WORK/'export'/row['species'];out.mkdir(parents=True,exist_ok=True)
    proof={'source_sha256':row['source']['sha256'],'base_source_sha256':base['source_sha256'],
        'geometry_skin_bones_actions_exact':True,'material_graphs_equal_except_typed_images':True,
        'shared_actions':actions,'normal_and_shiny_home_sha256':{v:sha(ROOT/'assets/sprites/pokemon'/('pokemon_home_shiny' if v=='shiny' else 'pokemon_home')/((row['species'] if v=='shiny' else 'Silvally')+'.png')) for v in ['normal','shiny']}}
    write(out/'binding-proof.json',proof)
    job={'species':row['species'],'source':row['source']['path'],'source_sha256':row['source']['sha256'],
        'diagnostic_rig_selection':row['diagnostic_rig_selection'],'actions':actions,'output':str(out),
        'native_flatten_bone_hierarchy_diagnostic':True,'scvi_pbr_probe':False}
    if not (out/'export.json').exists():
        write(out/'job.json',job)
        run_flatpak(HERE/'phase5_godot_export_worker.py',out/'job.json',[(old,':ro'),(WORK,''),(HERE,':ro')],out/'export.log')
    assert sha(out/'model.glb')==read(out/'export.json')['glb_sha256']
    return out


def build(row):
    exported=prepare(row);name=row['species'];source=Path(row['source']['path'])
    out=WORK/'materials'/name;out.mkdir(parents=True,exist_ok=True)
    import catalog_remaining_eye_domain as eye
    import catalog_remaining_body_detail as body
    from catalog_remaining_six_variants import convert_pixel
    eye.SOURCES['silvally']=(source.name,row['source']['sha256'],('Eye11',))
    body.SOURCES['silvally']=(row['source']['sha256'],*body.SOURCES['silvally'][1:])
    eyegl=out/'eye.glb'
    if not eyegl.exists():
        eye.repair('silvally',source,exported/'model.glb',eyegl)
    normal=out/'normal/model.glb';normal.parent.mkdir(exist_ok=True)
    body.repair('silvally',row['source']['sha256'],eyegl,normal)
    doc,blob=chunks(normal)
    changed=[]
    for m in doc['materials']:
        if m['name'] in ('Eye11','BodyCIncVco11'):continue # Retain each type's own accent colours.
        info=m['pbrMetallicRoughness']['baseColorTexture'];t=doc['textures'][info['index']]
        view=doc['bufferViews'][doc['images'][t['source']]['bufferView']];start=view.get('byteOffset',0)
        image=Image.open(BytesIO(blob[start:start+view['byteLength']])).convert('RGBA')
        result=Image.new('RGBA',image.size);result.putdata([convert_pixel('silvally','shiny',m['name'],p) for p in image.getdata()])
        assert result.getchannel('A').tobytes()==image.getchannel('A').tobytes()
        if result.tobytes()==image.tobytes():continue
        encoded=BytesIO();result.save(encoded,format='PNG')
        info['index']=append_png(doc,blob,encoded.getvalue(),m['name']+'_reviewed_base_shiny',t.get('sampler',0));changed.append(m['name'])
    assert changed
    shiny=out/'shiny/model.glb';shiny.parent.mkdir(exist_ok=True);write_glb(shiny,doc,blob);compare(normal,shiny)
    return exported,normal,shiny,{'policy':'reviewed-base-body-palette-with-native-type-accents-v1',
        'binding_proof_sha256':sha(exported/'binding-proof.json'),'changed_shiny_materials':changed,
        'palette_code_sha256':sha(HERE/'catalog_remaining_six_variants.py')}
