from pathlib import Path
import json
import sys
from PIL import Image,ImageDraw,ImageChops

root=Path(sys.argv[1]).resolve()

def detail(path, size=(200,200)):
    with Image.open(path) as original:
        im=original.convert('RGB')
        bg=Image.new('RGB',im.size,im.getpixel((0,0)))
        bounds=ImageChops.difference(im,bg).point(lambda x:255 if x>10 else 0).getbbox()
        if bounds:im=im.crop(bounds)
        im.thumbnail(size)
        canvas=Image.new('RGB',size,'#15202b')
        canvas.paste(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
        return canvas
ledger=json.loads((Path(__file__).parent/'catalog_100_visual_triage_results.json').read_text())
names=[r['species'] for r in ledger['entries'] if r['technical_status']=='converted']
for index,name in enumerate(names):
    p=root/name/'report.json'
    if not p.exists():continue
    row=json.loads(p.read_text())
    target=root/name/'motion-sheet.png'
    if not target.exists():
        sheet=Image.new('RGB',(1400,1050),'#15202b');draw=ImageDraw.Draw(sheet)
        draw.text((8,4),f'{index+1}/88 {name} — first cycle: 0%, 33%, 67%, 100%; bottom: back idle/special/sleep/faint/loop',fill='white')
        for col,clip in enumerate(row['clips']):
            draw.text((col*200+4,20),clip['action'],fill='white')
            for line,frac in enumerate([0,1/3,2/3,1]):
                tick=round(((clip['frames']-1)/clip['cycles'])*frac)
                sheet.paste(detail(root/name/f"{clip['action']}-{tick:04d}.png"),(col*200,38+line*200))
        for col,pose in enumerate(['idle','special_attack','sleep','faint_start','faint_loop']):
            sheet.paste(detail(root/name/f'{pose}-back.png'),(col*200,845))
        sheet.save(target)
print('Sheets ready:',sum((root/n/'motion-sheet.png').exists() for n in names))
