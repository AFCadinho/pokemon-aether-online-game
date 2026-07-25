# Changelog

- Bag-items now open a context-aware action menu with a right-click. Depending on the item, you can use or open it, move it to Character Customization, redeem it, or assign it to the hotbar.
- Name Change Tickets now let Trainers update both their username and display name; previous usernames stay reserved to prevent impersonation.
- Gender Chance Tickets now safely return every unlocked cosmetic to the Bag before changing gender, then reset the Trainer to the appropriate default appearance.
- Aether Gift Store cosmetic previews now keep the Trainer in a neutral default top and bottom, while the item being considered replaces the matching appearance part.
- Renamed Aether Membership to Aether Blessing and added tradeable 3, 7, 14, and 30-day vouchers to the Aether Gift Store. Each duration has a dedicated colour-coded 48x48 pixel-art icon. Vouchers remain in the Bag until redeemed; redeemed time stacks, appears with a live countdown in personal buffs, and unlocks the optional `Blessed` Trainer Card title for chat only until expiry.
- Renamed the player-facing Aether Store to Aether Gift Store.
- Adinho Classic Sunglasses are now gender-neutral and render on both male and female character models; the rest of the Adinho Classic outfit remains male-only.
- Trainer Services now contains only the Name Change Ticket and Gender Chance Ticket, each with a dedicated transparent pixel-art item icon.
- The Adinho Classic Store product is now a tradeable six-item box. Opening it in the Bag grants separate Hair, Beard, Sunglasses, Shirt, Trousers and Shoes cosmetics, which can each be moved to or returned from Character Customization independently.
- Character Customization now shows the active paid-cosmetic count per component and respects the server-authoritative limit of eight; starter options, `None`, and colour choices do not consume space.
- Added the male-only Adinho Classic outfit box alongside separate male-only, colour-customizable hair, beard, glasses, shirt, trousers and shoes products; Store purchases and wardrobe use enforce character-model compatibility, and equipping hair immediately refreshes its linked eyebrows in the overworld.
- Tradeable cosmetic Bag items can now be moved into Character Customization and returned to the Bag later; active wardrobe items themselves cannot be traded.
- Aether Gems now have a durable wallet balance, and the seven available Adinho cosmetics can be purchased through a server-authoritative, replay-safe checkout that adds the tradeable box directly to the Bag.
- The nine implemented field and weather Charms shown in the Aether Store are now purchasable permanent, stackable and tradeable Bag items in their own Charms category; gameplay reset preserves them.
- The Trainer Card now includes a Wallet tab for Pokédollars and Aether Gems, ready to accommodate future gameplay currencies when they are introduced.
- The Aether Store can now preview cosmetics on the player's current trainer from the front, sides, and back, with temporary colour choices for grayscale items.
- Character Customization now shares expanded Hair and Chroma palettes with the Store preview, offers custom Hair and Chroma colours, and includes the original Default skin plus twelve curated skin tones without recolouring body outlines or clothing details.
- Adinho cosmetic products now reuse a single front-facing spritesheet frame as their shared Store and Bag icon.
- Legacy Tan and Dark body selections now migrate to the matching skin tone on the standard body model.

## 0.3.31 - 2026-07-23

**Added**
- Added a Map chat tab for nearby conversations, with messages briefly appearing above each speaking trainer.
- Added new battle animations for Pyro Ball, Court Change, High Jump Kick, Sparkling Aria, Draining Kiss, Psychic Noise, Grassy Glide, Wood Hammer, Drain Punch, Superpower, Psychic Terrain, Grassy Terrain, Electric Terrain, and Misty Terrain.
- Psychic, Grassy, Electric, and Misty Terrain now have their own animated battlefield effects that remain visible while active.
- Added chat settings for choosing which main chat tabs are visible and changing their order.
- Added early previews for the upcoming Quest Log, Aether Store, Redeem Codes, server-wide and personal buffs, and Clan chat. These features are not fully active yet.

**Changed**
- Added a dedicated All chat tab that combines every available channel, while General now opens Global by default and keeps Global, Trade, and Help as subchannels.
- Reorganized the overworld interface so the Party and chat sit on the left, while the hotbar and Trainer Card sit on the right. Party Pokémon remain clickable during battles so their summaries can still be opened.
- The Battle UI now opens slightly farther to the right, leaving more room for the Party list and making the Battle Log button easier to spot.
- Refreshed the Party list, Trainer Card, chatbox, menus, and navigation icons with a cleaner and more consistent style.
- Shiny Pokémon now stand out more clearly in the Party list.
- Terrain effects now use stronger colors and more visible particles across the battlefield.

