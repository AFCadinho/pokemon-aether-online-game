"""Prepare individual HOME images and browser-native login media locally."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def prepare_home_icons(root: Path, output: Path) -> int:
    destination = output / 'home-icons'
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    catalog = {}
    for side, folder in [('normal', 'pokemon_home'), ('shiny', 'pokemon_home_shiny')]:
        files = sorted((root / 'assets/sprites/pokemon' / folder).glob('*.png'))
        if not files:
            raise RuntimeError(f'Missing HOME images: {folder}')
        catalog[side] = {}
        for source in files:
            # Hash filenames avoid case, accent and punctuation URL ambiguities.
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            target = destination / f'{digest}.png'
            if not target.exists():
                shutil.copy2(source, target)
            catalog[side][source.stem] = 'home-icons/' + target.name
    (destination / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=True) + '\n')
    return sum(path.stat().st_size for path in destination.iterdir())


def prepare_login_media(root: Path, output: Path, ffmpeg='ffmpeg') -> int:
    source = root / 'assets/video/login_background.ogv'
    if not source.is_file():
        raise RuntimeError('Missing login world video')
    destination = output / 'login-media'
    destination.mkdir(parents=True, exist_ok=True)
    # Keep the whole world tour, its source resolution and frame rate. H.264 is
    # decoded natively by the browser; faststart allows playing before EOF.
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    marker = destination / '.source-sha256'
    video = destination / 'world.mp4'
    poster = destination / 'poster.webp'
    if marker.is_file() and marker.read_text() == digest and video.is_file() and poster.is_file():
        return video.stat().st_size + poster.stat().st_size
    subprocess.run([ffmpeg, '-nostdin', '-v', 'error', '-y', '-i', str(source), '-an',
                    '-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
                    '-movflags', '+faststart', str(video)], check=True)
    subprocess.run([ffmpeg, '-nostdin', '-v', 'error', '-y', '-i', str(source),
                    '-frames:v', '1', '-c:v', 'libwebp', '-quality', '95', str(poster)], check=True)
    marker.write_text(digest)
    return video.stat().st_size + poster.stat().st_size
