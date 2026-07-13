extends Node2D

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCENE: PackedScene = preload(BATTLE_SCENE_PATH)
const REMOTE_PLAYER_AVATAR_SCRIPT: Script = preload("res://scripts/world/remote_player_avatar.gd")
const POSITION_AUTOSAVE_INTERVAL_SECONDS := 12.0
const POSITION_PRESENCE_UPDATE_INTERVAL_SECONDS := 0.06
const POSITION_SAVE_EPSILON := 1.0
const PLAYTIME_FLUSH_INTERVAL_SECONDS := 60.0
const TILE_SIZE := 32.0
const TREE_LAYER_ROOT_NAME := "Trees"
const TALL_GRASS_VISUAL_LAYER_NAME := "TallGrassVisual"
const STRUCTURE_TOP_VISUAL_LAYER_NAMES: Array[String] = ["StructureTopVisual", "Structures Top"]
const TALL_GRASS_DEPTH_ROW_META := "pao_tall_grass_depth_row"
const TALL_GRASS_DEPTH_ROWS_BUILT_META := "pao_tall_grass_depth_rows_built"
const STRUCTURE_TOP_DEPTH_GROUP_META := "pao_structure_top_depth_group"
const STRUCTURE_TOP_DEPTH_GROUPS_BUILT_META := "pao_structure_top_depth_groups_built"
const TALL_GRASS_LAYER_Z_OFFSET := 1
const TREE_LAYER_Z_MIN := -4096
const TREE_LAYER_Z_MAX := 4096

@export var initial_spawn_name := "InitialSpawn"

var is_in_battle := false
var battle_instance: Node

@onready var player: CharacterBody2D = $Player
@onready var battle_ui_host: Control = %BattleUIHost

var is_loading_map := false
var position_autosave_elapsed := 0.0
var position_presence_elapsed := 0.0
var playtime_elapsed := 0.0
var unflushed_playtime_seconds := 0
var is_flushing_playtime := false
var is_saving_player_position := false
var has_pending_player_position_save := false
var authorized_teleport_in_progress := false
var authorized_teleport_locked_overworld := false
var authorized_teleport_apply_failed_autosave_blocked := false
var current_teleport_revision := 0
var last_saved_position_signature := ""
var last_presence_position_signature := ""
var confirmed_appearance_state: Dictionary = {}
var remote_players_container: Node2D
var remote_player_avatars: Dictionary = {}
var pending_remote_player_interaction: Dictionary = {}
var remote_player_interaction_pending := false
var active_battle_kind := ""
var active_battle_id := ""
var active_wild_pokemon_species := ""
var active_trainer_name := ""