**Fixed**
- Fixed Map chat messages appearing in the chatbox without showing a speech bubble above the speaking trainer.
- Fixed some Ranked battles getting stuck after an opponent timed out, disconnected, or when a battle update arrived late.
- Fixed moves such as Chilly Reception sometimes locking the battle controls before a replacement Pokémon could be chosen.
- Fixed Team Preview and switch menus occasionally selecting a different Pokémon than the one clicked.
- Weather-ending messages now correctly name the weather that stopped.

## 0.3.30 - 2026-07-22

**Added**
- Added battle animations for more than 50 moves, including multi-turn moves, delayed effects, protection interactions, switching attacks, and a persistent Substitute presentation.

**Changed**
- Battle screens now clearly show Run in wild battles and Forfeit in trainer and Ranked battles.
- Refreshed and polished many existing move animations, including their timing, sizing, effects, sounds, backgrounds, and impact presentation.
- Battle move animations now follow the live attacker and target positions and correctly mirror when used by the opposing Pokemon.
- Refreshed the standard healing and stat-change effects used by moves, items, abilities, and held items.
- Refined the battle utility bar with clearer contextual Bag, Run, and Forfeit actions and improved hover feedback.
- Improved compact battle party previews with clearer borders, larger Pokemon icons, and more readable fainted states.
- Move buttons now visibly dim and stop showing hover details while waiting for the opponent after submitting a PvP choice.

**Fixed**
- Fixed the PvP result overlay sometimes showing Defeat for the winning player when the server identified the winner by trainer name.
- Fixed several opposing move animations travelling from the player's side, using inverted vertical offsets, or appearing on the wrong Pokemon.
- Fixed Kowtow Cleave slicing its source spritesheet at the wrong size, which made its impact animation almost invisible.

## 0.3.22 - 2026-07-20

**Fixed**
- Fixed same-turn Ranked updates restoring an older active Pokemon during a forced switch, which could hide the fainted Pokemon and disable a valid replacement.

## 0.3.21 - 2026-07-20

**Fixed**
- Fixed Ranked battles sometimes applying Pursuit damage to the wrong Pokemon during a switch.
- Fixed a Pokemon briefly appearing as the wrong active Pokemon when it switched in and fainted during the same turn.

## 0.3.20 - 2026-07-20

**Fixed**
- Fixed damaged or fainted Pokemon sometimes appearing healed again during Ranked battles.
- Fixed a previously active Pokemon sometimes being unavailable when choosing a replacement after a faint.

## 0.3.19 - 2026-07-20

**Fixed**
- Fixed a fainted Pokemon sometimes appearing selectable again after Pursuit interrupted its switch.
- Fixed a Ranked battle sometimes ending as a server error when a replacement Pokemon was chosen between turns.

## 0.3.17 - 2026-07-19

**Fixed**
- Fixed Windows launcher updates failing when Windows briefly kept a launcher file locked after shutdown.

## 0.3.15 - 2026-07-19

**Fixed**
- Fixed the Windows launcher updater waiting indefinitely after the launcher window closed.

## 0.3.14 - 2026-07-19

**Changed**
- The launcher sidebar now uses a clearer Credits label and shows the expected hand cursor when hovering it.

## 0.3.13 - 2026-07-18

**Changed**
- Ranked battle updates now appear more quickly after both players make a choice.

**Fixed**
- Fixed the Windows launcher closing without applying or restarting after downloading a launcher update.
- Fixed a Ranked switch sometimes appearing for the opponent but not for the player who switched.
- If a Ranked choice was made from an outdated screen, the battle now refreshes to the current Pokemon and lets the player choose again.

## 0.3.12 - 2026-07-18

**Changed**
- The launcher now fits its sidebar, status information, news, and action buttons more neatly inside the window.

## 0.3.11 - 2026-07-18

**Fixed**
- Fixed Ranked battles showing fainted Pokemon as available again, rejecting moves after the battle advanced, or leaving a player stuck after a timeout result.

## 0.3.10 - 2026-07-18

**Changed**
- Refreshed the launcher sidebar with clearer navigation, a full Discord button, and a more compact server status card.

## 0.3.9 - 2026-07-18

