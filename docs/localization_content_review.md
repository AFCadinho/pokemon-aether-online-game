# Content translation review workflow

Status: active

The canonical content localization source is generated from the game's existing
mechanical indexes, but contains presentation fields only:

- 1,439 species and forms;
- 919 moves;
- 376 abilities;
- short descriptions for all 919 moves and the 316 abilities whose source index has
  a description.

`localization/content/generated/en.json` is the complete English presentation source.
The Dutch and Brazilian Portuguese files in the same directory are machine-generated
review drafts. They make the full catalog testable in-game, but are not considered
language-reviewed.

The manually reviewed overlays remain:

- `localization/content/en.json`;
- `localization/content/nl.json`;
- `localization/content/pt_BR.json`.

These files load after the generated catalogs, so a reviewed entry always overrides
its generated draft. Current reviewed coverage is all 18 types, all 25 natures, and
the 65 moves and 20 abilities used by the Route 1 and Alpha Gym trainer rosters.

## Safe update process

1. Regenerate the complete English source after a canonical data update:

   ```bash
   node tools/generate_content_localization_source.mjs
   ```

2. Generate separate Dutch and Portuguese review drafts only when intentionally
   refreshing automated translations:

   ```bash
   node tools/generate_content_translation_drafts.mjs --accept-machine-translation
   ```

3. Review entries in-game or against the English source.
4. Copy approved `name` and `shortDesc` fields into the matching manual locale file.
5. Run `res://tests/localization_content_data_check.gd` and the complete project
   checks.

Never add power, accuracy, PP, type, category, stat changes, prices, ownership, or
other mechanics to a locale catalog. Missing presentation fields fall back to English.
The 60 abilities without a description in the canonical source intentionally show no
generated description rather than inventing behavior.
