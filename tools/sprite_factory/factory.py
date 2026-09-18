"""Local quality-first sprite factory. Python 3 + Pillow, Blender is external.

Run --help. Outputs are content-addressed; masters are never resized or replaced.
"""
import argparse
import hashlib
import json
import math
import re
import shlex
import subprocess
import sys
import struct
import zlib
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat, __version__ as PIL_VERSION

HERE = Path(__file__).resolve().parent
VERSION = 1
CATEGORIES = {'idle', 'physical_attack', 'special_attack', 'damage', 'sleep', 'faint_start', 'faint_loop'}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')


def canonical_png(data):
    """Keep compressed pixels and colour-profile chunks; discard volatile stamps.

    Blender emits Date/RenderTime even without a visible stamp. No image decoding,
    resampling, quantization or recompression is performed here.
    """
    require(data[:8] == b'\x89PNG\r\n\x1a\n', 'Invalid PNG signature')
    output = bytearray(data[:8])
    offset, finished = 8, False
    while offset < len(data):
        require(offset + 12 <= len(data), 'Truncated PNG chunk')
        size = struct.unpack('>I', data[offset:offset+4])[0]
        end = offset + 12 + size
        require(end <= len(data), 'Truncated PNG payload')
        tag = data[offset+4:offset+8]
        require(zlib.crc32(data[offset+4:end-4]) == struct.unpack('>I', data[end-4:end])[0], 'PNG CRC mismatch')
        if tag not in (b'tEXt', b'zTXt', b'iTXt', b'tIME', b'eXIf'):
            output.extend(data[offset:end])
        offset = end
        if tag == b'IEND':
            finished = True
            break
    require(finished and offset == len(data), 'Invalid PNG ending')
    return bytes(output)


def canonical_masters(source, destination):
    for path in sorted(source.glob('*/*/*.png')):
        target = destination / path.relative_to(source)
        require(not target.exists(), 'Canonical master already exists')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(canonical_png(path.read_bytes()))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def safe_id(value):
    return isinstance(value, str) and re.fullmatch(r'[a-z0-9][a-z0-9_-]*', value) is not None


def validate(cfg, variant):
    require(cfg['schema'] == VERSION, 'Unknown manifest schema')
    require(safe_id(cfg['species']) and safe_id(variant), 'Invalid species/form or variant ID')
    require(cfg['review']['status'] in ('configured', 'approved'), 'Manifest mapping must be explicitly configured')
    require(cfg['variants'].get(variant, {}).get('available') is True, 'Variant source unavailable; use existing fallback')
    require(cfg['render']['resolution'] == [512, 512] and cfg['render']['fps'] in (24, 60),
            'Supported quality baselines are 512px / 24 or native 60 FPS')
    require(set(cfg['cameras']) == {'front', 'back'}, 'Both explicit cameras required')
    require(cfg['actions'].get('idle') is not None, 'Idle mapping required')
    require(set(cfg['actions']) <= CATEGORIES, 'Unknown action category')
    require(isinstance(cfg.get('qc'), dict) and cfg['qc'].get('safe_margin', -1) >= 0
            and cfg['qc'].get('bounds_jump', 0) > 0, 'Missing or invalid quality-check settings')
    for view, camera in cfg['cameras'].items():
        require(camera['ortho_scale'] > 0, 'Invalid camera scale')
        present = cfg['presentation'][view]
        require(present['render_scale'] >= 1 and len(present['anchor']) == 2, 'Invalid presentation scale/anchor')
        require(0 < present['min_visible_height'] <= present['max_visible_height'], 'Invalid readability limits')
    for name, action in cfg['actions'].items():
        if action is None:
            continue
        frames = action['frames']
        require(0 < len(frames) <= 4096, 'Strange frame range: ' + name)
        require(all(isinstance(f, (int, float)) and math.isfinite(f) for f in frames), 'Invalid frames')
        require(all(b > a for a, b in zip(frames, frames[1:])), 'Frames must be increasing')
        require(action['source_fps'] > 0 and action['speed'] > 0, 'Invalid timing')
        if len(frames) > 1:
            require(all(abs((b - a) - action['source_fps'] / cfg['render']['fps']) < 1e-5 for a, b in zip(frames, frames[1:])),
                    'Sample source timeline at the configured render FPS')
        if name.startswith('faint'):
            require(not any(x in action['action'].lower() for x in ('down01_end', 'recovery', 'sleepend')),
                    'Recovery action cannot be selected as faint')
        require(action['review'] in ('needs_review', 'approved', 'rejected'), 'Invalid action review state')
        neutral_bones = action.get('neutral_bones', [])
        require(isinstance(neutral_bones, list) and all(isinstance(x, str) and x for x in neutral_bones)
                and len(set(neutral_bones)) == len(neutral_bones), 'Invalid neutral_bones')


