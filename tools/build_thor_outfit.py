"""Build Thor clothing and three cape poses on the existing 32px player grid.
Usage: python tools/build_thor_outfit.py /path/to/"Outfit Concepts/Thor"
The approved hand-authored concept supplies trainer layers and torso details.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json, sys, shutil
ROOT = Path(__file__).resolve().parents[1]
CONCEPT = Path(sys.argv[1])
INK='#10151d'; DARK='#222b37'; MID='#3a4656'; LIGHT='#59697b'; STEEL='#879aaf'; SILVER='#c1cfda'
NEAREST=Image.Resampling.NEAREST

def blank(n=32): return Image.new('RGBA',(n,n))
def read(p): return Image.open(p).convert('RGBA')
def native(p): return read(p).resize((128,128),NEAREST)
def cell(im,d,c):
    n=im.width//4
    return im.crop((c*n,d*n,(c+1)*n,(d+1)*n))

def resize_cells(im,n):
    """Pad/crop around the body origin, without scaling any painted pixel."""
    old=im.width//4; out=blank(n*4); offset=(n-old)//2
    for d in range(4):
        for c in range(4):
            frame=blank(n);frame.alpha_composite(cell(im,d,c),(offset,offset))
            out.paste(frame,(c*n,d*n))
    return out
def skin(p): return p[3]>0 and p[0]>p[1]>p[2] and p[0]-p[2]>35

def anchor(reference, target):
    def eyes(im): return [(x,y) for y in range(32) for x in range(32) if im.getpixel((x,y))==(232,232,248,255)]
    a,b=eyes(reference),eyes(target)
    if a and len(a)==len(b):return tuple(round(sum(q[k] for q in b)/len(b)-sum(q[k] for q in a)/len(a)) for k in [0,1])
    points=[(x,y,reference.getpixel((x,y))) for y in range(18) for x in range(32) if reference.getpixel((x,y))[3]]
    def score(offset):
        dx,dy=offset;total=0
        for x,y,p in points:
            q=target.getpixel((x+dx,y+dy)) if 0<=x+dx<32 and 0<=y+dy<32 else (0,0,0,0)
            total+=sum(abs(a-b) for a,b in zip(p,q))
        return total
    return min([(x,y) for y in range(-8,9) for x in range(-4,5)],key=score)

def shade(im,palette):
    out=blank(im.width);colors=[Image.new('RGBA',(1,1),c).getpixel((0,0)) for c in palette]
    for y in range(im.height):
        for x in range(im.width):
            p=im.getpixel((x,y))
            if p[3]:out.putpixel((x,y),colors[min(3,int(sum(p[:3])/3)//64)])
    return out

def cape(d,pose,phase,off,wide_idle=False):
    im=blank(48 if wide_idle else 32); draw=ImageDraw.Draw(im); dx,dy=off
    pad=(im.width-32)//2
    # Four-direction authored cloth silhouettes; the centre stays below the head.
    if d in [0,3]:
        if pose==0:
            # A hanging cape should remain visible beyond both arms from the
            # front. Widen the hem by three native pixels per side, keeping
            # the shoulders attached and the folded fish/ride poses intact.
            pts=([(11,20),(20,20),(23,22),(25,25),(26,28),(24,29),(20,28),(16,29),(11,28),(7,29),(5,28),(6,25),(8,22)]
                 if wide_idle else [(11,20),(20,20),(23,26),(23,28),(19,27),(16,28),(12,27),(8,28),(9,24)])
        elif pose==1:pts=[(11,20),(20,20),(25,20),(28,22),(28,26),(24,28),(19,27),(16,28),(11,27),(7,28),(3,26),(3,22),(7,20)]
        else:
            flutter=1 if phase in [1,3] else 0
            # Broad, rounded cloth folds: lifted hem, no separate pointed tips.
            pts=[(11,20),(20,20),(25,18),(29,18+flutter),(31,20+flutter),(30,24),(26,26),(21,25),(16,26),(11,25),(6,26),(1,24),(0,20+flutter),(2,18+flutter),(6,18)]
    else:
        if pose==0:
            pts=([(12,20),(18,20),(21,22),(24,26),(24,28),(21,29),(17,28),(14,27),(11,26)]
                 if wide_idle else [(12,20),(18,20),(21,27),(19,29),(14,27),(11,26)])
        elif pose==1:pts=[(12,20),(18,20),(24,20),(30,21),(33,23),(32,26),(28,28),(23,29),(17,28),(12,25)]
        else:pts=[(12,20),(18,20),(24,19),(31,17+(phase%2)),(36,17+(phase%2)),(38,19+(phase%2)),(37,23),(33,25),(28,26),(23,26),(17,27),(12,25)]
        if d==2:pts=[(31-x,y) for x,y in pts]
    pts=[(x+dx+pad,y+dy+pad) for x,y in pts];draw.polygon(pts,fill=INK)
    mask=im.getchannel('A')
    # Crisp red folds, no smooth gradients or baked electric particles.
    for y in range(im.height):
        for x in range(im.width):
            if mask.getpixel((x,y)) and all(0<=xx<im.width and 0<=yy<im.height and mask.getpixel((xx,yy)) for xx,yy in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]):
                color=['#872137','#bb2d42','#ee4c56','#bb2d42','#541b2d'][(x-dx-pad+phase//2)%5]
                im.putpixel((x,y),Image.new('RGBA',(1,1),color).getpixel((0,0)))
    return im

def hammer(base,d,off,style):
    im=blank();dr=ImageDraw.Draw(im);dx,dy=off
    # Hide the hammer while fishing so it cannot cover the rod or its grip.
    if style=='fish':return im,(7+dx,23+dy)
    goal=[(9,24),(14,25),(17,25),(22,24)][d];gx,gy=goal[0]+dx,goal[1]+dy
    candidates=[(x,y) for y in range(max(0,gy-3),min(32,gy+4)) for x in range(max(0,gx-3),min(32,gx+4)) if skin(base.getpixel((x,y)))]
    hx,hy=min(candidates,key=lambda p:abs(p[0]-gx)+abs(p[1]-gy)) if candidates else (gx,gy)
    sign=1 if d in [2,3] else -1
    headx=max(3,min(28,hx+sign*3));heady=max(23+dy,hy-2)
    dr.line([(headx,heady+1),(hx,hy+3)],fill=INK,width=3)
    dr.line([(headx,heady+1),(hx,hy+3)],fill='#946743',width=1)
    dr.polygon([(headx-3,heady-2),(headx+2,heady-2),(headx+3,heady-1),(headx+3,heady+1),(headx+1,heady+2),(headx-3,heady+1)],fill=INK)
    dr.rectangle((headx-2,heady-1,headx+2,heady),fill=STEEL)
    dr.line([(headx-2,heady),(headx-2,heady-1),(headx,heady-1)],fill=SILVER)
    dr.point((headx,heady),fill='#39d5e7')
    # Preserve the player's actual grip and skin tone through the handle.
    for x,y in candidates:
        if abs(x-hx)<=1 and abs(y-hy)<=1:im.putpixel((x,y),(0,0,0,0))
    return im,(headx,heady)

def save(im,p):
    p.parent.mkdir(parents=True,exist_ok=True);im.resize((im.width*2,im.height*2),NEAREST).save(p)

def partpath(g,cat,id,style):return ROOT/f'assets/player/{g}/{cat}'/(f'{style}/{id}_{style}.png' if style else f'{id}.png')

manifest=json.loads((ROOT/'assets/battles/trainers/player/manifest.json').read_text())
metadata={}; previews={}
for gender in ['male','female']:
    bodyid='Gen4_Base_F_v1' if gender=='female' else 'Gen4_Base_v1'
    walkbase=native(partpath(gender,'body',bodyid,''));metadata[gender]={}
    for style in ['','fish','ride']:
        body=native(partpath(gender,'body',bodyid,style))
        templates={k:native(partpath(gender,k,v,style)) for k,v in [('top','Shirt'),('bottom','Trousers'),('shoes','Shoes')]}
        layers={k:shade(v,[INK,DARK,MID,LIGHT] if k!='shoes' else [INK,DARK,LIGHT,STEEL]) for k,v in templates.items()}
        cape_size=48 if not style else 32;pad=(cape_size-32)//2
        capes=[blank(cape_size*4) for _ in range(3)]; overlays=[blank(cape_size*4) for _ in range(3)];heads=[]
        for d in range(4):
            for c in range(4):
                b=cell(body,d,c);off=anchor(cell(walkbase,d,0),b);dx,dy=off
                top=cell(layers['top'],d,c);art=top.copy();dr=ImageDraw.Draw(art)
                if d in [0,3]:
                    src=read(CONCEPT/gender/'Overworld'/('front' if d==0 else 'back')/'Armor.png').resize((32,32),NEAREST)
                    for y in range(21,28):
                        for x in range(11,21):
                            if src.getpixel((x,y))[3] and 0<=x+dx<32 and 0<=y+dy<32:
                                art.putpixel((x+dx,y+dy),src.getpixel((x,y)))
                else:
                    sx=14 if d==1 else 16
                    dr.rectangle((sx+dx,22+dy,sx+dx+2,24+dy),fill=STEEL)
                    dr.point((sx+dx,22+dy),fill=SILVER);dr.point((sx+dx+1,25+dy),fill='#39d5e7')
                # Exact Starter sleeves; retain the approved extended male front hem.
                mask=cell(templates['top'],d,c).getchannel('A')
                if gender=='male' and d==0:
                    ImageDraw.Draw(mask).rectangle((12+dx,26+dy,18+dx,27+dy),fill=255)
                    if c in [0,2]:
                        for x in [10,20]:mask.putpixel((x,26),255);art.putpixel((x,26),(0,0,0,255))
                art.putalpha(mask)
                if d==0:
                    # Taper the illuminated abdominal plate instead of carrying
                    # the broad chest highlight down into a rounded belly.
                    # Preserve the established sleeve/skin coverage in each pose.
                    waist={24:[DARK,STEEL,MID,'#39d5e7',MID,STEEL,DARK],
                           25:[INK,DARK,MID,MID,MID,DARK,INK],
                           26:[INK,DARK,DARK,STEEL,DARK,DARK,INK],
                           27:[INK,INK,DARK,DARK,DARK,INK,INK]}
                    for y,colors in waist.items():
                        for x,color in enumerate(colors,12):
                            if 0<=x+dx<32 and 0<=y+dy<32 and mask.getpixel((x+dx,y+dy)):
                                art.putpixel((x+dx,y+dy),Image.new('RGBA',(1,1),color).getpixel((0,0)))
                for y in range(32):
                    for x in range(32):
                        if skin(b.getpixel((x,y))) and ((y<21+dy) or (d==0 and 13+dx<=x<=17+dx and y<=22+dy) or (d==1 and x==15+dx and y<=22+dy) or (d==2 and x==16+dx and y<=22+dy)):
                            art.putpixel((x,y),(0,0,0,0))
                layers['top'].paste(art,(c*32,d*32))
                weapon,head=hammer(b,d,off,style);heads.append(list(head))
                for pose in range(3):
                    cloth=cape(d,pose,c,off,wide_idle=not style);rear=blank(cape_size);front=blank(cape_size)
                    # Viewed from behind, cloth occludes the hand-held hammer.
                    # Keep exposed hammer pixels outside the cape silhouette.
                    if d==3:
                        front.alpha_composite(weapon,(pad,pad))
                        front.alpha_composite(cloth)
                    else:
                        rear.alpha_composite(cloth)
                        front.alpha_composite(weapon,(pad,pad))
                    if d < 3:
                        reference=cell(walkbase,d,0)
                        for fy in range(6,21):
                            for fx in range(8,24):
                                if skin(reference.getpixel((fx,fy))):
                                    assert not front.getpixel((fx+dx+pad,fy+dy+pad))[3], (gender,style,d,c,'accessory covers face')
                                    assert not art.getpixel((fx+dx,fy+dy))[3], (gender,style,d,c,'armor covers face')
                    capes[pose].paste(rear,(c*cape_size,d*cape_size));overlays[pose].paste(front,(c*cape_size,d*cape_size))
        save(layers['top'],partpath(gender,'top','Thor_Shirt',style))
        for cat,id,starter in [('bottom','Thor_Trousers','Trousers'),('shoes','Thor_Shoes','Shoes')]:
            # Preserve exact source coverage, including half-grid pixels in the
            # female fishing trousers. Recolouring must not resample that mask.
            full=read(partpath(gender,cat,starter,style))
            result=shade(full,[INK,DARK,MID,LIGHT] if cat=='bottom' else [INK,DARK,LIGHT,STEEL])
            target=partpath(gender,cat,id,style);target.parent.mkdir(parents=True,exist_ok=True);result.save(target)
        for cat,poses in [('cape',capes),('cape_overlay',overlays)]:
            save(resize_cells(poses[0],32),partpath(gender,cat,'Thor_Hammer',style))
            if not style:
                for p,im in enumerate(poses):save(im,ROOT/f'assets/player/effects/thor/{gender}/{cat}_{p}.png')
        if not style:metadata[gender]['hammer_heads']=heads
        for pose in range(3 if not style else 1):
            comp=blank(cape_size*4)
            for im in [capes[pose],body,layers['bottom'],layers['shoes'],layers['top'],overlays[pose]]:comp.alpha_composite(resize_cells(im,cape_size))
            # Preview-only hair from the previously approved, registered collection.
            assets=CONCEPT.parents[1]/'overworld/skins/Outfit Designs'
            hair=assets/('Female Variants' if gender=='female' else '')/'Aether Voyager'/({'':'Walking','fish':'Fishing','ride':'Surfing'}[style])/'Hair.png'
            comp.alpha_composite(resize_cells(native(hair),cape_size))
            previews[(gender,style,pose)]=comp
    for cat,id in [('top','Thor_Shirt'),('bottom','Thor_Trousers'),('shoes','Thor_Shoes'),('cape','Thor_Hammer')]:
        p=ROOT/f'assets/player/{gender}/{cat}/parts_manifest.json';vals=json.loads(p.read_text());
        if id not in vals:vals.append(id)
        p.write_text(json.dumps(vals,indent=2)+'\n')
    # Approved trainer art: separate rear cape; hammer belongs to its overlay.
    train=ROOT/f'assets/battles/trainers/player/{gender}/thor';train.mkdir(parents=True,exist_ok=True)
    for cat,src,id in [('top','Armor','Thor_Shirt'),('bottom','Trousers','Thor_Trousers'),('shoes','Shoes','Thor_Shoes'),('cape','Cape','Thor_Hammer')]:
        shutil.copyfile(CONCEPT/gender/'Trainer'/f'{src}.png',train/f'{cat}.png')
        manifest['genders'][gender]['categories'][cat]['parts'][id]={'path':f'res://assets/battles/trainers/player/{gender}/thor/{cat}.png','scale':1.0}
    weapon=blank(80);dr=ImageDraw.Draw(weapon)
    dr.line([(55,41),(62,61)],fill=INK,width=3);dr.line([(55,41),(62,61)],fill='#946743')
    dr.polygon([(49,39),(52,36),(60,35),(65,39),(63,44),(54,45)],fill=INK)
    dr.polygon([(50,40),(53,37),(59,36),(63,39),(62,42),(54,43)],fill=STEEL)
    dr.line([(51,40),(54,38),(59,37)],fill=SILVER,width=1);dr.rectangle((57,38,58,40),fill='#39d5e7')
    save(weapon,train/'cape_overlay.png')
    manifest['genders'][gender]['categories']['cape_overlay']['parts']['Thor_Hammer']={'path':f'res://assets/battles/trainers/player/{gender}/thor/cape_overlay.png','scale':1.0}
(ROOT/'assets/battles/trainers/player/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ROOT/'assets/player/effects/thor/anchors.json').write_text(json.dumps(metadata,indent=2)+'\n')
out=CONCEPT/'Implementation';out.mkdir(exist_ok=True)
for (gender,style,pose),comp in previews.items():save(comp,out/f'{gender}_{style or "walk"}_{pose}.png')
# Overview and looping comparison use the same runtime cape sheets.
frames=[]
for tick in range(32):
    frame=Image.new('RGB',(1024,320),'#8b929b');dr=ImageDraw.Draw(frame)
    moving=8<=tick<24;pose=2 if moving else (1 if tick in [7,24,25] else 0);col=(tick//2)%4 if moving else 0
    for gi,g in enumerate(['male','female']):
        dr.text((8,gi*160+5),g+' / '+('lopen' if moving else 'stilstaan'),fill=INK)
        im=previews[(g,'',pose)]
        for d in range(4):
            f=cell(im,d,col).resize((192,192),NEAREST);frame.paste(f,(d*256+32,gi*160-8),f)
    frames.append(frame)
frames[0].save(out/'Cape-beweging.gif',save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=2)
print('Thor: both genders, all garment/movement sheets, three directional cape poses and trainer layers built.')
