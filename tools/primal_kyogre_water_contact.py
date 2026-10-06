"""Approved Kyogre water-contact palette/depth and pixel foam, at native scale."""
import math
from PIL import Image, ImageDraw

FRAME = (192, 224)

def clamp(x):return max(0,min(1,x))
def underwater(x,y,row,phase):
    # Per-anatomy submersion: top-down fins lie in water even when the source
    # pose swings them up-screen. Body/rider positions never change.
    if row==0:
        fin=clamp((abs(x-96)-25)/24)*.74 if y>=65 else 0
        belly=clamp((y-120)/16)*.95 if 70<=x<=121 else 0
        tail=.62 if 60<=x<=137 and y<72 else 0
        return max(fin,belly,tail)
    if row==3:
        fin=clamp((abs(x-96)-23)/24)*.74
        tail=clamp((y-102)/25)*.88
        return max(fin,tail)
    u=x if row==1 else 192-x
    fin=clamp((y-110)/34)*.96 if 45<=u<=119 else 0
    # Far flipper: behind the body, lightly submerged in both source poses.
    far=.61*clamp(((84 if phase<2 else 76)-y)/12) if 52<=u<=111 else 0
    tail=.67*clamp((u-116)/18)
    belly=clamp((y-103)/15)*.72 if u<126 else 0
    return max(fin,far,tail,belly)

def immerse(im,row,phase):
    out=im.copy();px=out.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=px[x,y]
            if not a:continue
            depth=underwater(x,y,row,phase)
            mix=.45*depth
            px[x,y]=(round(r*(1-mix)+34*mix),round(g*(1-mix)+104*mix),round(b*(1-mix)+127*mix),round(a*(1-.72*depth)))
    return out

def foam(row,t,moving):
    # Broken contact strokes follow the hull; no detached oval beneath it.
    out=Image.new('RGBA',FRAME);d=ImageDraw.Draw(out)
    bright=(188,228,227,220);mid=(108,184,199,195);dim=(74,141,164,135)
    shift=round(math.sin(t*math.tau)*1)
    if row==0:
        lines=[[(75,125),(80,130),(88,134),(97,136),(106,134),(115,129)]]
    elif row==3:
        lines=[[(71,88),(75,91),(79,92)],[(115,92),(120,90),(123,87)]]
    else:
        lines=[[(29,100),(32,105),(38,109),(46,113),(54,114)],[(66,113),(72,112),(79,113)],[(97,114),(106,115),(114,112),(123,108)]]
        if row==2:lines=[[(192-x,y) for x,y in line] for line in lines]
    for li,line in enumerate(lines):
        pts=[(x,y+(shift if li else 0)) for x,y in line]
        d.line(pts,fill=mid,width=2 if li==0 else 1)
        for k,(x,y) in enumerate(pts):
            if (k+int(t*8))%3!=0:d.line((x,y,x+2,y),fill=bright,width=1)
    if moving:
        phase=t%1
        for j in range(3):
            age=(phase+j/3)%1;length=5+round(age*8);spread=round(age*8);alpha=round((1-age)*145)
            color=(111,190,203,alpha)
            if row==0:
                y=31-round(age*20)
                d.line((84-spread,y,84-spread+length,y+1),fill=color)
                d.line((108+spread-length,y,108+spread,y+1),fill=color)
            elif row==3:
                y=145+round(age*25)
                d.line((87-spread,y,87-spread+length,y+1),fill=color)
                d.line((105+spread-length,y,105+spread,y+1),fill=color)
            else:
                x=171+round(age*15);y=102
                if row==2:x=192-x
                bend=3 if row==1 else -3
                d.line([(x-bend,y-9-spread),(x,y-6-spread),(x,y-3-spread)],fill=color)
                d.line([(x-bend,y+9+spread),(x,y+6+spread),(x,y+3+spread)],fill=color)
    return out

