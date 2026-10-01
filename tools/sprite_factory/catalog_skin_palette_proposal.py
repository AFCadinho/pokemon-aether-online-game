"""Source-skin UV colour mask for review: no vertices, weights, alpha or clips changed."""
import colorsys
import json
from io import BytesIO
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageChops, ImageFilter
from catalog_remaining_eye_bake import chunks,append_png,write_glb
from catalog_remaining_native_emission import sha
from phase5_variant_parity import compare


def accessor(doc,blob,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    kind,size={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',size*count)
    return [struct.unpack_from('<'+kind*count,blob,start+i*stride) for i in range(a['count'])]


def build(row,joints,hue,saturation,target):
    if sha(row['path'])!=row['glb_sha256']:raise ValueError('Pinned skin palette input changed')
    doc,original=chunks(Path(row['path']));blob=bytearray(original);masks={};images={};changed=[]
    for node in doc['nodes']:
        if 'mesh' not in node or 'skin' not in node:continue
        names=[doc['nodes'][i]['name'] for i in doc['skins'][node['skin']]['joints']]
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            mi=primitive['material'];material=doc['materials'][mi]
            if 'eye' in material['name'].lower():continue
            info=material.get('pbrMetallicRoughness',{}).get('baseColorTexture')
            if info is None:continue
            if mi not in images:
                tex=doc['textures'][info['index']];view=doc['bufferViews'][doc['images'][tex['source']]['bufferView']];start=view.get('byteOffset',0)
                images[mi]=Image.open(BytesIO(original[start:start+view['byteLength']])).convert('RGBA')
                masks[mi]=(Image.new('L',images[mi].size),Image.new('L',images[mi].size))
            uv=accessor(doc,original,primitive['attributes']['TEXCOORD_0']);bones=accessor(doc,original,primitive['attributes']['JOINTS_0']);weights=accessor(doc,original,primitive['attributes']['WEIGHTS_0']);indices=[r[0] for r in accessor(doc,original,primitive['indices'])]
            owned=[names[b[max(range(len(w)),key=lambda k:w[k])]] in joints for b,w in zip(bones,weights)]
            transform=info.get('extensions',{}).get('KHR_texture_transform',{});scale=transform.get('scale',[1,1]);offset=transform.get('offset',[0,0]);width,height=images[mi].size
            for k in range(0,len(indices),3):
                tri=indices[k:k+3];yes=all(owned[i] for i in tri)
                # glTF UV origin is upper-left; do not apply the Blender V flip.
                # https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#images
                points=[((uv[i][0]*scale[0]+offset[0])*(width-1),(uv[i][1]*scale[1]+offset[1])*(height-1)) for i in tri]
                ImageDraw.Draw(masks[mi][0 if yes else 1]).polygon(points,fill=255)
    for mi,image in images.items():
        mask,other=masks[mi];overlap=ImageChops.multiply(mask,other)
        if overlap.histogram()[255]>max(64,sum(1 for p in mask.get_flattened_data() if p)/100):
            raise ValueError('Selected joint UVs overlap unselected surfaces; no automatic palette proposal')
        mask=ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(3)),other)
        result=image.copy();pixels=result.load()
        for y in range(image.height):
            for x in range(image.width):
                if mask.getpixel((x,y))==0:continue
                p=pixels[x,y];h,s,v=colorsys.rgb_to_hsv(*(n/255 for n in p[:3]))
                if p[3]<16 or s<.13 or v<.12:continue
                pixels[x,y]=(*[round(n*255) for n in colorsys.hsv_to_rgb(hue,saturation,v)],p[3])
        if result.tobytes()==image.tobytes():continue
        assert result.getchannel('A').tobytes()==image.getchannel('A').tobytes()
        out=BytesIO();result.save(out,format='PNG');material=doc['materials'][mi];info=material['pbrMetallicRoughness']['baseColorTexture'];sampler=doc['textures'][info['index']].get('sampler',0);info['index']=append_png(doc,blob,out.getvalue(),material['name']+'_joint_uv_palette',sampler);changed.append(material['name'])
    if not changed:raise ValueError('No positive selected-joint colour pixels')
    target.parent.mkdir(parents=True,exist_ok=False);write_glb(target,doc,blob)
    result=dict(row,path=str(target),glb_sha256=sha(target),geometry_motion_sha256=compare(Path(row['path']),target),skin_palette_proposal={'joints':joints,'hue':hue,'saturation':saturation,'materials':changed,'source_sha256':row['glb_sha256'],'alpha_unchanged':True},runtime_approved=False)
    target.with_suffix('.receipt.json').write_text(json.dumps(result,indent=2));return result
