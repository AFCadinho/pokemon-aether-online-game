# PokeAether localization inventory

Status: active migration inventory

Baseline commit: `96be89e3a`

Date: 2026-07-29

Initial locales: English (`en`), Dutch (`nl`), Brazilian Portuguese (`pt-BR`)

## Purpose

This inventory records where player-visible text currently comes from, who owns each
category, and how it will be migrated. It is a migration baseline, not a claim that
every candidate occurrence is translatable: source scans also find empty values,
numbers, symbols, preview data, and internal diagnostics.

The English catalog is canonical. Dutch and Brazilian Portuguese must contain the same
keys and placeholders.

## Current baseline

The login/settings pilot and all eleven shared-interface slices are complete. The
three client catalogs currently contain 1,402 matching keys. Language selection is
available before login and in the shared settings menu, is stored locally, updates at
runtime, and falls back to English.

Completed client domains:

- login and settings;
- loading, main navigation, location, time, and weather;
- Party slots and Pokémon Summary interface chrome, including runtime status, EV,
  move-order, Poké Ball, and held-item messages;
- Bag and hotbar interface chrome, including categories, search and empty states,
  item-action flows, local medicine previews, Escape Rope interactions, and runtime
  refresh;
- Market and standard shop buy/sell flows;
- Pokédex interface chrome and mail composition, attachments, rules, and statuses;
- Friends, nearby-player, Guild, and player-trading interfaces;
- Aether Store and Aether Atelier, including item-overlay presentation and localized
  search;
- Alpha, developer, and relevant staff interfaces, including account impersonation,
  staff teleport, item/currency tools, and Trainer Progress;
- canonical-ID item display overlays for 69 currently player-facing items, covering
  the standard PokéMart, virtual and legacy Escape Rope, fishing rods, field Charms,
  Aether Blessing vouchers, Trainer-service tickets, Guild emblems, and current
  Store cosmetics.

Pokémon, move, ability, nature, and type display data remain in their canonical English
data sources until their Pokémon Data overlay slices. Items outside the current
69-entry player-facing catalog safely retain the English name and description supplied
by their authoritative source.

The remaining localization surface is concentrated in later phases:

| Source | Baseline | Meaning |
| --- | ---: | --- |
| Godot scene text properties | 302 occurrences | `text`, placeholder, tooltip, title, or description properties |
| Scene properties already using localization keys | 50 occurrences | Primarily login and settings |
| Scene candidates still requiring classification | 252 occurrences | Includes real text and intentional values such as numbers and symbols |
| Direct GDScript UI-text candidates | 1,225 occurrences | Literal assignments, option labels, and direct message calls |
| Existing `LocalizationManager.text/plural` calls | 31 calls | Login and settings dynamic text |
| Raw backend `error/detail/message` reads | 264 occurrences | Includes diagnostics and text that currently reaches players |
| Directly player-visible backend-message candidates | 73 occurrences | Status labels, dialogs, chat system messages, and error helpers |
| Launcher scene and script candidates | 68 occurrences | 39 scene properties and 29 script assignments |
| Local English world-sign files | 1 file / 3 signs | Pallet Town is the current local sign-content pilot |
| Local Pokémon data indexes | 919 moves / 376 abilities | English display names and descriptions mixed with mechanical data |

These counts are deliberately called *candidates*. They are useful for tracking the
surface and spotting new debt, but catalog keys—not raw occurrence counts—will be the
release completeness metric.

## Text ownership

| Category | Current source | Owner after migration | Treatment |
| --- | --- | --- | --- |
| Login, settings, shared controls | Scenes and GDScript | Client catalogs | Semantic `ui.*` and `common.*` keys |
| General UI and navigation | `ui_overlay.tscn`, `ui_overlay.gd`, standalone UI scripts | Client catalogs | Migrate one functional domain at a time |
| Battle UI and event sentences | Battle scenes, `battle.gd`, event formatter | Client catalogs | Full-sentence templates with named placeholders |
| Local system notifications | UI and world scripts | Client catalogs | `notification.*` or domain-specific `ui.*` keys |
| Known backend failures | Service responses rendered by UI | Client error catalog | Stable server code mapped to `error.<domain>.<code>` |
| Unknown backend failures | Raw server response | Client generic fallback | Never expose technical payloads; log diagnostics separately |
| NPC dialogue | Game Content `/dialogues` endpoint | Game Content locale directories | Request by locale and cache by `(locale, dialogue_id)` |
| NPC display metadata | Game Content `/npcs` and local NPC resources | Game Content or client overlay | Keep NPC IDs stable; localize display fields |
| World signs | `data/world_text/signs/en` | Locale-specific sign files | Same sign IDs in every locale with English fallback |
| Species, moves, abilities, items, natures, types | Local indexes and API display data | Pokémon Data overlays | Resolve translated display fields by canonical ID |
| Shops and cosmetics | API data and client fallback text | Pokémon Data/shop overlays plus client UI catalog | Prices and inventory IDs remain language-neutral |
| Launcher interface | Separate `launcher` Godot project | Launcher catalogs | Same locale model and fallback as the game |
| Login and launcher news | Remote English JSON | Localized news source | Select by locale; fall back to English entries |
| Player chat, mail bodies, names, guild names/descriptions | Player-generated/server data | Player | Intentionally never machine-translated |

