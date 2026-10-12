"""Assemble completed local review frames into a reviewable poster and videos."""
import argparse
import html
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont
from catalog_galar_birds_candidates import sha, read, write
from zygarde_preview import ROOT, HERE, WORK


def main(compatibility, mobile):
    reports = {}
    for label, folder in [('Compatibility',compatibility),('Mobile',mobile)]:
        report = read(folder/'godot-review.json')
        assert len(report['entries'])==2 and all(not r['errors'] for r in report['entries'])
        assert {r['species'] for r in report['entries']}=={'zygarde-10','zygarde-10-shiny'}
        assert not report['runtime_approved']
        for entry in read(folder/'catalog.json')['entries']:
            assert sha(entry['runtime_path'])==entry['runtime_sha256']
        for row in report['entries']:
            assert set(row['clips'])=={'idle','physical_attack','special_attack','damage','sleep','faint_start','faint_loop'}
            variant='shiny' if row['species'].endswith('-shiny') else 'normal'
            assert len(list((folder/(variant+'-frames')).glob('*.png')))==row['video_frames']
        video=WORK/('preview.mp4' if label=='Compatibility' else 'preview-mobile.mp4')
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','12',
            '-i',str(folder/'normal-frames/%04d.png'),'-framerate','12','-i',str(folder/'shiny-frames/%04d.png'),
            '-filter_complex','[0:v][1:v]hstack=inputs=2,scale=1200:600',
            '-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
        reports[label]={'report':str(folder/'godot-review.json'),'sha256':sha(folder/'godot-review.json'),
                        'video':str(video),'video_sha256':sha(video),
                        'video_frames':sum(r['video_frames'] for r in report['entries']),
                        'visibility_samples':sum(r['visibility_samples'] for r in report['entries']),
                        'material_samples':sum(r['material_samples'] for r in report['entries'])}
    poster=Image.new('RGB',(1600,1100),'#151821')
    draw=ImageDraw.Draw(poster)
    font=ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf',28)
    draw.text((32,20),'Zygarde 10% · lokale proefversie',font=font,fill='white')
    for i,(variant,species) in enumerate([('normal','zygarde-10'),('shiny','zygarde-10-shiny')]):
        im=Image.open(compatibility/(species+'-idle-front.png')).convert('RGB')
        im.thumbnail((760,760));poster.paste(im,(20+i*800,70))
        draw.text((40+i*800,840),variant.capitalize(),font=font,fill='white')
        im=Image.open(compatibility/(variant+'-core-0.png')).convert('RGB').crop((230,235,550,610))
        im.thumbnail((190,190));poster.paste(im,(560+i*800,840))
        draw.text((40+i*800,895),'Model + kern in Godot',font=font,fill='#bdc6dd')
    draw.text((32,1040),'Visuele reconstructie — nog niet toegelaten tot de game of R2',font=font,fill='#e7c17b')
    poster.save(WORK/'preview.png')
    pictures=[]
    for folder in [compatibility,mobile]:
        for variant in ['normal','shiny']:
            for angle in [-35,0,35]:
                path=folder/(variant+'-core-'+str(angle)+'.png')
                pictures.append('<figure><img loading="lazy" src="'+html.escape(str(path.relative_to(WORK)))+'"><figcaption>'+html.escape(folder.name+' / '+variant+' / '+str(angle)+'°')+'</figcaption></figure>')
    document='''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Zygarde 10% — lokale proef</title><style>
body{margin:32px auto;padding:0 20px;max-width:1200px;background:#151821;color:#edf0fa;font:17px/1.5 system-ui}
h1{font-size:32px}video{width:100%;background:#202020;border-radius:12px}a{color:#c8aaff}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px}figure{margin:0}img{width:100%;border-radius:10px}figcaption{color:#adb8d0}p{max-width:900px}</style>
<h1>Zygarde 10%: normal en shiny</h1><p>Lokale visuele reconstructie van de kern en transparante laag. De video's tonen een rondgang en alle zeven animaties. Links normal, rechts shiny.</p>
<p><strong>Nog niet goedgekeurd voor de game of R2.</strong> De werking van het kerneffect is gereconstrueerd; identieke weergave aan de oorspronkelijke game is niet bewezen. Beide renderers zijn op Linux getest; dit is geen Android-test.</p>
<h2>Compatibility</h2><video controls loop playsinline poster="preview.png" src="preview.mp4"></video>
<h2>Mobile-renderer op Linux</h2><video controls loop playsinline preload="none" src="preview-mobile.mp4"></video>
<h2>Close-ups</h2><div class="grid">'''+''.join(pictures)+'</div></html>'
    (WORK/'preview.html').write_text(document)
    code=list(HERE.glob('zygarde_preview*.py'))+list(HERE.glob('zygarde_preview*.gd'))+list(HERE.glob('zygarde_preview*.gdshader'))
    stage=read(WORK/'stage.json')
    result={'schema':1,'species':'zygarde-10','status':'local_visual_preview','runtime_approved':False,
            'release_approved':False,'published':False,'platform':'Linux','renderers':reports,
            'source_glb_sha256':stage['source_glb_sha256'],'stage_sha256':sha(WORK/'stage.json'),
            'geometry_motion_signatures':[r['geometry_motion_signature'] for r in stage['entries']],
            'interpretations':stage['interpretations'],
            'code_sha256':{str(p.relative_to(ROOT)):sha(p) for p in code},
            'poster':str(WORK/'preview.png'),'poster_sha256':sha(WORK/'preview.png'),
            'gallery':str(WORK/'preview.html'),'gallery_sha256':sha(WORK/'preview.html')}
    write(HERE/'zygarde_preview_result.json',result)
    print('ZYGARDE_LOCAL_GALLERY',WORK/'preview.html')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--compatibility',type=Path,default=WORK/'review-v4')
    p.add_argument('--mobile',type=Path,default=WORK/'review-mobile-v4')
    args=p.parse_args();main(args.compatibility,args.mobile)
