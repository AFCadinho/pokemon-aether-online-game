# PokeAether localization implementation plan

Status: in progress

Created: 2026-07-29

Initial locales: English (`en`), Dutch (`nl`), Brazilian Portuguese (`pt-BR`)

## Progress

| Phase | Status |
| --- | --- |
| Phase 0: inventory and conventions | Complete; see `localization_inventory.md` and `localization_conventions.md` |
| Phase 1: Godot localization foundation | Complete in commit `96be89e3a` |
| Phase 2: login and settings pilot | Complete in commit `96be89e3a` |
| Phase 3: automated guardrails | In progress; catalog, placeholder, fallback, persistence, and pilot layout checks are active |
| Phase 4: shared game interface | Complete; all 11 functional domains are migrated |
| Phase 5: battle localization | Complete; battle UI, dynamic events, timers, field state, results, and calculator are migrated |
| Phase 6: world signs and NPC dialogue | Complete; signs, Game Content dialogue, NPC display overlays, locale caches, and fallback are active |
| Phase 7: Pokémon and item content | Complete; full species, move, ability, and item presentation coverage is active |
| Phase 8: backend error contracts | Complete; stable codes, safe localization, diagnostics, and transport fallbacks are active |
| Phases 9-10 | Planned |

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

### Completion note

Phase 5 is complete on `feature/localization-foundation`.

- Battle controls, confirmations, spectator controls, result screens, reconnect
  messages, errors, field timers, side conditions, stat badges, hover cards, and the
  damage calculator resolve through the client catalogs.
- `BattleEventTextFormatter` renders move, switch, item, ability, status, damage,
  healing, weather, field-effect, transformation, and terminal sentences from named
  placeholders. Canonical protocol values are never translated.
- Runtime checks exercise the same components and representative event data in
  English, Dutch, and Brazilian Portuguese. Catalog parity and placeholder parity are
  enforced across all 1,802 keys.
- Live battle controls and current dynamic panels re-render immediately after a locale
  change without changing battle state, legal actions, or timers.

Temporary battle-log behavior: entries already appended to the log remain in the
language in which they were received because the current log stores rendered strings.
New entries and all live battle controls use the newly selected locale immediately.
Re-rendering historical entries requires retaining their structured event payloads and
can be added later without changing the authoritative battle protocol.

Canonical species, move, ability, item, nature, and type display data remains English
until the remaining Phase 7 overlays. Raw backend-provided error strings remain Phase
8 work; localized client fallbacks are already present.

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

### Completed implementation

- The current Pallet Town sign catalog is available in all three locales and validated
  for identical IDs. Sign lookup follows the global locale and falls back per sign to
  English.
- The Game Content service stores the current dialogue catalog under `en`, `nl`, and
  `pt-BR`, resolves `Accept-Language`, and falls back to English.
- NPC mechanics remain canonical and language-neutral. Locale overlays may replace
  only display names, inline dialogue, and display messages.
- Client dialogue and NPC caches are isolated by HTTP locale. NPC metadata is marked
  for safe reload after a runtime locale change, so the next interaction uses the new
  language.
- The gateway already forwards `Accept-Language`; its local end-to-end routes were
  verified for Dutch dialogue and Brazilian Portuguese NPC metadata.

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

The client-side item catalogs store presentation-only `name` and `shortDesc` fields.
Generated catalogs cover all 1,395 canonical items, while the 69-item reviewed pilot
loads afterward and overrides its draft entries. `ItemLocalization` resolves those
fields by canonical item ID, preserves the original English response as fallback, and
never copies quantity, price, ownership, effects, or other mechanics into an overlay.
Bag, hotbar, Market, Pokémon Summary, trade, mail, Aether Atelier, and Donator Store
item presentation share this resolver.

The shared `ContentLocalization` resolver now provides the same ID-first contract for
types, natures, species, moves, abilities, and statuses. The initial complete catalogs
cover all 18 types and 25 natures. Pokémon Summary, Pokédex, move learning, PC filters,
battle party hover, and the damage calculator resolve type and nature presentation
through this service while retaining canonical type and nature values internally.

The reviewed content slice covers all 65 moves and 20 abilities explicitly used by the
current Route 1 and Alpha Gym trainer rosters. English, Dutch, and Brazilian Portuguese
overlays provide names and short descriptions. Pokémon Summary, Pokédex move search,
PC filters, battle move slots, move hover cards, and Pokémon hover cards resolve these
presentation fields through the shared service. The catalogs contain no power,
accuracy, PP, type, category, or ability mechanics. Full local indexes (919 moves and
376 abilities) and all 1,439 species/forms now have generated presentation coverage.
Dutch and Brazilian Portuguese generated entries are review drafts; manually approved
overlays always take precedence. See `localization_content_review.md` for the guarded
generation and review workflow.

Statuses and effects use the structured `pokemon.status.*`, `battle.status.*`, and
`battle.event.status.*` keys completed in Phase 5. Shop and cosmetic titles/actions
use normal UI keys, while their item names and descriptions use `ItemLocalization`.
Remaining Pokémon presentation in bag actions, the hotbar, PC party slots, mail,
PvP preview, and trade uses the species resolver. Nicknames and player-generated
content remain unchanged.

Phase 7 is technically complete. Dutch and Brazilian Portuguese generated entries
remain review drafts; linguistic approval and final terminology choices are part of
the Phase 10 release gate rather than an architecture or consumer-coverage gap.

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

### Completed implementation

- `BackendErrorLocalization` extracts stable codes from top-level and nested gateway
  response shapes.
- Known player-facing account, Guild, trade, inventory, shop, appearance, mail,
  fishing, field-move, and reward codes map to localized messages in all three
  catalogs.
- All player-facing Godot HTTP services and both battle API clients use the shared
  resolver; background metadata-loader failures remain diagnostic-only.
- Unknown codes show a safe localized generic error and never expose raw backend text.
- English server messages remain available separately for logs and diagnostics.
- Connection, TLS, and timeout failures are localized through the same service.
- The account service preserves existing domain codes and normalizes legacy
  `HTTPException` strings to stable category codes without changing HTTP statuses.
- The complete contract and extension workflow are documented in
  `localization_error_contract.md`.

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

### Completed implementation

- The standalone launcher now uses the same `en`, `nl`, and `pt_BR` locale model,
  system-locale detection, normalization, and English catalog fallback as the game.
- Its language selector updates the interface immediately and persists the selection
  beside the existing install-directory preference.
- Static controls, actions, server presence, progress, download/extraction states,
  launcher self-update states, uninstall flows, tooltips, and player-facing failures
  are covered by complete launcher catalogs.
- Starting the game passes the validated launcher locale as a user argument. The game
  imports and persists this value through `SettingsManager`, keeping both projects in
  sync without sharing their separate Godot user-data files.
- Login and launcher news requests send `Accept-Language` with English as the requested
  fallback. Both consumers select translated news again immediately after a runtime
  language change.
- News remains compatible with the original English-only `items`/`articles` arrays.
  New feeds may add per-item `localizations` (or `translations`) keyed by `nl`,
  `pt-BR`, and `en`, or use top-level `locales` buckets. Missing translated fields
  inherit the English/base item.
- `launcher/config/news.example.json` documents the preferred per-item format.
- Dedicated launcher runtime checks and game-project integration checks validate
  locale behavior, catalog parity, placeholders, preference synchronization, request
  headers, translated news selection, and English fallback.

Phase 9 is technically complete. External websites, registration, credits, and legal
documents remain deliberately outside the game/launcher catalogs and require their own
content and legal review before release.

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
