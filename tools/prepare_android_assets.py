"""Generate the small cry availability index before native import/export."""
import argparse
import json
import shutil
from pathlib import Path


def prepare(root: Path) -> list[str]:
    files = sorted('res://' + path.relative_to(root).as_posix()
                   for path in (root / 'assets/audio/sfx/pokemon_cries').rglob('*.ogg')
)
    if not files:
        raise RuntimeError('Missing Pokémon cries; cannot create Android availability index')
    destination = root / 'generated/browser_audio_catalog.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(files) + '\n')
    return files


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset-output', type=Path, help='Optional local review payload; does not publish')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    cries = prepare(root)
    if args.asset_output:
        from build_web_on_demand import prepare_home_icons, prepare_mobile_assets
        prepare_home_icons(root, args.asset_output)
        for resource in cries:
            relative = resource.removeprefix('res://')
            target = args.asset_output / 'browser-audio' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / relative, target)
        prepare_mobile_assets(root, args.asset_output)
