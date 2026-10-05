extends "catalog_mega_battle_review.gd"
## Review the proposed flight heights with the same runtime hover policy.
## Grounding profiles and native 120 Hz validation remain inherited.
var flight_heights: Dictionary = {}

func _motion_offset(species: String, action: String, time: float) -> float:
	if flight_heights.is_empty():
		var path := OS.get_environment("POKEAETHER_PHASE5_CANDIDATES")
		var proposal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		flight_heights = proposal.hover
	var row: Dictionary = runtime_rows[species]
	var duration := float(row.animations[action].duration)
	var height := float(flight_heights[species])
	assert(height >= 0.0 and height <= 1.0)
	return super._motion_offset(species, action, time) + placement_rules.hover_target(
		{"hover_height": height}, action, time, duration)
