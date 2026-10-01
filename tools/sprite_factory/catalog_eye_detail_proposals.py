"""Explicit eye-only review textures. Preserves alpha and native scene geometry.

Source-mask recovery and hand-authored highlight/iris proposals are separately
labelled. Named recipes also recolour skin on shiny eye atlases; copying the
entire normal eye atlas is unsafe when it includes surrounding body colour.
"""
from pathlib import Path
from io import BytesIO
from copy import deepcopy
import colorsys,hashlib,json,sys
from PIL import Image,ImageDraw
from catalog_skin_palette_proposal import accessor
from catalog_remaining_eye_bake import chunks,bake_eye
from catalog_sleep_atlas_proposals import texture
from scvi_material_probe import inspect_materials

# Only named materials are used; no body texture or global export default changes.
SKIN_HUES={'wailmer':(.57,.79),'sealeo':(.56,.83),'armaldo':(.59,.94),
 'corsola':(.97,.55),'druddigon':(.97,.13),'fearow':(.09,.15),
 'jellicent-male':(.55,.38),'kabutops':(.08,.30),'kingler':(.07,.29),
 'nidoking':(.86,.60),'nidoqueen':(.57,.31),'octillery':(.02,.13),
 'rattata':(.77,.33),'seaking':(.04,.13),'spearow':(.07,.13),
 'tentacool':(.56,.70),'gorebyss':(.90,.14),'huntail':(.55,.34),
 'swellow':(.60,.40),'taillow':(.62,.40)}
