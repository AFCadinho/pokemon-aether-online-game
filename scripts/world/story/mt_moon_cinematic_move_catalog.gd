extends RefCounted

class_name MtMoonCinematicMoveCatalog

const MOVES := {
	"normal": {"id": "hyper-beam", "name": "Hyper Beam", "sound": "res://assets/battles/animations/hyperbeam/PRSFX- Hyper Beam.wav"},
	"fire": {"id": "blast-burn", "name": "Blast Burn", "sound": "res://assets/battles/animations/flamethrower/PRSFX- Flamethrower.wav"},
	"water": {"id": "hydro-cannon", "name": "Hydro Cannon", "sound": "res://assets/battles/animations/hydrovortex/PRSFX- Hydro Vortex3.wav"},
	"electric": {"id": "thunder", "name": "Thunder", "sound": "res://assets/battles/animations/thunderbolt/PRSFX- Thunderbolt1.wav"},
	"grass": {"id": "frenzy-plant", "name": "Frenzy Plant", "sound": "res://assets/battles/animations/razorleaf/PRSFX- Razor Leaf1.wav"},
	"ice": {"id": "blizzard", "name": "Blizzard", "sound": "res://assets/battles/animations/blizzard/PRSFX- Blizzard.wav"},
	"fighting": {"id": "close-combat", "name": "Close Combat", "sound": "res://assets/battles/animations/closecombat/PRSFX- Close Combat.wav"},
	"poison": {"id": "sludge-wave", "name": "Sludge Wave", "sound": "res://assets/battles/animations/sludgebomb/PRSFX- Sludge Bomb1.wav"},
	"ground": {"id": "earthquake", "name": "Earthquake", "sound": "res://assets/battles/animations/earthquake/PRSFX- Earthquake1.wav"},
	"flying": {"id": "hurricane", "name": "Hurricane", "sound": "res://assets/battles/animations/hurricane/PRSFX- Hurricane.wav"},
	"psychic": {"id": "future-sight", "name": "Future Sight", "sound": "res://assets/battles/animations/futuresight/PRSFX- Future Sight1.wav"},
	"bug": {"id": "megahorn", "name": "Megahorn", "sound": "res://assets/battles/animations/bugbite/PRSFX- Bug Bite.wav"},
	"rock": {"id": "stone-edge", "name": "Stone Edge", "sound": "res://assets/battles/animations/rockthrow/PRSFX- Rock Throw1.wav"},
	"ghost": {"id": "shadow-ball", "name": "Shadow Ball", "sound": "res://assets/battles/animations/shadowball/PRSFX- Shadow Ball1.wav"},
	"dragon": {"id": "draco-meteor", "name": "Draco Meteor", "sound": "res://assets/battles/animations/dracometeor/PRSFX- Draco Meteor1.wav"},
	"dark": {"id": "dark-pulse", "name": "Dark Pulse", "sound": "res://assets/battles/animations/darkpulse/PRSFX- Dark Pulse1.wav"},
	"steel": {"id": "flash-cannon", "name": "Flash Cannon", "sound": "res://assets/battles/animations/flashcannon/PRSFX- Flash Cannon.wav"},
	"fairy": {"id": "moonblast", "name": "Moonblast", "sound": "res://assets/battles/animations/moonblast/PRSFX- Moonblast1.wav"},
}


static func for_types(types: Array[String]) -> Dictionary:
	var type_id := "normal"
	if not types.is_empty():
		type_id = str(types[0]).strip_edges().to_lower()
	var move: Dictionary = MOVES.get(type_id, MOVES.normal).duplicate()
	move["type"] = type_id if MOVES.has(type_id) else "normal"
	return move
