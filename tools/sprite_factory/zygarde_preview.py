"""Build a local, unapproved Zygarde 10 visual reconstruction. No admission path."""
import json
import os
from pathlib import Path

from catalog_shiny_151_material_probe import rebuild
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_galar_birds_candidates import sha, read, write, visibility
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials
from scvi_uv_probe import read_uv_tracks
from effect_uv_samples import channel_samples
import catalog_dlc_layer_emission as emission
import scvi_eye_motion

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT / '.tmp/zygarde-preview-v1'
OLD = ROOT / '.tmp/alternate-forms-batch-v1'


def material_motion(row, directory):
    result = {}
    alpha = {}
    def keys(values, fps):
        return [[i/fps,v] for i,v in enumerate(values) if i in (0,len(values)-1)
                or v != values[i-1] or v != values[i+1]]
    for action,motion in row['actions'].items():
        data = read_uv_tracks(directory/(motion+'.tracm'),parameters=('BaseColor',),
            scalar_parameters=tuple(['EmissionIntensity']+['EmissionIntensityLayer'+str(i) for i in range(1,5)]))
        assert all(c == [data['config_flag'],data['frames'],data['fps']] for c in data['nested_timing'])
        unique = {}
        for track in data['scalar_tracks']:
            identity = (track['material'],track['parameter'])
            if identity in unique: assert unique[identity] == track
            unique[identity] = track
        names = {k[0] for k in unique}
        for name in names:
            parameters = sorted(k[1] for k in unique if k[0]==name)
            samples = [channel_samples(unique[(name,key)]['keys'],data['frames']-1) for key in parameters]
            assert all(s == samples[0] for s in samples), 'Layers require independent power tracks'
            spec = result.setdefault(name,{'parameters':parameters,'clips':{}})
            assert spec['parameters']==parameters
            spec['clips'][action] = keys(samples[0],data['fps'])
        for track in data['tracks']:
            assert track['material']=='eff_body_d' and track['parameter']=='BaseColor'
            samples = [channel_samples(c,data['frames']-1) for c in track['channels']]
            assert all(set(s)=={1.0} for s in samples[:3])
            value = keys(samples[3],data['fps'])
            if action in alpha:assert alpha[action]==value
            alpha[action]=value
    assert set(alpha)==set(row['actions'])
    assert all(set(spec['clips'])==set(row['actions']) for spec in result.values())
    return {'emission':result,'effect_alpha':alpha,
            'interpretation':'Piecewise-linear source frame samples; common layer power proved per material and clip.'}


