# Changelog

## 0.2.2 - 2026-06-28

**Added**
- Added the first complete wild Pokemon capture flow using Bag Poké Balls during wild battles.
- Added Gen 4-style Poké Ball capture animations for throw, shake, break-out, and successful catch states.
- Added backend capture handling that consumes balls, resolves catch success, creates owned Pokemon, and updates party state when space is available.
- Added pass-turn battle resolution so failed wild capture attempts let the wild Pokemon take its turn.
- Added stored Poké Ball metadata and an initial Poké Ball summon animation for wild battle player leads.

**Changed**
- Wild battle Bag actions now use backend catch results for shake count, success state, inventory updates, and battle completion.
- Wild battle capture actions now write both item use and capture outcome messages to the battle log.
- Trainer battle openings now play Poké Ball lead summon animations for both the player and NPC trainer.
- Switch events now use fast Poké Ball recall and release animations without replaying the full throw.
- Switch release animations now leave audio space for future Pokemon cries.

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
