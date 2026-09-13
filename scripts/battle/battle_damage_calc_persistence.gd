extends RefCounted

const PERSISTENT_FIELDS := [
	"item", "ability", "nature", "status", "evs", "ivs",
	"assumedMoves", "replaceMoves", "exactStats",
]


static func select_persistent_fields(assumptions: Dictionary, edited_fields: Dictionary) -> Dictionary:
	var selected: Dictionary = {}
	for key: String in PERSISTENT_FIELDS:
		if bool(edited_fields.get(key, false)) and assumptions.has(key):
			selected[key] = assumptions.get(key)
	return selected


static func remove_transient_fields(assumptions: Dictionary) -> Dictionary:
	var cleaned := assumptions.duplicate(true)
	cleaned.erase("boosts")
	return cleaned