func _exit_tree() -> void:
	if GameState.current_map != null and is_instance_valid(GameState.current_map) and is_ancestor_of(GameState.current_map):
		GameState.clear_world_runtime_state()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("world")
	_ensure_remote_players_container()
	_connect_world_presence_signals()
	await _setup_initial_world_state()
	_normalize_map_depth_layer_z_indices(GameState.current_map)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_track_playtime(delta)

	if is_in_battle or is_loading_map:
		return

	position_presence_elapsed += delta
	if position_presence_elapsed >= POSITION_PRESENCE_UPDATE_INTERVAL_SECONDS:
		position_presence_elapsed = 0.0
		_publish_world_presence()

	position_autosave_elapsed += delta
	if position_autosave_elapsed >= POSITION_AUTOSAVE_INTERVAL_SECONDS:
		position_autosave_elapsed = 0.0
		if not _is_player_position_save_blocked_by_teleport():
			await _save_current_player_position_if_changed(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_current_player_position_if_changed(true)
		_flush_playtime_if_needed.call_deferred(true)

func save_current_player_state() -> void:
	_save_current_player_position_if_changed.call_deferred(true)
	_flush_playtime_if_needed.call_deferred(true)
	_publish_world_presence.call_deferred(true)

func save_current_player_state_now() -> Dictionary:
	if _is_player_position_save_blocked_by_teleport():
		return {
			"success": false,
			"error": _get_player_position_save_block_reason(),
		}
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if player == null or GameState.current_map == null:
		return {
			"success": false,
			"error": "World is not ready.",
		}

	while is_saving_player_position:
		await get_tree().process_frame

	if _is_player_position_save_blocked_by_teleport():
		return {
			"success": false,
			"error": _get_player_position_save_block_reason(),
		}

	var signature: String = _get_current_player_position_signature(false)
	var result: Dictionary = await _save_current_player_position(signature, "", false, true)
	if bool(result.get("success", false)):
		_publish_world_presence(true)
	_flush_playtime_if_needed.call_deferred(true)
	return result


func begin_authorized_teleport() -> Dictionary:
	var block_reason := get_authorized_teleport_block_reason()
	if block_reason != "":
		return {
			"success": false,
			"error": block_reason,
		}
	authorized_teleport_in_progress = true
	has_pending_player_position_save = false
	GameState.lock_overworld_input()
	authorized_teleport_locked_overworld = true
	while is_saving_player_position:
		await get_tree().process_frame
	block_reason = _get_authorized_teleport_block_reason(true)
	if block_reason != "":
		cancel_authorized_teleport()
		return {
			"success": false,
			"error": block_reason,
		}
	return {"success": true}


func cancel_authorized_teleport() -> void:
	authorized_teleport_in_progress = false
	if authorized_teleport_locked_overworld:
		GameState.unlock_overworld_input()
	authorized_teleport_locked_overworld = false


func apply_authorized_teleport_state(state: Dictionary) -> Dictionary:
	authorized_teleport_in_progress = true
	if player == null:
		_mark_authorized_teleport_apply_failed()
		return {
			"success": false,
			"error": "World player is not ready.",
		}

	var target_scene_path := str(state.get("mapScenePath", "")).strip_edges()
	if target_scene_path == "":
		_mark_authorized_teleport_apply_failed()
		return {
			"success": false,
			"error": "Teleport response is missing a map scene path.",
		}

	if not authorized_teleport_locked_overworld:
		GameState.lock_overworld_input()
		authorized_teleport_locked_overworld = true
	is_loading_map = true
	_clear_remote_players()

	var current_scene_path := _get_map_scene_path(GameState.current_map)
	var target_map: Node = GameState.current_map
	if current_scene_path != target_scene_path:
		target_map = _instantiate_map(target_scene_path)
		if target_map == null:
			_mark_authorized_teleport_apply_failed()
			return {
				"success": false,
				"error": "Could not load teleport map: %s" % target_scene_path,
			}
		_clear_current_map()
		$CurrentMap.add_child(target_map)
		GameState.current_map = target_map
		_normalize_map_depth_layer_z_indices(target_map)
		MusicManager.play_map_music(target_map)

	move_player_to_map(target_map)
	if player.has_method("reset_movement_state"):
		player.call("reset_movement_state")
	var position_result := _position_player_at_authorized_teleport_state(target_map, state)
	if not bool(position_result.get("success", false)):
		_mark_authorized_teleport_apply_failed()
		return position_result
	current_teleport_revision = int(state.get("teleportRevision", current_teleport_revision))
	_apply_camera_limits_for_map(target_map)

	await get_tree().physics_frame
	is_loading_map = false
	last_presence_position_signature = ""
	has_pending_player_position_save = false
	var ack_result: Dictionary = await _ack_authorized_teleport_state(state)
	if not bool(ack_result.get("success", false)):
		_mark_authorized_teleport_apply_failed()
		return {
			"success": false,
			"error": str(ack_result.get("error", "Could not acknowledge authorized teleport.")),
		}
	last_saved_position_signature = _get_current_player_position_signature(true)
	authorized_teleport_apply_failed_autosave_blocked = false
	authorized_teleport_in_progress = false
	_publish_world_presence(true)
	if authorized_teleport_locked_overworld:
		GameState.unlock_overworld_input()
	authorized_teleport_locked_overworld = false
	return {"success": true}


func apply_remote_authorized_teleport_state(state: Dictionary) -> Dictionary:
	var block_reason := _get_authorized_teleport_block_reason(false, true)
	if block_reason != "":
		_mark_authorized_teleport_apply_failed()
		return {
			"success": false,
			"error": block_reason,
		}
	return await apply_authorized_teleport_state(state)


func get_authorized_teleport_block_reason() -> String:
	return _get_authorized_teleport_block_reason(false)


func _get_authorized_teleport_block_reason(ignore_teleport_in_progress := false, ignore_failed_autosave_block := false) -> String:
	if authorized_teleport_in_progress and not ignore_teleport_in_progress:
		return "Another teleport is already in progress."
	if authorized_teleport_apply_failed_autosave_blocked and not ignore_failed_autosave_block:
		return "A previous teleport was saved by the server but did not finish locally. Reload before saving or teleporting again."
	if is_loading_map:
		return "A map transition is already in progress."
	if is_in_battle:
		return "Cannot teleport during battle."
	if player == null or GameState.current_map == null:
		return "World is not ready."
	if GameState.input_locked:
		return "Cannot teleport while dialogue or a global input lock is active."
	if GameState.overworld_input_locked and not ignore_teleport_in_progress:
		return "Cannot teleport while overworld movement is locked."
	if GameState.ui_input_locked:
		return "Cannot teleport while a menu lock is active."
	if player.has_method("is_tile_moving") and bool(player.call("is_tile_moving")):
		return "Cannot teleport while moving."
	if bool(player.get("route_gate_interaction_in_progress")):
		return "Cannot teleport during a route transition."
	if bool(player.get("fishing_activity_active")) or bool(player.get("surf_activity_active")):
		return "Cannot teleport during an overworld activity."
	return ""


func _mark_authorized_teleport_apply_failed() -> void:
	is_loading_map = false
	authorized_teleport_in_progress = false
	authorized_teleport_apply_failed_autosave_blocked = true
	has_pending_player_position_save = false
	if authorized_teleport_locked_overworld:
		GameState.unlock_overworld_input()
	authorized_teleport_locked_overworld = false


func _is_player_position_save_blocked_by_teleport() -> bool:
	return authorized_teleport_in_progress or authorized_teleport_apply_failed_autosave_blocked


func _get_player_position_save_block_reason() -> String:
	if authorized_teleport_apply_failed_autosave_blocked:
		return "A server-authorized teleport did not finish locally; position autosave is blocked to protect the new server position."
	return "Authorized teleport is in progress."


func _ack_authorized_teleport_state(state: Dictionary) -> Dictionary:
	var teleport_revision := int(state.get("teleportRevision", current_teleport_revision))
	var position_data: Dictionary = _dictionary_from_value(state.get("position", {}))
	var ack_state: Dictionary = {
		"mapId": str(state.get("mapId", _get_map_id(GameState.current_map))).strip_edges(),
		"mapScenePath": str(state.get("mapScenePath", _get_map_scene_path(GameState.current_map))).strip_edges(),
		"position": {
			"x": float(position_data.get("x", player.global_position.x)),
			"y": float(position_data.get("y", player.global_position.y)),
		},
		"gender": PlayerSave.gender,
		"facingDirection": str(state.get("facingDirection", _direction_to_name(player.last_direction))).strip_edges(),
		"spawnMarker": str(state.get("spawnMarker", "")).strip_edges(),
		"appearance": _get_confirmed_appearance_state(),
		"roles": _get_current_role_presence_state(),
		"selectedRoleBadge": GameState.selected_role_badge,
		"activityState": "battle" if is_in_battle else "idle",
		"activityContext": _get_current_activity_context(),
		"teleportRevision": teleport_revision,
	}
	var result: Dictionary = await PlayerGameStateService.save_player_position(ack_state)
	if bool(result.get("success", false)):
		var response_state: Dictionary = _dictionary_from_value(result.get("state", {}))
		current_teleport_revision = int(response_state.get("teleportRevision", teleport_revision))
		position_autosave_elapsed = 0.0
		return {"success": true}
	if str(result.get("error", "")) == "FORCED_TELEPORT_PENDING":
		return {
			"success": false,
			"error": "The server is still waiting for the forced teleport destination acknowledgement.",
		}
	return result


func load_map(target_scene_path: String, target_spawn_name: String) -> void:
	if is_loading_map:
		push_warning("World.load_map ignored because a map is already loading: %s" % target_scene_path)
		return

	is_loading_map = true
	_clear_remote_players()

	if target_scene_path == "":
		push_error("World.load_map failed: target_scene_path is empty.")
		is_loading_map = false
		GameState.unlock_overworld_input()
		return

	var target_scene: PackedScene = load(target_scene_path) as PackedScene
	if target_scene == null:
		push_error("World.load_map failed: could not load scene %s" % target_scene_path)
		is_loading_map = false
		GameState.unlock_overworld_input()
		return

	if player.get_parent() != null:
		player.get_parent().remove_child(player)

	for child in $CurrentMap.get_children():
		child.queue_free()

	var new_map: Node = target_scene.instantiate()
	$CurrentMap.add_child(new_map)

	GameState.current_map = new_map
	_normalize_map_depth_layer_z_indices(new_map)
	MusicManager.play_map_music(new_map)

	move_player_to_map(new_map)
	_position_player_at_spawn(new_map, target_spawn_name, Vector2.ZERO)
	_apply_camera_limits_for_map(new_map)

	await get_tree().physics_frame
	is_loading_map = false
	await _save_current_player_position_if_changed(true, target_spawn_name)
	_publish_world_presence(true)
	GameState.unlock_overworld_input()

func move_player_to_map(map: Node) -> void:
	var players: Node = map.get_node_or_null("Entities/Players")
	var player_parent: Node = players if players != null else map
		
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
		
	player_parent.add_child(player)

func _position_player_at_spawn(map: Node, spawn_name: String, fallback_position: Vector2) -> void:
	var spawn_position: Vector2 = fallback_position
	var spawn: Node = map.get_node_or_null("Spawns/" + spawn_name)
	if spawn != null:
		spawn_position = spawn.global_position
	else:
		push_warning("World: spawn '%s' not found in %s. Using fallback position." % [spawn_name, map.name])

	spawn_position = _snap_world_position_to_map_tile_center(map, spawn_position)
	player.global_position = spawn_position
	player.target_position = spawn_position
	player.move_start_position = spawn_position
	player.is_moving = false
	player.set_idle_frame()
	player.refresh_map_layers()
	_sync_player_activity_state_for_current_tile()
	if player.has_method("reset_pokemon_follower_position"):
		player.call("reset_pokemon_follower_position")

func _position_player_at_authorized_teleport_state(map: Node, state: Dictionary) -> Dictionary:
	var spawn_marker := str(state.get("spawnMarker", "")).strip_edges()
	if spawn_marker != "":
		var spawn: Node = map.get_node_or_null("Spawns/" + spawn_marker)
		if spawn == null:
			return {
				"success": false,
				"error": "Teleport spawn marker '%s' was not found in %s." % [spawn_marker, map.name],
			}

		var spawn_position := _snap_world_position_to_map_tile_center(map, (spawn as Node2D).global_position)
		player.global_position = spawn_position
		player.target_position = spawn_position
		player.move_start_position = spawn_position
		player.is_moving = false
		player.last_direction = _direction_from_name(str(state.get("facingDirection", "down")))
		player.set_idle_frame()
		player.refresh_map_layers()
		_sync_player_activity_state_for_current_tile()
		if player.has_method("reset_pokemon_follower_position"):
			player.call("reset_pokemon_follower_position")
		GameState.player_position = spawn_position
		GameState.player_direction = player.last_direction
		GameState.has_player_position = true
		return {"success": true}

	_position_player_at_saved_state(map, state)
	return {"success": true}

func _position_player_at_saved_state(map: Node, state: Dictionary) -> void:
	var position_data: Dictionary = _dictionary_from_value(state.get("position", {}))
	var saved_position: Vector2 = Vector2(
		float(position_data.get("x", player.global_position.x)),
		float(position_data.get("y", player.global_position.y))
	)
	saved_position = _snap_world_position_to_map_tile_center(map, saved_position)

	player.global_position = saved_position
	player.target_position = saved_position
	player.move_start_position = saved_position
	player.is_moving = false
	player.last_direction = _direction_from_name(str(state.get("facingDirection", "down")))
	player.set_idle_frame()
	player.refresh_map_layers()
	_sync_player_activity_state_for_current_tile()
	if player.has_method("reset_pokemon_follower_position"):
		player.call("reset_pokemon_follower_position")
	GameState.player_position = saved_position
	GameState.player_direction = player.last_direction
	GameState.has_player_position = true


func _sync_player_activity_state_for_current_tile() -> void:
	if player != null and player.has_method("sync_activity_state_for_current_tile"):
		player.call("sync_activity_state_for_current_tile")


func _setup_initial_world_state() -> void:
	var first_map: Node = $CurrentMap.get_child(0)
	var saved_state: Dictionary = {}
	if GameState.has_prepared_world_state():
		var prepared_state: Dictionary = GameState.consume_prepared_world_state()
		if bool(prepared_state.get("hasSavedState", false)):
			saved_state = _dictionary_from_value(prepared_state.get("savedState", {}))
	else:
		await _load_player_party_state()
		var saved_state_response: Dictionary = await PlayerGameStateService.load_player_position()
		if bool(saved_state_response.get("success", false)) and bool(saved_state_response.get("hasState", false)):
			saved_state = _dictionary_from_value(saved_state_response.get("state", {}))
			_apply_saved_appearance_state(saved_state)
		elif not bool(saved_state_response.get("success", false)):
			push_warning("World: player position load failed: %s" % str(saved_state_response.get("error", "Unknown error")))

	var initial_map: Node = first_map
	var saved_scene_path: String = str(saved_state.get("mapScenePath", ""))
	if saved_scene_path != "" and saved_scene_path != _get_map_scene_path(first_map):
		var saved_map: Node = _instantiate_map(saved_scene_path)
		if saved_map != null:
			_clear_current_map()
			$CurrentMap.add_child(saved_map)
			initial_map = saved_map
		else:
			push_warning("World: saved map '%s' could not be loaded. Falling back to initial map." % saved_scene_path)

	GameState.current_map = initial_map
	_normalize_map_tree_layer_z_indices(initial_map)
	MusicManager.play_map_music(initial_map)
	move_player_to_map(initial_map)

	if not saved_state.is_empty():
		_apply_saved_appearance_state(saved_state)
		_position_player_at_saved_state(initial_map, saved_state)
		current_teleport_revision = int(saved_state.get("teleportRevision", current_teleport_revision))
		last_saved_position_signature = _get_current_player_position_signature(true)
	elif not GameState.has_player_position:
		_position_player_at_spawn(initial_map, initial_spawn_name, player.global_position)
		_save_current_player_position_if_changed.call_deferred(true, initial_spawn_name)

	_apply_camera_limits_for_map(initial_map)
	player.refresh_map_layers()
	WorldPresenceService.connect_presence.call_deferred()
	_publish_world_presence.call_deferred(true)


func _instantiate_map(scene_path: String) -> Node:
	var target_scene: PackedScene = load(scene_path) as PackedScene
	if target_scene == null:
		return null
	return target_scene.instantiate()


func _clear_current_map() -> void:
	for child in $CurrentMap.get_children():
		$CurrentMap.remove_child(child)
		child.queue_free()


func _apply_camera_limits_for_map(map: Node) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var bounds := _get_map_visual_bounds(map)
	if not bool(bounds.get("valid", false)):
		return

	var rect: Rect2 = bounds["rect"]
	camera.limit_left = floori(rect.position.x)
	camera.limit_top = floori(rect.position.y)
	camera.limit_right = ceili(rect.position.x + rect.size.x)
	camera.limit_bottom = ceili(rect.position.y + rect.size.y)
	camera.reset_smoothing()


func _get_map_visual_bounds(map: Node) -> Dictionary:
	var visual_bounds := _get_generated_visual_bounds(map)
	if bool(visual_bounds.get("valid", false)):
		return visual_bounds

	return _get_tilemap_layer_bounds(map)


func _get_generated_visual_bounds(map: Node) -> Dictionary:
	var visuals := map.get_node_or_null("Visuals") as Node2D
	if visuals == null or not visuals.has_meta("tiled_visual_map"):
		return {"valid": false}

	var metadata: Dictionary = visuals.get_meta("tiled_visual_map")
	var width := int(metadata.get("width", 0))
	var height := int(metadata.get("height", 0))
	var tile_width := int(metadata.get("tile_width", 0))
	var tile_height := int(metadata.get("tile_height", 0))
	if width <= 0 or height <= 0 or tile_width <= 0 or tile_height <= 0:
		return {"valid": false}

	var top_left := visuals.global_position
	return {
		"valid": true,
		"rect": Rect2(top_left, Vector2(width * tile_width, height * tile_height)),
	}


func _get_tilemap_layer_bounds(map: Node) -> Dictionary:
	var rect := Rect2()
	var has_rect := false
	var layers := _collect_tilemap_layers(map)
	for layer: TileMapLayer in layers:
		if not layer.visible:
			continue

		var used_rect := layer.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue

		var top_left := layer.to_global(layer.map_to_local(used_rect.position) - Vector2(TILE_SIZE, TILE_SIZE) * 0.5)
		var bottom_right_cell := used_rect.position + used_rect.size
		var bottom_right := layer.to_global(layer.map_to_local(bottom_right_cell) - Vector2(TILE_SIZE, TILE_SIZE) * 0.5)
		var layer_rect := Rect2(top_left, bottom_right - top_left).abs()
		if has_rect:
			rect = rect.merge(layer_rect)
		else:
			rect = layer_rect
			has_rect = true

	return {
		"valid": has_rect,
		"rect": rect,
	}


func _collect_tilemap_layers(root: Node) -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers_recursive(root, layers)
	return layers


func _collect_tilemap_layers_recursive(node: Node, layers: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		layers.append(node as TileMapLayer)

	for child: Node in node.get_children():
		_collect_tilemap_layers_recursive(child, layers)

func _normalize_map_tree_layer_z_indices(map: Node) -> void:
	var trees_root: Node = map.get_node_or_null(TREE_LAYER_ROOT_NAME)
	if trees_root == null:
		return

	_normalize_tree_layer_z_indices_recursive(trees_root)

func _normalize_map_depth_layer_z_indices(map: Node) -> void:
	if map == null:
		return

	_normalize_map_tree_layer_z_indices(map)
	_build_tall_grass_visual_depth_rows(map)
	_build_structure_top_visual_depth_groups(map)

func _normalize_tree_layer_z_indices_recursive(node: Node) -> void:
	if node is TileMapLayer:
		var tile_map_layer: TileMapLayer = node as TileMapLayer
		var used_rect: Rect2i = tile_map_layer.get_used_rect()
		if used_rect.size != Vector2i.ZERO:
			var layer_bottom_y: float = tile_map_layer.global_position.y + float(used_rect.position.y + used_rect.size.y) * TILE_SIZE
			tile_map_layer.z_as_relative = false
			tile_map_layer.z_index = clampi(floori(layer_bottom_y), TREE_LAYER_Z_MIN, TREE_LAYER_Z_MAX)

	for child: Node in node.get_children():
		_normalize_tree_layer_z_indices_recursive(child)

func _build_tall_grass_visual_depth_rows(map: Node) -> void:
	var grass_layers: Array[TileMapLayer] = []
	_collect_tall_grass_visual_layers_recursive(map, grass_layers)

	for grass_layer: TileMapLayer in grass_layers:
		if bool(grass_layer.get_meta(TALL_GRASS_DEPTH_ROWS_BUILT_META, false)):
			continue

		var used_cells: Array[Vector2i] = grass_layer.get_used_cells()
		if used_cells.is_empty():
			continue

		var parent := grass_layer.get_parent()
		if parent == null:
			continue

		var rows := {}
		for cell: Vector2i in used_cells:
			var row := cell.y
			if not rows.has(row):
				rows[row] = []
			rows[row].append(cell)

		var row_group := Node2D.new()
		row_group.name = "%sDepthRows" % grass_layer.name
		row_group.set_meta(TALL_GRASS_DEPTH_ROW_META, true)
		parent.add_child(row_group)

		for row in rows.keys():
			var row_layer := TileMapLayer.new()
			row_layer.name = "%sRow%d" % [grass_layer.name, int(row)]
			row_layer.tile_set = grass_layer.tile_set
			row_layer.visible = grass_layer.visible
			row_layer.modulate = grass_layer.modulate
			row_layer.position = grass_layer.position
			row_layer.z_as_relative = false
			row_layer.z_index = _get_tall_grass_row_z_index(grass_layer, int(row))
			row_layer.set_meta(TALL_GRASS_DEPTH_ROW_META, true)
			row_group.add_child(row_layer)

			for cell: Vector2i in rows[row]:
				var source_id := grass_layer.get_cell_source_id(cell)
				if source_id == -1:
					continue
				row_layer.set_cell(
					cell,
					source_id,
					grass_layer.get_cell_atlas_coords(cell),
					grass_layer.get_cell_alternative_tile(cell)
				)

		grass_layer.visible = false
		grass_layer.set_meta(TALL_GRASS_DEPTH_ROWS_BUILT_META, true)

func _collect_tall_grass_visual_layers_recursive(node: Node, grass_layers: Array[TileMapLayer]) -> void:
	var tile_map_layer := node as TileMapLayer
	if tile_map_layer != null:
		var tiled_name := str(tile_map_layer.get_meta("tiled_name", tile_map_layer.name))
		if tiled_name == TALL_GRASS_VISUAL_LAYER_NAME and not bool(tile_map_layer.get_meta(TALL_GRASS_DEPTH_ROW_META, false)):
			grass_layers.append(tile_map_layer)

	for child: Node in node.get_children():
		_collect_tall_grass_visual_layers_recursive(child, grass_layers)

func _get_tall_grass_row_z_index(grass_layer: TileMapLayer, row: int) -> int:
	var tile_size := Vector2(TILE_SIZE, TILE_SIZE)
	if grass_layer.tile_set != null:
		tile_size = Vector2(grass_layer.tile_set.tile_size)

	var row_center_local := grass_layer.map_to_local(Vector2i(0, row))
	var row_bottom_global := grass_layer.to_global(row_center_local + Vector2(0.0, tile_size.y * 0.5)).y
	return clampi(floori(row_bottom_global) + TALL_GRASS_LAYER_Z_OFFSET, TREE_LAYER_Z_MIN, TREE_LAYER_Z_MAX)

func _build_structure_top_visual_depth_groups(map: Node) -> void:
	var structure_layers: Array[TileMapLayer] = []
	_collect_structure_top_visual_layers_recursive(map, structure_layers)

	for structure_layer: TileMapLayer in structure_layers:
		if bool(structure_layer.get_meta(STRUCTURE_TOP_DEPTH_GROUPS_BUILT_META, false)):
			continue

		var used_cells: Array[Vector2i] = structure_layer.get_used_cells()
		if used_cells.is_empty():
			continue

		var parent := structure_layer.get_parent()
		if parent == null:
			continue

		var groups := _build_connected_tile_groups(used_cells)
		var group_root := Node2D.new()
		group_root.name = "%sDepthGroups" % structure_layer.name
		group_root.set_meta(STRUCTURE_TOP_DEPTH_GROUP_META, true)
		parent.add_child(group_root)

		for group_index in range(groups.size()):
			var group: Array[Vector2i] = groups[group_index]
			var group_layer := TileMapLayer.new()
			group_layer.name = "%sGroup%d" % [structure_layer.name, group_index]
			group_layer.tile_set = structure_layer.tile_set
			group_layer.visible = structure_layer.visible
			group_layer.modulate = structure_layer.modulate
			group_layer.position = structure_layer.position
			group_layer.z_as_relative = false
			group_layer.z_index = _get_tile_group_bottom_z_index(structure_layer, group, 0)
			group_layer.set_meta(STRUCTURE_TOP_DEPTH_GROUP_META, true)
			group_root.add_child(group_layer)

			for cell: Vector2i in group:
				var source_id := structure_layer.get_cell_source_id(cell)
				if source_id == -1:
					continue
				group_layer.set_cell(
					cell,
					source_id,
					structure_layer.get_cell_atlas_coords(cell),
					structure_layer.get_cell_alternative_tile(cell)
				)

		structure_layer.visible = false
		structure_layer.set_meta(STRUCTURE_TOP_DEPTH_GROUPS_BUILT_META, true)

func _collect_structure_top_visual_layers_recursive(node: Node, structure_layers: Array[TileMapLayer]) -> void:
	var tile_map_layer := node as TileMapLayer
	if tile_map_layer != null:
		var tiled_name := str(tile_map_layer.get_meta("tiled_name", tile_map_layer.name))
		if STRUCTURE_TOP_VISUAL_LAYER_NAMES.has(tiled_name) and not bool(tile_map_layer.get_meta(STRUCTURE_TOP_DEPTH_GROUP_META, false)):
			structure_layers.append(tile_map_layer)

	for child: Node in node.get_children():
		_collect_structure_top_visual_layers_recursive(child, structure_layers)

func _build_connected_tile_groups(cells: Array[Vector2i]) -> Array[Array]:
	var remaining := {}
	for cell: Vector2i in cells:
		remaining[cell] = true

	var groups: Array[Array] = []
	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	while not remaining.is_empty():
		var first_cell: Vector2i = remaining.keys()[0]
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [first_cell]
		remaining.erase(first_cell)

		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			group.append(cell)

			for direction: Vector2i in directions:
				var neighbor := cell + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					stack.append(neighbor)

		groups.append(group)

	return groups

func _get_tile_group_bottom_z_index(layer: TileMapLayer, group: Array[Vector2i], z_offset: int) -> int:
	var tile_size := Vector2(TILE_SIZE, TILE_SIZE)
	if layer.tile_set != null:
		tile_size = Vector2(layer.tile_set.tile_size)

	var bottom_y := -INF
	for cell: Vector2i in group:
		var cell_bottom_y := layer.to_global(layer.map_to_local(cell) + Vector2(0.0, tile_size.y * 0.5)).y
		bottom_y = maxf(bottom_y, cell_bottom_y)

	if is_inf(bottom_y):
		return 0

	return clampi(floori(bottom_y) + z_offset, TREE_LAYER_Z_MIN, TREE_LAYER_Z_MAX)


func _ensure_remote_players_container() -> void:
	if remote_players_container != null and is_instance_valid(remote_players_container):
		_order_remote_players_container()
		return

	remote_players_container = Node2D.new()
	remote_players_container.name = "RemotePlayers"
	add_child(remote_players_container)
	_order_remote_players_container()


func _order_remote_players_container() -> void:
	if remote_players_container == null or not is_instance_valid(remote_players_container):
		return
	if player == null or not is_instance_valid(player):
		return

	# Equal z_index falls back to scene tree order. Keep remote players before
	# the local player so your own character wins exact overlap ties.
	move_child(remote_players_container, player.get_index())


func _connect_world_presence_signals() -> void:
	if not WorldPresenceService.roster_changed.is_connected(_on_world_presence_roster_changed):
		WorldPresenceService.roster_changed.connect(_on_world_presence_roster_changed)
	if not WorldPresenceService.roster_player_changed.is_connected(_on_world_presence_roster_player_changed):
		WorldPresenceService.roster_player_changed.connect(_on_world_presence_roster_player_changed)
	if not WorldPresenceService.roster_player_removed.is_connected(_on_world_presence_roster_player_removed):
		WorldPresenceService.roster_player_removed.connect(_on_world_presence_roster_player_removed)


func _publish_world_presence(force := false) -> void:
	if not AuthService.is_authenticated() or player == null or GameState.current_map == null:
		return

	var signature := _get_current_player_position_signature()
	if not force and signature == last_presence_position_signature:
		return

	last_presence_position_signature = signature
	WorldPresenceService.update_position(_build_current_player_position_state(""))


func _track_playtime(delta: float) -> void:
	if not AuthService.is_authenticated() or is_loading_map:
		return

	playtime_elapsed += delta
	if playtime_elapsed < 1.0:
		return

	var elapsed_seconds: int = floori(playtime_elapsed)
	playtime_elapsed -= float(elapsed_seconds)
	unflushed_playtime_seconds += elapsed_seconds
	PlayerSave.playtime_seconds += elapsed_seconds
	if float(unflushed_playtime_seconds) >= PLAYTIME_FLUSH_INTERVAL_SECONDS:
		_flush_playtime_if_needed.call_deferred(false)


func _flush_playtime_if_needed(force: bool = false) -> void:
	if is_flushing_playtime or not AuthService.is_authenticated():
		return
	if unflushed_playtime_seconds <= 0:
		return
	if not force and float(unflushed_playtime_seconds) < PLAYTIME_FLUSH_INTERVAL_SECONDS:
		return

	is_flushing_playtime = true
	var delta_seconds: int = mini(unflushed_playtime_seconds, 120)
	var result: Dictionary = await PlayerStatsService.add_playtime(delta_seconds)
	if bool(result.get("success", false)):
		unflushed_playtime_seconds = maxi(unflushed_playtime_seconds - delta_seconds, 0)
		PlayerStatsService.apply_stats_result(result)
	else:
		push_warning("World: playtime save failed: %s" % str(result.get("error", "Unknown error")))
	is_flushing_playtime = false
	if unflushed_playtime_seconds >= int(PLAYTIME_FLUSH_INTERVAL_SECONDS):
		_flush_playtime_if_needed.call_deferred(false)


func _apply_remote_player_states(player_states: Array, prune_missing := true) -> void:
	_ensure_remote_players_container()

	var seen_user_ids := {}
	var current_map_id := _get_map_id(GameState.current_map)
	for player_state_value in player_states:
		if typeof(player_state_value) != TYPE_DICTIONARY:
			continue

		var player_state: Dictionary = player_state_value
		var user_id := int(player_state.get("userId", 0))
		if user_id <= 0:
			continue

		var user_key := str(user_id)
		if str(player_state.get("mapId", "")) != current_map_id:
			if not prune_missing:
				var stale_avatar: Node2D = remote_player_avatars.get(user_key, null)
				remote_player_avatars.erase(user_key)
				if stale_avatar != null and is_instance_valid(stale_avatar):
					stale_avatar.queue_free()
			continue

		seen_user_ids[user_key] = true
		var avatar: Node2D = remote_player_avatars.get(user_key, null)
		if avatar == null or not is_instance_valid(avatar):
			var new_avatar: Variant = REMOTE_PLAYER_AVATAR_SCRIPT.new()
			if not new_avatar is Node2D:
				push_warning("World: remote player avatar script did not create a Node2D.")
				continue
			avatar = new_avatar as Node2D
			remote_player_avatars[user_key] = avatar
			remote_players_container.add_child(avatar)
			var interaction_callable := Callable(self, "_on_remote_player_interaction_requested")
			if avatar.has_signal("interaction_requested") and not avatar.is_connected("interaction_requested", interaction_callable):
				avatar.connect("interaction_requested", interaction_callable)

		avatar.call("apply_state", player_state)

	_sort_remote_player_avatar_nodes()

	if not prune_missing:
		return

	for user_key in remote_player_avatars.keys():
		if seen_user_ids.has(user_key):
			continue

		var avatar: Node2D = remote_player_avatars.get(user_key, null)
		remote_player_avatars.erase(user_key)
		if avatar != null and is_instance_valid(avatar):
			avatar.queue_free()


func _sort_remote_player_avatar_nodes() -> void:
	if remote_players_container == null or not is_instance_valid(remote_players_container):
		return

	var avatars := remote_players_container.get_children()
	avatars.sort_custom(_compare_remote_player_avatar_nodes)
	for index in avatars.size():
		remote_players_container.move_child(avatars[index], index)


func _compare_remote_player_avatar_nodes(a: Node, b: Node) -> bool:
	return _get_remote_player_avatar_user_id(a) < _get_remote_player_avatar_user_id(b)


func _get_remote_player_avatar_user_id(avatar: Node) -> int:
	if avatar == null:
		return 0

	var user_id_value: Variant = avatar.get("user_id")
	if user_id_value == null:
		return 0

	return int(user_id_value)


func _clear_remote_players() -> void:
	get_tree().call_group("player_interaction_coordinator", "close_for_map_transition")
	pending_remote_player_interaction.clear()
	remote_player_interaction_pending = false
	for avatar in remote_player_avatars.values():
		if avatar != null and is_instance_valid(avatar):
			avatar.queue_free()
	remote_player_avatars.clear()


func _remove_remote_player(user_id: int) -> void:
	var user_key := str(user_id)
	var avatar: Node2D = remote_player_avatars.get(user_key, null)
	remote_player_avatars.erase(user_key)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()


func _on_world_presence_roster_changed(_players: Array, _roster_revision: int) -> void:
	_apply_remote_player_states(WorldPresenceService.get_current_map_players(), true)


func _on_world_presence_roster_player_changed(player_state: Dictionary, _roster_revision: int) -> void:
	_apply_remote_player_states([player_state], false)


func _on_world_presence_roster_player_removed(user_id: int, _roster_revision: int) -> void:
	_remove_remote_player(user_id)

func _on_remote_player_interaction_requested(player_state: Dictionary, world_position: Vector2) -> void:
	var candidate := {
		"player": player_state.duplicate(true),
		"worldPosition": world_position,
	}
	if pending_remote_player_interaction.is_empty() or _is_remote_interaction_candidate_above(candidate, pending_remote_player_interaction):
		pending_remote_player_interaction = candidate
	if not remote_player_interaction_pending:
		remote_player_interaction_pending = true
		_resolve_remote_player_interaction.call_deferred()

func _resolve_remote_player_interaction() -> void:
	remote_player_interaction_pending = false
	if pending_remote_player_interaction.is_empty():
		return
	var candidate := pending_remote_player_interaction.duplicate(true)
	pending_remote_player_interaction.clear()
	var player_state: Dictionary = _dictionary_from_value(candidate.get("player", {}))
	var world_position: Vector2 = candidate.get("worldPosition", Vector2.ZERO)
	var screen_position := get_viewport().get_canvas_transform() * world_position
	get_tree().call_group("player_interaction_coordinator", "open_context_for_player", player_state, screen_position)

func _is_remote_interaction_candidate_above(first: Dictionary, second: Dictionary) -> bool:
	var first_position: Vector2 = first.get("worldPosition", Vector2.ZERO)
	var second_position: Vector2 = second.get("worldPosition", Vector2.ZERO)
	if not is_equal_approx(first_position.y, second_position.y):
		return first_position.y > second_position.y
	return int(_dictionary_from_value(first.get("player", {})).get("userId", 0)) > int(_dictionary_from_value(second.get("player", {})).get("userId", 0))


func _save_current_player_position_if_changed(force := false, spawn_marker := "") -> void:
	if not AuthService.is_authenticated() or player == null:
		return
	if _is_player_position_save_blocked_by_teleport():
		return
	if is_saving_player_position:
		has_pending_player_position_save = true
		return

	var signature: String = _get_current_player_position_signature(true)
	if not force and signature == last_saved_position_signature:
		return

	await _save_current_player_position(signature, spawn_marker, true)


func _save_current_player_position(
	signature: String,
	spawn_marker: String,
	use_confirmed_appearance: bool = false,
	mark_current_appearance_confirmed: bool = false
) -> Dictionary:
	if _is_player_position_save_blocked_by_teleport():
		return {
			"success": false,
			"error": _get_player_position_save_block_reason(),
		}
	is_saving_player_position = true
	if _is_player_position_save_blocked_by_teleport():
		is_saving_player_position = false
		return {
			"success": false,
			"error": _get_player_position_save_block_reason(),
		}
	var state: Dictionary = _build_current_player_position_state(spawn_marker, use_confirmed_appearance)
	if _is_player_position_save_blocked_by_teleport():
		is_saving_player_position = false
		return {
			"success": false,
			"error": _get_player_position_save_block_reason(),
		}
	var result: Dictionary = await PlayerGameStateService.save_player_position(state)
	if bool(result.get("success", false)):
		var response_state: Dictionary = _dictionary_from_value(result.get("state", {}))
		current_teleport_revision = int(response_state.get("teleportRevision", current_teleport_revision))
		last_saved_position_signature = signature
		if mark_current_appearance_confirmed:
			confirmed_appearance_state = PlayerSave.to_appearance_state().duplicate(true)
		elif confirmed_appearance_state.is_empty():
			var appearance_value: Variant = state.get("appearance", {})
			if appearance_value is Dictionary:
				confirmed_appearance_state = (appearance_value as Dictionary).duplicate(true)
	else:
		if str(result.get("error", "")) == "FORCED_TELEPORT_PENDING":
			_mark_authorized_teleport_apply_failed()
		push_warning("World: player position save failed: %s" % str(result.get("error", "Unknown error")))
	is_saving_player_position = false
	if has_pending_player_position_save:
		has_pending_player_position_save = false
		_save_current_player_position_if_changed.call_deferred(true)
	return result


func _build_current_player_position_state(spawn_marker: String, use_confirmed_appearance: bool = false) -> Dictionary:
	var current_map: Node = GameState.current_map
	var position: Vector2 = _get_current_player_persistent_position()
	var appearance_state: Dictionary = _get_confirmed_appearance_state() if use_confirmed_appearance else _get_current_appearance_presence_state()
	var state: Dictionary = {
		"mapId": _get_map_id(current_map),
		"mapScenePath": _get_map_scene_path(current_map),
		"position": {
			"x": position.x,
			"y": position.y,
		},
		"gender": PlayerSave.gender,
		"facingDirection": _direction_to_name(player.last_direction),
		"spawnMarker": spawn_marker,
		"appearance": appearance_state,
		"roles": _get_current_role_presence_state(),
		"selectedRoleBadge": GameState.selected_role_badge,
		"activityState": "battle" if is_in_battle else "idle",
		"activityContext": _get_current_activity_context(),
		"teleportRevision": current_teleport_revision,
	}
	if player.has_method("get_network_movement_state"):
		state["movement"] = player.call("get_network_movement_state")
	state["follower"] = _get_current_follower_presence_state()
	return state


func _get_current_activity_context() -> Dictionary:
	if not is_in_battle:
		return {}
	return {
		"kind": active_battle_kind,
		"battleId": active_battle_id,
	}


func _save_player_activity_state_deferred(activity_state: String, activity_context: Dictionary = {}) -> void:
	_save_player_activity_state.call_deferred(activity_state, activity_context)


func _save_player_activity_state(activity_state: String, activity_context: Dictionary = {}) -> void:
	var result: Dictionary = await PlayerGameStateService.save_player_activity_state(activity_state, activity_context)
	if not bool(result.get("success", false)):
		push_warning("World: activity state save failed: %s" % str(result.get("error", "Unknown error")))


func _get_current_appearance_presence_state() -> Dictionary:
	return PlayerSave.to_appearance_state()

func _get_confirmed_appearance_state() -> Dictionary:
	if confirmed_appearance_state.is_empty():
		return _get_current_appearance_presence_state()
	return confirmed_appearance_state.duplicate(true)

func _apply_saved_appearance_state(state: Dictionary) -> void:
	var appearance: Dictionary = _dictionary_from_value(state.get("appearance", {}))
	PlayerSave.apply_appearance_state(appearance)
	confirmed_appearance_state = PlayerSave.to_appearance_state().duplicate(true)

	var body_id: String = str(appearance.get("body", "")).strip_edges()
	if body_id == "":
		return

	if player != null and player.has_method("refresh_appearance"):
		player.call("refresh_appearance")
	elif player != null and player.has_method("set_body_appearance"):
		player.call("set_body_appearance", body_id)


func _get_current_role_presence_state() -> Array:
	var roles_value: Variant = AuthService.current_user.get("roles", [])
	if not roles_value is Array:
		return []

	var roles: Array = roles_value as Array
	var presence_roles: Array = []
	for role_value: Variant in roles:
		if not role_value is Dictionary:
			continue

		var role: Dictionary = role_value as Dictionary
		var display_value: Variant = role.get("display", {})
		presence_roles.append({
			"id": str(role.get("id", "")),
			"category": str(role.get("category", "")),
			"label": str(role.get("label", role.get("name", ""))),
			"shortLabel": str(role.get("shortLabel", role.get("badge", ""))),
			"color": str(role.get("color", "")),
			"priority": int(role.get("priority", 0)),
			"display": display_value.duplicate(true) if display_value is Dictionary else {},
		})

	return presence_roles


func _get_current_follower_presence_state() -> Dictionary:
	if not GameState.show_follower or PlayerSave.party.is_empty():
		return {"visible": false}

	var lead_pokemon: Pokemon = PlayerSave.party[0]
	if lead_pokemon == null or lead_pokemon.species == "":
		return {"visible": false}

	return {
		"visible": true,
		"species": lead_pokemon.species,
		"shiny": lead_pokemon.shiny,
	}


func _get_current_player_position_signature(use_confirmed_appearance: bool = false) -> String:
	var current_map: Node = GameState.current_map
	var position: Vector2 = _get_current_player_persistent_position()
	var follower_state := _get_current_follower_presence_state()
	var appearance_state := _get_confirmed_appearance_state() if use_confirmed_appearance else _get_current_appearance_presence_state()
	return "%s|%s|%0.1f|%0.1f|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		_get_map_id(current_map),
		_get_map_scene_path(current_map),
		roundf(position.x / POSITION_SAVE_EPSILON) * POSITION_SAVE_EPSILON,
		roundf(position.y / POSITION_SAVE_EPSILON) * POSITION_SAVE_EPSILON,
		PlayerSave.gender,
		_direction_to_name(player.last_direction),
		GameState.selected_role_badge,
		str(follower_state.get("visible", false)),
		str(follower_state.get("species", "")),
		str(follower_state.get("shiny", false)),
		str(appearance_state.get("body", "")),
		str(appearance_state.get("hair", "")),
		str(appearance_state.get("hair_style_index", "")),
		str(appearance_state.get("headgear", "")),
		str(appearance_state.get("facegear", "")),
		str(appearance_state.get("top", "")),
		str(appearance_state.get("bottom", "")),
		str(appearance_state.get("shoes", "")),
		str(appearance_state.get("hair_color", "")),
		str(appearance_state.get("skin_tone", "")),
		str(appearance_state.get("eye_color", "")),
	]


func _get_map_id(map: Node) -> String:
	if map == null:
		return ""
	if map.has_method("get_map_id"):
		return str(map.call("get_map_id"))
	var scene_path: String = _get_map_scene_path(map)
	if scene_path != "":
		return scene_path
	return str(map.name)


func _get_map_scene_path(map: Node) -> String:
	if map == null:
		return ""
	return str(map.scene_file_path)


func _direction_to_name(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y >= 0.0 else "up"


func _direction_from_name(direction_name: String) -> Vector2:
	match direction_name.to_lower():
		"right":
			return Vector2.RIGHT
		"left":
			return Vector2.LEFT
		"up":
			return Vector2.UP
		_:
			return Vector2.DOWN


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _snap_world_position(position: Vector2) -> Vector2:
	return Vector2(roundf(position.x), roundf(position.y))


func _get_current_player_persistent_position() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var position: Vector2 = player.global_position
	if player.has_method("get_persistent_world_position"):
		var position_value: Variant = player.call("get_persistent_world_position")
		if position_value is Vector2:
			position = position_value as Vector2

	return _snap_world_position_to_map_tile_center(GameState.current_map, position)


func _snap_world_position_to_map_tile_center(map: Node, position: Vector2) -> Vector2:
	var tilemap := _get_position_reference_tilemap(map)
	if tilemap == null:
		return _snap_world_position(position)

	var tile_position: Vector2i = tilemap.local_to_map(tilemap.to_local(position))
	return _snap_world_position(tilemap.to_global(tilemap.map_to_local(tile_position)))


func _get_position_reference_tilemap(map: Node) -> TileMapLayer:
	if map == null or not is_instance_valid(map):
		return null

	for layer_name in ["Collision", "TallGrass", "LedgeDown", "LedgeUp", "LedgeLeft", "LedgeRight"]:
		var tilemap := map.get_node_or_null(layer_name) as TileMapLayer
		if tilemap != null:
			return tilemap

	return null


func _load_player_party_state() -> void:
	var party_response: Dictionary = await PlayerPartyStateService.load_party()
	if not bool(party_response.get("success", false)):
		push_warning("World: player party load failed: %s" % str(party_response.get("error", "Unknown error")))
		return
	if not bool(party_response.get("hasParty", false)):
		return

	var party_value: Variant = party_response.get("party", [])
	if not (party_value is Array):
		return

	PlayerSave.replace_party_from_state(party_value as Array)

func create_dev_wild_battle_response(wild_pokemon: Pokemon) -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)
	var player_payload: Dictionary = BattleApiPayloads.from_player_save(PlayerSave)
	
	var response: Dictionary = await BattleApiClient.create_dev_wild_battle(
		battle_request,
		player_payload,
		wild_pokemon.to_battle_dict(),
		_get_current_wild_battle_origin()
	)
	
	battle_request.queue_free()
	return response

func create_triggered_wild_battle_response(area_id: String, encounter_type: String = "grass") -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)
	var player_payload: Dictionary = BattleApiPayloads.from_player_save(PlayerSave)

	var response: Dictionary = await BattleApiClient.create_triggered_wild_battle(
		battle_request,
		player_payload,
		area_id,
		encounter_type,
		_get_current_wild_battle_origin()
	)

	battle_request.queue_free()
	return response