**Fixed**
- Fixed Ranked battles getting stuck after a Pokemon fainted, including manual and automatic replacement choices.
- Fixed long Ranked battles unexpectedly disconnecting both players while battle updates were being received.
- Fixed game-only releases removing the information launchers need to discover launcher updates.

## 0.3.6 - 2026-07-17

**Added**
- Ranked Battle History now shows a Battle ID that can be copied when reporting a problem.
- Footprints now briefly appear behind you while walking on sandy paths.
- Certain trees and cracked rocks can now be cleared with Cut and Rock Smash.
- You can teach Cut from the Bag, choose which move to replace, and use a Pokemon that knows Cut in the overworld.
- Field Move Charms have been added for Cut, Defog, Dive, Flash, Rock Climb, Rock Smash, Strength, Surf, Waterfall, and Whirlpool. Supported field actions can use a Charm instead of a Pokemon move.
- Field Move Charms now have their own item icons.
- Pewter City now has working exits to surrounding areas.
- Moving between maps now uses a smooth fade and loading indicator.
- The overworld now has a shared day and night cycle, including gradual dawn and dusk lighting and illuminated windows and lanterns at night.
- Moves can now be reordered by dragging them in a Pokemon's Summary.
- Flash can now be activated directly from a Pokemon's Summary or by using the Flash Charm from the Bag.
- Pokemon field moves and Field Move Charms can now be assigned to the hotbar.
- Flash creates a large light around the player in dark areas and at night.
- Rain and snow can now appear naturally in the overworld, with seasonal snow during winter.
- Indoor areas such as Oak's Lab stay clear and are not affected by outdoor weather.
- Players on the same map now see the same time of day and weather.
- Rain Dance, Snowscape, and Sunny Day can now change the current map's weather when used from a Pokemon Summary, Charm, or hotbar slot.
- You can now open another player's Trainer Card from the player list or by right-clicking that player.

**Changed**
- Trees and rocks on Route 2 and in Viridian Forest now block movement more reliably until they are cleared.
- Surf now requires the Surf unlock and either a party Pokemon that knows Surf or a Surf Charm.
- Cut, Rock Smash, and Surf now show a short system message instead of opening a dialogue window after use.
- When using a TM or HM, the Bag now shows Pokemon icons and only lists party members that can learn the move.
- TM and HM icons now match their move type. The Item Dex also shows whether a machine is a TM or HM and which type it belongs to.
- Pokemon Summary only shows the overworld-use button on moves that can be activated directly.
- Weather changed by a player lasts ten minutes for everyone on the map. These weather changes have a shared thirty-minute cooldown.
- The mini Trainer Card, full Trainer Card, and Appearance tab have been refreshed with cleaner layouts and better avatar presentation.
- The location card is now smaller and easier to read, with the region badge and radar placed more clearly.
- Hotbar slots have updated styling and now react when hovered.
- Battle party slots now use a neutral color, making active and fainted Pokemon easier to recognize. Move buttons now use the move's type color instead.
- The floating `SWITCH` label has been removed from the battle interface for a cleaner layout.

**Fixed**
- Fixed the second player in a Ranked battle being unable to confirm a lead, move, or switch and eventually timing out.
- Fixed some compatible Pokemon not appearing when choosing who should learn an HM.
- Fixed missing TM and HM icons and move-type information in the Item Dex. Machine items no longer show an incorrect empty effect label.
- Fixed some map exits becoming unusable after arriving on top of an exit trigger, including the return from Route 2 to Pewter City.
- Fixed dragged Summary moves appearing behind the Summary window. Dropping a move outside the list now safely restores its previous position.
- Fixed rain and snow sometimes appearing behind buildings and other map objects.
- Fixed the collapse button beside the location card being positioned incorrectly.
- Pokemon created through developer or content creator tools now receive the neutral Hardy Nature when no Nature is selected.

## 0.3.5 - 2026-07-16

**Added**
- Added a saved-trainer login view with trainer profile preview, session status, and a direct Continue flow.
- Added server-synchronized PvP decision timers for both players during Team Preview, move selection, forced switches, waiting states, and reconnect grace periods.
- Added PvP choice confirmations that show the selected lead, move, or incoming switch while waiting for the opponent.

**Changed**
- Redesigned the login screen with a blue Aether-themed layout, responsive news panel, improved login and saved-session cards, atmospheric login glow, and clearer Remember Me controls.
- Refreshed the launcher with a blue Aether-themed layout, improved spacing, and clearer server status, update progress, and news panels.
- PvP timers now show the current decision time instead of exposing the underlying bank, interpolate from server anchors without per-second events, and freeze at the submitted value while waiting.
- Repositioned the PvP timer panels and opponent HUD so names, health, stat changes, sprites, and battlefield animations remain readable.

