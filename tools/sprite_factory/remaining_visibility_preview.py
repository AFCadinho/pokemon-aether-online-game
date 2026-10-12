"""Nine form-state proposals; explicit authored visibility, no source-parity claim."""
import os
from pathlib import Path

import alternate_forms_batch as batch
from catalog_galar_birds_candidates import read, write, sha
from catalog_remaining_eye_bake import chunks
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT/'.tmp/remaining-colour-visibility-v1'
OLD = ROOT/'.tmp/alternate-forms-recovery-v1'
NAMES = ['minior-'+c for c in ['blue','green','indigo','meteor','orange','violet','yellow']] + [
    'cramorant-gorging','cramorant-gulping']


def visible(name, mesh):
    """Preview policy only; all final target lists are hash-bound in the stage."""
    if name.startswith('minior-'):
        if '_feeler_' in mesh: return False
        if '_shell_' in mesh: return name == 'minior-meteor'
        if name == 'minior-meteor' and ('_eye_' in mesh or '_mouth_' in mesh): return False
        return True
    if '_kawamasu' in mesh: return name == 'cramorant-gulping'
    if '_pikachu' in mesh: return name == 'cramorant-gorging'
    return True


def build():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    # Historical conversion modules are reused unchanged with a fresh output root.
    batch.WORK = WORK/'visibility-source'
    import alternate_forms_recovery_legacy as legacy
    intake = HERE/'alternate_forms_recovery_intake.json'
    rows = {r['species']:r for r in read(intake)['entries']}
    entries = []
    for name in NAMES:
        row = rows[name]
        reuse = name if (OLD/'export'/name/'model.glb').exists() else (
            'minior-blue' if name.startswith('minior-') and name != 'minior-meteor' else None)
        out = batch.WORK/'export'/name
        out.mkdir(parents=True,exist_ok=True)
        if reuse:
            previous_job = read(OLD/'export'/reuse/'job.json')
            assert previous_job['actions'] == row['actions']
            assert previous_job['source_sha256'] == row['source']['sha256']
            assert previous_job['diagnostic_rig_selection'] == row['diagnostic_rig_selection']
            for filename in ('model.glb','export.json'):
                p = out/filename
                if not p.exists(): p.symlink_to(OLD/'export'/reuse/filename)
        export, normal, shiny, evidence = legacy.build(row)
        exported = read(export/'export.json')
        for variant, path in [('normal',normal),('shiny',shiny)]:
            doc, _ = chunks(path)
            meshes = sorted(n['name'] for n in doc['nodes'] if 'mesh' in n)
            assert len(meshes) == (15 if name.startswith('minior-') else 8)
            tracks = [{'mesh':m,'source_target':m+'_shape','keys':[[0.0,visible(name,m)]]} for m in meshes]
            proposal = {'species':name,'runtime_approved':False,'tracks':tracks,
                'policy':'Authored static form state for every clip; discarded shell fragments hidden; only the selected Cramorant prey visible.',
                'limitations':'No native visibility timings recovered. Does not implement a mid-clip form transformation or prey ejection state.',
                'source_sha256':row['source']['sha256'],'intake_sha256':sha(intake)}
            proposal_path = WORK/'visibility-proposals'/(name+'.json')
            write(proposal_path, proposal)
            glb_hash = sha(path)
            visibility = {'schema':1,'glb_sha256':glb_hash,
                'clips':{a:{'duration':c['duration'],'loop':c['loop'],
                    'source_sha256':sha(proposal_path),'tracks':tracks} for a,c in exported['animations'].items()}}
            entries.append({'species':name+('-shiny' if variant=='shiny' else ''),
                'base_species':name,'variant':variant,'runtime_approved':False,
                'path':str(path),'glb_sha256':glb_hash,'animations':exported['animations'],
                'visibility':visibility,'proposal_sha256':sha(proposal_path),
                'source_glb':str(export/'model.glb'),'source_glb_sha256':sha(export/'model.glb'),
                'material_evidence':evidence,'sleep_binding':row.get('sleep_binding'),
                'material_limitations':'Native normal/rare palettes; own archived motions. Static visibility reconstruction and eye behaviour need visual review.'})
            if name.startswith('minior-'):
                table = batch.WORK/'legacy-palettes'/name/('normal' if variant=='normal' else 'rare')/(row['resource']+('' if variant=='normal' else '_rare')+'.trmtr')
                specs = {}
                for material in inspect_materials(table):
                    if 'LayerMaskMap' not in material['textures']: continue
                    f,c = material['floats'],material['colors']
                    assert c['UVScaleOffset']==[1,1,0,0] and f['EmissionIntensity']==0
                    textures = {}
                    for source,uniform in [('BaseColorMap','base_tex'),('LayerMaskMap','mask_tex'),
                            ('NormalMap','normal_tex'),('MetallicMap','metallic_tex'),('RoughnessMap','roughness_tex'),('AOMap','ao_tex')]:
                        if source not in material['textures']: continue
                        p = table.parent/Path(material['textures'][source]).with_suffix('.png').name
                        textures[uniform] = {'path':str(p),'sha256':sha(p),'size':list(Image.open(p).size)}
                    parameters = {'has_metallic_tex':'metallic_tex' in textures,
                        'has_roughness_tex':'roughness_tex' in textures,'base_metallic':f.get('Metallic',0),
                        'base_roughness':f.get('Roughness',.5),'normal_height':f['NormalHeight']}
                    for source,uniform in [('LayerMaskScale','layer_scale'),('MetallicLayer','layer_metallic'),
                            ('RoughnessLayer','layer_roughness'),('EmissionIntensityLayer','layer_power')]:
                        parameters[uniform] = [f[source+str(i)] for i in range(1,5)]
                    for i in range(1,5):
                        parameters['colour'+str(i)] = c['BaseColorLayer'+str(i)]
                        parameters['emission'+str(i)] = c['EmissionColorLayer'+str(i)]
                    specs[material['name']] = {'textures':textures,'parameters':parameters,
                        'source_shader':material['shaders'],'table_sha256':sha(table)}
                entries[-1]['minior_materials'] = specs
                entries[-1]['material_limitations'] += ' Separate-resolution linear layer shader is a local reconstruction; emission blending and native material animation remain unverified.'
        compare(normal,shiny)
        print('VISIBILITY_PREVIEW_GLB_BUILT',name,flush=True)
    write(WORK/'visibility-stage.json',{'runtime_approved':False,'entries':entries})


if __name__ == '__main__':
    build()