def main():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    row = next(r for r in read(HERE/'alternate_forms_za_intake.json')['entries'] if r['species']=='zygarde-10')
    for r in row['scvi_files'] + row['selected_motion_files']:
        assert sha(r['path']) == r['sha256'] and Path(r['path']).stat().st_size == r['bytes']
    directory = Path(row['source_directory'])
    source = OLD/'export/zygarde-10/model.glb'
    exported = read(source.with_name('export.json'))
    assert sha(source) == exported['glb_sha256']
    doc, binary = chunks(source)
    table = directory/'pm0770_11_00.trmtr'
    materials = {m['name']:m for m in inspect_materials(table)}
    curves = material_motion(row,directory)
    for m in doc['materials']:
        texture = directory/Path(materials[m['name']]['textures']['BaseColorMap']).with_suffix('.png')
        m.setdefault('pbrMetallicRoughness',{})['baseColorTexture'] = {
            'index':append_png(doc,binary,texture.read_bytes(),texture.stem,0)}
    WORK.mkdir(parents=True,exist_ok=True)
    seeded = WORK/'source-bound.glb'
    write_glb(seeded,doc,binary)
    compare(source,seeded)
    meshes = {n['name'] for n in doc['nodes'] if 'mesh' in n}
    from scvi_tracm import inspect_visibility
    row['excluded_visibility_targets'] = sorted({t['target'] for p in row['selected_motion_files']
        if p['path'].endswith('.tracm') for t in inspect_visibility(Path(p['path']))
        if t['target'].removesuffix('_shape') not in meshes})
    assert all('_shape_lod' in s for s in row['excluded_visibility_targets'])
    channels = {a:str(directory/(m+'.tracm')) for a,m in row['actions'].items()}
    entries = []
    for variant,suffix in [('normal',''),('shiny','_rare')]:
        table = directory/('pm0770_11_00'+suffix+'.trmtr')
        out = WORK/variant
        out.mkdir(exist_ok=True)
        material_receipt = rebuild(seeded,out/'albedo.glb',table)
        # The preview extends the existing layer-emission interpretation to ZA's
        # explicit EnableEmissionLayer flag. This is recorded, not source parity.
        original = emission.inspect_materials
        dynamic = False
        def emission_labels(path):
            rows = original(path)
            for m in rows:
                if any(s['values'].get('EnableEmissionLayer') == 'True' for s in m['shaders']):
                    m['shaders'] = [{'name':'Eye'}]
                    if dynamic and m['name'] in curves['emission']:
                        controlled = curves['emission'][m['name']]['parameters']
                        for i in range(1,5):
                            key = 'EmissionIntensityLayer'+str(i)
                            m['floats'][key] = 1 if key in controlled else 0
            return rows
        emission.inspect_materials = emission_labels
        try:
            emission.restore(out/'albedo.glb',out/'baseline.glb',table)
            dynamic = True
            emission_receipt = emission.restore(out/'albedo.glb',out/'model.glb',table)
        finally: emission.inspect_materials = original
        baseline = {}
        baseline_doc,baseline_bin = chunks(out/'baseline.glb')
        for m in inspect_materials(table):
            controlled = curves['emission'].get(m['name'],{}).get('parameters',[])
            if not controlled or m['name']=='body_b_01':continue
            if not any(m['floats'].get('EmissionIntensityLayer'+str(i),0)>0 and
                       'EmissionIntensityLayer'+str(i) not in controlled for i in range(1,5)):continue
            assert all(m['floats'].get(key,0)==0 for key in controlled)
            mat = next(r for r in baseline_doc['materials'] if r['name']==m['name'])
            image = baseline_doc['images'][baseline_doc['textures'][mat['emissiveTexture']['index']]['source']]
            view = baseline_doc['bufferViews'][image['bufferView']]
            target = out/(m['name']+'-static-emission.png')
            target.write_bytes(baseline_bin[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
            baseline[m['name']]={'path':str(target),'sha256':sha(target),
                'strength':mat.get('extensions',{}).get('KHR_materials_emissive_strength',{}).get('emissiveStrength',1)}
        path = out/'model.glb'
        entry = {'species':'zygarde-10'+('-shiny' if suffix else ''),'variant':variant,
                 'path':str(path),'glb_sha256':sha(path),'animations':exported['animations'],
                 'runtime_approved':False,'complete_pose_channels':True,
                 'material_table':str(table),'material_table_sha256':sha(table),
                 'material_receipt':material_receipt,'emission_receipt':emission_receipt,
                 'geometry_motion_signature':compare(source,path)}
        entry['visibility'] = visibility(row,entry,directory)
        # Verify that the baked eye's colour and shadow UV domains are equal.
        for motion in channels.values():
            tracks = read_uv_tracks(Path(motion),parameters=('UVScaleOffset','UVScaleOffset1'))
            values = {t['parameter']:[channel_samples(c,tracks['frames']-1) for c in t['channels']]
                      for t in tracks['tracks'] if t['material']=='eye'}
            eye = next(m for m in inspect_materials(table) if m['name']=='eye')
            defaults = eye['colors']
            first = values.get('UVScaleOffset', [[v] * tracks['frames'] for v in defaults['UVScaleOffset']])
            second = values.get('UVScaleOffset1', [[v] * tracks['frames'] for v in defaults['UVScaleOffset1']])
            assert first == second
        original = scvi_eye_motion.inspect_materials
        def eye_labels(path):
            rows = original(path)
            for m in rows:
                if m['name'] in ('eye','eff_body_c','eff_body_d'):
                    if m['name']=='eye':assert m['shaders'][0]['values']['EnableEyeOptions']=='True'
                    m['shaders']=[{'name':'Eye','values':{'EyelidType':'None'}}]
            return rows
        scvi_eye_motion.inspect_materials = eye_labels
        try:
            entry['eye_motion']=scvi_eye_motion.prepare({'material_source':str(table),'identity_intake':{
                'source_eye_material_diagnostic':'eyelid_source_uv','motion_channels':channels,
                'identity_evidence':{'source_sha256':{p:sha(p) for p in channels.values()}}}},
                entry['animations'],entry['glb_sha256'])
        finally: scvi_eye_motion.inspect_materials=original
        for material in entry['eye_motion']['materials']:
            if material['material'].startswith('eff_'):
                material['repeat_uv'] = True
        entry['materials']={m['name']:m for m in inspect_materials(table)}
        entry['material_motion'] = curves
        entry['static_emission'] = baseline
        core=entry['materials']['body_b_01']
        entry['core_textures']={}
        for name,texture in core['textures'].items():
            p=directory/Path(texture).with_suffix('.png')
            if name=='LocalSpecularProbe':p=p.with_stem(p.stem+'_0')
            entry['core_textures'][name]={'path':str(p),'sha256':sha(p)}
        entries.append(entry)
    compare(Path(entries[0]['path']),Path(entries[1]['path']))
    write(WORK/'stage.json',{'runtime_approved':False,'entries':entries,
        'source_glb':str(source),'source_glb_sha256':sha(source),
        'interpretations':[
            'Core: source colour and normal domains, view-dependent fifth-power Fresnel with source bias; formula is a reconstruction.',
            'Core normal-offset distortion strength 0.015 UV units is authored for this preview, not recovered from the source.',
            'The one exported white probe is sampled as a constant local reflection response; cubemap layout is not inferred.',
            'Shell: native albedo alpha and Godot screen-space thin refraction at authored strength 0.01.',
            'Layered emission and eyes use the existing PBR translation; original-engine equivalence is not claimed.',
            'Source emission-power and additive-opacity curves are retained; equal layer powers are verified before combining their masks.',
            'Additive effects retain source visibility timing; no geometry or skeletal animation replacement.']})
    project=WORK/'project';project.mkdir(exist_ok=True)
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Zygarde local preview"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    for name in ('tools','scripts','resources','data'):
        p=project/name
        if not p.exists():p.symlink_to(ROOT/name,target_is_directory=True)
    print('ZYGARDE_PREVIEW_STAGED', len(entries), flush=True)


if __name__=='__main__':main()
