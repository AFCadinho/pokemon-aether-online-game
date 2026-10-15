# Graphics quality Official Guide

Published as `adinho` in public **Official Guides** (category 13):
[Graphics Settings: Low, Medium, High & Ultra](https://forums.pokeaether.com/t/graphics-settings-low-medium-high-ultra/115).

The short English guide explains the four 3D battle quality presets, Android /
desktop differences, frame limits and when changes take effect. Technical terms
and resolution tables are deliberately omitted for accessibility.

`guide.md` is the exact published Markdown. `publication.json` records topic/post
IDs, author, category, saved-content SHA-256, rendered-table checks and anonymous
HTTP verification. Topic 115 already exists; do not recreate it.

The upcoming-update notice is intentional: the presets are present on local
`development` but absent from approved frontend `main` (`57dd7ae37`). Publishing
this guide does not release the client or activate performance telemetry.

Facts were checked against `scripts/services/android_quality_policy.gd`,
`battle_quality_policy.gd`, `settings_manager.gd`, the settings menu and
`docs/desktop-battle-quality.md` at frontend development `a09b8a3d6`.
The public category, active author, absence of a matching existing guide and
rendered Markdown were checked before publication. Discourse `PostCreator` ran
as the application user, with a same-title/content retry guard. No direct
database updates, forum settings changes or gameplay mutations were made.

Anonymous topic HTML and JSON both returned HTTP 200. The category, author,
four preset rows and upcoming notice match the reviewed text. The saved raw
content hash matches `guide.md`. Documentation-only checks were used; no game
code or assets changed and no full release certification was run.
