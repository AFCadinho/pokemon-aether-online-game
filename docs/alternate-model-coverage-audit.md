# Alternate-form model coverage audit

Snapshot: 2026-10-12.

This audit compares all local Pokémon species files and the actual national Pokédex visibility filter against both normal/shiny model bindings, the compiled model aliases, and the hash-pinned selected v13 index. It expands shared-pack references through the same catalog/geometry precedence as the runtime. It does not access production or prove that source meshes do not exist on disk.

Inspected **1439 species files**, **1438 visible Pokédex entries**, **1204 reviewed model pairs**, and **1200 selected v13 pairs**.

| Visible Pokédex status | Entries |
| --- | ---: |
| selected_v13 | 1197 |
| missing_pair | 229 |
| model_exists_under_other_name | 8 |
| prepared_not_selected | 4 |

**229 visible form identities lack a reviewed pair or an equivalent reviewed model.** This is a count of missing form coverage, not necessarily distinct meshes: colours, type materials, sizes, cosmetic forms and Totem forms are included. Several can potentially share geometry. No partially reviewed normal/shiny pairs were found.

## Recommended first batches

- Rotom Heat/Wash/Frost/Fan/Mow (5): common battle variants with different appliances.
- Enamorus Therian, Dialga/Palkia/Giratina Origin, Groudon/Kyogre Primal, Necrozma Dusk Mane/Dawn Wings/Ultra, Zygarde 10%/Complete.
- Deoxys Attack/Defense/Speed, Hoopa Unbound, Shaymin Sky, Keldeo Resolute, Meloetta Pirouette, Lycanroc Dusk/Midnight, Toxtricity Low Key and Ursaluna Bloodmoon.
- Then gender, seasonal, colour/pattern, type-material and other cosmetic variants. Batch ordering is an engineering recommendation, not measured usage frequency.

## Prepared, awaiting model-release selection

These forms have both palettes reviewed and a local candidate index, but are absent from the selected v13 index:

- `landorus-therian`
- `thundurus-therian`
- `tornadus-therian`
- `urshifu-rapid-strike`

Black/White Kyurem, crowned Zacian/Zamazenta and both Calyrex rider forms are already covered by selected v13. Ordinary regional forms and the current Mega forms need no new model in this audit (including the intentional shared female/male Mega Meowstic binding).

## Naming differences: models exist

These species-data names have an equivalent reviewed model under another key. Showdown identity equivalence proves inventory overlap; it does **not** add a frontend alias or prove every caller uses the right key. Test the actual emitted battle identity before changing these bindings.

| Species-data identity | Existing model |
| --- | --- |
| charizard-megax | charizard-mega-x |
| charizard-megay | charizard-mega-y |
| landorus-incarnate | landorus |
| meloetta-aria | meloetta |
| mewtwo-megax | mewtwo-mega-x |
| mewtwo-megay | mewtwo-mega-y |
| thundurus-incarnate | thundurus |
| tornadus-incarnate | tornadus |

Meloetta Pirouette is a real gap: its species file currently stores `showdown_id=meloetta`. The audit resolves the explicit `species_id` first so this data inconsistency cannot incorrectly count the Aria model as Pirouette coverage. Hidden `greninja-bond` is reported in JSON but excluded from visible-form totals; the backend explicitly treats that hidden starting identity as Greninja.

## Complete missing list by family

