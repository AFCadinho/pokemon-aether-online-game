# Regional Pokémon 3D coverage audit

2026-10-05 · task `regional-model-audit`

## Result

**54 of 57 ordinary regional forms are missing approved normal/shiny 3D pairs.** Only Galarian Articuno, Zapdos and Moltres are registered and present in the pinned v9 download index. Four additional region-labelled variants are also missing, bringing the full regional-name audit to **58 missing of 61 Pokédex entries** (116 missing normal/shiny identities).

| Region | Ordinary forms | Ready pairs | Missing pairs |
| --- | ---: | ---: | ---: |
| Alola | 18 | 0 | 18 |
| Galar | 19 | 3 | 16 |
| Hisui | 16 | 0 | 16 |
| Paldea | 4 | 0 | 4 |

Every missing identity is absent from both the reviewed registry and the actual pinned bundle index. None is merely a registered model under a missing download entry. Client and launcher registries/release pins agree. The runtime alias resolver has no regional aliases that would fill these gaps.

This is a local repository and pinned-index audit, **not a live production/R2 availability check**. It checks registration, inclusion and digest agreement; it does not repeat visual, animation or performance review of the three existing pairs. It does not certify every unrelated alternate form.

## Hisuian Samurott

The Pokédex uses `samurott-hisui`; the client only has `samurott` and `samurott@shiny`. The earlier production result names ordinary Samurott resource `pm0503_00_00`. Mapping the Hisui entry to that model would display the wrong form.

The connected sources contain **`pm0503_00_41`**, catalogued as national #503, form 1. Its source icon was inspected and shows Hisuian Samurott. Geometry, skeleton, normal and rare material tables, a rare body texture, **74 skeletal clips and 74 material clips** are present. Source file hashes and complete clip names are in the JSON evidence.

It needs candidate conversion, material/eye/shiny checks, action mapping, battle size and performance qualification, then normal/shiny bundles, registry admission and publication. Raw source availability does not qualify an installable model.

## Full Pokédex checklist

