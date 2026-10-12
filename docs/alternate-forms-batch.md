# Alternate-form batch qualification

All 229 audited gaps were included. 120 forms (240 appearances) are prepared; 109 remain held.

Prepared pair packs total 801,699,872 bytes; their native scene inputs total 1,786,279,168 bytes.

The prepared index is `release/approved_3d_alternate_forms_index.json`. The selected v13 index, R2 and production were not changed. Eight explicit naming aliases also resolve to existing reviewed pairs.

## Evidence

The admitted set has 2,816 exact comparison frames, 14,880 animation switches, 2,519,896 source visibility samples and 6,592 battle camera views.

- Linux Godot 4.6.2: native normal/shiny poses, back/side views, source visibility transitions, independently sampled 120 Hz floor clearance and both battle cameras.
- Lossless decoded resource equality, physical pack installation, exact Mobile renderer comparisons and actual Team Preview/classic/stadium loading for every admitted pair.
- Native geometry, source animation keys and texture resolution remain intact. Source visibility tracks use continuous nearest sampling to prevent stale accessory visibility on replay.
- Static Arceus palettes come from pinned native form selectors. Alcremie uses the source strawberry visibility selection. Genesect uses its complete standing battle bank. Absent ZA low-detail visibility targets are excluded only when the exported highest-detail mesh exists.
- Diagnostic images and pack files remain in the assigned worktree under `.tmp/alternate-forms-batch-v1`; qualification receipts pin them. Windows, macOS and physical Android were not tested in this batch.

Autumn, Summer and Winter Sawsbuck passed their source appearance and animation checks, but their shiny pack comparisons differ by a few pixels. For Winter, shared-texture and original-scene lossless packing both reproduced the discrepancy. These are strict render-comparison holds, not evidence of reduced geometry or texture resolution.

## Reproduction

Run scripts through `ops/worktrees/slot-env slot-c -- python3 ...` in this assigned task. The source intake pins the external source catalog/files and archive members; the importer revision is pinned by the export tooling. Use a fresh retained output revision when changing a source.

The native, legacy, ZA and colour intake scripts feed export → material → runtime → appearance → battle → delivery. `POKEAETHER_FORM_BATCH_COHORT` selects `native`, `legacy`, `za` or `colours`. Contact sheets require explicit visual review; existence or a successful export never grants approval. `alternate_forms_admission.py` verifies all evidence before catalog mutation, then checks every admitted model in the real game stages.

## Prepared forms

alcremie-caramel-swirl, alcremie-lemon-cream, alcremie-matcha-cream, alcremie-mint-cream, alcremie-rainbow-swirl, alcremie-ruby-cream, alcremie-ruby-swirl, alcremie-salted-cream, arceus-bug, arceus-dark, arceus-dragon, arceus-electric, arceus-fairy, arceus-fighting, arceus-fire, arceus-flying, arceus-ghost, arceus-grass, arceus-ground, arceus-ice, arceus-poison, arceus-psychic, arceus-rock, arceus-steel, arceus-water, basculegion-f, basculin-blue-striped, basculin-white-striped, deerling-autumn, deerling-summer, deerling-winter, deoxys-attack, deoxys-defense, deoxys-speed, dialga-origin, dudunsparce-three-segment, enamorus-therian, flabebe-blue, flabebe-orange, flabebe-white, flabebe-yellow, floette-blue, floette-eternal, floette-orange, floette-white, floette-yellow, florges-blue, florges-orange, florges-white, florges-yellow, furfrou-dandy, furfrou-debutante, furfrou-diamond, furfrou-heart, furfrou-kabuki, furfrou-la-reine, furfrou-matron, furfrou-pharaoh, furfrou-star, gastrodon-east, genesect-burn, genesect-chill, genesect-douse, genesect-shock, gimmighoul-roaming, giratina-origin, hoopa-unbound, indeedee-f, keldeo-resolute, lycanroc-dusk, lycanroc-midnight, magearna-original, maushold-four, meloetta-pirouette, meowstic-f, oinkologne-f, oricorio-pau, oricorio-pom-pom, oricorio-sensu, palkia-origin, pikachu-hoenn, pikachu-kalos, pikachu-original, pikachu-partner, pikachu-sinnoh, pikachu-unova, pikachu-world, polteageist-antique, rotom-frost, rotom-heat, rotom-mow, rotom-wash, shaymin-sky, shellos-east, sinistea-antique, tatsugiri-droopy, tatsugiri-stretchy, toxtricity-low-key, ursaluna-bloodmoon, vivillon-archipelago, vivillon-continental, vivillon-elegant, vivillon-fancy, vivillon-garden, vivillon-high-plains, vivillon-icy-snow, vivillon-jungle, vivillon-marine, vivillon-modern, vivillon-monsoon, vivillon-ocean, vivillon-pokeball, vivillon-polar, vivillon-river, vivillon-sandstorm, vivillon-savanna, vivillon-sun, vivillon-tundra, zarude-dada, zygarde-complete.