def worker(blender, source, job, path):
    write(path, job)
    command = shlex.split(blender) + ['--background', '--factory-startup', '--disable-autoexec',
        str(source), '--python-exit-code', '1', '--python', str(HERE / 'blender_worker.py'), '--', str(path)]
    with path.with_suffix('.log').open('w') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    return read(job['result'])


def inspect_source(args):
    source = Path(args.source).resolve()
    output = Path(args.output).resolve()
    source_hash = digest(source.read_bytes())
    report = worker(args.blender, source, dict(mode='inspect', result=str(output)), output.with_suffix('.job.json'))
    report.update(source=str(source), source_sha256=source_hash, status='inspected', species_form='unverified', pipeline=VERSION)
    require(digest(source.read_bytes()) == source_hash, 'Source changed during inspection')
    write(output, report)
    return report


def check_source(cfg, report):
    require(report['source_sha256'] == cfg['source']['sha256'], 'Source hash mismatch')
    require(report['blender'] == cfg['source']['blender'], 'Blender version differs from pinned version')
    require(cfg['rig'] in report['armatures'], 'Configured armature missing')
    blocking = [x for x in report['warnings'] if x.startswith(('missing_', 'linked_'))]
    require(not blocking, 'Missing or external linked dependencies: ' + str(blocking))
    unreviewed = set(report['warnings']) - set(cfg['source'].get('accepted_warnings', []))
    require(not unreviewed, 'Source requires explicit inspection review: ' + str(sorted(unreviewed)))
    actions = {x['name']: x for x in report['actions']}
    for category, action in cfg['actions'].items():
        if action is None:
            continue
        require(action['action'] in actions, 'Missing action: ' + action['action'])
        info = actions[action['action']]
        require(min(action['frames']) >= info['range'][0] and max(action['frames']) <= info['range'][1], 'Action frame range outside source')
        require(len(info['slots']) == 1 or action.get('slot') in info['slots'], 'Ambiguous action slot')
        if action.get('neutral_bones'):
            bones = report.get('armature_bones', {}).get(cfg['rig'], [])
            require(set(action['neutral_bones']) <= set(bones), 'Unknown neutral_bones')
    # External texture dependencies must be pinned too; packed inputs are covered by the .blend hash.
    for image in report['images']:
        if not image['embedded'] and image['source'] == 'FILE':
            expected = cfg['source'].get('external_textures', {}).get(image['name'])
            require(expected == digest(Path(image['path']).read_bytes()), 'Unpinned external texture: ' + image['name'])


