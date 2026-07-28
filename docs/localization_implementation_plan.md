# PokeAether localization implementation plan

Status: planned

Created: 2026-07-29

Initial locales: English (`en`), Dutch (`nl`), Brazilian Portuguese (`pt-BR`)

## Goal

Build a complete, maintainable localization system for the PokeAether game client,
backend-provided content, launcher, and player-facing service errors. The system must
allow players to select their language before login and from the in-game settings,
switch languages without a required restart, and fall back safely to English.

This plan separates the localization architecture from the translation workload. The
architecture should be introduced early, while existing screens and content can be
migrated incrementally.

## Architectural decisions

- English is the canonical source language and mandatory fallback.
- The initial released locales are `en`, `nl`, and `pt-BR`.
- Godot may use `pt_BR` internally; HTTP requests use the BCP 47 code `pt-BR`.
- Translation keys are semantic and stable, for example:
  - `ui.login.sign_in`
  - `ui.settings.language`
  - `battle.move_used`
  - `error.auth.invalid_credentials`
- Internal identifiers, API enums, save data, item IDs, move IDs, dialogue IDs, and
  battle protocol values are never translated.
- UI chrome and client-generated messages are localized in the client.
- Server-owned content is localized through locale-specific server content or
  translation overlays.
- Player-generated content such as chat, mail bodies, player names, guild names, and
  guild descriptions is not automatically translated.
- The language preference is stored locally so it is available before authentication.
  Account synchronization can be added later without replacing the local preference.
- Missing translations follow a safe fallback chain:
  - `nl-NL -> nl -> en`
  - `pt-BR -> pt -> en`
- A language failure must never prevent login, gameplay, a quest, or a battle action.

## Target architecture

The local setting is read before the login UI is shown. A central localization manager
applies the locale to Godot and announces runtime changes. Client services attach the
HTTP locale to relevant requests. Localized caches include the locale in their keys or
are invalidated when the locale changes.

Player-facing text has three primary owners:

| Text category | Owner |
| --- | --- |
| Buttons, labels, tooltips, local errors, battle templates | Godot client catalogs |
| NPC dialogue and other backend-owned narrative content | Game Content service |
| Species, move, ability, item, and shop display data | Pokémon Data localization overlays |

The launcher is a separate Godot project and adopts the same locale codes, key naming
rules, fallback behavior, and validation tools.

## Phase 0: inventory and conventions

### Work

- Inventory all player-visible text and classify it as:
  - static Godot scene text;
  - dynamic GDScript UI text;
  - battle presentation text;
  - backend error text;
  - NPC dialogue;
  - world signs;
  - Pokémon, move, ability, item, nature, and shop data;
  - launcher and news content;
  - player-generated content.
- Document the translation key naming convention.
- Establish a terminology glossary for recurring PokeAether and Pokémon concepts.
- Decide which proper names remain unchanged in Dutch and Portuguese.
- Define rules for placeholders, plural forms, RichText, and BBCode.
- Record intentional exclusions for debug logs, URLs, protocol values, and developer
  diagnostics.

### Acceptance criteria

- Every text category has one explicit owner.
- IDs and player-visible labels are clearly separated.
- Translation key and placeholder conventions are documented before bulk migration.

## Phase 1: Godot localization foundation

### Work

- Add a central `LocalizationManager` autoload.
- Add a locale preference to `SettingsManager`.
- Persist the preference in `user://settings.json`.
- Define supported locale metadata for `en`, `nl`, and `pt_BR`.
- On first launch, select a supported operating-system language or fall back to English.
- Add Godot translation catalogs with English entries for every introduced key.
- Add a `locale_changed` signal for dynamic interfaces.
- Add helpers for:
  - normal translations;
  - parameterized translations;
  - plural forms;
  - safe English fallback;
  - locale normalization;
  - mapping between Godot and HTTP locale codes.
- Ensure accented Latin characters render correctly.

Language names are displayed in their own language:

```text
English
Nederlands
Português (Brasil)
```

### Acceptance criteria

