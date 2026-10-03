extends "res://scripts/world/map_metadata.gd"

const FLOOR_ENCOUNTER_AREAS := {
	&"floor_3": "kanto_pokemon_tower_3f",
	&"floor_4": "kanto_pokemon_tower_4f",
	&"floor_5": "kanto_pokemon_tower_5f",
	&"floor_6": "kanto_pokemon_tower_6f",
	&"floor_7": "kanto_pokemon_tower_7f",
}


func get_wild_encounter_area_id() -> String:
	return str(FLOOR_ENCOUNTER_AREAS.get(_get_encounter_floor(), ""))


func get_wild_encounter_chance(encounter_type: String = "grass") -> float:
	if encounter_type.strip_edges().to_lower() != "cave" or get_wild_encounter_area_id().is_empty():
		return 0.0
	var player := _get_local_player()
	var seal := get_node_or_null("EncounterRegions/HealingSeal")
	if player != null and seal != null:
		var safe_region: Rect2 = seal.get_meta("pao_region_rect", Rect2())
		if safe_region.has_point(to_local(_get_player_feet_position(player))):
			return 0.0
	return cave_encounter_chance


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	var chance := get_wild_encounter_chance(encounter_type)
	return chance > 0.0 and randf() < chance


func _get_encounter_floor() -> StringName:
	var mask := get_node_or_null("FloorVisibilityMask")
	if mask == null:
		return &""
	var player := _get_local_player()
	if player == null:
		return mask.active_floor
	# Walking checks run immediately after a step, before the mask's next frame.
	# Derive the floor from feet position so stairs and restored saves use the right table.
	var position_on_map := to_local(_get_player_feet_position(player))
	for floor_name: StringName in mask.floor_regions:
		var bounds: Rect2 = mask.floor_regions[floor_name]
		if bounds.has_point(position_on_map):
			return floor_name
	return &""


func _get_local_player() -> Node2D:
	var player := get_node_or_null("Entities/Players/Player") as Node2D
	if player != null:
		return player
	if not is_inside_tree():
		return null
	for candidate: Node in get_tree().get_nodes_in_group("player"):
		if candidate is Node2D and is_ancestor_of(candidate):
			return candidate as Node2D
	return null


func _get_player_feet_position(player: Node2D) -> Vector2:
	if player.has_method("get_feet_position"):
		return player.call("get_feet_position") as Vector2
	return player.global_position
