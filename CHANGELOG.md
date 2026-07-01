# Changelog

## Unreleased

**Added**
- Added Tiled `PA_Interactables` support for map-owned signs and other interactive objects.
- Added Pokédex wild location entries with species rarity labels instead of raw encounter chances.

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