## Remaining holds

A hold means this batch has not qualified the required source binding, material or motion. It does not imply no model exists anywhere. Each group below needs the stated evidence before admission.

- **delivery** — AssertionError: Pixel equality failed: ['sawsbuck-autumn@shiny']
  Forms: sawsbuck-autumn.
- **delivery** — AssertionError: Pixel equality failed: ['sawsbuck-summer@shiny']
  Forms: sawsbuck-summer.
- **delivery** — AssertionError: Pixel equality failed: ['sawsbuck-winter@shiny']
  Forms: sawsbuck-winter.
- **legacy-material** — ValueError: Archived source effects require their matching material motion evidence
  Forms: necrozma-dawn-wings, necrozma-dusk-mane.
- **mapping_hold** — Expected one own source rig; found 0
  Forms: greninja-ash.
- **mapping_hold** — archive_or_raw_variant_identity_requires_review
  Forms: gourgeist-large, gourgeist-small, gourgeist-super, ogerpon-cornerstone-tera, ogerpon-hearthflame-tera, ogerpon-teal-tera, ogerpon-wellspring-tera, pichu-spiky-eared, pikachu-belle, pikachu-cosplay, pikachu-libre, pikachu-phd, pikachu-pop-star, pikachu-rock-star, poltchageist-artisan, pumpkaboo-large, pumpkaboo-small, pumpkaboo-super, sinistcha-masterpiece, xerneas-neutral.
- **mapping_hold** — form_material_selector_requires_explicit_sampling
  Forms: minior-blue, minior-green, minior-indigo, minior-meteor, minior-orange, minior-violet, minior-yellow.
- **mapping_hold** — shared_base_geometry_and_source_scale_require_verification
  Forms: araquanid-totem, eevee-starter, gumshoos-totem, kommo-o-totem, lurantis-totem, mimikyu-busted-totem, mimikyu-totem, pikachu-starter, ribombee-totem, rockruff-dusk, salazzle-totem, togedemaru-totem, vikavolt-totem.
- **motion_hold** — No complete own-source battle action set
  Forms: castform-rainy, castform-snowy, castform-sunny, cramorant-gorging, cramorant-gulping, eternatus-eternamax, necrozma-ultra.
- **source-binding** — Typed own rigs found. Archived actions use the base rig prefix; bone/skin compatibility and normal/shiny material bindings still need proof.
  Forms: silvally-bug, silvally-dark, silvally-dragon, silvally-electric, silvally-fairy, silvally-fighting, silvally-fire, silvally-flying, silvally-ghost, silvally-grass, silvally-ground, silvally-ice, silvally-poison, silvally-psychic, silvally-rock, silvally-steel, silvally-water.
- **source-material** — Own geometry and animations exported. Matching verified normal/shiny material tables are unavailable in the inspected SCVI/ZA route; archived material reconstruction remains unqualified.
  Forms: burmy-sandy, burmy-trash, cherrim-sunshine, unown-b, unown-c, unown-d, unown-e, unown-exclamation, unown-f, unown-g, unown-h, unown-i, unown-j, unown-k, unown-l, unown-m, unown-n, unown-o, unown-p, unown-q, unown-question, unown-r, unown-s, unown-t, unown-u, unown-v, unown-w, unown-x, unown-y, unown-z, wormadam-sandy, wormadam-trash.
- **source-motion** — ZA source geometry and battle actions found; the required sleep action is absent from the selected native bank.
  Forms: groudon-primal, kyogre-primal.
- **source-motion** — motion_bank_hold:sleep:missing; missing_action:sleep
  Forms: squawkabilly-blue, squawkabilly-white, squawkabilly-yellow.
- **source-shader** — Detailed base and layer-mask textures use different resolutions. Exact native multi-texture shader sampling is required; downsampling is refused.
  Forms: rotom-fan.
- **source-shader** — Native Fresnel/probe material remains unqualified: the source texture reference could not be resolved by the material pipeline.
  Forms: zygarde-10.