def build(args):
    cfg = read(args.manifest)
    validate(cfg, args.variant)
    source = Path(args.source).resolve()
    output = Path(args.output).resolve()
    require(not str(output).startswith(str(HERE.parents[1] / 'assets')), 'Use a separate local output directory')
    report_path = output / 'inspection' / (cfg['source']['sha256'] + '.json')
    inspect_args = argparse.Namespace(source=str(source), output=str(report_path), blender=args.blender)
    report = inspect_source(inspect_args)
    check_source(cfg, report)
    code_hash = digest((HERE / 'factory.py').read_bytes() + (HERE / 'blender_worker.py').read_bytes())
    identity = dict(manifest=cfg, variant=args.variant, blender=report['blender'], blender_build=report['blender_build'], pipeline=VERSION,
                    code_sha256=code_hash, pillow=PIL_VERSION)
    build_id = digest(canonical(identity))
    target = output / cfg['species'] / args.variant / build_id
    require(not target.exists(), 'Build directory already exists: use verify; choose another output root for independent rebuild')
    target.mkdir(parents=True)
    for name in ('factory.py', 'blender_worker.py'):
        (target / name).write_bytes((HERE / name).read_bytes())
    write(target / 'provenance.json', dict(identity=identity, build_id=build_id, source_sha256=report['source_sha256'], manifest_sha256=digest(canonical(cfg))))
    write(target / 'inspection.json', report)
    write(target / 'state.json', dict(status='configured'))
    result = worker(args.blender, source, dict(mode='render', manifest=cfg, variant=args.variant,
                    output=str(target), result=str(target / 'render.json')), target / 'render.job.json')
    require(digest(source.read_bytes()) == cfg['source']['sha256'], 'Read-only source was changed')
    (target / 'masters').rename(target / 'raw-renders')
    canonical_masters(target / 'raw-renders', target / 'masters')
    write(target / 'state.json', dict(status='rendered'))
    qc = quality(target, cfg, result)
    write(target / 'qc.json', qc)
    package(target, cfg, args.variant)
    write(target / 'state.json', dict(status='needs_review', build_id=build_id))
    print(target, flush=True)
    print('Technical errors:', len(qc['errors']), 'warnings:', len(qc['warnings']), flush=True)
    return target


def finalize(args):
    """Re-run postprocessing from verified renders without another 3D render.

    Only an identical archived Blender worker is accepted. The new pipeline
    identity and fresh review gate apply; the existing masters remain read-only.
    """
    previous = Path(args.build).resolve()
    verify(previous)
    old = read(previous / 'provenance.json')
    require((previous/'blender_worker.py').read_bytes() == (HERE/'blender_worker.py').read_bytes(), 'Renderer changed: fresh .blend build required')
    identity = old['identity']
    cfg, variant = identity['manifest'], identity['variant']
    validate(cfg, variant)
    identity['code_sha256'] = digest((HERE/'factory.py').read_bytes() + (HERE/'blender_worker.py').read_bytes())
    identity['pillow'] = PIL_VERSION
    build_id = digest(canonical(identity))
    output = Path(args.output).resolve()
    require(not str(output).startswith(str(HERE.parents[1] / 'assets')), 'Use a separate local output directory')
    target = output / cfg['species'] / variant / build_id
    require(not target.exists(), 'Build directory already exists')
    target.mkdir(parents=True)
    for name in ('factory.py', 'blender_worker.py'):
        (target/name).write_bytes((HERE/name).read_bytes())
    write(target/'provenance.json', dict(identity=identity, build_id=build_id,
          source_sha256=old['source_sha256'], manifest_sha256=old['manifest_sha256'],
          rendered_from=str(previous), rendered_build_id=old['build_id']))
    write(target/'inspection.json', read(previous/'inspection.json'))
    write(target/'render.json', read(previous/'render.json'))
    write(target/'raw-source.json', dict(root=str(previous/'masters'), files=read(previous/'qc.json')['files']))
    canonical_masters(previous/'masters', target/'masters')
    write(target/'state.json', dict(status='rendered'))
    qc = quality(target, cfg, read(target/'render.json'))
    write(target/'qc.json', qc)
    package(target, cfg, variant)
    write(target/'state.json', dict(status='needs_review', build_id=build_id))
    print(target, flush=True)
    return target


