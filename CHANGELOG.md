# Changelog

## Unreleased

**Added**
- Added an Electric Terrain battlefield animation with yellow terrain particles and ambient tinting.
- Added distinct Primordial Sea and Desolate Land battlefield animations using heavier rain, storm haze, harsh sunlight, and heat haze layers.
- Added a Delta Stream battlefield animation with wind bands, air particles, cloud veil, and cool sky tinting.
- Added Primal Reversion event handling so Red Orb and Blue Orb transformations can play the mega evolution animation.
- Added dedicated wild and trainer battle music tracks.
- Added an explicit follower sprite map so Pokemon forms can resolve to the correct follower sprite assets.
- Added a follower sprite map validation tool for future form sprite updates.

**Fixed**
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