**Fixed**
- Fixed news articles not loading in the launcher and login screen when the news feed returns its `articles` collection.
- Fixed returning from Settings to the login screen ending the saved session and forcing a full username/password login despite Remember Me being enabled.
- Fixed one player's PvP timer continuing after submitting a move or switch, timers resuming while an opponent was still disconnected, and reconnect countdowns disappearing behind normal turn timers.
- Fixed PvP Team Preview occasionally waiting twelve seconds after both leads were selected by keeping correlated lead responses on the realtime action path.
- Fixed automatic lead selection and timeout-forfeit results not reaching both clients consistently, including stale Team Preview screens and missing winner names.
- Fixed repeated and simultaneous disconnect flows so reconnect state remains visible and battles do not resume until both players are connected.
- Fixed both PvP clients showing different remaining decision times after reconnect; timers now resume from the same refreshed server deadline.

## 0.3.4 - 2026-07-12

**Added**
- Added overworld use for Potion, Super Potion, Hyper Potion, Max Potion, Full Restore, Antidote, Burn Heal, Ice Heal, Awakening, Paralyze Heal, Full Heal, and Revive. Select a party Pokemon from the Bag to preview and apply the effect.
- Added a permanent Escape Rope Key Item. It returns you to your latest healing point without healing your party and has a 30-minute cooldown that continues while you are offline.
- Added an eight-slot hotbar on the left side of the screen. Drag usable Bag items into a chosen slot and activate them by clicking or pressing keys 1–8.
- Added hotbar item counts, unavailable-item states, highlighted drop targets, slot clearing with right-click, and drag-and-drop swapping between hotbar slots.
- Added client-side map sign interactions for small and large overworld signs, including local sign text loading, Pallet Town sign placements, text-only dialogue presentation, and validation checks for sign content and scene references.
- Added Player Trade. You can request a nearby player, exchange Pokemon, item stacks, and money, then review and confirm the exact exchange together.
- Added live trade invitations, incoming-request notifications, reconnection recovery, and clear system messages for Pokemon and item transfers.
- Added draggable trade, invitation, and Pokemon-summary windows so you can arrange them around the game screen.
- Added a searchable item picker for quickly finding tradable inventory items and choosing their quantities.

**Changed**
- Redesigned the battle UI for a more competitive experience with a persistent battle log, a wider battlefield, compact HP HUDs, direct six-Pokemon switching, two-by-two move controls, contextual mechanic buttons, and separate Bag and Damage Calculator panels.
- Battle windows now use a compact in-world layout instead of covering the full screen. During PvP, chat and other overworld UI panels remain usable and move above or below the battle UI based on the most recently clicked interface.
- Escape Rope is now used exclusively from the configurable hotbar instead of the action bar or legacy inventory stacks.
- The standard PokéMart now focuses on currently usable Poké Balls and medicines. Escape Rope, Repel, Super Repel, and Max Repel are no longer sold there; existing owned stacks remain in the Bag.
- Stored EVs can now only be assigned to their matching stat. For example, stored Speed EVs can no longer be spent on Sp. Def.
- Trade offers now use Pokemon from your current party. Drag a party slot into your offer, click an offered Pokemon to inspect its summary, and keep at least one Pokemon in your party.
- Redesigned the trade workspace with compact Pokemon slots, player names above each offer, clearer money controls, improved invitation screens, and consistent button hover feedback.
- Trade completion now refreshes your party immediately and closes the workspace once the transfer is complete.

**Fixed**
- Reduced the delay before Mega Evolution by preloading its battle effect, prewarming and caching available Mega-form sprites, and showing immediate feedback while waiting for server confirmation.
- Fixed Pokemon sometimes receiving EVs but not keeping earned EXP after defeating a wild Pokemon.
- Fixed EXP bars not updating after battle rewards and added clear system messages showing how much EXP each Pokemon earned.
- Fixed Escape Rope confirmation and cooldown feedback being inconsistent, and updated its confirmation window to match the game UI.
- Fixed cleared hotbar slots restoring Escape Rope automatically and fixed dragged item icons appearing behind the hotbar.
- Improved trade invitation delivery and state recovery so new invitations, acceptances, offers, readiness, and completed trades stay in sync for both players.
- Fixed trade offers occasionally reverting, appearing late for the other player, or showing stale trade-state errors after quick updates.
- Fixed money offers resetting while typing or not appearing consistently in the shared offer and final review.

