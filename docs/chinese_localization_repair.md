# Simplified Chinese localization repair

Status: active

## Scope

This repair replaces unreviewed machine translations in Pokémon-specific content
with verified Simplified Chinese terminology. It covers battle and Pokédex labels,
types, Natures, move names, Ability names, item names, and the corresponding short
descriptions where an official Chinese source exists.

Species display names remain English under the existing product terminology policy.
PokeAether-specific names and prose remain in their reviewed overlays or fall back to
English until they receive a separate Chinese-language review.

## Baseline audit

The pre-repair catalogs contain:

- 18 machine-translated type names and 25 machine-translated Nature names;
- 919 generated move entries, 377 generated Ability entries, and 1,447 generated
  item entries;
- only 65 moves, 20 Abilities, and 69 items in the manually reviewed overlays;
- Pokémon UI mistranslations such as `Power` as `电源`, `Accuracy` as `加速器`,
  `Move` as `移动`, and `Ability` as `能力`.

The generated Simplified Chinese catalogs were produced by the Google Translate
review-draft path in `tools/generate_content_translation_drafts.mjs`. That path is
useful for technical coverage but is not an approved terminology source.

## Verified terminology source

Canonical game terminology is imported from the PokéAPI CSV data snapshot at commit
`c40a25c6544b97334a1ae8b1965a378fa3317c28`, using official language ID 12
(`zh-hans`). The snapshot provides exact identifier coverage for all 919 current move
IDs, 311 of 377 Ability IDs, and 1,030 of 1,447 item IDs in PokeAether. A
deterministic localized machine-name rule covers another 293 TM/HM item IDs.

Official Chinese flavor text covers 826 moves, 267 of the 317 described
Abilities, and 1,008 items. Reviewed overrides retain PokeAether's current
Hidden Power mechanics and cover Armor Cannon and Bitter Blade. The same
TM/HM rule supplies 293 short item descriptions. Remaining generated prose
uses the English source text instead of an unreviewed Chinese translation.

The raw upstream CSV files are not copied into the game. A deterministic import tool
reads an explicitly supplied snapshot directory and updates presentation-only fields.
Entries without a verified Chinese value fall back to English instead of retaining an
unreviewed machine translation. Existing reviewed PokeAether-specific overlays remain
authoritative.

## Safety rules

- Never modify IDs, types, Power, accuracy, PP, effects, prices, or other mechanics.
- Keep source provenance and coverage checks in the importer.
- Require an explicit local CSV path; normal builds and tests never access the network.
- Preserve placeholders and presentation-only catalog schemas.
- Treat official flavor text as presentation copy, not as a source of mechanics.
- Keep each repair phase independently reviewable and revertible.