def quality(root, cfg, render):
    result = dict(errors=[], warnings=[], actions={}, files={})
    result['warnings'].extend(render.get('facial_warnings', []))
    fps = cfg['render']['fps']
    previews = root / 'previews'
    previews.mkdir()
    overview = Image.new('RGB', (1024, 560), '#252735')
    for vi, view in enumerate(('front', 'back')):
        names = [a for a in cfg['actions'] if cfg['actions'][a] is not None]
        contact = Image.new('RGB', (1024, len(names) * 280), '#252735')
        draw = ImageDraw.Draw(contact)
        for row, action in enumerate(names):
            spec = cfg['actions'][action]
            paths = sorted((root / 'masters' / view / action).glob('*.png'))
            key = view + '/' + action
            hashes, boxes, frames, margins, luminance = [], [], [], [], []
            require(len(paths) == len(spec['frames']), 'Incomplete master action: ' + key)
            for path in paths:
                with Image.open(path) as im:
                    require(im.size == (512, 512) and im.mode == 'RGBA', 'Invalid master format')
                    frame = im.copy()
                result['files'][str(path.relative_to(root))] = digest(path.read_bytes())
                frames.append(frame)
                hashes.append(digest(frame.tobytes()))
                # Alpha-weighted luminance is diagnostic, never an artistic approval.
                # Transparent background pixels must not bias a small species dark.
                rgb = frame.convert('RGB')
                weight = frame.getchannel('A')
                means = ImageStat.Stat(rgb, weight).mean
                luminance.append(round((0.2126 * means[0] + 0.7152 * means[1] + 0.0722 * means[2]) / 255, 4))
                box = frame.getchannel('A').getbbox()
                boxes.append(box)
                if box is None:
                    result['errors'].append(key + ':empty:' + path.name)
                    margins.append(0)
                    continue
                margin = min(box[0], box[1], 512 - box[2], 512 - box[3])
                margins.append(margin)
                if margin == 0:
                    result['errors'].append(key + ':clipping:' + path.name)
                elif margin < cfg['qc']['safe_margin']:
                    result['warnings'].append(key + ':safe_margin:' + path.name)
            geometry = render['geometry'][view][action]
            if any(x['outside'] for x in geometry):
                result['errors'].append(key + ':geometry_outside_camera')
            visible = [b for b in boxes if b]
            union = [min(b[0] for b in visible), min(b[1] for b in visible), max(b[2] for b in visible), max(b[3] for b in visible)] if visible else None
            for a, b in zip(boxes, boxes[1:]):
                if a and b and max(abs(x-y) for x, y in zip(a, b)) > cfg['qc']['bounds_jump']:
                    result['warnings'].append(key + ':abrupt_bounds_change')
                    break
            if spec['loop'] and len(hashes) > 1 and hashes[0] == hashes[-1]:
                result['warnings'].append(key + ':duplicate_loop_end')
            if len(set(hashes)) == 1 and len(hashes) > 1:
                result['warnings'].append(key + ':static_action')
            if luminance and max(luminance) < 0.06:
                result['warnings'].append(key + ':extremely_dark_render')
            if luminance and min(luminance) > 0.94:
                result['warnings'].append(key + ':extremely_bright_render')
            if union and (union[2]-union[0] < 8 or union[3]-union[1] < 8):
                result['errors'].append(key + ':extreme_small_bounds')
            if union and action == 'idle':
                # sprite_box uses 2x baseline display scale; evaluate separate configured presentation.
                height = (union[3]-union[1]) * 1.7 / cfg['presentation'][view]['render_scale']
                present = cfg['presentation'][view]
                if not present['min_visible_height'] <= height <= present['max_visible_height']:
                    result['warnings'].append(key + ':presentation_height:' + str(round(height, 2)))
                overview.paste(frames[0], (vi * 512, 32), frames[0])
            result['actions'][key] = dict(count=len(paths), unique_frames=len(set(hashes)), pixel_hashes=hashes,
                bounds=boxes, union=union, min_margin=min(margins), duration=len(paths)/fps,
                playback_duration=len(paths)/fps/spec['speed'], loop=spec['loop'],
                alpha_weighted_luminance=dict(min=min(luminance), max=max(luminance),
                                              mean=round(sum(luminance) / len(luminance), 4)))
            for col, index in enumerate([0, len(frames)//3, 2*len(frames)//3, len(frames)-1]):
                thumb = frames[index].resize((256, 256), Image.Resampling.LANCZOS)
                contact.paste(thumb, (col*256, row*280+24), thumb)
            draw.text((8, row*280+4), key + '  ' + str(len(paths)) + ' frames', fill='white')
            # Rounded cumulative timestamps preserve either source cadence without drift.
            durations = [round((i+1)*1000/fps)-round(i*1000/fps) for i in range(len(frames))]
            frames[0].save(previews / (view + '-' + action + '.webp'), save_all=True,
                append_images=frames[1:], duration=durations, loop=0 if spec['loop'] else 1, lossless=True, method=4)
        contact.save(previews / (view + '-contact.png'))
    ImageDraw.Draw(overview).text((12, 8), cfg['species'] + ' / normal or configured variant / front + back', fill='white')
    overview.save(previews / 'overview.png')
    (previews / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Sprite review</title><style>body{background:#252735;color:white;font:16px sans-serif}img{max-width:100%}</style>'
        + '<h1>' + cfg['species'] + '</h1><p>Source-timing previews: ' + str(fps) + ' FPS. Review eyes, loop seams, actions, faint hold and in-game placement.</p>'
        + ''.join('<h2>' + p.stem + '</h2><img src="' + p.name + '">' for p in sorted(previews.glob('*.png')))
        + ''.join('<h2>' + p.stem + '</h2><img src="' + p.name + '">' for p in sorted(previews.glob('*.webp')))
        + '<h2>Technical warnings</h2><pre>' + json.dumps(dict(errors=result['errors'], warnings=result['warnings']), indent=2) + '</pre>')
    return result


def package(root, cfg, variant):
    provenance = read(root / 'provenance.json')
    runtime = root / 'runtime'
    meta = dict(schema=VERSION, species=cfg['species'], variant=variant, build_id=provenance['build_id'],
                cell_size=512, fps=cfg['render']['fps'], status='needs_review', presentation=cfg['presentation'], views={}, faint_policy='hold_until_recall')
    for view in ('front', 'back'):
        meta['views'][view] = {}
        for action, spec in cfg['actions'].items():
            if spec is None:
                continue
            paths = sorted((root / 'masters' / view / action).glob('*.png'))
            pages = []
            for start in range(0, len(paths), 64):
                batch = paths[start:start+64]
                columns = min(8, len(batch))
                sheet = Image.new('RGBA', (columns*512, math.ceil(len(batch)/columns)*512))
                for i, path in enumerate(batch):
                    with Image.open(path) as frame:
                        # Exact RGBA copy, including RGB beneath transparent pixels.
                        sheet.paste(frame, ((i % columns)*512, (i//columns)*512))
                name = f'{view}/{action}-{start//64:02}.png'
                destination = runtime / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                sheet.save(destination, compress_level=6)
                pages.append(dict(file=name, count=len(batch), columns=columns, sha256=digest(destination.read_bytes())))
            meta['views'][view][action] = dict(pages=pages, count=len(paths), loop=spec['loop'], speed=spec['speed'],
                status='needs_review' if spec['review'] != 'rejected' else 'rejected', source_action=spec['action'])
    write(runtime / 'manifest.json', meta)


def verify(root):
    root = Path(root)
    qc, meta = read(root / 'qc.json'), read(root / 'runtime/manifest.json')
    provenance = read(root / 'provenance.json')
    if 'identity' in provenance:
        require(digest(canonical(provenance['identity'])) == provenance['build_id'], 'Build identity changed')
        require(digest((root/'factory.py').read_bytes() + (root/'blender_worker.py').read_bytes()) == provenance['identity']['code_sha256'], 'Archived pipeline changed')
        require(meta['build_id'] == provenance['build_id'], 'Runtime build identity differs')
    for path, expected in qc['files'].items():
        require(digest((root / path).read_bytes()) == expected, 'Master altered: ' + path)
    for view, actions in meta['views'].items():
        for action, spec in actions.items():
            index = 0
            for page in spec['pages']:
                path = root / 'runtime' / page['file']
                require(digest(path.read_bytes()) == page['sha256'], 'Atlas altered')
                with Image.open(path) as atlas:
                    for i in range(page['count']):
                        x, y = (i % page['columns'])*512, (i//page['columns'])*512
                        with Image.open(root / 'masters' / view / action / f'{index:04}.png') as master:
                            require(atlas.crop((x,y,x+512,y+512)).tobytes() == master.tobytes(), 'Atlas pixel mismatch')
                        index += 1
            require(index == spec['count'], 'Atlas frame count mismatch')
    return digest(canonical(meta))


def review(args):
    root = Path(args.build).resolve()
    verify(root)
    qc = read(root / 'qc.json')
    require(args.reviewer.strip() and args.note.strip(), 'Human reviewer and rationale required')
    if args.status == 'approved':
        require(not qc['errors'], 'Technical errors block approval')
        require(not qc['warnings'] or args.accept_warnings, 'Explicit warning acknowledgement required')
    meta = read(root / 'runtime/manifest.json')
    selection = set(args.actions.split(',')) if args.actions else None
    if selection:
        require(selection <= {view + '/' + name for view, actions in meta['views'].items() for name in actions}, 'Unknown view/action review selection')
    for view, actions in meta['views'].items():
        for name, action in actions.items():
            if selection is None or view + '/' + name in selection:
                action['status'] = args.status
    states = {action['status'] for actions in meta['views'].values() for action in actions.values()}
    meta['status'] = ('approved' if 'approved' in states else 'needs_review' if 'needs_review' in states else 'rejected') if selection else args.status
    write(root / 'runtime/manifest.json', meta)
    write(root / 'approval.json', dict(status=meta['status'], reviewer=args.reviewer, note=args.note,
          build_id=meta['build_id'], runtime_sha256=digest(canonical(meta)), accepted_warnings=qc['warnings']))
    write(root / 'state.json', dict(status=meta['status'], build_id=meta['build_id']))


def catalog(args):
    entries = {}
    for name in args.build:
        root = Path(name).resolve()
        actual = verify(root)
        meta = read(root / 'runtime/manifest.json')
        if not args.preview:
            approval = read(root / 'approval.json')
            require(approval['status'] == 'approved' and meta['status'] == 'approved'
                    and approval['runtime_sha256'] == actual and approval['build_id'] == meta['build_id'], 'Unapproved or changed build')
        else:
            require(meta['status'] in ('needs_review', 'approved'), 'Rejected build cannot be previewed')
        key = meta['species'] + ':' + meta['variant']
        require(key not in entries, 'Duplicate species/variant')
        entries[key] = dict(path=str(root / 'runtime/manifest.json'), sha256=digest((root / 'runtime/manifest.json').read_bytes()))
    write(args.output, dict(schema=VERSION, mode='preview' if args.preview else 'approved', entries=entries))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('inspect')
    p.add_argument('--source', required=True); p.add_argument('--output', required=True)
    p.add_argument('--blender', default='flatpak run org.blender.Blender')
    p = sub.add_parser('build')
    for name in ('manifest', 'source', 'output'):
        p.add_argument('--'+name, required=True)
    p.add_argument('--variant', default='normal')
    p.add_argument('--blender', default='flatpak run org.blender.Blender')
    p = sub.add_parser('verify'); p.add_argument('build')
    p = sub.add_parser('finalize'); p.add_argument('build'); p.add_argument('--output', required=True)
    p = sub.add_parser('review'); p.add_argument('build')
    p.add_argument('--status', choices=['approved', 'rejected'], required=True)
    p.add_argument('--reviewer', required=True); p.add_argument('--note', required=True)
    p.add_argument('--accept-warnings', action='store_true')
    p.add_argument('--actions', help='Optional comma-separated view/action selections; other actions retain their review status')
    p = sub.add_parser('catalog'); p.add_argument('build', nargs='+')
    p.add_argument('--output', required=True); p.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    try:
        {'inspect': inspect_source, 'build': build, 'finalize': finalize, 'review': review, 'catalog': catalog,
         'verify': lambda a: print(verify(a.build))}[args.command](args)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, str(exc) + '\n')


if __name__ == '__main__':
    main()