## 0.3.3 - 2026-07-10

**Added**
- Added Route 1 visual depth, generated map visuals, tall-grass rustle effects, and water ripple effects.
- Added styled overworld nameplates for the player, remote players, and NPCs.
- Added route and door transition hint scenes for clearer overworld exits.
- Added dialogue metadata loading from the game-content service.
- Added overworld Pokemon NPC support, metadata loading, collision blocking, and Route 1/Pallet Town overworld Pokemon placements.
- Added boss battle NPC support with difficulty selection.
- Added Trainer Red as a Pallet Town boss battle with Easy, Medium, and Hard teams, dialogue, mugshot, and reward content.
- Added market attendant NPC support, a market service client, and the first market UI flow.
- Added backend game-content routes for NPCs, dialogues, and overworld Pokemon.
- Added backend account-service support for standard market purchases and shop item source validation.

**Changed**
- Improved NPC metadata, trainer metadata, dialogue fallback handling, and overworld interaction validation.
- Updated trainer repository handling and trainer metadata tests for the expanded Trainer Red content.
- Improved market UI integration in the main overlay and Pallet Town scene.
- Cleaned up overworld NPC sprite assets and migrated to the newer official overworld sprite pack.

**Fixed**
- Fixed Trainer Red's boss battle difficulty overlay blocking clicks in team preview and battle UI after the difficulty choice.
- Fixed trainer team-preview lead selection staying locked or showing unusable party slots when saved HP data was missing.
- Fixed party slot HP parsing for battle payloads that include stats or conditions but no explicit `hp` field.
- Fixed local dialogue validation for Pallet Town Trainer Red dialogue references.
- Fixed backend Pokemon box handling around market and trainer content updates.

## 0.3.1 - 2026-07-08

**Added**
- Added updated Kanto map visuals, teleport catalog data, and Pallet Town door-opening visuals.
- Added a Heal NPC that can restore your party from the overworld.
- Added a Nurse mugshot for Heal NPC dialogue.
- Added persistent heal-point respawns for wild and NPC battle losses.
- Added a minimized Ranked queue panel so players can keep playing while waiting in queue.
- Added a Ranked match-found countdown banner with a notification sound and short screen-dim warning before PvP starts.
- Added battle animations for Spikes, Toxic Spikes, Sticky Web, Reflect, Light Screen, Aurora Veil, Thunder Wave, Toxic, Will-O-Wisp, Blizzard, Spore, Hurricane, Taunt, and Encore.
- Added improved custom Flamethrower visuals and tuned imported move animation sizing/positioning.
- Added battlefield side-effect visuals for Stealth Rock, Spikes, Toxic Spikes, Sticky Web, Reflect, Light Screen, and Aurora Veil.
- Added continuous status condition animations for paralysis, poison, badly poison, burn, freeze, and sleep.
- Added confusion, Taunt, and Encore volatile badges above battle sprites, including turn counts where available.
- Added status icon badges to the battle HUD, normal party slots, and Pokemon summary cards.
- Added persistence for non-PvP party status conditions so poisoned, burned, paralyzed, asleep, and frozen Pokemon keep their condition across wild and NPC battles.

**Changed**
- Party healing now uses the same reusable healing flow across NPCs and developer tools.
- Heal NPCs now store the player's last heal point for future blackout respawns.
- Ranked queue close/minimize behavior is now explicit: minimizing keeps the queue active, while closing or logging out leaves the queue unless a match has already been found.
- PvP now prepares teams by healing the current party before joining a PvP room or ranked queue, and heals the party again after PvP ends.
- If a Ranked match starts while the player is in a wild or NPC battle, the PvE battle is forfeited and cleaned up before PvP opens.
- Battle status presentation now separates one-time move animations, continuous status overlays, and end-of-turn residual status damage animations.
- Taunt, Encore, and confusion presentation now follows the same above-sprite badge style as stat-stage changes instead of using compact abbreviations.
- Creator-generated Pokemon can now use holdable berries where appropriate.

