# First-run presentation examples and sizes

The chooser uses static battle screenshots supplied for the first-play dialog,
so a new player can decide without fetching a model or starting a 3D renderer.
`2d.png` (960 × 540) shows Lopunny versus Landorus-Therian in the Aether stadium.
`3d.png` (1907 × 985) shows Roaring Moon versus Dragonite in a 3D cave arena.
Keep the full screenshots visible with their original aspect ratios. Both use
linear filtering when scaled down, including the 2D screenshot's UI text.

`data/battle_visual_download_info.json` describes optional full collections, not
remaining downloads or base game size. 2D includes the six normal/shiny HOME and
animated front/back packs; optional Gen5 pixel packs are separate. 3D includes
all bundles in the approved v8 index. Installation/staging space and environment
packs are additional. The launcher Downloads page computes remaining downloads.

Regenerate after changing sprite pack pins or the approved model index:

```
python3 tools/build_battle_visual_download_info.py --bundle-dir PATH_TO_BUNDLES
python3 tools/build_battle_visual_download_info.py --check
```

The generator reads sprite files from the bootstrapped source assets and ZIP
central-directory sizes from approved archives. Missing model archives use
bounded public range requests (at most 64 KiB per archive); they do not download
the whole model collection. No credentials or local asset paths are stored in
the committed metadata. The offline check prevents stale size labels from
passing the desktop release workflow.