func _get_current_wild_battle_origin() -> Dictionary:
	var current_map: Node = GameState.current_map as Node
	if current_map == null:
		return {}

	var metadata: Dictionary = {}
	if current_map.has_method("get_location_metadata"):
		var metadata_value: Variant = current_map.call("get_location_metadata")
		if metadata_value is Dictionary:
			metadata = (metadata_value as Dictionary).duplicate(true)

	var map_id := ""
	var location_name := ""
	var region_name := ""
	if current_map.has_method("get_map_id"):
		map_id = str(current_map.call("get_map_id")).strip_edges()
	if current_map.has_method("get_map_display_name"):
		location_name = str(current_map.call("get_map_display_name")).strip_edges()
	if current_map.has_method("get_map_region_name"):
		region_name = str(current_map.call("get_map_region_name")).strip_edges()

	var origin: Dictionary = {}
	_set_origin_text_value(origin, "locationId", str(metadata.get("locationId", map_id)).strip_edges())
	_set_origin_text_value(origin, "locationName", str(metadata.get("locationName", location_name)).strip_edges())
	_set_origin_text_value(origin, "regionId", str(metadata.get("regionId", region_name.to_lower().replace(" ", "_"))).strip_edges())
	_set_origin_text_value(origin, "regionName", str(metadata.get("regionName", region_name)).strip_edges())
	_set_origin_text_value(origin, "mapId", str(metadata.get("mapId", map_id)).strip_edges())
	return origin