| Family | Count | Missing species identities |
| --- | ---: | --- |
| Alcremie | 8 | alcremie-caramel-swirl, alcremie-lemon-cream, alcremie-matcha-cream, alcremie-mint-cream, alcremie-rainbow-swirl, alcremie-ruby-cream, alcremie-ruby-swirl, alcremie-salted-cream |
| Araquanid | 1 | araquanid-totem |
| Arceus | 17 | arceus-bug, arceus-dark, arceus-dragon, arceus-electric, arceus-fairy, arceus-fighting, arceus-fire, arceus-flying, arceus-ghost, arceus-grass, arceus-ground, arceus-ice, arceus-poison, arceus-psychic, arceus-rock, arceus-steel, arceus-water |
| Basculegion | 1 | basculegion-f |
| Basculin | 2 | basculin-blue-striped, basculin-white-striped |
| Burmy | 2 | burmy-sandy, burmy-trash |
| Castform | 3 | castform-rainy, castform-snowy, castform-sunny |
| Cherrim | 1 | cherrim-sunshine |
| Cramorant | 2 | cramorant-gorging, cramorant-gulping |
| Deerling | 3 | deerling-autumn, deerling-summer, deerling-winter |
| Deoxys | 3 | deoxys-attack, deoxys-defense, deoxys-speed |
| Dialga | 1 | dialga-origin |
| Dudunsparce | 1 | dudunsparce-three-segment |
| Eevee | 1 | eevee-starter |
| Enamorus | 1 | enamorus-therian |
| Eternatus | 1 | eternatus-eternamax |
| Flabébé | 4 | flabebe-blue, flabebe-orange, flabebe-white, flabebe-yellow |
| Floette | 5 | floette-blue, floette-eternal, floette-orange, floette-white, floette-yellow |
| Florges | 4 | florges-blue, florges-orange, florges-white, florges-yellow |
| Furfrou | 9 | furfrou-dandy, furfrou-debutante, furfrou-diamond, furfrou-heart, furfrou-kabuki, furfrou-la-reine, furfrou-matron, furfrou-pharaoh, furfrou-star |
| Gastrodon | 1 | gastrodon-east |
| Genesect | 4 | genesect-burn, genesect-chill, genesect-douse, genesect-shock |
| Gimmighoul | 1 | gimmighoul-roaming |
| Giratina | 1 | giratina-origin |
| Gourgeist | 3 | gourgeist-large, gourgeist-small, gourgeist-super |
| Greninja | 1 | greninja-ash |
| Groudon | 1 | groudon-primal |
| Gumshoos | 1 | gumshoos-totem |
| Hoopa | 1 | hoopa-unbound |
| Indeedee | 1 | indeedee-f |
| Keldeo | 1 | keldeo-resolute |
| Kommo-o | 1 | kommo-o-totem |
| Kyogre | 1 | kyogre-primal |
| Lurantis | 1 | lurantis-totem |
| Lycanroc | 2 | lycanroc-dusk, lycanroc-midnight |
| Magearna | 1 | magearna-original |
| Maushold | 1 | maushold-four |
| Meloetta | 1 | meloetta-pirouette |
| Meowstic | 1 | meowstic-f |
| Mimikyu | 2 | mimikyu-busted-totem, mimikyu-totem |
| Minior | 7 | minior-blue, minior-green, minior-indigo, minior-meteor, minior-orange, minior-violet, minior-yellow |
| Necrozma | 3 | necrozma-dawn-wings, necrozma-dusk-mane, necrozma-ultra |
| Ogerpon | 4 | ogerpon-cornerstone-tera, ogerpon-hearthflame-tera, ogerpon-teal-tera, ogerpon-wellspring-tera |
| Oinkologne | 1 | oinkologne-f |
| Oricorio | 3 | oricorio-pau, oricorio-pom-pom, oricorio-sensu |
| Palkia | 1 | palkia-origin |
| Pichu | 1 | pichu-spiky-eared |
| Pikachu | 14 | pikachu-belle, pikachu-cosplay, pikachu-hoenn, pikachu-kalos, pikachu-libre, pikachu-original, pikachu-partner, pikachu-phd, pikachu-pop-star, pikachu-rock-star, pikachu-sinnoh, pikachu-starter, pikachu-unova, pikachu-world |
| Poltchageist | 1 | poltchageist-artisan |
| Polteageist | 1 | polteageist-antique |
| Pumpkaboo | 3 | pumpkaboo-large, pumpkaboo-small, pumpkaboo-super |
| Ribombee | 1 | ribombee-totem |
| Rockruff | 1 | rockruff-dusk |
| Rotom | 5 | rotom-fan, rotom-frost, rotom-heat, rotom-mow, rotom-wash |
| Salazzle | 1 | salazzle-totem |
| Sawsbuck | 3 | sawsbuck-autumn, sawsbuck-summer, sawsbuck-winter |
| Shaymin | 1 | shaymin-sky |
| Shellos | 1 | shellos-east |
| Silvally | 17 | silvally-bug, silvally-dark, silvally-dragon, silvally-electric, silvally-fairy, silvally-fighting, silvally-fire, silvally-flying, silvally-ghost, silvally-grass, silvally-ground, silvally-ice, silvally-poison, silvally-psychic, silvally-rock, silvally-steel, silvally-water |
| Sinistcha | 1 | sinistcha-masterpiece |
| Sinistea | 1 | sinistea-antique |
| Squawkabilly | 3 | squawkabilly-blue, squawkabilly-white, squawkabilly-yellow |
| Tatsugiri | 2 | tatsugiri-droopy, tatsugiri-stretchy |
| Togedemaru | 1 | togedemaru-totem |
| Toxtricity | 1 | toxtricity-low-key |
| Unown | 27 | unown-b, unown-c, unown-d, unown-e, unown-exclamation, unown-f, unown-g, unown-h, unown-i, unown-j, unown-k, unown-l, unown-m, unown-n, unown-o, unown-p, unown-q, unown-question, unown-r, unown-s, unown-t, unown-u, unown-v, unown-w, unown-x, unown-y, unown-z |
| Ursaluna | 1 | ursaluna-bloodmoon |
| Vikavolt | 1 | vikavolt-totem |
| Vivillon | 19 | vivillon-archipelago, vivillon-continental, vivillon-elegant, vivillon-fancy, vivillon-garden, vivillon-high-plains, vivillon-icy-snow, vivillon-jungle, vivillon-marine, vivillon-modern, vivillon-monsoon, vivillon-ocean, vivillon-pokeball, vivillon-polar, vivillon-river, vivillon-sandstorm, vivillon-savanna, vivillon-sun, vivillon-tundra |
| Wormadam | 2 | wormadam-sandy, wormadam-trash |
| Xerneas | 1 | xerneas-neutral |
| Zarude | 1 | zarude-dada |
| Zygarde | 2 | zygarde-10, zygarde-complete |

## Verification and limits

The script checks game/launcher registry parity, the release index size/SHA and asset set, every expanded pack binding and accepted non-revoked source hash, candidate bindings, unique species IDs, and stable species inputs. JSON records individual rows and source hashes. No gameplay changes, model approvals, uploads, releases or visual qualifications are performed.

This is coverage of species represented in this repository, not every form ever present in a Pokémon title. A listed form is not proof it is currently obtainable or allowed in every battle format. Missing identity coverage may trigger 2D when the exact missing key reaches the presenter. Source availability and whether an existing mesh/material can safely be reused require a separate intake.

Reproduce from an assigned frontend worktree with the backend as a read-only input:

```sh
python3 tools/sprite_factory/audit_alternate_model_coverage.py --backend /path/to/pokemon-aether-backend
```
