# Changelog

## Unreleased

**Added**
- Added an Electric Terrain battlefield animation with yellow terrain particles and ambient tinting.
- Added distinct Primordial Sea and Desolate Land battlefield animations using heavier rain, storm haze, harsh sunlight, and heat haze layers.
- Added an explicit follower sprite map so Pokemon forms can resolve to the correct follower sprite assets.
- Added a follower sprite map validation tool for future form sprite updates.

**Fixed**
- Fixed Primal Groudon and Primal Kyogre hover stats still showing their base form stats after Red Orb or Blue Orb activation.
- Fixed Pokemon HOME icons not loading for form species such as Alolan Ninetales and Oricorio forms.
- Fixed Pokemon followers using the base species sprite instead of available form sprites, including Alolan Ninetales, Oricorio forms, Deoxys forms, Rotom forms, and regional forms.

**Changed**
- Party hover cards now show held item next to HP and nature next to ability.
- Follower sprite loading now checks the species-to-asset map before falling back to legacy filename guesses.

## 0.2.0 - 2026-06-28

**Added**
- Added character customization.

**Fixed**
- Fixed battles breaking when multiple Pokemon of the same species are used on the same team.
- Fixed all recently reported bugs from the latest test cycle.

**Changed**
- Releases are now published manually instead of automatically building a new client on every code push.
