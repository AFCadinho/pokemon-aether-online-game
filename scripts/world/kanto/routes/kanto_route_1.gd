extends Node2D

@export var encounter_area_id := "kanto_route_1"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.1
@export_file("*.ogg") var music_track_path := "res://assets/audio/music/overworld/overworld_theme.ogg"

func _ready() -> void:
	await _load_encounter_area_metadata()

func get_wild_encounter_area_id() -> String:
	return encounter_area_id

func get_music_track_path() -> String:
	return music_track_path

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
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)
