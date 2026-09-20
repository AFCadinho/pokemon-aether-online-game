"""Create explicit, source-hash-pinned export jobs from the approved catalog."""
import argparse
import json
from pathlib import Path

from catalog_compaction_benchmark import SPECIES

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source_catalog', type=Path)
parser.add_argument('source_root', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--bake-colors', action='store_true')
parser.add_argument('--pbr-maps', action='store_true')
parser.add_argument('--species', nargs='+', choices=SPECIES, default=list(SPECIES))
args = parser.parse_args()
catalog = json.loads(args.source_catalog.read_text())
entries = []
for species in args.species:
    manifest = Path(catalog['entries'][species + ':normal']['path'])
    cfg = json.loads((manifest.parent.parent / 'render.job.json').read_text())['manifest']
    source = args.source_root / species / 'normal' / cfg['source']['filename']
    entries.append(dict(source=str(source.resolve()), manifest=cfg))
args.output.mkdir(parents=True, exist_ok=False)
(args.output / 'export-job.json').write_text(json.dumps(dict(entries=entries, bake_colors=args.bake_colors or args.pbr_maps, pbr_maps=args.pbr_maps, output=str((args.output / 'glb').resolve())), indent=2))