**Fixed**
- Fixed the developer Clear Party tool only clearing the local UI, which could make the cleared party reappear and send newly generated Pokemon to PC storage.
- Blackout respawns now heal the party and no longer let fainted battle state overwrite the healed party.
- Fixed players remaining queued after closing the Ranked menu.
- Fixed matched Ranked players getting stuck when the opponent closed the Ranked interface before battle start.
- Fixed Ranked match-found overlays blocking wild battle actions during the countdown.
- Fixed stale matched queue state after forfeiting or reconnecting to a previous Ranked match.
- Fixed Ranked validation being reset by the pre-queue party heal, which could show `Ranked Ready` while join still failed.
- Fixed PvP battle damage being written back to the overworld party after PvP ends.
- Fixed the active player party sometimes staying damaged in the UI after a PvP forfeit before the server heal response finished.
- Fixed lead Booster Energy activations not showing their battle log text, battle text, or Quark Drive/Protosynthesis stat badge before turn one.
- Fixed hazard switch-in damage logs and HP deltas being merged with following attack damage.
- Fixed Stealth Rock field markers appearing too transparent or too far from the affected side.
- Fixed party held item markers drawing above other UI layers.
- Fixed badly poisoned Pokemon losing their `tox` state when a new wild or NPC battle started.
- Fixed saved status conditions being shown in the client but not restored inside Showdown battle logic at battle start.
- Fixed poison and burn residual animations replaying during normal attack damage on already-statused targets.
- Fixed the summary card missing the Pokemon's current status condition.

## 0.3.0 - 2026-07-06

**Added**
- Added PC Boxes. You can now open the PC from a physical PC in the overworld and manage your Pokemon storage from there.
- Added drag-and-drop support for PC Boxes. Move Pokemon between box slots and party slots by dragging them.
- Added PC search. You can find Pokemon by name, type, ability, or held item across your boxes.
- Added Pokemon release support from the PC, with a confirmation warning before a Pokemon is released permanently.
- Added held item markers to party slots so you can quickly see when a Pokemon is holding an item.
- Added new battle move animations for Earthquake, Knock Off, Focus Blast, U-turn, Flip Turn, Stealth Rock, and Rapid Spin.

**Changed**
- Battles should feel smoother, with cleaner timing and more responsive battle presentation.
- PC Boxes now use clearer box tabs, improved slot visuals, draggable windows, and type-colored box slots.
- Pokemon summaries can now be opened from PC slots by clicking a Pokemon.

**Fixed**
- Improved several battle presentation issues around switching, HP updates, fainted Pokemon, and battle startup visuals.

## 0.2.9 - 2026-07-03

**Added**
- Added the first real overworld map: Pallet Town.
- Added complete Pokedex move tabs for level-up, egg, TM, tutor, special, event, legacy, legacy event, and pre-evolution moves.
- Added move search to the Pokedex moves tab.

**Changed**
- Improved Pokedex move section headers so learnset groups are easier to scan.

## 0.2.7 - 2026-07-03

**Added**
- Added the new Friend List interface with friend search, friend requests, blocking, status messages, and last-seen information.
- Added buttons to message or mail friends directly from the Friend List.
- Added friend request alerts with a red badge and notification sound.
- Added private messages through the chat tab, including unread badges and clearer active conversation styling.
- Added `/pm username` to start a private message with an online player.
- Added Pokemon sharing in private messages through `/team` or by dragging Pokemon into chat.
- Added a Help chat tab with a 5 minute cooldown.
- Added Ranked PvP tabs for Play, Rules, Bans, Live, Leaderboard, and History.
- Added Aether OU ranked details, banlist visibility, and leaderboard filters for Daily, Weekly, Monthly, and All Time.

**Changed**
- Improved the Friend List layout, spacing, colors, buttons, and confirmation prompts.
- Offline friends can no longer be opened through the Friend List message button.
- Private messages now stay realtime-only and are easier to follow visually.
- Improved the Ranked PvP interface with a draggable window, better tab spacing, clearer team previews, and more readable validation messages.
- Reordered the top-left options row to Bag, Socials, Aether Exchange, Clan, PvP Interface, and Settings.
- Updated the Aether Exchange icon.
- Improved chat tab positioning and hover behavior on Ranked PvP tabs.

**Fixed**
- Fixed private messages sometimes failing to open for players outside your Friend List.
- Fixed private messages not always showing shared Pokemon correctly.
- Fixed the return-to-login confirmation appearing behind the Settings menu.
- Fixed several Friend List and chat alignment issues.

## 0.2.6 - 2026-07-01