- The selected locale survives a game restart.
- Changing locale does not require logging out or restarting.
- A missing Dutch or Portuguese entry displays English, never a raw key.
- Locale changes cannot modify game state, save data, or network protocol values.

## Phase 2: login and settings pilot

### Work

- Add the language selector to the shared settings menu.
- Make it available from both the login screen and the in-game settings.
- Migrate all login text to translation keys.
- Migrate all settings tabs, labels, buttons, descriptions, and confirmation dialogs.
- Migrate authentication errors, server status, and connection messages.
- Refresh dynamically created controls when `locale_changed` is emitted.
- Test all supported window resolutions.

### Acceptance criteria

- Login and settings are complete in English, Dutch, and Brazilian Portuguese.
- The language changes immediately while the settings menu is open.
- Logging out does not reset the language.
- These screens contain no unintended English text in Dutch or Portuguese.
- Longer translations wrap correctly at 1280x720, 1600x900, and 1920x1080.

This is the first production-ready localization milestone.

## Phase 3: automated guardrails

### Work

- Add catalog validation for:
  - missing keys;
  - duplicate keys;
  - missing English fallback;
  - placeholder mismatches;
  - invalid locale codes;
  - malformed RichText or BBCode.
- Add a check for newly introduced hardcoded player-facing text in GDScript and scenes.
- Maintain explicit allowlists for debug logs, tests, internal IDs, and technical
  diagnostics.
- Add a non-shipping pseudo-locale that expands text to expose layout problems.
- Add localization checks to the normal project test runner and CI workflow.

### Acceptance criteria

- New untranslated player-facing strings cannot be added silently.
- Placeholder sets match across all catalogs.
- The English catalog is always complete.
- A failed localization check explains the exact key and locale involved.

## Phase 4: shared game interface

Migrate the general interface in small, independently testable domains:

1. Main navigation, shared dialogs, and general notifications.
2. Party and Pokémon summaries.
3. Bag, inventory, and hotbar.
4. Market and standard shops.
5. Pokédex.
6. Mail and notifications.
7. Friends and nearby players.
8. Guilds.
9. Trading.
10. Aether Store and Aether Atelier.
11. Relevant staff and developer interfaces.

The large `ui_overlay.gd` file must be migrated per functional domain rather than in one
large change.

### Acceptance criteria per domain

- All labels, tooltips, statuses, confirmations, and validation messages are localizable.
- Search supports localized display names without replacing canonical IDs.
- Dynamic controls refresh after a locale change.
- Long text and special characters do not overflow or become clipped.
- English fallback remains functional when a non-English entry is intentionally removed
  in a test.

## Phase 5: battle localization

### Work

- Convert battle event sentences into parameterized translation templates.
- Localize battle menus, timers, result screens, statuses, weather, terrain, stats, and
  player-facing battle errors.
- Keep authoritative battle events structured and language-neutral.
- Resolve move, ability, item, species, type, and effect display names at presentation
  time.
- Preserve event data so the battle log can eventually be re-rendered after a locale
  change.
- Test placeholder order in every locale; never construct translated sentences by
  concatenating translated fragments.

### Acceptance criteria

- The same battle event stream renders correctly in all three locales.
- Locale has no influence on legal actions, timing, state transitions, or determinism.
- A locale change cannot interrupt or invalidate an active battle.
- Existing battle logs either re-render in the new language or follow an explicitly
  documented temporary behavior until re-rendering is implemented.

### Sequencing note

There are active local changes in battle-related files at the time this plan was
created. Battle localization should begin after that work is completed or cleanly
baselined to avoid mixing unrelated behavioral and localization changes.

## Phase 6: world signs and NPC dialogue

### World signs

Extend the existing sign layout:

```text
data/world_text/signs/en/...
data/world_text/signs/nl/...
data/world_text/signs/pt-BR/...
```

Use the global locale instead of an implicit per-node English default. Validate that all
locale catalogs contain the same sign IDs.

### NPC dialogue

Introduce locale directories in the Game Content service:

```text
game-content/data/dialogues/en/...
game-content/data/dialogues/nl/...
game-content/data/dialogues/pt-BR/...
```

