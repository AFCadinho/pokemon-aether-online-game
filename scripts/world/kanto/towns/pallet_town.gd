extends Node2D

@export var map_id := "kanto_pallet_town"
@export var map_region_name := "Kanto"
@export var map_display_name := "Pallet Town"
@export var world_access_group_id := "kanto_pallet_town"
@export var world_access_group_label := "Pallet Town"
@export_enum("exterior", "interior", "route", "wilderness", "transition") var world_access_area_type := "exterior"
@export var location_id := "kanto.pallet_town"
@export var location_name := "Pallet Town"
@export var region_id := "kanto"
@export var encounter_area_id := "kanto_pallet_town"
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.1
@export_range(0.0, 1.0, 0.01) var old_rod_encounter_chance := 1.0
@export_range(0.0, 1.0, 0.01) var good_rod_encounter_chance := 1.0
@export_range(0.0, 1.0, 0.01) var super_rod_encounter_chance := 1.0
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"

const TILE_SIZE := 32.0
const TREE_TOP_VISUAL_LAYERS := [
	"Structures Top",
]

func _ready() -> void:
	_configure_visual_layer_order()
	await _load_encounter_area_metadata()


func get_map_id() -> String:
	return map_id


func get_map_display_name() -> String:
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_location_metadata() -> Dictionary:
	return {
		"locationId": location_id,
		"locationName": location_name,
		"regionId": region_id,
		"regionName": map_region_name,
		"mapId": map_id,
	}


func get_music_track_path() -> String:
	return music_track_path


func _configure_visual_layer_order() -> void:
	var visuals := get_node_or_null("Visuals")
	if visuals == null:
		return

	for layer_name: String in TREE_TOP_VISUAL_LAYERS:
		var layer := visuals.get_node_or_null(layer_name) as TileMapLayer
		if layer != null:
			_set_tree_top_layer_z_index(layer)


func _set_tree_top_layer_z_index(layer: TileMapLayer) -> void:
	var used_rect := layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return

	var layer_bottom_y := layer.global_position.y + float(used_rect.position.y + used_rect.size.y) * TILE_SIZE
	layer.z_as_relative = false
	layer.z_index = clampi(floori(layer_bottom_y), -4096, 4096)


func get_wild_encounter_area_id() -> String:
	return encounter_area_id


func get_wild_encounter_chance(encounter_type: String = "grass") -> float:
	match encounter_type.strip_edges().to_lower():
		"surf":
			return surf_encounter_chance
		"fish", "fishing":
			return old_rod_encounter_chance
		"old_rod":
			return old_rod_encounter_chance
		"good_rod":
			return good_rod_encounter_chance
		"super_rod":
			return super_rod_encounter_chance
		_:
			return 0.0


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	var encounter_chance := get_wild_encounter_chance(encounter_type)
	if encounter_chance <= 0.0:
		return false

	return randf() <= encounter_chance


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)


func _load_encounter_area_metadata() -> void:
	if encounter_area_id.strip_edges() == "":
		return

	var metadata_service := get_node_or_null("/root/EncounterMetadataService")
	if metadata_service == null or not metadata_service.has_method("get_encounter_area_metadata"):
		return

	var response: Dictionary = await metadata_service.call("get_encounter_area_metadata", encounter_area_id)
	if not response.get("success", false):
		push_warning("Pallet Town encounter metadata failed for %s: %s" % [
			encounter_area_id,
			str(response.get("error", "Unknown API error")),
		])
		return

	var metadata: Dictionary = response.get("metadata", {})
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	surf_encounter_chance = _metadata_encounter_chance(encounter_types, "surf", surf_encounter_chance)
	old_rod_encounter_chance = _metadata_encounter_chance(encounter_types, "old_rod", old_rod_encounter_chance)
	good_rod_encounter_chance = _metadata_encounter_chance(encounter_types, "good_rod", good_rod_encounter_chance)
	super_rod_encounter_chance = _metadata_encounter_chance(encounter_types, "super_rod", super_rod_encounter_chance)


func _metadata_encounter_chance(encounter_types: Dictionary, encounter_type: String, fallback: float) -> float:
	var encounter_metadata: Dictionary = encounter_types.get(encounter_type, {})
	return clampf(float(encounter_metadata.get("encounterChance", fallback)), 0.0, 1.0)
