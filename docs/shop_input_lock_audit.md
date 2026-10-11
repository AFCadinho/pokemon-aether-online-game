# Shop movement and interaction audit

All six registered shop catalogs and their frontend opening paths were checked.
The bug is the handoff from `BaseNPC._start_manual_interaction()` to UIOverlay:
`open_market()` activates its window while the legacy NPC input lock is still
held. The old tracker therefore acquired no window lock. The NPC then returned
and released its lock, allowing movement and another interaction with the shop
still visible.

| Storefront | Opening path | Finding and coverage |
| --- | --- | --- |
| Pokémart | MarketAttendantNPC → `open_market()` | Reproduced and fixed through the real popup opening path. |
| Item Buyer | Same popup, `player_sells` | Reproduced and fixed, including closing the sell window. |
| Evolution Item Seller | `evolution_item_shop` → same popup | Reproduced and fixed. |
| Mega Stone Seller | `mega_stone_shop` → same popup | Reproduced and fixed. |
| Z-Crystal Seller | `z_crystal_shop` → same popup | Reproduced and fixed. |
| Battle Point Vendor | `battle_point_exchange` → same popup | Reproduced and fixed. |
| Aether Gift Store | Toolbar → `open_store()` → `_activate_ui_panel()` | Uses the same vulnerable tracker; normally opens without an NPC lock. Tracker tested with an existing lock. |
| Guild Shop | Tab within `guild_popup`, activated by `_open_guild_popup()` | Protected by the Guild window tracker; overlapping lock tested. |
| Aether Exchange | Toolbar → `open_exchange()` → `_activate_ui_panel()` | Shared tracker tested with an existing lock. |
| Aether Atelier | NPC → `open_aether_atelier()` → `_activate_ui_panel()` | Same NPC handoff bug; shared tracker tested with an existing lock. |
| Pokémon/team rental | RentalNPC awaits `menu.finished` | Code review: NPC interaction stays active until the workspace closes, so no early handoff. |
| Magikarp salesman / Guild Base registrar | Await purchase confirmation and result | Code review: transaction remains within the active NPC interaction. |
| Shiny Mount Collector / Bike Voucher exchange | Await menus and exchange/dialogue | Code review: interaction remains active throughout. |

The tracker now acquires an independent, instance-specific scoped overworld
lock even when dialogue or an NPC already holds another lock. Closing, hiding
or destroying the last tracked window releases only that scope. UI controls
remain usable. Overlay teardown also releases its scope. Other scoped story and
teleport locks remain owned by their callers. Staff teleport may ignore its own
window lock only if no other scoped owner or window is active.

`tests/shop_modal_input_lock_check.gd` reproduces the old NPC handoff failure,
then checks every NPC market ID, buying and selling, the real player/NPC input
guards, shared storefront tracking, overlapping windows, hide/destruction,
story lock ownership, staff teleport bypass and overlay cleanup. It is included
in the project check list. Backend catalog and transaction logic are unchanged;
these checks use local UI fixtures and do not make live purchases.
