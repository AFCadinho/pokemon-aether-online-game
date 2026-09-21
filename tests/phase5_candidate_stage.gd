extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
## Test-only adapter. Never loaded by the game or registered in Settings.
const REVIEW = preload("res://docs/phase5b-review-decisions.json")

func _catalog_species_allowed(species: String) -> bool:
	for entry: Dictionary in REVIEW.data.entries:
		if entry.species == species:
			return entry.status == "eligible_for_5c_normal"
	return false

func _supports_combatant(species: String, shiny: bool, double: bool, substitute: bool) -> bool:
	return _catalog_species_allowed(species) and not shiny and not double and not substitute

func _motion_profile(species: String) -> Dictionary:
	return catalog_entries.get(species, {}).get("_review_motion", {})

func _visual_rect(index: int) -> Rect2:
	if actors[index] == null or not actors[index].visible:
		return Rect2()
	var data: Dictionary = entries[identities[index]].get("_review_bounds", {}).get(current_actions[index], {})
	assert(not data.is_empty())
	var box := AABB(Vector3(data.min[0], data.min[1], data.min[2]), Vector3(data.size[0], data.size[1], data.size[2]))
	var rect := Rect2()
	for corner in 8:
		var point := _project_to_ui(actors[index].global_transform * box.get_endpoint(corner))
		rect = Rect2(point, Vector2.ZERO) if corner == 0 else rect.expand(point)
	return rect
