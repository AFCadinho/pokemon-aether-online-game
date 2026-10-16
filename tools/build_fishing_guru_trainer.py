#!/usr/bin/env python3
"""Authored Fishing Guru trainer layers on the approved male pose (80px logical).
The starter trouser/shoe/hair contours are attributed template adaptations;
vest, rolled sleeves, hat, rod, line and reel are original registered pixel drawing.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import argparse
ROOT=Path(__file__).resolve().parents[1]
HEX={'o':'29352f','s':'56624f','m':'7b8564','h':'a2a67c','b':'365c59','t':'527c77','u':'82a198','e':'474336','v':'897957','a':'bba67e','l':'dfcca3','d':'293b3e','p':'465c5b','q':'657973','f':'514f43','g':'85816a','R':'bd7151','X':'000000'}
P={k:tuple(bytes.fromhex(v))+(255,) for k,v in HEX.items()}
def blank():return Image.new('RGBA',(80,80))
def read(path):
 im=Image.open(path).convert('RGBA')
 if im.size==(160,160):
  small=im.resize((80,80),Image.Resampling.NEAREST)
  assert small.resize(im.size,Image.Resampling.NEAREST).tobytes()==im.tobytes(),path
  return small
 assert im.size==(80,80),path
 return im

def poly(im,points,color,outline=None):ImageDraw.Draw(im).polygon(points,fill=P[color],outline=P[outline] if outline else None)
def line(im,points,color,width=1):ImageDraw.Draw(im).line(points,fill=P[color],width=width)
def remap(im,mapping):
 out=im.copy();out.putdata([mapping[p[:3]] if p[3] else (0,0,0,0) for p in im.get_flattened_data()]);return out

def artwork(project):
 src=project/'assets/battles/trainers/player/male';base=read(src/'base.png')
 pants=remap(read(src/'starter_kit/trousers.png'),{(0,0,0):P['X'],(50,37,56):P['d'],(68,49,76):P['p'],(83,61,93):P['q']})
 shoes=remap(read(src/'starter_kit/shoes.png'),{(0,0,0):P['X'],(77,77,77):P['f'],(104,104,104):P['g'],(122,122,122):P['g'],(167,167,183):P['g'],(189,189,189):P['g']})
 hair=remap(read(src/'starter_kit/hair.png'),{(0,0,0):(0,0,0,255),(34,34,34):(34,34,34,255),(54,54,54):(54,54,54,255),(76,76,76):(76,76,76,255),(93,93,93):(122,122,122,255)})
 top=blank()
 # Under-shirt, collar and rolled sleeves follow the posed body, not a scaled overworld cel.
 poly(top,[(38,25),(46,25),(50,28),(50,43),(49,47),(36,47),(35,43),(36,29)],'t','o')
 poly(top,[(37,26),(33,27),(30,30),(30,33),(33,35),(37,32),(39,29)],'t','o')
 poly(top,[(33,28),(31,31),(32,33),(35,31),(37,28)],'u')
 line(top,[(30,32),(33,34),(35,32)],'u',2)
 poly(top,[(48,26),(51,28),(54,32),(55,35),(52,37),(49,33),(47,30)],'t','o')
 poly(top,[(49,28),(51,29),(53,32),(52,34),(50,31)],'u')
 line(top,[(52,36),(54,35),(54,33)],'u',2)
 poly(top,[(40,25),(43,27),(46,25),(44,30),(42,30)],'b')
 line(top,[(42,30),(42,43),(43,46)],'b')
 # Open sand vest: two large panels and only two pocket flaps.
 poly(top,[(37,26),(40,26),(41,30),(40,42),(41,46),(36,46),(35,42),(36,31)],'a','e')
 poly(top,[(38,27),(40,29),(39,36),(37,35),(37,30)],'l')
 poly(top,[(45,26),(48,26),(50,29),(49,42),(49,46),(44,46),(45,40),(44,30)],'a','e')
 poly(top,[(46,27),(48,28),(48,35),(46,35)],'l')
 ImageDraw.Draw(top).rectangle((36,37,39,41),fill=P['v']);ImageDraw.Draw(top).rectangle((36,38,39,38),fill=P['l'])
 ImageDraw.Draw(top).rectangle((45,37,48,41),fill=P['v']);ImageDraw.Draw(top).rectangle((45,38,48,38),fill=P['l'])
 line(top,[(36,44),(40,44)],'v');line(top,[(45,44),(49,44)],'v')
 # Bucket hat: closed crown, quiet highlights, darker band, short soft brim.
 hat=blank();poly(hat,[(38,4),(47,4),(50,6),(52,11),(54,13),(53,14),(34,14),(33,13),(35,10),(36,6)],'m','o')
 poly(hat,[(38,5),(46,5),(47,6),(39,6),(37,8),(36,9),(36,7)],'h')
 poly(hat,[(49,7),(50,8),(51,12),(49,12)],'s')
 line(hat,[(35,11),(39,11),(48,11),(51,11)],'b')
 line(hat,[(35,12),(40,12),(48,12),(52,13)],'h')
 line(hat,[(35,14),(52,14)],'s')
 # Bobber on the same anatomical side; trainer sprite is authored facing slightly left.
 poly(hat,[(49,7),(50,6),(51,7),(51,8),(49,8)],'R')
 ImageDraw.Draw(hat).rectangle((49,9,51,9),fill=P['l']);hat.putpixel((50,10),P['e'])
 # Back-carried rod and reel are visibly attached near the hip, with a separate line.
 rear=blank();line(rear,[(53,58),(54,49),(55,39),(57,28),(59,17),(62,6),(64,2)],'a')
 line(rear,[(61,10),(62,6),(64,2)],'v')
 line(rear,[(65,3),(67,6),(69,12),(69,29)],'u')
 ImageDraw.Draw(rear).rectangle((68,30,70,31),fill=P['R']);ImageDraw.Draw(rear).rectangle((68,32,70,33),fill=P['l']);rear.putpixel((69,34),P['e'])
 poly(rear,[(55,48),(58,48),(59,49),(59,52),(57,53),(55,51)],'d')
 ImageDraw.Draw(rear).rectangle((56,49,57,51),fill=P['u']);line(rear,[(58,52),(60,52),(60,53)],'a')
 ImageDraw.Draw(rear).rectangle((53,54,54,59),fill=P['v']);line(rear,[(53,55),(53,58)],'a')
 front=blank();line(front,[(48,27),(47,31),(44,36),(41,42),(38,46)],'v')
 line(rear,[(50,40),(52,43),(54,47)],'v')
 # Use the same full canvas and original pose. Face, ball and exposed hands are in the base.
 layers={'bottom':pants,'shoes':shoes,'top':top,'hair':hair,'headgear':hat,'cape':rear,'cape_overlay':front}
 # The starter trouser template overlaps the free hand at the hip. Keep the
 # approved hand/ball pixels above our garment overlays without changing the base.
 protected=Image.new('L',(80,80));locked=ImageDraw.Draw(protected)
 locked.rectangle((21,18,26,28),fill=255)
 locked.rectangle((50,40,55,48),fill=255)
 for category in ['bottom','shoes','top','cape_overlay']:
  layers[category].paste((0,0,0,0),(0,0),protected)
 return base,layers

def main():
 p=argparse.ArgumentParser();p.add_argument('--project-root',type=Path,default=ROOT);p.add_argument('--out-dir',type=Path);p.add_argument('--review',type=Path);p.add_argument('--check',action='store_true');a=p.parse_args()
 project=a.project_root.resolve();out=(a.out_dir or project/'assets/battles/trainers/player/male/fishing_guru').resolve();base,layers=artwork(project)
 names={'top':'Vest','bottom':'Trousers','shoes':'Shoes','hair':'Hair','headgear':'Hat','cape':'BackRear','cape_overlay':'BackFront'}
 for k,im in layers.items():
  path=out/(names[k]+'.png');export=im.resize((160,160),Image.Resampling.NEAREST)
  if a.check:assert path.is_file() and Image.open(path).convert('RGBA').tobytes()==export.tobytes(),f'Art differs: {path}'
  else:out.mkdir(parents=True,exist_ok=True);export.save(path)
 if a.review:
  comp=layers['cape'].copy();comp.alpha_composite(base)
  for k in ['bottom','shoes','top','cape_overlay','hair','headgear']:comp.alpha_composite(layers[k])
  a.review.parent.mkdir(parents=True,exist_ok=True);comp.resize((160,160),Image.Resampling.NEAREST).save(a.review)
 print('Verified' if a.check else 'Wrote','seven Fishing Guru trainer layers')
if __name__=='__main__':main()
