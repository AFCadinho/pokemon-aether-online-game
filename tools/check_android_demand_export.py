"""Check actual Android export contents; source exclusions alone are insufficient."""
import argparse
from pathlib import Path
import re
import zipfile
from build_web_preview import pack_entry_names


FOLDERS = ('assets/sprites/pokemon/pokemon_home/',
           'assets/sprites/pokemon/pokemon_home_shiny/',
           'assets/audio/sfx/pokemon_cries/',
           'assets/audio/sfx/pokemon_anime_cries/')


def verify(root: Path, entries: list[str]) -> None:
    forbidden_imports = set()
    for folder in FOLDERS:
        for source in (root / folder).glob('*.import'):
            forbidden_imports.update(re.findall(r'res://(\.godot/imported/[^"\n]+)', source.read_text()))
    forbidden = [name for name in entries if name.startswith(FOLDERS)
                 or name in forbidden_imports or 'login_background.ogv' in name]
    if forbidden:
        raise RuntimeError(f'On-demand assets leaked into Android export: {forbidden[:10]}')
    required = ('generated/browser_audio_catalog.json', 'assets/ui/home_unknown.png.import',
                'scenes/overworld/kanto/routes/kanto_route_5.tscn.remap')
    for name in required:
        if name not in entries:
            raise RuntimeError(f'Android export is missing {name}')
    print('PASS Android export: external icons/cries/video, bundled placeholder/catalog/full world')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('export', type=Path)
    args = parser.parse_args()
    if args.export.suffix == '.apk':
        with zipfile.ZipFile(args.export) as archive:
            entries = [name.removeprefix('assets/') for name in archive.namelist()
                       if name.startswith('assets/')]
    else:
        entries = pack_entry_names(args.export)
    verify(Path(__file__).resolve().parents[1], entries)


if __name__ == '__main__':
    main()