**Added**
- Added interactable road signs in the overworld.
- Added wild location information to the Pokédex so catchable Pokémon show where they can be found.
- Added rarity labels to Pokédex wild locations instead of raw encounter chances.

**Fixed**
- Fixed normal UI party slots resizing on hover while keeping the hover state visually clear.
- Fixed Pokemon summaries showing the current trainer as OT after receiving a Pokemon through mail.
- Fixed read-only Pokemon summary previews showing the viewer as the current trainer in mail and chat.
- Fixed Escape opening settings instead of closing the active overlay panel first.
- Fixed NPC battle pivot moves opening empty move slots after a KO and forced switch sequence.
- Fixed NPC trainer HUD team icons changing species during faint and forced switch transitions.

## 0.2.5 - 2026-06-30

**Added**
- Added fishing in the overworld. Cast your rod near water, wait for the bite, and react in time to reel in a wild Pokemon.
- Added surfing on water tiles after using the surf prompt.
- Added wild Pokemon encounters while fishing and surfing in Pallet Town.
- Added proper fishing and surfing poses for customized characters, including layered outfits, hair, caps, eyes, and accessories.

**Changed**
- Running Shoes now also make surfing faster.
- Fishing can still find Pokemon while Repel is active, while grass and surf encounters are still blocked by Repel.

**Fixed**
- Fixed players being able to walk onto water without surfing.
- Fixed surfing not being restored after logging in or returning from battle while standing on water.
- Fixed the player briefly leaving the surf pose when a surf encounter starts.
- Fixed successful fishing sometimes not starting an encounter when Repel was enabled.

## 0.2.4 - 2026-06-30

**Added**
- Added a dedicated PvP battle music track.
- Added Pokemon experience gains after battles, including level-up messages after rewards are claimed.
- Added move learning prompts when a Pokemon levels up and already knows four moves.
- Added level-up evolution prompts after rewards and EXP items, including the choice to evolve or wait.
- Added experience progress bars to the player battle HUD, party slots, and Pokemon summaries.
- Added EV training support, including stored EVs, manual EV allocation, vitamins, wings, and battle EV gains.
- Added EV Yield information to the Pokedex so players can see what training rewards each Pokemon gives.
- Added animated Pokedex sprites with a front/back toggle.
- Added a visual Happiness progress bar placeholder in Pokemon summaries.
- Added effect details to medicine items in the Item Dex, including EXP, healing, PP, and ability item strengths.

**Changed**
- The Battle Music setting now lists PvP battle tracks and controls which music plays during PvP battles.
- Pokemon summaries now show training progress more clearly.
- Move learning prompts now show queue progress and clearer messages when multiple moves need review.
- Pokemon EV gains are stored first so players can choose where to allocate them later.
- The Pokedex now uses a larger, clearer layout with animated Pokemon previews.

**Fixed**
- Fixed EXP and EV rewards being given to Pokemon that did not take part in the battle.

## 0.2.3 - 2026-06-29

**Added**
- Added a redesigned Pokemon summary screen that is easier to read and keeps every tab the same size.
- Added a front/back sprite toggle in Pokemon summaries.
- Added a small shiny marker in Pokemon summaries.
- Added clearer origin info in Pokemon summaries, including where a Pokemon came from, when it was obtained, and whether it was caught or generated.
- Added hover descriptions for moves and abilities in Pokemon summaries.

**Changed**
- Battle logs now behave better on different screen sizes and remember your choice during the session.
- Your own overworld character now appears in front when players stand on the same spot.
- Pokemon summary stats now highlight nature boosts and drops.
- Stored EVs now use a roomier two-row layout for better readability.
- Poké Ball and held item changes now use searchable suggestions instead of long option lists.
- Changing a Pokemon's assigned Poké Ball now warns you first, consumes the new ball, and does not return the previous ball.
- Wild Pokemon now receive random natures and IVs, so caught Pokemon should feel less identical.
- Confirmation prompts now match the game's UI style.

