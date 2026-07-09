extends Node2D

@export var map_id := "kanto_pallet_town"
@export var map_region_name := "Kanto"
@export var map_display_name := "Pallet Town"
@export var location_id := "kanto.pallet_town"
@export var location_name := "Pallet Town"
@export var region_id := "kanto"
@export var encounter_area_id := "kanto_pallet_town"
@export_range(0.0, 1.0, 0.01) var surf_encounter_chance := 0.1
@export_range(0.0, 1.0, 0.01) var fish_encounter_chance := 1.0
@export_file("*.ogg") var music_track_path := "res://assets/music/overworld/kanto/towns/pallet_town.ogg"

const TILE_SIZE := 32.0
const TREE_TOP_VISUAL_LAYERS := [
	"Structures Top",
]
const DOOR_LAYER_NAME := "Door Layer"
const DOOR_COVER_LAYER_NAMES := [
	"Structures Bottom",
	"Objects Layer",
	"Structures Top",
]
const DOOR_OPEN_OFFSET := Vector2(10.0, 0.0)
const DOOR_TWEEN_SECONDS := 0.16

var door_layer: TileMapLayer
var door_groups: Array[Dictionary] = []
var door_tweens: Dictionary = {}

func _ready() -> void:
	_configure_visual_layer_order()
	_setup_door_animation_groups()
	await _load_encounter_area_metadata()


func _process(_delta: float) -> void:
	_update_door_animation_state()


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


func _setup_door_animation_groups() -> void:
	door_groups.clear()

	var visuals := get_node_or_null("Visuals")
	if visuals == null:
		return

	door_layer = visuals.get_node_or_null(DOOR_LAYER_NAME) as TileMapLayer
	if door_layer == null:
		return

	var door_z_index := door_layer.z_index
	for cover_layer_name: String in DOOR_COVER_LAYER_NAMES:
		var door_cover_layer := visuals.get_node_or_null(cover_layer_name) as TileMapLayer
		if door_cover_layer != null:
			door_z_index = mini(door_z_index, door_cover_layer.z_index - 1)

	var used_cells := door_layer.get_used_cells()
	var groups := _build_door_cell_groups(used_cells)
	for group_index in range(groups.size()):
		var cells: Array = groups[group_index]
		var animated_layer := TileMapLayer.new()
		animated_layer.name = "AnimatedDoor%d" % group_index
		animated_layer.tile_set = door_layer.tile_set
		animated_layer.position = door_layer.position
		animated_layer.z_as_relative = door_layer.z_as_relative
		animated_layer.z_index = door_z_index
		animated_layer.modulate = door_layer.modulate
		visuals.add_child(animated_layer)

		for cell_value: Variant in cells:
			var cell := cell_value as Vector2i
			animated_layer.set_cell(
				cell,
				door_layer.get_cell_source_id(cell),
				door_layer.get_cell_atlas_coords(cell),
				door_layer.get_cell_alternative_tile(cell)
			)
			door_layer.erase_cell(cell)

		door_groups.append({
			"id": group_index,
			"cells": cells,
			"layer": animated_layer,
			"closed_position": animated_layer.position,
			"open": false,
		})


func _build_door_cell_groups(cells: Array[Vector2i]) -> Array:
	var remaining := {}
	for cell: Vector2i in cells:
		remaining[cell] = true

	var groups: Array = []
	for start_cell: Vector2i in cells:
		if not remaining.has(start_cell):
			continue

		var group: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_cell]
		remaining.erase(start_cell)

		while not queue.is_empty():
			var current := queue.pop_front() as Vector2i
			group.append(current)
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = current + offset
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					queue.append(neighbor)

		groups.append(group)

	return groups


func _update_door_animation_state() -> void:
	if door_layer == null or door_groups.is_empty():
		return

	var player := _get_local_player()
	if player == null:
		_close_all_door_groups()
		return

	var player_feet_position := _get_player_feet_position(player)
	var player_cell := door_layer.local_to_map(door_layer.to_local(player_feet_position))

	for group: Dictionary in door_groups:
		if _is_player_in_front_of_door_group(player_cell, group):
			if not bool(group.get("open", false)):
				_set_door_group_open(group, true)
		elif bool(group.get("open", false)):
			_set_door_group_open(group, false)


func _get_local_player() -> Node2D:
	var player := get_node_or_null("Entities/Players/Player") as Node2D
	if player != null:
		return player

	var tree := get_tree()
	if tree == null:
		return null

	var players := tree.get_nodes_in_group("player")
	for player_value: Variant in players:
		var candidate := player_value as Node2D
		if candidate != null and is_ancestor_of(candidate):
			return candidate

	return null


func _get_player_feet_position(player: Node2D) -> Vector2:
	if player.has_method("get_feet_position"):
		return player.call("get_feet_position") as Vector2
	return player.global_position


func _is_player_in_front_of_door_group(player_cell: Vector2i, group: Dictionary) -> bool:
	var cells: Array = group.get("cells", [])
	if cells.is_empty():
		return false

	var max_y := -2147483648
	for cell_value: Variant in cells:
		var cell := cell_value as Vector2i
		max_y = maxi(max_y, cell.y)

	for cell_value: Variant in cells:
		var cell := cell_value as Vector2i
		if cell.y == max_y and player_cell == cell + Vector2i.DOWN:
			return true

	return false


func _close_all_door_groups() -> void:
	for group: Dictionary in door_groups:
		if bool(group.get("open", false)):
			_set_door_group_open(group, false)


func _set_door_group_open(group: Dictionary, open: bool) -> void:
	group["open"] = open

	var group_id := int(group.get("id", -1))
	var layer := group.get("layer") as TileMapLayer
	if layer == null:
		return

	var existing_tween := door_tweens.get(group_id) as Tween
	if existing_tween != null:
		existing_tween.kill()

	var closed_position := group.get("closed_position", layer.position) as Vector2
	var target_position := closed_position + DOOR_OPEN_OFFSET if open else closed_position
	var target_alpha := 0.0 if open else 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(layer, "position", target_position, DOOR_TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(layer, "modulate:a", target_alpha, DOOR_TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	door_tweens[group_id] = tween


func get_wild_encounter_area_id() -> String:
	return encounter_area_id


func get_wild_encounter_chance(encounter_type: String = "grass") -> float:
	match encounter_type.strip_edges().to_lower():
		"surf":
			return surf_encounter_chance
		"fish", "fishing":
			return fish_encounter_chance
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
	fish_encounter_chance = _metadata_encounter_chance(encounter_types, "fish", fish_encounter_chance)
	fish_encounter_chance = _metadata_encounter_chance(encounter_types, "fishing", fish_encounter_chance)


func _metadata_encounter_chance(encounter_types: Dictionary, encounter_type: String, fallback: float) -> float:
	var encounter_metadata: Dictionary = encounter_types.get(encounter_type, {})
	return clampf(float(encounter_metadata.get("encounterChance", fallback)), 0.0, 1.0)