| Identity | Classification | Normal | Shiny | v9 bundle |
| --- | --- | --- | --- | --- |
| arcanine-hisui | regional form | Missing | Missing | Missing |
| articuno-galar | regional form | Ready | Ready | Listed |
| avalugg-hisui | regional form | Missing | Missing | Missing |
| braviary-hisui | regional form | Missing | Missing | Missing |
| corsola-galar | regional form | Missing | Missing | Missing |
| darmanitan-galar-zen | battle transformation | Missing | Missing | Missing |
| darmanitan-galar | regional form | Missing | Missing | Missing |
| darumaka-galar | regional form | Missing | Missing | Missing |
| decidueye-hisui | regional form | Missing | Missing | Missing |
| diglett-alola | regional form | Missing | Missing | Missing |
| dugtrio-alola | regional form | Missing | Missing | Missing |
| electrode-hisui | regional form | Missing | Missing | Missing |
| exeggutor-alola | regional form | Missing | Missing | Missing |
| farfetchd-galar | regional form | Missing | Missing | Missing |
| geodude-alola | regional form | Missing | Missing | Missing |
| golem-alola | regional form | Missing | Missing | Missing |
| goodra-hisui | regional form | Missing | Missing | Missing |
| graveler-alola | regional form | Missing | Missing | Missing |
| grimer-alola | regional form | Missing | Missing | Missing |
| growlithe-hisui | regional form | Missing | Missing | Missing |
| lilligant-hisui | regional form | Missing | Missing | Missing |
| linoone-galar | regional form | Missing | Missing | Missing |
| marowak-alola-totem | totem variant | Missing | Missing | Missing |
| marowak-alola | regional form | Missing | Missing | Missing |
| meowth-alola | regional form | Missing | Missing | Missing |
| meowth-galar | regional form | Missing | Missing | Missing |
| moltres-galar | regional form | Ready | Ready | Listed |
| mr-mime-galar | regional form | Missing | Missing | Missing |
| muk-alola | regional form | Missing | Missing | Missing |
| ninetales-alola | regional form | Missing | Missing | Missing |
| persian-alola | regional form | Missing | Missing | Missing |
| pikachu-alola | cap variant | Missing | Missing | Missing |
| ponyta-galar | regional form | Missing | Missing | Missing |
| qwilfish-hisui | regional form | Missing | Missing | Missing |
| raichu-alola | regional form | Missing | Missing | Missing |
| rapidash-galar | regional form | Missing | Missing | Missing |
| raticate-alola-totem | totem variant | Missing | Missing | Missing |
| raticate-alola | regional form | Missing | Missing | Missing |
| rattata-alola | regional form | Missing | Missing | Missing |
| samurott-hisui | regional form | Missing | Missing | Missing |
| sandshrew-alola | regional form | Missing | Missing | Missing |
| sandslash-alola | regional form | Missing | Missing | Missing |
| sliggoo-hisui | regional form | Missing | Missing | Missing |
| slowbro-galar | regional form | Missing | Missing | Missing |
| slowking-galar | regional form | Missing | Missing | Missing |
| slowpoke-galar | regional form | Missing | Missing | Missing |
| sneasel-hisui | regional form | Missing | Missing | Missing |
| stunfisk-galar | regional form | Missing | Missing | Missing |
| tauros-paldea-aqua | regional form | Missing | Missing | Missing |
| tauros-paldea-blaze | regional form | Missing | Missing | Missing |
| tauros-paldea-combat | regional form | Missing | Missing | Missing |
| typhlosion-hisui | regional form | Missing | Missing | Missing |
| voltorb-hisui | regional form | Missing | Missing | Missing |
| vulpix-alola | regional form | Missing | Missing | Missing |
| weezing-galar | regional form | Missing | Missing | Missing |
| wooper-paldea | regional form | Missing | Missing | Missing |
| yamask-galar | regional form | Missing | Missing | Missing |
| zapdos-galar | regional form | Ready | Ready | Listed |
| zigzagoon-galar | regional form | Missing | Missing | Missing |
| zoroark-hisui | regional form | Missing | Missing | Missing |
| zorua-hisui | regional form | Missing | Missing | Missing |

Pikachu-Alola is a cap variant, not a regional species redesign. Alolan Raticate/Marowak Totem and Galarian Darmanitan Zen are additional size/battle variants. They remain explicit backlog entries, separate from the 57 ordinary regional forms.

## Why earlier totals did not catch this

Completing national species numbers does not complete every alternate form of those numbers. Regional identities must be counted and validated separately. The existing national-count code deliberately deduplicates alternate forms, so a 1,025-species count cannot establish regional-form coverage.

## Reproduce

The audit calls the actual local account-service Pokédex visibility function (1,438 visible entries in this snapshot), then checks all region-labelled identities against both normal/shiny registries and the SHA-pinned v9 index. It asserts exact index membership against the release allowlist and agreement between game and launcher data.

```sh
python3 tools/sprite_factory/audit_regional_model_coverage.py \
  --backend /path/to/pokemon-aether-backend \
  --sources /path/to/3d_models \
  --output tools/sprite_factory/regional_model_coverage_audit.json
```

Evidence: `tools/sprite_factory/regional_model_coverage_audit.json`. Input revisions and hashes are recorded there. No gameplay settings, models, assets or approvals were changed.

## Next production order

1. Start with Hisuian Samurott, whose exact source resources are confirmed.
2. Intake and produce the remaining 15 Hisui and 4 Paldea forms as explicit normal/shiny identities.
3. Intake the 18 Alola and remaining 16 Galar forms, then the four extra variants. Locate and validate each source form; never substitute its ordinary species model.
4. Keep a regional coverage check alongside national-species and Mega coverage checks before declaring the whole Pokédex complete.