**Fixed**
- Fixed the forfeit confirmation prompt appearing behind other battle UI.
- Fixed Red Orb and Blue Orb not showing up properly as held item choices.
- Fixed ability names in Pokemon summaries sometimes showing names like `run-away` instead of `Run Away`.
- Fixed Pokemon summaries sometimes showing HP as a percentage instead of the real HP value.
- Fixed saved overworld positions sometimes drifting off the tile grid after disconnecting or returning from battle during movement.
- Fixed overworld players, followers, NPCs, and trees sometimes appearing in the wrong visual order while overlapping.
- Fixed PvP team indicators showing shiny markers on the wrong Pokemon.
- Fixed form Pokemon such as Landorus-Therian briefly showing the wrong form when switching in.
- Fixed NPC trainer battle openings briefly showing form Pokemon such as Landorus-Therian as their base species before the summon animation finished.
- Fixed Leftovers and other healing animations not playing on visible form Pokemon such as Landorus-Therian.
- Fixed stat-lowering particles looking too large and spread out on the battle screen.

## 0.2.2 - 2026-06-29

**Added**
- Added the first complete wild Pokemon capture flow using Bag Poké Balls during wild battles.
- Added Gen 4-style Poké Ball capture animations for throw, shake, break-out, and successful catch states.
- Added backend capture handling that consumes balls, resolves catch success, creates owned Pokemon, and updates party state when space is available.
- Added pass-turn battle resolution so failed wild capture attempts let the wild Pokemon take its turn.
- Added stored Poké Ball metadata and an initial Poké Ball summon animation for wild battle player leads.
- Added Pokemon cry assets and cry playback on Poké Ball release moments.
- Added a summary-card Poké Ball selector for changing owned Pokemon summon ball cosmetics.

**Changed**
- Wild battle Bag actions now use backend catch results for shake count, success state, inventory updates, and battle completion.
- Wild battle capture actions now write both item use and capture outcome messages to the battle log.
- Trainer battle openings now play Poké Ball lead summon animations for both the player and NPC trainer.
- PvP battle openings now play sequential Poké Ball lead summon animations for both sides.
- Switch events now use fast Poké Ball recall and release animations without replaying the full throw.
- PvP opponent switch and summon animations now use public Poké Ball metadata when available.
- Switch release animations now leave audio space for future Pokemon cries.
- Owned Pokemon Poké Ball changes now consume the newly selected ball and return the previously assigned ball to the Bag.

**Fixed**
- Fixed team-preview battle leads being visible before their Poké Ball lead animations play.
- Fixed battle move slots losing type labels after recent battle UI changes.
- Fixed battle HUD placeholders briefly showing poison status and 75% HP before real Pokemon data loads.
- Fixed form Pokemon such as Landorus-Therian briefly rendering as their base species in PvP and NPC battle openings.
- Fixed overworld NPCs drawing behind the player when the NPC is lower on screen.

## 0.2.1 - 2026-06-28

**Added**
- Added an Electric Terrain battlefield animation with yellow terrain particles and ambient tinting.
- Added distinct Primordial Sea and Desolate Land battlefield animations using heavier rain, storm haze, harsh sunlight, and heat haze layers.
- Added a Delta Stream battlefield animation with wind bands, air particles, cloud veil, and cool sky tinting.
- Added Primal Reversion event handling so Red Orb and Blue Orb transformations can play the mega evolution animation.
- Added dedicated wild and trainer battle music tracks.
- Added an explicit follower sprite map so Pokemon forms can resolve to the correct follower sprite assets.
- Added a follower sprite map validation tool for future form sprite updates.

**Fixed**
- Fixed Hidden Power battle move slots showing the wrong type and PP in battle.
- Fixed Choice-locked and otherwise disabled battle moves staying clickable in the move UI.
- Fixed NPC trainer battles getting stuck with empty move slots after the opponent fainted and needed a forced switch.
- Fixed Primal Groudon and Primal Kyogre hover stats still showing their base form stats after Red Orb or Blue Orb activation.
- Fixed Pokemon HOME icons not loading for form species such as Alolan Ninetales and Oricorio forms.
- Fixed Pokemon followers using the base species sprite instead of available form sprites, including Alolan Ninetales, Oricorio forms, Deoxys forms, Rotom forms, and regional forms.

**Changed**
- Delta Stream wind bands now loop with a smooth back-and-forth motion instead of snapping back to the start.
- Party hover cards now show held item next to HP and nature next to ability.
- Player sprites now take draw priority over their follower when they overlap at nearly the same height.
- Follower sprite loading now checks the species-to-asset map before falling back to legacy filename guesses.

## 0.2.0 - 2026-06-28

**Added**
- Added character customization.

**Fixed**
- Fixed battles breaking when multiple Pokemon of the same species are used on the same team.
- Fixed all recently reported bugs from the latest test cycle.

**Changed**
- Releases are now published manually instead of automatically building a new client on every code push.
