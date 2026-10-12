"""Build traceable contact sheets; viewing them is an explicit review step."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw
from alternate_forms_batch import WORK, read, write, sha


def appearance(output, only=None):
    output.mkdir(parents=True,exist_ok=False)
    entries=[]
    for p in sorted((WORK/'appearance').glob('*/godot-review.json')):
        if only and p.parent.name not in only:continue
        if any(r['errors'] for r in read(p)['entries']):continue
        for row in read(p)['entries']:
            entries.append((p,row))
    pages=[]
    selections=[['idle','physical_attack','physical_attack_2','special_attack','sleep','faint_loop'],
                ['idle:back','idle:side','faint_start']]
    for subset,actions in enumerate(selections):
        for offset in range(0,len(entries),8):
            page=Image.new('RGB',(len(actions)*180,1600),'#202430');draw=ImageDraw.Draw(page)
            recorded=[]
            for i,(report,row) in enumerate(entries[offset:offset+8]):
                draw.text((5,i*200+3),row['species'],fill='white');images=[]
                for j,wanted in enumerate(actions):
                    action,_,view=wanted.partition(':');view=view or 'front'
                    matches=[p for p in row['poses'] if p['action']==action and p['view']==view and p.get('status')!='missing']
                    if not matches:continue
                    pose=matches[0];path=report.parent/pose['image']
                    im=Image.open(path).convert('RGB');im.thumbnail((176,174))
                    page.paste(im,(j*180+2,i*200+20));draw.text((j*180+2,i*200+183),wanted,fill='white')
                    images.append({'path':str(path),'sha256':sha(path)})
                recorded.append({'species':row['species'],'report':str(report),'report_sha256':sha(report),'images':images})
            path=output/f'appearance-{subset}-{offset//8+1:02}.jpg';page.save(path,quality=94)
            pages.append({'path':str(path),'sha256':sha(path),'entries':recorded})
    write(output/'index.json',{'reviewed':False,'pages':pages})
    print('CONTACTS',len(entries),'appearances',len(pages),'pages')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path)
    p.add_argument('--only')
    args=p.parse_args()
    appearance(args.output.resolve(),set(args.only.split(',')) if args.only else None)