func _set_origin_text_value(origin: Dictionary, key: String, value: String) -> void:
	var cleaned := value.strip_edges()
	if cleaned != "":
		origin[key] = cleaned

func create_trainer_battle_response(trainer_id: String) -> Dictionary:
	var battle_request := HTTPRequest.new()
	add_child(battle_request)
	var player_payload: Dictionary = BattleApiPayloads.from_player_save(PlayerSave)

	var response: Dictionary = await BattleApiClient.create_trainer_battle(
		battle_request,
		player_payload,
		trainer_id
	)

	battle_request.queue_free()
	return response


func _mount_battle_ui() -> bool:
	if BATTLE_SCENE == null or battle_ui_host == null:
		return false

	_clear_battle_ui_instance()
	battle_instance = BATTLE_SCENE.instantiate()
	battle_ui_host.add_child(battle_instance)
	battle_ui_host.visible = true

	if battle_instance.has_signal("battle_ended"):
		battle_instance.battle_ended.connect(_on_battle_ended)

	return true


func _clear_battle_ui_instance() -> void:
	if battle_instance != null and is_instance_valid(battle_instance):
		if battle_instance.get_parent() != null:
			battle_instance.get_parent().remove_child(battle_instance)
		battle_instance.queue_free()
	battle_instance = null
	if battle_ui_host != null:
		battle_ui_host.visible = false

