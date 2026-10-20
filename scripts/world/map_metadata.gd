extends Node2D

const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")

@export var map_id := ""
@export var map_region_name := ""
@export var map_display_name := ""
# Opt-in: keep complete trees independent of adjacent forest crowns.
@export var individual_tree_depth_sorting := false
@export var world_access_group_id := ""
@export var world_access_group_label := ""
@export_enum("exterior", "interior", "route", "wilderness", "transition") var world_access_area_type := "exterior"
# Allow cave interiors to support riding without changing world-access grouping.
@export var land_mounts_allowed_interior := false
@export var land_mount_dismount_blocked := false
@export var land_mount_required_entry := false
@export var preserve_land_mount_on_transition := false
# Grid regions where leaving a tile to the north is forbidden.
@export var northbound_blocked_regions: Array[Rect2i] = []
@export var location_id := ""
@export var location_name := ""
@export var region_id := ""
@export var mount_license_region_id := ""
@export var encounter_area_id := ""
@export var step_encounter_type := ""
@export_group("Battle")
@export_enum("grass", "water", "cave", "ss_anne") var battle_environment_id := "grass"
@export_group("")
@export_enum("outdoor", "indoor", "dark") var lighting_profile := "outdoor"
@export_group("Cave visibility")
# Matching groups preserve Flash across floors; an empty group has no sight mask.
@export var cave_visibility_group_id := ""
@export_range(16.0, 512.0, 1.0) var cave_visibility_radius := 96.0
@export_range(1.0, 64.0, 1.0) var cave_visibility_feather := 12.0
@export_group("")
@export_enum("outdoor", "disabled") var weather_profile := "outdoor"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.0
@export_range(0.0, 1.0, 0.01) var cave_encounter_chance := 0.0
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.0
# An explicit track ID always wins. Leave this empty for a regular interior
# that should inherit the track associated with its town or city music profile.
@export var music_track_id := ""
@export var music_profile_id := ""

@onready var collision: TileMapLayer = find_map_tilemap_layer("Collision")


func _ready() -> void:
	if encounter_area_id.strip_edges() != "":
		await _load_encounter_area_metadata()


func get_map_id() -> String:
	return map_id


func find_map_tilemap_layer(layer_name: String) -> TileMapLayer:
	return MapLayerResolverScript.find_tilemap_layer(self, [layer_name])


func get_map_display_name() -> String:
	var floor_mask := get_node_or_null("FloorVisibilityMask")
	if floor_mask != null and floor_mask.has_method("get_active_floor_display_name"):
		var floor_display_name := str(floor_mask.call("get_active_floor_display_name")).strip_edges()
		if floor_display_name != "":
			return floor_display_name
	return map_display_name


func get_map_region_name() -> String:
	return map_region_name


func get_world_access_area_type() -> String:
	return world_access_area_type


func allows_land_mounts() -> bool:
	return world_access_area_type != "interior" or land_mounts_allowed_interior


func get_location_metadata() -> Dictionary:
	var resolved_region_id := (
		region_id
		if region_id.strip_edges() != ""
		else map_region_name.to_lower().replace(" ", "_")
	)
	return {
		"locationId": location_id if location_id.strip_edges() != "" else map_id,
		"locationName": location_name if location_name.strip_edges() != "" else get_map_display_name(),
		"regionId": resolved_region_id,
		"regionName": map_region_name,
		"mapId": map_id,
		"mountLicenseRegionId": (
			mount_license_region_id
			if mount_license_region_id.strip_edges() != ""
			else resolved_region_id
		),
		"battleEnvironmentId": battle_environment_id,
	}


func get_battle_environment_id() -> String:
	return battle_environment_id


func get_music_track_id() -> String:
	return music_track_id


func get_music_profile_id() -> String:
	return music_profile_id


func get_lighting_profile() -> String:
	return lighting_profile


func get_cave_visibility_settings() -> Dictionary:
	if cave_visibility_group_id.strip_edges().is_empty():
		return {}
	return {
		"groupId": cave_visibility_group_id.strip_edges(),
		"radius": cave_visibility_radius,
		"feather": cave_visibility_feather,
	}


func get_weather_profile() -> String:
	return weather_profile


func get_actor_sort_z_floor(_world_position: Vector2) -> int:
	return -4096


func get_wild_encounter_area_id() -> String:
	return encounter_area_id


func get_step_encounter_type() -> String:
	return step_encounter_type.strip_edges().to_lower()


func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	match encounter_type.strip_edges().to_lower():
		"grass":
			return randf() <= grass_encounter_chance
		"cave":
			return randf() <= cave_encounter_chance
		"surf":
			return randf() <= surf_encounter_chance
		_:
			return false


func _load_encounter_area_metadata() -> void:
	var metadata_service := get_node_or_null("/root/EncounterMetadataService")
	if metadata_service == null or not metadata_service.has_method("get_encounter_area_metadata"):
		return

	var response: Dictionary = await metadata_service.call("get_encounter_area_metadata", encounter_area_id)
	if not response.get("success", false):
		push_warning("Encounter metadata failed for %s: %s" % [
			encounter_area_id,
			str(response.get("error", "Unknown API error")),
		])
		return

	var metadata: Dictionary = response.get("metadata", {})
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	var grass_metadata: Dictionary = encounter_types.get("grass", {})
	grass_encounter_chance = clampf(float(grass_metadata.get("encounterChance", grass_encounter_chance)), 0.0, 1.0)
	var cave_metadata: Dictionary = encounter_types.get("cave", {})
	cave_encounter_chance = clampf(float(cave_metadata.get("encounterChance", cave_encounter_chance)), 0.0, 1.0)
	var surf_metadata: Dictionary = encounter_types.get("surf", {})
	surf_encounter_chance = clampf(float(surf_metadata.get("encounterChance", surf_encounter_chance)), 0.0, 1.0)


func is_position_blocked_by_character(world_position: Vector2) -> bool:
	return MapCharacterBlocking.is_position_blocked_by_character(self, world_position)


func get_closed_route_gate_npc(world_position: Vector2) -> Node:
	return MapCharacterBlocking.get_closed_route_gate_npc(self, world_position)


func allows_land_mount_dismount() -> bool:
	return not land_mount_dismount_blocked


func get_world_travel_rules() -> Dictionary:
	var rules := {}
	if land_mount_required_entry:
		rules["mountRequiredEntry"] = true
	if land_mount_dismount_blocked:
		rules["dismountBlocked"] = true
	if preserve_land_mount_on_transition or land_mount_dismount_blocked:
		rules["preserveLandMount"] = true
	if not northbound_blocked_regions.is_empty():
		var regions: Array[Dictionary] = []
		for region in northbound_blocked_regions:
			regions.append({"x":region.position.x,"y":region.position.y,"width":region.size.x,"height":region.size.y})
		rules["northBlockedRegions"] = regions
	return rules


func is_world_barrier_step_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	if to_position.y >= from_position.y:
		return false
	var cell := Vector2i((from_position - global_position) / 32.0)
	for region in northbound_blocked_regions:
		if region.has_point(cell):
			return true
	return false