- Send `Accept-Language` from the client.
- Verify the gateway forwards or maps the header correctly.
- Apply fallback in the content service.
- Key dialogue caches by `(locale, dialogue_id)` or invalidate them on locale changes.
- Validate identical dialogue IDs across locales.

### Acceptance criteria

- Dialogue and sign IDs remain stable across languages.
- The next interaction after a locale change uses the new locale.
- Missing translations fall back to English.
- Missing localized content can never block an interaction or progression check.

## Phase 7: Pokémon and item content

Keep authoritative mechanical data language-neutral and add translation overlays keyed
by canonical IDs.

Example base data:

```json
{
  "id": "potion",
  "category": "medicine"
}
```

Example locale overlay:

```json
{
  "potion": {
    "name": "Potion",
    "short_desc": "Restores HP."
  }
}
```

Add overlays for:

- species;
- moves;
- abilities;
- items;
- types;
- natures;
- statuses and effects;
- shops and cosmetic content.

### Acceptance criteria

- APIs and saved objects always retain canonical IDs.
- Localized names can be used for display and search.
- Locale-specific responses and caches include the locale in their cache key.
- Prices, power, accuracy, quantities, effects, and other mechanical values are never
  duplicated into translation files.
- Switching locale cannot alter owned items, learned moves, teams, or Pokémon instances.

## Phase 8: backend error contracts

### Work

- Give every known player-facing backend failure a stable error code.
- Translate known error codes in the client.
- Keep the English server message as a compatibility fallback and diagnostic aid.
- Map unknown codes to a safe generic localized error.
- Prevent raw technical details from being displayed directly to players.

Example:

```json
{
  "code": "guild_name_taken",
  "message": "That guild name is already in use."
}
```

### Acceptance criteria

- Known service errors display correctly in all supported locales.
- Unknown errors still produce a useful localized message.
- Localization changes do not alter HTTP status handling or service behavior.

## Phase 9: launcher and news

### Work

- Add the same locale model and fallback behavior to the launcher project.
- Localize launcher actions, download states, server status, and errors.
- Share or synchronize the local preference when practical.
- Serve login and launcher news per locale.
- Use English news as fallback.
- Review external registration, website, credits, and legal flows separately.

### Acceptance criteria

- Launcher locale behavior is consistent with the game.
- News content can be selected by locale without breaking older English-only entries.
- Missing localized launcher or news content falls back to English.

## Phase 10: completeness and release gate

PokeAether is considered fully localized for the initial language set when:

- every non-user-generated player-facing system string uses the localization system;
- `en`, `nl`, and `pt-BR` catalogs are complete;
- all world signs and NPC dialogue are translated;
- species, move, ability, item, and relevant shop display content is translated;
- known backend errors use stable translated error codes;
- login, normal gameplay, battles, and launcher flows have been tested in every locale;
- no catalog, placeholder, or fallback validation errors remain;
- supported resolutions pass layout checks;
- Dutch has received product review;
- Brazilian Portuguese has received native-speaker review;
- user-generated content remains intentionally untranslated.

## Translation workflow

Codex can handle most technical and repetitive work:

- extract and classify strings;
- create and migrate translation keys;
- maintain the complete English catalog;
- produce initial Dutch and Brazilian Portuguese translations;
- preserve placeholder and terminology consistency;
- add validators and tests;
- identify missing translations and hardcoded strings;
- prepare per-feature localization changes.

Human review focuses on:

- Dutch tone of voice and product terminology;
- decisions about official or untranslated Pokémon terminology;
- visual quality at supported resolutions;
- native-speaker review and correction of Brazilian Portuguese;
- narrative quality for dialogue and story content.

## Recommended first implementation milestone

Implement phases 0 through 2 together:

1. Document conventions and classify text ownership.
2. Add the localization manager, locale persistence, catalogs, and fallback.
3. Add `en`, `nl`, and `pt-BR` language choices.
4. Fully localize login and settings.
5. Verify live switching and supported resolutions.

After this milestone, the architecture and contribution rules are established. Remaining
domains can then be migrated incrementally without adding further localization debt.