IRIS_HUES={'elgyem':(.34,.80),'beheeyem':(.40,.61),'lunatone':(.99,.60),'claydol':(.99,.12),'aegislash-shield':(.76,.12)}
OFFICIAL={'bulbasaur':'pm0001_00_00','bidoof':'pm0399_00_00',
 'rhyperior':'pm0464_00_00','shiftry':'pm0275_00_00','kyurem':'pm0646_11_00',
 'keldeo-ordinary':'pm0647_11_00'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def hue_transfer(image,source,target,saturation_delta=0.0,value_ratio=1.0):
 result=image.copy();values=[]
 for p in image.get_flattened_data():
  h,s,v=colorsys.rgb_to_hsv(*(x/255 for x in p[:3]));distance=min(abs(h-source),1-abs(h-source))
  if p[3] and s>.22 and v>.16 and distance<.085:
   p=(*[round(x*255) for x in colorsys.hsv_to_rgb((h+target-source)%1,max(0,min(1,s+saturation_delta)),max(0,min(1,v*value_ratio)))],p[3])
  values.append(p)
 result.putdata(values)
 assert result.getchannel('A').tobytes()==image.getchannel('A').tobytes()
 return result

def paired_skin_delta(normal,shiny,background):
 """Use corresponding body texels to keep eye-atlas skin equal to shiny skin."""
 nd,nb=chunks(Path(normal['path']));sd,sb=chunks(Path(shiny['path']))
 sm={m['name']:m for m in sd['materials']};best=None
 for material in nd['materials']:
  name=material['name']
  if 'eye' in name.lower() or name not in sm:continue
  if 'baseColorTexture' not in material.get('pbrMetallicRoughness',{}):continue
  a,ainfo=texture(nd,nb,material);z,zinfo=texture(sd,sb,sm[name])
  if a.size!=z.size or ainfo.get('extensions')!=zinfo.get('extensions'):continue
  aa=list(a.get_flattened_data());zz=list(z.get_flattened_data())
  for i in range(0,len(aa),max(1,len(aa)//8192)):
   x,y=aa[i],zz[i]
   if min(x[3],y[3])<200:continue
   distance=sum((x[k]-background[k])**2 for k in range(3))
   if best is None or distance<best[0]:best=(distance,x,y,name)
 if best is None or best[0]>35**2:raise ValueError('No corresponding source body colour for eye atlas')
 _,a,z,name=best;ah,ass,av=colorsys.rgb_to_hsv(*(x/255 for x in a[:3]));zh,zs,zv=colorsys.rgb_to_hsv(*(x/255 for x in z[:3]))
 return (ah,zh,zs-ass,zv/max(av,.1)),{'normal_body_pixel':a,'shiny_body_pixel':z,'material':name,'squared_distance':best[0]}

def keldeo_iris(image,mask):
 """Authored blue iris/pupil proposal inside the source's positive green iris mask."""
 result=image.copy();mask=mask.resize(image.size,Image.Resampling.NEAREST)
 pixels=mask.load();points=[(x,y) for y in range(mask.height) for x in range(mask.width) if pixels[x,y][1]>180 and pixels[x,y][0]<80]
 if not points:raise ValueError('No source iris mask')
 xs,ys=zip(*points);cx=(min(xs)+max(xs))/2;cy=(min(ys)+max(ys))/2;rx=(max(xs)-min(xs)+1)/2;ry=(max(ys)-min(ys)+1)/2
 for x,y in points:
  px=(x-cx)/rx;py=(y-cy)/ry
  result.putpixel((x,y),(12,15,24,255) if (px/.37)**2+(py/.68)**2<1 else (30,135,194,255))
 draw=ImageDraw.Draw(result);radius=rx*.18;gx=cx-rx*.22;gy=cy-ry*.35;draw.ellipse((gx-radius,gy-radius,gx+radius,gy+radius),fill=(250,250,250,255))
 return result

def nincada_glints(image):
 result=image.copy();draw=ImageDraw.Draw(result);w=image.width/4;h=image.height/4
 # The atlas contains four native open cells across its first row. Blink and
 # closed cells below it are intentionally untouched.
 for col in range(4):
  cell=image.crop((round(col*w),0,round((col+1)*w),round(h)))
  dark=[(x,y) for y in range(cell.height) for x in range(cell.width) if max(cell.getpixel((x,y))[:3])<65]
  if not dark:raise ValueError('Open eye cell has no pupil')
  xs,ys=zip(*dark);cx=(min(xs)+max(xs))/2;cy=(min(ys)+max(ys))/2
  rx=(max(xs)-min(xs)+1)*.09;gx=col*w+cx-rx;gy=cy-rx*1.2
  draw.ellipse((gx-rx,gy-rx,gx+rx,gy+rx),fill=(250,250,250,255))
 assert result.getchannel('A').tobytes()==image.getchannel('A').tobytes()
 return result

def build(runtime_path,source_root,output):
 output.mkdir(parents=True,exist_ok=False);rows=json.loads(runtime_path.read_text());by={r['species']:r for r in rows};jobs=[];audit=[]
 for row in rows:
  if sha(row['path'])!=row['glb_sha256']:raise ValueError('Eye proposal GLB hash changed')
  name=row['species'].removesuffix('-shiny');shiny=row['species'].endswith('-shiny');doc,blob=chunks(Path(row['path']));materials={};notes=[]
  resource=None;official={}
  if name in OFFICIAL:
   identity=OFFICIAL[name];resource=source_root/identity.split('_')[0]/identity;table=resource/(identity+'.trmtr')
   if table.exists():official={r['name']:r for r in inspect_materials(table)}
  for mat in doc['materials']:
   mname=mat['name']
   if name=='anorith' and mname in ['BodyAParasVco00','BodyAParasVco01']:
    directory=output/row['species'];directory.mkdir(exist_ok=True)
    scale=4;ring=Image.new('RGBA',(512*scale,512*scale),(255,255,255,255));draw=ImageDraw.Draw(ring);domains=[]
    for mesh in doc['meshes']:
     for primitive in mesh['primitives']:
      if doc['materials'][primitive['material']]['name']!=mname:continue
      uv=accessor(doc,blob,primitive['attributes']['TEXCOORD_0']);positions=accessor(doc,blob,primitive['attributes']['POSITION']);indices=[v[0] for v in accessor(doc,blob,primitive['indices'])];xs,ys=zip(*uv)
      lo=min(p[2] for p in positions);hi=max(p[2] for p in positions);cut=(lo+hi)/2+(hi-lo)*.325
      for start in range(0,len(indices),3):
       polygon=[(positions[i][2],*uv[i]) for i in indices[start:start+3]];clipped=[]
       for current,previous in zip(polygon,polygon[-1:]+polygon[:-1]):
        inside=current[0]>=cut;was=previous[0]>=cut
        if inside!=was:
         t=(cut-previous[0])/(current[0]-previous[0]);clipped.append((cut,previous[1]+t*(current[1]-previous[1]),previous[2]+t*(current[2]-previous[2])))
        if inside:clipped.append(current)
       if len(clipped)>=3:draw.polygon([(u*512*scale,v*512*scale) for _,u,v in clipped],fill=(255,255,255,0))
      domains.append([min(xs),min(ys),max(xs),max(ys)])
    ring=ring.resize((512,512),Image.Resampling.LANCZOS);path=directory/(mname+'.png');ring.save(path)
    materials[mname]={'open':{'path':str(path),'sha256':sha(path)},'alpha':True,'method':'Authored compatibility white sclera shell with pupil window over the smaller source pupil sphere; source lens cannot refract in Compatibility; pupil window rasterised from the actual forward lens surface, not a guessed atlas centre','source_eye_uv_domains':domains};continue
   if 'eye' not in mname.lower():continue
   im,_=texture(doc,blob,mat);changed=False;data={}
   if mname in official and any(s['name']=='Eye' for s in official[mname]['shaders']):
    im=Image.open(BytesIO(bake_eye(official[mname],resource))).convert('RGBA');changed=True
    data.update(opaque=True,disable_false_emission=True,method='source material Eye mask colours; removes flattened coat colour',material_table=str(table),material_table_sha256=sha(table))
    if name=='keldeo-ordinary':
     mask=Image.open(resource/Path(official[mname]['textures']['LayerMaskMap']).with_suffix('.png').name).convert('RGBA');im=keldeo_iris(im,mask);data['method']+='; authored blue iris and pupil using source mask and HOME colour reference'
   if name=='nincada':im=nincada_glints(im);changed=True;data['method']='Authored white glints on four open native atlas cells; blink cells retained'
   recipe=(SKIN_HUES.get(name) or IRIS_HUES.get(name)) if shiny else None
   if recipe and name in SKIN_HUES:
    recipe,receipt=paired_skin_delta(by[name],row,im.getpixel((0,0)));data['paired_body_colour']=receipt
   if recipe:
    corrected=hue_transfer(im,*recipe)
    if corrected.tobytes()!=im.tobytes():im=corrected;changed=True;data['method']='Explicit shiny '+('iris' if name in IRIS_HUES else 'skin on eye atlas')+' hue; black/white pixels and alpha retained'
   if not changed:continue
   directory=output/row['species'];directory.mkdir(exist_ok=True);path=directory/(mname+'.png');im.save(path)
   data['open']={'path':str(path),'sha256':sha(path)}
   closed=row.get('eye_states',{}).get(mname)
   if closed:
    image=Image.open(closed['path']).convert('RGBA')
    if recipe:image=hue_transfer(image,*recipe)
    cp=directory/(mname+'-closed.png');image.save(cp);data['closed']={'path':str(cp),'sha256':sha(cp)}
   materials[mname]=data
  audit.append({'species':row['species'],'eye_materials':[m['name'] for m in doc['materials'] if 'eye' in m['name'].lower()],'corrected':list(materials),'runtime_approved':False})
  if materials:jobs.append(dict(row,eye_detail_materials=materials))
 (output/'audit.json').write_text(json.dumps(audit,indent=2))
 job={'output':str(output/'runtime'),'entries':jobs,'runtime_approved':False};(output/'job.json').write_text(json.dumps(job,indent=2));print('Corrected scenes:',len(jobs))
 return job

if __name__=='__main__':build(Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve(),Path(sys.argv[3]).resolve())
