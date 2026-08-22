extends RefCounted

class_name MtMoonCinematicMoveCatalog

const MOVES := {
	"normal": {"id": "hyper-beam", "name": "Hyper Beam"},
	"fire": {"id": "blast-burn", "name": "Blast Burn"},
	"water": {"id": "hydro-cannon", "name": "Hydro Cannon"},
	"electric": {"id": "thunder", "name": "Thunder"},
	"grass": {"id": "frenzy-plant", "name": "Frenzy Plant"},
	"ice": {"id": "blizzard", "name": "Blizzard"},
	"fighting": {"id": "close-combat", "name": "Close Combat"},
	"poison": {"id": "sludge-wave", "name": "Sludge Wave"},
	"ground": {"id": "earthquake", "name": "Earthquake"},
	"flying": {"id": "hurricane", "name": "Hurricane"},
	"psychic": {"id": "future-sight", "name": "Future Sight"},
	"bug": {"id": "megahorn", "name": "Megahorn"},
	"rock": {"id": "stone-edge", "name": "Stone Edge"},
	"ghost": {"id": "shadow-ball", "name": "Shadow Ball"},
	"dragon": {"id": "draco-meteor", "name": "Draco Meteor"},
	"dark": {"id": "dark-pulse", "name": "Dark Pulse"},
	"steel": {"id": "flash-cannon", "name": "Flash Cannon"},
	"fairy": {"id": "moonblast", "name": "Moonblast"},
}


static func for_types(types: Array[String]) -> Dictionary:
	var type_id := "normal"
	if not types.is_empty():
		type_id = str(types[0]).strip_edges().to_lower()
	var move: Dictionary = MOVES.get(type_id, MOVES.normal).duplicate()
	move["type"] = type_id if MOVES.has(type_id) else "normal"
	return move