## Client hotspots

The scanner found the following largest direct-text hotspots. The counts are candidate
occurrences and include some intentional non-language values.

### Scenes

| File | Candidates |
| --- | ---: |
| `scenes/interface/ui_overlay.tscn` | 99 |
| `scenes/battle/party_hover_card.tscn` | 34 |
| `scenes/battle/battle.tscn` | 24 |
| `scenes/battle/pokemon_hover_card.tscn` | 21 |
| `scenes/interface/hotkey_sidebar.tscn` | 16 |
| `scenes/battle/move_hover_card.tscn` | 8 |
| `scenes/battle/vs_panel_container.tscn` | 7 |

### Scripts

| File | Candidates |
| --- | ---: |
| `scripts/ui/ui_overlay.gd` | 745 |
| `scripts/ui/trade_workspace.gd` | 76 |
| `scripts/ui/guild_popup.gd` | 55 |
| `scripts/ui/donator_store_popup.gd` | 54 |
| `scripts/ui/aether_atelier_popup.gd` | 52 |
| `scripts/ui/friendlist_popup.gd` | 44 |
| `scripts/battle/battle.gd` | 33 |
| `scripts/ui/player_interaction_coordinator.gd` | 23 |
| `scripts/ui/trade_invitation_dialog.gd` | 15 |
| `scripts/ui/fishing_action_controller.gd` | 12 |

`ui_overlay.gd` is over 33,000 lines and owns many unrelated interfaces. It must never
be bulk-rewritten as one localization change. Each contained domain receives its own
catalog prefix, tests, review, and commit.

## Server-owned content findings

- `GatewayApiConfig` currently sends JSON accept/content headers but no
  `Accept-Language`.
- `DialogueMetadataService` caches only by dialogue ID.
- NPC and dialogue normalization accepts English display strings and dialogue arrays
  directly from the server.
- Multiple UI flows display raw `error`, `detail`, or `message` fields.
- Local sign content currently exists only under `signs/en`.
- Login news is English-only remote content and correctly remains English during the
  client pilot.

These are cross-repository contracts. Client header support can be prepared locally,
but locale-aware server responses and stable error codes require corresponding backend
and Game Content work before they can be considered complete.

## Pokémon data findings

- `move_summary_index.json` contains 919 English move names and descriptions alongside
  mechanical fields.
- `ability_summary_index.json` contains 376 English ability names and descriptions
  alongside mechanical fields.
- Species, item, market, cosmetic, Pokédex, and shop responses also carry display text
  from APIs.
- Several client helpers currently turn canonical IDs into title-cased English. This is
  acceptable only as an English diagnostic fallback, not as localized display data.

Localized overlays must be keyed by canonical IDs. Mechanical values such as type IDs,
power, accuracy, PP, price, quantity, ownership, and effects remain in the authoritative
base data.

## Intentional exclusions

The following strings are not translation debt:

- resource paths, URLs, node paths, environment-variable names, and HTTP headers;
- API routes, JSON field names, protocol event names, enum values, canonical IDs, and
  save-data keys;
- log messages, assertions, test descriptions, developer diagnostics, and stack-facing
  errors that are never displayed to a player;
- player names, usernames, guild names/descriptions, chat, private messages, and mail
  subject/body content;
- numeric values, percentages, keyboard shortcuts, currency symbols, gender/status
  abbreviations, and decorative glyphs when they have no linguistic meaning;
- PokeAether/Aether branding and approved character, species, and product proper names.

An exclusion stops being valid if the same string is passed to a player-visible label,
dialog, tooltip, chat system message, or notification.

## Migration order

1. Add automated hardcoded-text guardrails with an explicit baseline/allowlist.
2. Migrate common controls, loading, main navigation, action-bar tooltips, and general
   system notifications.
3. Split `ui_overlay.gd` work into party/summary, bag/hotbar, market/shops, Pokédex,
   mail, social, guild, trade, Store/Atelier, and staff/developer slices.
4. Migrate standalone UI components alongside their owning domain.
5. Localize battle UI and then structured battle-event presentation.
6. Add locale-aware signs, NPC dialogue, and NPC display metadata.
7. Add Pokémon Data locale overlays and localized search.
8. Replace raw backend messages with stable error-code mappings.
9. Localize the launcher and add locale-aware news.
10. Run the complete release gate in all locales and supported resolutions.

## Completed battle slice

Phase 5 now covers battle menus, action labels, timers, result screens, status and
field presentation, the damage calculator, and structured battle-event templates.
Runtime checks cover English, Dutch, and Brazilian Portuguese. Historical battle-log
lines retain their original render language temporarily; new lines and live controls
switch immediately.

## Next implementation slice

The next recommended slice is Phase 6:

- locale-aware world sign files with stable sign IDs and English fallback;
- locale-aware NPC dialogue and display metadata requests;
- cache isolation by locale and runtime refresh behavior;
- validation that missing localized content never blocks interaction or gameplay.

Canonical move, ability, species, nature, and type display data remain English until
their remaining Phase 7 overlays. Raw backend errors remain outside the battle slice
and are handled through stable error-code mappings in Phase 8.
