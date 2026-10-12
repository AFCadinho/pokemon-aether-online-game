"""Frame source screenshots for manual floor/camera review; retain full originals."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw
from alternate_forms_batch import WORK, read, write, sha


def build(output, only=None):
    output.mkdir(parents=True,exist_ok=False)
    rows=[]
    for p in sorted((WORK/'status/battle').glob('*.json')):
        state=read(p);name=state['species']
        if state['status']!='measured' or only and name not in only:continue
        report=WORK/'battle'/name/'final/battle-review.json'
        if not report.exists():continue
        data=read(report)
        if sha(report)!=state['battle_report_sha256']:continue # Producer has not committed this revision yet.
        entries={r['species']:r for r in data['entries'] if 'clips' in r}
        images=[]
        for suffix,camera,side,action in [('', 'classic',0,'idle'),('-shiny','stadium',0,'idle'),
                ('','stadium',1,'faint_loop'),('-shiny','classic',1,'faint_loop')]:
            entry=entries[name+suffix]
            shots=[s for s in entry['shots'] if s['arena_camera']==camera and s['side']==side and s['action']==action]
            if not shots:
                shots=[s for s in entry['shots'] if s['arena_camera']==camera and s['side']==side and s['action']=='faint_start']
            shot,=shots
            path=report.parent/shot['image']
            images.append({'path':str(path),'sha256':sha(path),'shot':shot,'label':camera+' '+str(side)+' '+action+suffix})
        rows.append({'species':name,'report_sha256':sha(report),'images':images})
    pages=[]
    for offset in range(0,len(rows),5):
        canvas=Image.new('RGB',(1152,1000),'#202430');draw=ImageDraw.Draw(canvas)
        subset=rows[offset:offset+5]
        for i,row in enumerate(subset):
            draw.text((4,i*200+2),row['species'],fill='white')
            for j,item in enumerate(row['images']):
                source=Image.open(item['path']).convert('RGB')
                x,y,w,h=item['shot']['screen_rect']
                # Camera-dependent crop retains nearby arena floor and the model.
                size=max(w+140,h+90,260);cx=x+w/2;cy=y+h/2
                crop=[max(0,int(cx-size*.8)),max(0,int(cy-size*.5)),min(source.width,int(cx+size*.8)),min(source.height,int(cy+size*.5))]
                image=source.crop(crop);image.thumbnail((284,170))
                canvas.paste(image,(j*288+2,i*200+18));draw.text((j*288+2,i*200+184),item['label'],fill='white')
                item['contact_crop']=crop
        path=output/f'battle-{offset//5+1:02}.jpg';canvas.save(path,quality=94)
        pages.append({'path':str(path),'sha256':sha(path),'entries':subset})
    write(output/'index.json',{'reviewed':False,'pages':pages})
    print('BATTLE_CONTACTS',len(rows),'pairs',len(pages),'pages')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('--only')
    a=p.parse_args();build(a.output.resolve(),set(a.only.split(',')) if a.only else None)
