extends Node2D

@export var encounter_area_id := "kanto_route_1"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.1

func _ready() -> void:
	await _load_encounter_area_metadata()

func get_wild_encounter_area_id() -> String:
	return encounter_area_id

func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	if encounter_type != "grass":
		return false

	return randf() <= grass_encounter_chance

func _load_encounter_area_metadata() -> void:
	var response: Dictionary = await EncounterMetadataService.get_encounter_area_metadata(encounter_area_id)
	if not response.get("success", false):
		push_warning("Route 1 encounter metadata failed for %s: %s" % [
			encounter_area_id,
			str(response.get("error", "Unknown API error")),
		])
		return

	var metadata: Dictionary = response.get("metadata", {})
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	var grass_metadata: Dictionary = encounter_types.get("grass", {})
	grass_encounter_chance = clampf(float(grass_metadata.get("encounterChance", grass_encounter_chance)), 0.0, 1.0)

func is_position_blocked_by_character(world_position: Vector2) -> bool:
	var npcs: Node = get_node_or_null("Entities/NPCs")
	if npcs == null:
		return false
		
	for npc: Node in npcs.get_children():
		if npc.has_method("blocks_world_position"):
			if npc.blocks_world_position(world_position):
				return true
		
	return false 
