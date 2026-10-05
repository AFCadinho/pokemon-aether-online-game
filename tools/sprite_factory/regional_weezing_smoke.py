"""Compact own-source chimney plume proposal; independently remeasure afterwards.

Only two smoke meshes change. Body mesh/accessors, rig and all skeletal clips
remain byte-identical. The plumes follow their own chimney joints instead of the
exported cloth extension, which stretches beyond the battle camera in attacks.
"""
import copy
import json
from pathlib import Path
import struct
from PIL import Image
from catalog_remaining_eye_bake import chunks,write_glb
from catalog_dlc_flat_motion import values,mesh_signature
from catalog_galar_birds_candidates import sha
from phase5_variant_parity import compare

WORK=Path(__file__).resolve().parents[2]/'.tmp/regional-production-v1'


def replace(doc,binary,index,rows):
    accessor=doc['accessors'][index];size={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[accessor['type']]
    fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[accessor['componentType']]
    start=len(binary)
    for row in rows:binary.extend(struct.pack('<'+fmt*size,*row))
    length=len(binary)-start;binary.extend(b'\0'*(-len(binary)%4))
    doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':length})
    result=copy.deepcopy(accessor);result['bufferView']=len(doc['bufferViews'])-1;result.pop('byteOffset',None)
    if 'min'in result:result['min']=[min(r[i]for r in rows)for i in range(size)]
    if 'max'in result:result['max']=[max(r[i]for r in rows)for i in range(size)]
    doc['accessors'].append(result);return len(doc['accessors'])-1


def main():
    output=WORK/'weezing-smoke-v1';output.mkdir(exist_ok=False)
    stage=json.loads((WORK/'runtime-final-v1.json').read_text());rows=[]
    noise_path=Path('/home/adinho/Documents/3d_models/Pokémon SCVI Base + DLC Model Dump/pm0110/pm0110_00_31/pm0110_00_31_smoke_b_01_msk.png')
    noise=Image.open(noise_path).convert('L')
    for row in stage:
        if not row['species'].startswith('weezing-galar'):continue
        source=Path(row['path']);assert sha(source)==row['glb_sha256']
        doc,binary=chunks(source);before=mesh_signature(doc,binary);bone_names=[doc['nodes'][n]['name']for n in doc['skins'][0]['joints']];changed=[]
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                if doc['materials'][primitive['material']]['name']!='smoke_c':continue
                attrs=primitive['attributes'];points=values(doc,binary,attrs['POSITION']);normals=values(doc,binary,attrs['NORMAL']);uvs=values(doc,binary,attrs['TEXCOORD_0'])
                anchor=min(p[1]for p in points);joint=bone_names.index('horn_a_10'if 'smoke_e_'in mesh['name']else 'horn_n_06')
                shifted=[]
                for p,n,uv in zip(points,normals,uvs):
                    value=noise.getpixel((int((uv[0]%1)*noise.width)%noise.width,int((uv[1]%1)*noise.height)%noise.height))/255
                    offset=value*.04
                    shifted.append((p[0]+n[0]*offset,anchor+(p[1]-anchor)*.25+n[1]*offset,p[2]+n[2]*offset))
                attrs['POSITION']=replace(doc,binary,attrs['POSITION'],shifted)
                attrs['JOINTS_0']=replace(doc,binary,attrs['JOINTS_0'],[(joint,0,0,0)]*len(points))
                attrs['WEIGHTS_0']=replace(doc,binary,attrs['WEIGHTS_0'],[(1.,0.,0.,0.)]*len(points))
                changed.append(mesh['name'])
        assert len(changed)==2
        after=mesh_signature(doc,binary)
        assert all(after[n]==before[n]for n in before if n not in changed)
        target=output/(row['species']+'.glb');write_glb(target,doc,binary)
        result=dict(row,path=str(target),glb_sha256=sha(target),runtime_approved=False)
        for k in ['runtime_path','runtime_sha256']:result.pop(k,None)
        result['smoke_proposal']={'source_sha256':sha(source),'changed_smoke_meshes':changed,'other_meshes_unchanged':True,
            'noise_source':str(noise_path),'noise_sha256':sha(noise_path),'height_ratio':.25,'source_joints':['horn_a_10','horn_n_06'],
            'limitation':'Compact chimney plumes with baked source noise; original long cloth extension replaced. Native body motion unchanged. New placement measurement and visual review required.'}
        rows.append(result)
    assert len(rows)==2;compare(Path(rows[0]['path']),Path(rows[1]['path']))
    (output/'stage.json').write_text(json.dumps(rows,indent=2)+'\n')


if __name__=='__main__':main()