func start_dev_wild_battle(wild_pokemon: Pokemon) -> void:
	if is_in_battle:
		return
		
	is_in_battle = true
	active_battle_kind = "wild"
	active_battle_id = ""
	active_wild_pokemon_species = wild_pokemon.species if wild_pokemon != null else "wild Pokemon"
	_lock_overworld_for_battle()
	
	var response: Dictionary = await create_dev_wild_battle_response(wild_pokemon)
	if not response.get("success", false):
		push_warning("World.start_dev_wild_battle failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	active_battle_id = str(response.get("battleId", ""))
	_save_player_activity_state_deferred("battle", _get_current_activity_context())

	if not _mount_battle_ui():
		push_error("World.start_dev_wild_battle failed: could not load battle scene.")
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	MusicManager.play_wild_battle_music()
	
	await battle_instance.setup_wild_battle_from_response(
		PlayerSave.party[0],
		wild_pokemon,
		response
	)

func start_triggered_wild_battle_for_area(area_id: String, encounter_type: String = "grass") -> void:
	if is_in_battle:
		return

	is_in_battle = true
	active_battle_kind = "wild"
	active_battle_id = ""
	active_wild_pokemon_species = "wild Pokemon"
	_lock_overworld_for_battle()

	var response: Dictionary = await create_triggered_wild_battle_response(area_id, encounter_type)
	if not response.get("success", false):
		push_warning("World.start_triggered_wild_battle_for_area failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	active_battle_id = str(response.get("battleId", ""))
	_save_player_activity_state_deferred("battle", _get_current_activity_context())

	var wild_pokemon_data: Dictionary = response.get("wildPokemon", {})
	var wild_pokemon: Pokemon = PokemonFactory.create_pokemon_from_backend_payload(wild_pokemon_data)
	if wild_pokemon == null:
		push_warning("World.start_triggered_wild_battle_for_area failed: backend wild Pokemon payload could not be loaded for display.")
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return
	active_wild_pokemon_species = wild_pokemon.species

	if not _mount_battle_ui():
		push_error("World.start_triggered_wild_battle_for_area failed: could not load battle scene.")
		_abort_battle_start()
		await GameErrorDialogService.show_report_to_staff_message()
		return

	MusicManager.play_wild_battle_music()

	await battle_instance.setup_wild_battle_from_response(
		PlayerSave.party[0],
		wild_pokemon,
		response
	)

func start_trainer_battle(trainer_data: Dictionary) -> bool:
	if is_in_battle:
		return false

	var trainer_id := str(trainer_data.get("id", ""))
	if trainer_id == "":
		push_warning("World.start_trainer_battle failed: trainer has no id.")
		return false

	is_in_battle = true
	active_battle_kind = "trainer"
	active_battle_id = ""
	active_wild_pokemon_species = ""
	active_trainer_name = str(trainer_data.get("name", "Trainer"))
	_lock_overworld_for_battle()

	var response: Dictionary = await create_trainer_battle_response(trainer_id)
	if not response.get("success", false):
		push_warning("World.start_trainer_battle failed: %s" % str(response.get("error", "Unknown error")))
		_abort_battle_start()
		return false
	active_battle_id = str(response.get("battleId", ""))
	_save_player_activity_state_deferred("battle", _get_current_activity_context())

	if not _mount_battle_ui():
		push_error("World.start_trainer_battle failed: could not load battle scene.")
		_abort_battle_start()
		return false

	MusicManager.play_trainer_battle_music()

	await battle_instance.setup_trainer_battle_from_response(
		PlayerSave.party[0],
		trainer_data,
		response
	)

	return true

func start_pvp_battle_from_response(response: Dictionary) -> bool:
	if is_in_battle:
		if not await _interrupt_current_battle_for_pvp_match():
			return false
	if not bool(response.get("success", false)):
		push_warning("World.start_pvp_battle_from_response failed: %s" % str(response.get("error", "Unknown error")))
		return false

	is_in_battle = true
	active_battle_kind = "pvp"
	active_battle_id = str(response.get("battleId", ""))
	active_wild_pokemon_species = ""
	active_trainer_name = ""
	_save_player_activity_state_deferred("battle", _get_current_activity_context())
	_lock_overworld_for_battle()

	if not _mount_battle_ui():
		push_error("World.start_pvp_battle_from_response failed: could not load battle scene.")
		_abort_battle_start()
		return false

	MusicManager.play_pvp_battle_music()
	await battle_instance.setup_pvp_battle_from_response(
		PlayerSave.party[0] if not PlayerSave.party.is_empty() else null,
		response
	)
	return true

func _interrupt_current_battle_for_pvp_match() -> bool:
	if not is_in_battle:
		return true
	if active_battle_kind == "pvp":
		return false
	await _forfeit_current_non_pvp_battle_for_pvp_match()
	end_wild_battle()
	return true

func _forfeit_current_non_pvp_battle_for_pvp_match() -> void:
	var battle_id := active_battle_id.strip_edges()
	if battle_id == "":
		return
	var battle_kind := active_battle_kind.strip_edges()
	if battle_kind == "" or battle_kind == "pvp":
		return

	var forfeit_request := HTTPRequest.new()
	add_child(forfeit_request)
	var response: Dictionary = await BattleApiClient.send_choice(
		forfeit_request,
		battle_id,
		"p1",
		"forfeit",
		1
	)
	forfeit_request.queue_free()

	if not bool(response.get("success", false)):
		push_warning(
			"World: could not register %s battle %s as a PvP queue forfeit: %s" % [
				battle_kind,
				battle_id,
				str(response.get("error", "Unknown error")),
			]
		)
	
func end_wild_battle() -> void:
	if battle_instance != null and battle_instance.has_signal("battle_ended"):
		var ended_callback := Callable(self, "_on_battle_ended")
		if battle_instance.is_connected("battle_ended", ended_callback):
			battle_instance.disconnect("battle_ended", ended_callback)
	_clear_battle_ui_instance()
	is_in_battle = false
	active_battle_kind = ""
	active_battle_id = ""
	active_wild_pokemon_species = ""
	active_trainer_name = ""
	_save_player_activity_state_deferred("idle")
	_unlock_overworld_after_battle()
	MusicManager.play_overworld_music()
	
func _on_battle_ended(result: Dictionary) -> void:
	var should_claim_wild_reward := _should_claim_wild_battle_reward(result)
	var should_claim_trainer_reward := _should_claim_trainer_battle_reward(result)
	var should_respawn_after_loss := _should_respawn_after_battle_loss(result, active_battle_kind)
	var reward_battle_id := active_battle_id
	var reward_species := active_wild_pokemon_species
	var reward_trainer_name := active_trainer_name
	end_wild_battle()
	_notify_caught_pokemon_if_needed(result)
	if should_respawn_after_loss:
		await _respawn_after_battle_loss()
		return
	if should_claim_wild_reward and reward_battle_id != "":
		await _award_wild_battle_money(reward_battle_id, reward_species)
	if should_claim_trainer_reward and reward_battle_id != "":
		await _award_trainer_battle_rewards(reward_battle_id, reward_trainer_name)


func _should_respawn_after_battle_loss(result: Dictionary, battle_kind: String) -> bool:
	if battle_kind not in ["wild", "trainer"]:
		return false

	var reason := str(result.get("reason", "")).strip_edges().to_lower()
	if reason in ["caught", "flee"]:
		return false
	if reason in ["forfeit", "loss", "blackout"]:
		return true
	if reason == "win" and _is_player_battle_winner(str(result.get("winner", ""))):
		return false

	var winner := str(result.get("winner", "")).strip_edges().to_lower()
	if winner.is_empty():
		return false
	return winner not in ["p1", "player 1", "player1"] and bool(result.get("localPartyDefeated", _is_current_party_defeated()))


func _respawn_after_battle_loss() -> void:
	var result: Dictionary = await PlayerGameStateService.respawn_player()
	if not bool(result.get("success", false)):
		push_warning("World: respawn after battle loss failed: %s" % str(result.get("error", "Unknown error")))
		await _fallback_respawn_after_battle_loss()
		return

	_apply_respawn_party_response(_dictionary_from_value(result.get("party", {})))
	var position_state := _dictionary_from_value(result.get("position", {}))
	if position_state.is_empty():
		push_warning("World: respawn response did not include a position.")
		await _fallback_respawn_after_battle_loss()
		return

	position_state = _normalize_respawn_position_state(position_state)
	var apply_result: Dictionary = await apply_authorized_teleport_state(position_state)
	if not bool(apply_result.get("success", false)):
		push_warning("World: respawn position apply failed: %s" % str(apply_result.get("error", "Unknown error")))
		return
	get_tree().call_group("ui_overlay", "add_system_message", "You blacked out, returned to your last heal point, and your party was healed.")


func _fallback_respawn_after_battle_loss() -> void:
	var default_respawn_state := _get_default_healer_respawn_state()
	var party_heal_service := get_node_or_null("/root/PartyHealService")
	if party_heal_service != null and party_heal_service.has_method("heal_current_party_and_save"):
		await party_heal_service.call("heal_current_party_and_save")

	var apply_result: Dictionary = await apply_authorized_teleport_state(default_respawn_state)
	if not bool(apply_result.get("success", false)):
		push_warning("World: fallback respawn position apply failed: %s" % str(apply_result.get("error", "Unknown error")))
		get_tree().call_group("ui_overlay", "add_system_message", "You blacked out, but the default heal point could not be loaded.")
		return

	get_tree().call_group("ui_overlay", "add_system_message", "You blacked out and returned to Nurse Joy.")


func _get_default_healer_respawn_state() -> Dictionary:
	return {
		"mapId": "kanto_pallet_town",
		"mapScenePath": "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn",
		"position": {
			"x": 368.0,
			"y": 272.0,
		},
		"facingDirection": "down",
		"spawnMarker": "HealNPC",
		"markerId": "pallet_town_heal_npc",
	}


func _normalize_respawn_position_state(position_state: Dictionary) -> Dictionary:
	var normalized_state := position_state.duplicate(true)
	var map_id := str(normalized_state.get("mapId", "")).strip_edges()
	var marker_id := str(normalized_state.get("markerId", "")).strip_edges()
	var spawn_marker := str(normalized_state.get("spawnMarker", "")).strip_edges()
	if map_id != "kanto_pallet_town" or spawn_marker != "":
		return normalized_state

	if marker_id not in ["", "pallet_town_heal_npc", "pallet_town_initial_spawn"]:
		return normalized_state

	normalized_state["spawnMarker"] = "HealNPC"
	normalized_state["markerId"] = "pallet_town_heal_npc"
	normalized_state["position"] = {
		"x": 368.0,
		"y": 272.0,
	}
	return normalized_state


func _apply_respawn_party_response(party_response: Dictionary) -> void:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null or not player_save.has_method("replace_party_from_state"):
		return
	var party_value: Variant = party_response.get("party", [])
	if party_value is Array:
		player_save.call("replace_party_from_state", party_value as Array)


func _is_current_party_defeated() -> bool:
	var party_value: Variant = PlayerSave.get("party")
	if not (party_value is Array):
		return false

	var party: Array = party_value as Array
	var has_pokemon := false
	for pokemon_value: Variant in party:
		var pokemon := pokemon_value as Pokemon
		if pokemon == null:
			continue
		has_pokemon = true
		if pokemon.current_hp > 0:
			return false
	return has_pokemon

func _notify_caught_pokemon_if_needed(result: Dictionary) -> void:
	if str(result.get("reason", "")) != "caught":
		return

	var pokemon_payload := _extract_caught_pokemon_chat_payload(result.get("pokemon", {}))
	if pokemon_payload.is_empty():
		return

	var species := str(pokemon_payload.get("species", "Pokemon")).strip_edges()
	if species == "":
		species = "Pokemon"

	var message := "You caught %s!" % species
	if result.has("addedToParty") and bool(result.get("addedToParty", false)):
		message = "You caught %s! Added to your party." % species

	get_tree().call_group("ui_overlay", "add_system_pokemon_message", message, [pokemon_payload])

func _extract_caught_pokemon_chat_payload(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}

	var wrapper: Dictionary = value as Dictionary
	var payload: Dictionary = wrapper.duplicate(true)
	var nested_value: Variant = wrapper.get("pokemon", {})
	if nested_value is Dictionary:
		payload = (nested_value as Dictionary).duplicate(true)
		var owned_id := str(wrapper.get("id", "")).strip_edges()
		if owned_id != "" and not payload.has("ownedPokemonId"):
			payload["ownedPokemonId"] = owned_id

	var species := str(payload.get("species", "")).strip_edges()
	if species == "":
		return {}
	return payload

func _should_claim_wild_battle_reward(result: Dictionary) -> bool:
	if active_battle_kind != "wild":
		return false
	if str(result.get("reason", "")) != "win":
		return false
	if not _is_player_battle_winner(str(result.get("winner", ""))):
		return false

	return true

func _should_claim_trainer_battle_reward(result: Dictionary) -> bool:
	if active_battle_kind != "trainer":
		return false
	if str(result.get("reason", "")) != "win":
		return false
	if not _is_player_battle_winner(str(result.get("winner", ""))):
		return false

	return true

func _award_wild_battle_money(battle_id: String, pokemon_species: String) -> void:
	var previous_money: int = max(int(PlayerSave.money), 0)
	var wallet_result: Dictionary = await PlayerWalletService.award_wild_battle_money(battle_id)
	print("[EXP_DEBUG] wild reward response battle=", battle_id, " success=", wallet_result.get("success", false), " reward=", wallet_result.get("reward", {}), " party=", wallet_result.get("party", []))
	if bool(wallet_result.get("success", false)):
		PlayerWalletService.apply_wallet_result(wallet_result)
		for pokemon: Pokemon in PlayerSave.party:
			if pokemon != null:
				print("[EXP_DEBUG] party after reward id=", pokemon.owned_pokemon_id, " species=", pokemon.species, " level=", pokemon.level, " exp=", pokemon.experience, " floor=", pokemon.current_level_exp, " next=", pokemon.next_level_exp)
		_notify_wild_battle_money_awarded(pokemon_species, max(int(PlayerSave.money), 0) - previous_money)
		_notify_reward_experience_gains(wallet_result.get("reward", {}))
		_notify_reward_effort_gains(wallet_result.get("reward", {}))
		_notify_reward_level_ups(wallet_result.get("reward", {}))
	else:
		push_warning("World: wild battle money reward failed: %s" % str(wallet_result.get("error", "Unknown error")))

func _award_trainer_battle_rewards(battle_id: String, trainer_name: String) -> void:
	var previous_money: int = max(int(PlayerSave.money), 0)
	var reward_result: Dictionary = await PlayerWalletService.award_trainer_battle_rewards(battle_id)
	if bool(reward_result.get("success", false)):
		PlayerWalletService.apply_wallet_result(reward_result)
		var reward: Dictionary = reward_result.get("reward", {}) as Dictionary
		var money_awarded: int = max(int(reward.get("money", max(int(PlayerSave.money), 0) - previous_money)), 0)
		_notify_trainer_battle_rewards_awarded(trainer_name, money_awarded)
		_notify_reward_experience_gains(reward)
		_notify_reward_effort_gains(reward)
		_notify_reward_level_ups(reward)
	else:
		push_warning("World: trainer battle reward failed: %s" % str(reward_result.get("error", "Unknown error")))

func _notify_wild_battle_money_awarded(pokemon_species: String, money_awarded: int) -> void:
	if money_awarded <= 0:
		return

	var species_text := pokemon_species.strip_edges()
	if species_text == "":
		species_text = "wild Pokemon"

	var message := "You fainted %s and earned $%s." % [species_text, _format_money_amount(money_awarded)]
	get_tree().call_group("ui_overlay", "refresh_money_display")
	get_tree().call_group("ui_overlay", "add_system_message", message)

func _notify_trainer_battle_rewards_awarded(trainer_name: String, money_awarded: int) -> void:
	if money_awarded <= 0:
		return

	var trainer_text := trainer_name.strip_edges()
	if trainer_text == "":
		trainer_text = "the Trainer"

	var message := "You defeated %s and earned $%s." % [trainer_text, _format_money_amount(money_awarded)]
	get_tree().call_group("ui_overlay", "refresh_money_display")
	get_tree().call_group("ui_overlay", "add_system_message", message)

func notify_progression_reward(reward: Dictionary) -> void:
	_notify_reward_level_ups(reward)

func _notify_reward_experience_gains(reward_value: Variant) -> void:
	if not (reward_value is Dictionary):
		return
	var experience_value: Variant = (reward_value as Dictionary).get("experience", [])
	if not (experience_value is Array):
		return
	for entry_value: Variant in experience_value as Array:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var amount: int = max(int(entry.get("experience", 0)), 0)
		if amount <= 0:
			continue
		var progression := _dictionary_from_value(entry.get("progression", {}))
		var pokemon_name := str(progression.get("species", "")).strip_edges()
		if pokemon_name == "":
			pokemon_name = _reward_pokemon_name(int(entry.get("pokemonId", 0)))
		if pokemon_name == "":
			pokemon_name = "Your Pokemon"
		get_tree().call_group("ui_overlay", "add_system_message", "%s gained %s EXP." % [pokemon_name, amount])

func _reward_pokemon_name(pokemon_id: int) -> String:
	if pokemon_id <= 0:
		return ""
	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null and pokemon.owned_pokemon_id == pokemon_id:
			return pokemon.species
	return ""

func _notify_reward_effort_gains(reward_value: Variant) -> void:
	if not (reward_value is Dictionary):
		return

	var reward: Dictionary = reward_value as Dictionary
	var effort_value: Variant = reward.get("effort", [])
	if not (effort_value is Array):
		return

	for effort_entry_value: Variant in effort_value as Array:
		if not (effort_entry_value is Dictionary):
			continue
		var effort_entry: Dictionary = effort_entry_value as Dictionary
		var changes: Dictionary = _dictionary_from_value(effort_entry.get("storedEvChanges", effort_entry.get("gainedEvs", effort_entry.get("evChanges", {}))))
		var parts: Array[String] = []
		for stat_key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
			var amount := int(changes.get(stat_key, 0))
			if amount > 0:
				parts.append("+%s %s" % [amount, _format_effort_stat_label(stat_key)])
		if parts.is_empty():
			continue

		var species := str(effort_entry.get("species", "Pokemon")).strip_edges()
		if species == "":
			species = "Pokemon"
		get_tree().call_group("ui_overlay", "add_system_message", "%s stored %s EVs." % [species, ", ".join(parts)])

func _format_effort_stat_label(stat_key: String) -> String:
	match stat_key.strip_edges().to_lower():
		"hp":
			return "HP"
		"atk":
			return "ATK"
		"def":
			return "DEF"
		"spa":
			return "SP. ATK"
		"spd":
			return "SP. DEF"
		"spe":
			return "SPEED"
		_:
			return stat_key.to_upper()

func _notify_reward_level_ups(reward_value: Variant) -> void:
	if not (reward_value is Dictionary):
		return

	var reward: Dictionary = reward_value as Dictionary
	var level_ups_value: Variant = reward.get("levelUps", [])
	if not (level_ups_value is Array):
		return

	for level_up_value: Variant in level_ups_value:
		if not (level_up_value is Dictionary):
			continue

		var level_up: Dictionary = level_up_value as Dictionary
		var species := str(level_up.get("species", "Pokemon")).strip_edges()
		if species == "":
			species = "Pokemon"

		var previous_level := int(level_up.get("previousLevel", 0))
		var level := int(level_up.get("level", 0))
		if level <= 0:
			continue

		var message := "%s grew to Lv. %s!" % [species, level]
		if previous_level > 0 and level - previous_level > 1:
			message = "%s grew from Lv. %s to Lv. %s!" % [species, previous_level, level]
		get_tree().call_group("ui_overlay", "add_system_message", message)
		_notify_reward_level_up_moves(species, level_up)

	get_tree().call_group("ui_overlay", "queue_reward_move_learn_candidates", reward)

func _notify_reward_level_up_moves(species: String, level_up: Dictionary) -> void:
	_notify_reward_move_messages(
		species,
		level_up.get("learnedMoves", []),
		"%s learned %s!"
	)
	_notify_reward_move_messages(
		species,
		level_up.get("moveLearnCandidates", []),
		"%s can learn %s."
	)

func _notify_reward_move_messages(species: String, moves_value: Variant, message_template: String) -> void:
	if not (moves_value is Array):
		return

	for move_value: Variant in moves_value:
		var move_name := _reward_move_name(move_value)
		if move_name == "":
			continue

		get_tree().call_group("ui_overlay", "add_system_message", message_template % [species, move_name])

func _reward_move_name(move_value: Variant) -> String:
	if not (move_value is Dictionary):
		return ""

	var move_event: Dictionary = move_value as Dictionary
	var move_name := str(move_event.get("name", "")).strip_edges()
	if move_name != "":
		return move_name

	var move_payload_value: Variant = move_event.get("move", {})
	if move_payload_value is Dictionary:
		var move_payload: Dictionary = move_payload_value as Dictionary
		move_name = str(move_payload.get("name", move_payload.get("id", ""))).strip_edges()
		if move_name != "":
			return move_name

	return str(move_event.get("moveId", "")).strip_edges()

func _format_money_amount(value: int) -> String:
	var value_text := str(max(value, 0))
	var formatted := ""
	var counter := 0
	for index in range(value_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			formatted = "," + formatted
		formatted = value_text.substr(index, 1) + formatted
		counter += 1
	return formatted

func _is_player_battle_winner(winner: String) -> bool:
	var normalized_winner := winner.strip_edges().to_lower()
	if normalized_winner == "":
		return false
	if normalized_winner == "player 1":
		return true

	var player_names: Array[String] = [
		PlayerSave.player_name,
		AuthService.get_display_name(),
		str(AuthService.current_user.get("username", "")),
	]
	for player_name: String in player_names:
		if player_name.strip_edges() != "" and normalized_winner == player_name.strip_edges().to_lower():
			return true

	return false

func _lock_overworld_for_battle() -> void:
	GameState.lock_overworld_input()
	if player.has_method("reset_movement_state"):
		player.reset_movement_state()
	_sync_player_activity_state_for_current_tile()
	player.set_process(false)
	player.set_physics_process(false)

func _unlock_overworld_after_battle() -> void:
	if player.has_method("reset_movement_state"):
		player.reset_movement_state()
	_sync_player_activity_state_for_current_tile()
	player.set_process(true)
	player.set_physics_process(true)
	GameState.unlock_overworld_input()

func _abort_battle_start() -> void:
	_clear_battle_ui_instance()
	is_in_battle = false
	active_battle_kind = ""
	active_battle_id = ""
	active_wild_pokemon_species = ""
	active_trainer_name = ""
	_save_player_activity_state_deferred("idle")
	_unlock_overworld_after_battle()
	MusicManager.play_overworld_music()
