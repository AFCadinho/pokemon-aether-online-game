# PokeAether localization conventions

Status: active

Date: 2026-07-29

## Canonical language and locale codes

- English (`en`) is the canonical source and mandatory fallback.
- Dutch uses `nl`.
- Brazilian Portuguese uses `pt_BR` inside Godot and `pt-BR` in HTTP.
- A new key is not complete until all released locale catalogs contain it.

## Key names

Keys describe meaning and ownership, not the current English wording:

```text
common.close
ui.loading.preparing
ui.party.empty_slot
ui.bag.search_placeholder
notification.hotbar.updated
battle.result.victory
error.guild.name_taken
```

Use lowercase dot-separated segments. Use `snake_case` inside a segment when multiple
words are required. Do not include a locale, visual node name, or English sentence in
the key.

Preferred namespaces:

| Namespace | Use |
| --- | --- |
| `common.*` | Truly shared actions and short labels |
| `ui.<domain>.*` | Interface owned by one functional domain |
| `notification.<domain>.*` | Client-generated system notices |
| `battle.*` | Battle UI and event templates |
| `error.<domain>.*` | Stable player-facing failure mappings |
| `language.*` | Language names shown in their own language |

Do not reuse a key merely because two English strings currently look the same. Reuse it
only when both occurrences have the same meaning and are expected to change together.

## Scene and script usage

Static scene controls store the semantic key in their translatable property:

```text
text = "common.close"
tooltip_text = "ui.navigation.open_settings"
```

Dynamic GDScript uses the localization manager:

```gdscript
label.text = LocalizationManager.text("ui.party.level", {"level": level})
```

Dynamic interfaces must subscribe to `LocalizationManager.locale_changed` and refresh
all generated labels, option items, statuses, and cached presentation text.

Never translate internal IDs before logic, persistence, search indexing, or network
calls. Resolve the display string only at the presentation boundary.

## Placeholders and sentences

- Use named placeholders: `{trainer}`, `{count}`, `{item}`.
- Placeholder names and sets must match in every locale.
- Pass numbers as values; do not bake changing quantities into catalog entries.
- Translate full sentences. Never construct grammar by concatenating translated
  fragments.
- Keep player-generated values separate from templates.
- Escape player/server values before inserting them into BBCode or RichText.

Example:

```json
"notification.item_received": "{trainer} received {item}."
```

## Plurals

For the initial three locales, define explicit singular and plural keys and select them
through `LocalizationManager.plural`:

```text
ui.social.friend_count.one
ui.social.friend_count.many
```

Do not add English suffixes such as `"s"` in code. If a future language requires more
plural categories, extend the helper and catalog format centrally.

## RichText and BBCode

- Keep BBCode balanced within one catalog entry.
- Do not allow translated text to introduce arbitrary URLs or metadata.
- Prefer styling controls over BBCode when the message is assembled from untrusted
  values.
- Tests must validate allowed tags and balanced opening/closing tags before the
  RichText migration is considered complete.

## Terminology and proper names

The following remain unchanged in all locales unless an approved product glossary
explicitly overrides them:

- PokeAether and Aether branding;
- Pokémon and Pokédex spelling, including the accent;
- player names, usernames, guild names, and character names;
- canonical species names for the initial release;
- canonical IDs for species, moves, abilities, items, types, natures, locations,
  currencies, badges, quests, and content.

Move, ability, item, location, badge, and category *display names* may be localized
through approved overlays. Their canonical IDs never change.

Initial recurring terminology:

| English | Dutch | Brazilian Portuguese |
| --- | --- | --- |
| Trainer | Trainer | Treinador |
| Settings | Instellingen | Configurações |
| Bag | Tas | Bolsa |
| Party | Team | Equipe |
| Guild | Guild | Guilda |
| Battle | Gevecht | Batalha |
| Aether Gems | Aether Gems | Gemas Aether |
| Pokédollars | Pokédollars | Pokédollars |

The glossary is a product rule. If a term changes, update existing catalog entries
together rather than allowing per-screen variants.

## Server and external content

- Send the normalized HTTP locale only to endpoints that support it.
- Locale-aware caches include the locale in their key or are cleared on locale change.
- Known backend failures use stable codes and client translations.
- Unknown backend failures show a safe generic localized message; raw details are for
  diagnostics only.
- English-only external content may remain English while its surrounding client UI is
  localized, but the fallback must be documented.

## Translation quality

- English describes the intended meaning, not implementation details.
- Dutch uses natural product language rather than literal word-for-word translation.
- Brazilian Portuguese requires native-speaker review before release.
- Preserve tone, capitalization, punctuation, placeholders, and meaningful line breaks.
- Verify every migrated screen at 1280×720, 1600×900, and 1920×1080.

## Definition of done for a migrated domain

A domain is complete only when:

- no unintended player-facing literal remains in its scenes or scripts;
- all three catalogs contain the same keys and placeholders;
- static and dynamic text update when the locale changes;
- missing localized entries fall back to English;
- player/server values are safely inserted;
- layout and domain regression tests pass;
- intentional exclusions are recorded and reviewed.
