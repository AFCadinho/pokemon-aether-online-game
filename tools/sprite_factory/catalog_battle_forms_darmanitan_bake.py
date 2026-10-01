"""Reproduce the approved Darmanitan material atlas from hash-pinned baked inputs."""
import argparse
from pathlib import Path
from io import BytesIO
import colorsys, copy, hashlib, json
from PIL import Image
from catalog_remaining_eye_bake import chunks, write_glb, append_png

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
base=args.work.resolve()
checkpoint=json.loads(Path(__file__).with_name('catalog_battle_forms_next_seven_checkpoint.json').read_text())
for relative,expected in checkpoint['darmanitan_bake_inputs_sha256'].items():
 if hashlib.sha256((base/relative).read_bytes()).hexdigest()!=expected:
  raise ValueError('Darmanitan bake input changed: '+relative)
raw=base/'legacy-export/darmanitan-zen/flat/model.glb'
materials={'BodyVco':base/'legacy-material-bakes/darmanitan-zen-uv1/BodyVco-colour.png','Body':base/'legacy-material-bakes/darmanitan-zen-uv1/Body-colour.png'}
out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)

def png_bytes(img):
 b=BytesIO();img.save(b,format='PNG',optimize=True);return b.getvalue()
def shiny_img(path):
 im=Image.open(path).convert('RGBA')
 px=[]
 for r,g,b,a in im.getdata():
  h,s,v=colorsys.rgb_to_hsv(r/255,g/255,b/255)
  # Darmanitan Zen shiny: cyan body shifts to blue; orange accents to pink.
  if 0.46 <= h <= 0.62 and s > 0.10:
   h=0.62
  elif 0.025 <= h <= 0.13 and s > 0.18:
   h=0.84
  rr,gg,bb=colorsys.hsv_to_rgb(h,s,v)
  px.append((round(rr*255),round(gg*255),round(bb*255),a))
 im.putdata(px);return im

def build(target, shiny=False):
 doc,binbuf=chunks(raw)
 if 'KHR_texture_transform' in doc.get('extensionsUsed',[]):
  doc['extensionsUsed'].remove('KHR_texture_transform')
 for material in doc['materials']:
  name=material['name']
  if name not in materials: continue
  tex=material['pbrMetallicRoughness']['baseColorTexture']
  sampler=doc['textures'][tex['index']].get('sampler',0)
  image=Image.open(materials[name]).convert('RGBA')
  if shiny:image=shiny_img(materials[name])
  texture=append_png(doc,binbuf,png_bytes(image),f'{name}_{"shiny" if shiny else "normal"}_uv01_bake',sampler)
  tex['index']=texture
  tex.pop('extensions',None)
  tex['texCoord']=0
 write_glb(target,doc,binbuf)
 return hashlib.sha256(target.read_bytes()).hexdigest()
for name,shiny in [('normal',False),('shiny',True)]:
 p=out/f'{name}.glb';print(name,build(p,shiny),p.stat().st_size)
