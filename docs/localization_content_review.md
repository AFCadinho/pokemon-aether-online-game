# Content translation review workflow

Status: active

The canonical content localization source is generated from the game's existing
mechanical indexes, but contains presentation fields only:

- 1,439 species and forms;
- 919 moves;
- 377 abilities;
- 1,447 items;
- short descriptions for all 919 moves and the 317 abilities whose source index has
  a description;
- names and short descriptions for all 1,447 canonical items.

`localization/content/generated/en.json` is the complete English presentation source.
The Dutch and Brazilian Portuguese files in the same directory are machine-generated
review drafts. The Simplified Chinese catalogs use verified PokéAPI `zh-hans` names
and flavor text where available, reviewed local overrides for documented exceptions,
and English fallback for unverified presentation. They do not retain automated Chinese
content drafts. All generated catalogs make the full catalog testable in-game; free
product prose still requires native-speaker review.

The item equivalents live under `localization/items/generated/`. The generated item
catalogs contain only `name` and `shortDesc`; quantities, prices, effects, ownership,
and other mechanics remain in canonical game data.

The initial Simplified Chinese interface, launcher, sign, and dialogue catalogs are
complete machine-generated review drafts with a reviewed core glossary. Pokémon names
and terminology follow the controlled process in `docs/chinese_localization_repair.md`.
Free prose still requires native-speaker review before language-quality approval is
recorded.

The manually reviewed overlays remain:

- `localization/content/en.json`;
- `localization/content/nl.json`;
- `localization/content/pt_BR.json`.
- `localization/content/zh_CN.json`.

The manually reviewed item overlays remain:

- `localization/items/en.json`;
- `localization/items/nl.json`;
- `localization/items/pt_BR.json`.
- `localization/items/zh_CN.json`.

These files load after the generated catalogs, so a reviewed entry always overrides
its generated draft. Current reviewed coverage is all 18 types, all 25 natures, and
the 65 moves and 20 abilities used by the Route 1 and Alpha Gym trainer rosters, plus
the 69-item pilot catalog.

## Safe update process

1. Regenerate the complete English source after a canonical data update:

   ```bash
   node tools/generate_content_localization_source.mjs
   ```

2. Generate separate Dutch, Portuguese, and Simplified Chinese review drafts only when intentionally
   refreshing automated translations:

   ```bash
   node tools/generate_content_translation_drafts.mjs --accept-machine-translation
   ```

   To refresh only item drafts without touching the existing move and ability drafts:

   ```bash
   node tools/generate_content_translation_drafts.mjs \
     --accept-machine-translation \
     --items-only
   ```

   The generator preserves existing verified Simplified Chinese content presentation.
   To verify or refresh it from the pinned PokéAPI snapshot, run:

   ```bash
   python3 tools/import_pokeapi_zh_hans.py --csv-dir /path/to/pinned/data/v2/csv
   python3 tools/import_pokeapi_zh_hans.py --csv-dir /path/to/pinned/data/v2/csv --check
   ```

3. Review entries in-game or against the English source. This includes deciding
   terminology policy, such as whether move names should remain English.
4. Copy approved `name` and `shortDesc` fields into the matching manual locale file.
5. Run `res://tests/localization_content_data_check.gd`,
   `res://tests/localization_item_data_check.gd`, and the complete project checks.

Never add power, accuracy, PP, type, category, stat changes, prices, ownership, or
other mechanics to a locale catalog. Missing presentation fields fall back to English.
The 60 abilities without a description in the canonical source intentionally show no
generated description rather than inventing behavior.
