# Batch 01: normal and shiny in-game review

The 14 paired candidates are available for **local desktop battle review** in
the development game. They remain screened candidates: this does not add them
to the seven-species approved release, launcher delivery or the base game build.
The four shiny material holds remain outside this catalog.

## Open the battle review

From the frontend repository on this computer, run:

```sh
python3 tools/sprite_factory/launch_catalog_batch_01_review.py
```

This opens the real local desktop battle screen with normal on the left and
shiny on the right. Use **Vorige/Volgende** to move through all 14 pairs and
the action buttons to inspect attacks, damage, sleep and faint. **Herstel**
returns the current pair to idle. No account, Pokémon collection or backend
battle is required. The review window does not change saved game settings.

The rendered first-pair smoke check showed both Charmeleon appearances, the
Immersive HUD and working review controls after the battle loading cover cleared.

## Select the local catalog in the game

In the game, open **Settings**, enable **3D (experimental)**, then choose
**Choose local 3D model catalog…**. Select:

`/home/adinho/Documents/3d_models/PokeAether/catalog-batch-01-paired-review-v1/catalog.json`

Start a **new single battle** after selecting it. Use a local game build based
on `development` containing the batch-01 screened registry; an older release
still knows only the original approved models. The local catalog contains both
normal and shiny for each species below. Shiny is shown when the battle
Pokémon itself is shiny. Other species and held forms continue to use the
existing fallback. The catalog is an explicit local review choice and does not
change the default model selection for other players.

| Review pairs | | | |
| --- | --- | --- | --- |
| Charmeleon | Dunsparce | Flaaffy | Houndoom |
| Houndour | Igglybuff | Mareep | Persian |
| Phanpy | Skiploom | Slowking | Stantler |
| Teddiursa | Ursaring | | |

Look at both sides of the battle screen, normal and shiny colours, idle motion,
attacks, damage, sleep and faint. For Ursaring, Houndour and Houndoom, compare
fur at battle distance with the previously soft-looking small Pokédex preview.
Report each Pokémon as acceptable or give the specific visible problem. A hold
for one species does not stop the others.

## Exact local artifact

The catalog SHA-256 is
`859921e52976b1bf4c48322cda0deff6cf9f82e710b21f6a38b00c9fd8fb50ee`.
It references 28 hash-checked scenes copied to its own `models/` directory;
their total size is about 353.15 MiB. Keep that folder together with the
catalog. `review-manifest.json` lists all 28 identities and the qualification
hash. The checked-in game and launcher screened registries contain the same
scene pins and one shared calibrated motion profile per normal/shiny pair.

The real battle presenter loaded this exact local catalog in a rendered Classic
arena run: 14 independent pairs, bidirectional variant switches, shiny native
attacks, faint/replacement, Immersive HUD clearance, cache eviction/reload and
held-Ampharos-shiny fallback all passed without script/renderer errors. The
original 75-model screened catalog still passes its own admission check.

The local folder can be recreated from the retained source scenes with
`prepare_catalog_batch_01_playable_review.py` and a **new** output directory.
It is not a portable player download or a release artifact.
