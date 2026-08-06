@tool
extends Node2D

class_name BaseNPC

const NpcDefinitionResource := preload("res://scripts/world/npcs/npc_definition.gd")

const MISSING_DIALOGUE_LINES: Array[String] = [
	"This NPC has no dialogue.",
	"Please contact staff.",
]

## A profile is authoritative for every non-empty field it provides.
## Placement-specific values such as position, facing, and movement stay on this node.
@export var npc_profile: NpcDefinitionResource:
	set(value):
		var profile_changed := Callable(self, "_on_npc_profile_changed")
		if (
			Engine.is_editor_hint()
			and npc_profile != null
			and npc_profile.changed.is_connected(profile_changed)
		):
			npc_profile.changed.disconnect(profile_changed)
		npc_profile = value
		if (
			Engine.is_editor_hint()
			and npc_profile != null
			and not npc_profile.changed.is_connected(profile_changed)
		):
			npc_profile.changed.connect(profile_changed)
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_refresh_npc_profile_preview")

@export var npc_id := ""
@export var npc_definition_id := ""
## Optional server-content identity for reusable NPC scenes. Placed NPCs normally use npc_id.
@export var npc_metadata_id := ""
## Optional story condition. An empty quest id keeps the NPC unrestricted.
@export var required_quest_id := ""
@export var required_quest_step_id := ""
@export_enum("active", "completed") var required_quest_status := "completed"
## Optional scene-presence window driven by projected story state.
@export var visibility_required_quest_id := ""
@export var visibility_required_quest_step_id := ""
@export_enum("available", "active", "completed") var visibility_required_quest_status := "completed"
@export var visibility_hidden_quest_id := ""
@export var visibility_hidden_quest_step_id := ""
@export_enum("available", "active", "completed") var visibility_hidden_quest_status := "completed"
## Keep an NPC visible for the rest of the current map visit after its hide condition becomes true.
@export var defer_story_hide_until_reload := false
## Exceptional scene-specific override. Normal dialogue comes from NPC metadata.
@export var dialogue_id := ""
@export var display_name := ""
@export var facing_direction := Vector2.DOWN
@export var dialogue_lines: Array[String] = []
@export var npc_sprite_frames: SpriteFrames
@export var sprite_offset := Vector2(0, -16)
## Optional catalog id. Empty values use the central NPC assignment table.
@export var portrait_id := ""
@export var mugshot: Texture2D
@export_enum("idle", "pace_horizontal", "pace_vertical") var movement_behavior := "idle"
@export_range(1, 12, 1) var movement_tiles := 3
@export var movement_wait_seconds := 0.0
@export var movement_speed_pixels := 90.0
## Fetch metadata on spawn when this NPC can display catalog-driven quest markers.
@export var preload_quest_markers := false
@export_range(1, 8, 1) var manual_interaction_reach_tiles := 1
@export var pickpocket_enabled := false
@export var pickpocket_npc_type := ""
@export_range(1, 100, 1) var pickpocket_required_level := 1

const TILE_SIZE := 32
const MOVE_SPEED := 120.0
const MAX_STORY_PATH_STEPS := 32
const STORY_PATH_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const DEFAULT_PLAYER_VISUAL_SORT_DEPTH := 8
const MANUAL_INTERACTION_DELAY_SECONDS := 0.15
const PLAYER_OVERLAP_SORT_Y_EPSILON := 0.1
const NAMEPLATE_WIDTH := 164.0
const NAMEPLATE_CENTER_X := NAMEPLATE_WIDTH * 0.5
const NAMEPLATE_TEXT_PADDING := 10.0
const NAMEPLATE_MIN_NAME_WIDTH := 44.0
const NAMEPLATE_MAX_NAME_WIDTH := 132.0
const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")

@onready var sprite: AnimatedSprite2D = $Look/AnimatedSprite2D
@onready var feet_marker: Marker2D = $FeetMarker
@onready var interaction_area: Area2D = $InteractionArea

var player_nearby := false
var nearby_player: Node2D
var is_interacting := false
var npc_metadata_loaded := false
var npc_metadata_load_failed := false
var metadata_dialogue_id := ""
var metadata_display_name := ""
var nameplate: Control
var nameplate_background: Panel
var nameplate_label: Label
var quest_marker_bindings: Array[Dictionary] = []
var quest_marker: PanelContainer
var quest_marker_label: Label
var movement_origin_tile := Vector2i.ZERO
var movement_current_offset_tiles := 0
var movement_direction_sign := 1
var movement_next_step_at_msec := 0
var movement_reserved_tile := Vector2i.ZERO
var story_visibility_active := true
var is_npc_moving := false


func _ready_base_npc() -> void:
	_apply_npc_profile()
	if Engine.is_editor_hint():
		_refresh_npc_profile_preview()
		return
	_resolve_catalog_mugshot()

	z_as_relative = false
	if npc_sprite_frames != null:
		sprite.sprite_frames = _get_directional_sprite_frames(npc_sprite_frames)
	sprite.position = sprite_offset
	_set_idle_frame(_get_cardinal_direction(facing_direction))
	if interaction_area != null:
		var body_entered_callable := Callable(self, "_on_interaction_area_body_entered")
		var body_exited_callable := Callable(self, "_on_interaction_area_body_exited")
		if not interaction_area.body_entered.is_connected(body_entered_callable):
			interaction_area.body_entered.connect(body_entered_callable)
		if not interaction_area.body_exited.is_connected(body_exited_callable):
			interaction_area.body_exited.connect(body_exited_callable)
	movement_origin_tile = _to_tile(get_feet_position())
	_schedule_next_npc_movement_step()
	_update_sort_z()
	_setup_nameplate()
	var story_service := get_node_or_null("/root/StoryService")
	if story_service != null and not story_service.story_changed.is_connected(_on_story_changed):
		story_service.story_changed.connect(_on_story_changed)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	if preload_quest_markers:
		_initialize_quest_markers.call_deferred()
	_apply_story_visibility()


func _apply_npc_profile() -> void:
	if npc_profile == null:
		return

	if not npc_profile.npc_id.strip_edges().is_empty():
		npc_id = npc_profile.npc_id
	if not npc_profile.npc_definition_id.strip_edges().is_empty():
		npc_definition_id = npc_profile.npc_definition_id
	if not npc_profile.display_name.strip_edges().is_empty():
		display_name = npc_profile.display_name
	if npc_profile.sprite_frames != null:
		npc_sprite_frames = npc_profile.sprite_frames
	if not npc_profile.portrait_id.strip_edges().is_empty():
		portrait_id = npc_profile.portrait_id
	if npc_profile.mugshot != null:
		mugshot = npc_profile.mugshot


func _resolve_catalog_mugshot() -> void:
	var catalog := get_node_or_null("/root/TrainerPortraitCatalog")
	if catalog == null:
		return
	var resolved_portrait_id: String = catalog.resolve_portrait_id(
		portrait_id,
		npc_id,
		npc_definition_id
	)
	if resolved_portrait_id.is_empty():
		return
	var resolved_texture: Texture2D = catalog.get_texture(resolved_portrait_id)
	if resolved_texture != null:
		portrait_id = resolved_portrait_id
		mugshot = resolved_texture


func _on_npc_profile_changed() -> void:
	if Engine.is_editor_hint():
		call_deferred("_refresh_npc_profile_preview")


func _refresh_npc_profile_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return

	_apply_npc_profile()
	var preview_sprite := get_node_or_null("Look/AnimatedSprite2D") as AnimatedSprite2D
	if preview_sprite == null:
		return

	if npc_sprite_frames != null:
		preview_sprite.sprite_frames = _get_directional_sprite_frames(npc_sprite_frames)
	preview_sprite.position = sprite_offset
	sprite = preview_sprite
	_set_idle_frame(_get_cardinal_direction(facing_direction))


func blocks_world_position(world_position: Vector2) -> bool:
	if not story_visibility_active:
		return false
	var blocked_tile := _to_tile(feet_marker.global_position)
	if is_npc_moving:
		var checked_tile := _to_tile(world_position)
		return blocked_tile == checked_tile or movement_reserved_tile == checked_tile
	return blocked_tile == _to_tile(world_position)


func get_feet_position() -> Vector2:
	return feet_marker.global_position


func set_story_sprite_offset(value: Vector2) -> void:
	sprite_offset = value
	if sprite != null:
		sprite.position = value


func build_battle_trainer_metadata(metadata: Dictionary) -> Dictionary:
	var battle_metadata := metadata.duplicate(true)
	if npc_sprite_frames != null:
		# Resources stay client-local; the battle API receives the original
		# metadata before this visual-only enrichment is added.
		# Use the same directional frames as the overworld renderer so battle
		# staging can select the inward-facing idle pose from atlas-only NPCs.
		battle_metadata["_battle_sprite_frames"] = _get_directional_sprite_frames(npc_sprite_frames)
		battle_metadata["_battle_sprite_offset"] = sprite_offset
	if mugshot != null:
		battle_metadata["_battle_mugshot"] = mugshot
	return battle_metadata


func is_story_requirement_met() -> bool:
	return StoryService.is_requirement_met(
		required_quest_id,
		required_quest_step_id,
		required_quest_status
	)


func _to_tile(world_position: Vector2) -> Vector2i:
	var local_position := world_position - _get_map_origin()
	return Vector2i(
		floori(local_position.x / TILE_SIZE),
		floori(local_position.y / TILE_SIZE)
	)


func _tile_to_world(tile_position: Vector2i) -> Vector2:
	return _get_map_origin() + Vector2(
		tile_position.x * TILE_SIZE + TILE_SIZE * 0.5,
		tile_position.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func _get_map_origin() -> Vector2:
	if GameState.current_map != null:
		return GameState.current_map.global_position

	return Vector2.ZERO


func _get_body_feet_position(body: Node2D) -> Vector2:
	if body.has_method("get_feet_position"):
		return body.get_feet_position()
	return body.global_position


func _get_body_target_feet_position(body: Node2D) -> Vector2:
	if body.has_method("get_target_feet_position"):
		return body.get_target_feet_position()
	return _get_body_feet_position(body)


func _get_step_direction_from_positions(from_position: Vector2, to_position: Vector2) -> Vector2:
	var delta := to_position - from_position
	if abs(delta.x) > abs(delta.y):
		return Vector2(sign(delta.x), 0)

	if delta.y != 0:
		return Vector2(0, sign(delta.y))

	if delta.x != 0:
		return Vector2(sign(delta.x), 0)

	return Vector2.ZERO


func _face_body(body: Node2D) -> void:
	var direction := _get_step_direction_from_positions(get_feet_position(), _get_body_feet_position(body))
	_set_idle_frame(direction)


func face_world_position(world_position: Vector2) -> void:
	var direction := _get_step_direction_from_positions(get_feet_position(), world_position)
	_set_idle_frame(direction)


func can_story_move_path(path: Array[String]) -> bool:
	if path.is_empty() or path.size() > MAX_STORY_PATH_STEPS or is_npc_moving:
		return false
	for direction_name: String in path:
		if direction_name not in STORY_PATH_DIRECTIONS:
			return false
	return true


func story_move_path(path: Array[String]) -> bool:
	if not can_story_move_path(path) or not _preflight_story_move_path(path):
		return false

	is_npc_moving = true
	var final_direction := facing_direction
	for direction_name: String in path:
		var direction := _story_path_direction(direction_name)
		var current_tile := _to_tile(get_feet_position())
		var target_tile := current_tile + Vector2i(int(direction.x), int(direction.y))
		var target_feet_position := _tile_to_world(target_tile)

		final_direction = direction
		facing_direction = direction
		_play_walk_animation(direction)
		_update_directional_sensors()
		movement_reserved_tile = target_tile
		var target_global_position := global_position + (target_feet_position - get_feet_position())
		var duration := global_position.distance_to(target_global_position) / maxf(
			movement_speed_pixels,
			1.0
		)
		var tween := create_tween()
		tween.tween_property(self, "global_position", target_global_position, duration)
		await tween.finished
		_update_sort_z()

	_finish_story_path_movement(final_direction)
	return true


func _preflight_story_move_path(path: Array[String]) -> bool:
	if not _has_story_movement_context():
		return false
	var current_tile := _to_tile(get_feet_position())
	for direction_name: String in path:
		var direction := _story_path_direction(direction_name)
		var target_tile := current_tile + Vector2i(int(direction.x), int(direction.y))
		if not _can_story_npc_move_to(_tile_to_world(target_tile)):
			return false
		current_tile = target_tile
	return true


func _can_story_npc_move_to(world_position: Vector2) -> bool:
	var current_map: Node = GameState.current_map
	if current_map == null or not is_instance_valid(current_map):
		return false

	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player_node := candidate as Node2D
		if player_node != null and _to_tile(_get_body_target_feet_position(player_node)) == _to_tile(world_position):
			return false

	var collision_tilemap := MapLayerResolverScript.find_tilemap_layer(current_map, ["Collision"])
	if collision_tilemap == null:
		return false
	var local_position := collision_tilemap.to_local(world_position)
	var tile_position := collision_tilemap.local_to_map(local_position)
	if collision_tilemap.get_cell_source_id(tile_position) != -1:
		return false
	if collision_tilemap.get_cell_tile_data(tile_position) != null:
		return false
	return not _is_story_position_blocked_by_other_node(current_map, world_position)


func _is_story_position_blocked_by_other_node(node: Node, world_position: Vector2) -> bool:
	for child: Node in node.get_children():
		if child == self:
			continue
		if child.has_method("blocks_world_position") and bool(child.call("blocks_world_position", world_position)):
			return true
		if _is_story_position_blocked_by_other_node(child, world_position):
			return true
	return false


func _has_story_movement_context() -> bool:
	if not is_inside_tree() or feet_marker == null or sprite == null:
		return false
	if not GameState.is_overworld_input_locked():
		return false
	var current_map: Node = GameState.current_map
	if current_map == null or not is_instance_valid(current_map):
		return false
	return MapLayerResolverScript.find_tilemap_layer(current_map, ["Collision"]) != null


func _finish_story_path_movement(direction: Vector2) -> void:
	movement_reserved_tile = Vector2i.ZERO
	is_npc_moving = false
	movement_origin_tile = _to_tile(get_feet_position())
	movement_current_offset_tiles = 0
	_set_idle_frame(direction)
	_update_directional_sensors()
	_schedule_next_npc_movement_step()


func _story_path_direction(direction_name: String) -> Vector2:
	match direction_name:
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.ZERO


func _play_walk_animation(direction: Vector2) -> void:
	var animation_name := _get_walk_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func _set_idle_frame(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	facing_direction = _get_cardinal_direction(direction)

	var animation_name := _get_idle_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		sprite.stop()
		return

	animation_name = _get_walk_animation_name(direction)
	if animation_name != "" and sprite.sprite_frames.has_animation(animation_name):
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()


func _setup_nameplate() -> void:
	if nameplate != null:
		_sync_nameplate()
		return

	nameplate = Control.new()
	nameplate.name = "Nameplate"
	nameplate.visible = false
	nameplate.z_index = 512
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.offset_left = -82.0
	nameplate.offset_top = -80.0
	nameplate.offset_right = 82.0
	nameplate.offset_bottom = -56.0
	add_child(nameplate)

	nameplate_background = Panel.new()
	nameplate_background.name = "NameplateBackground"
	nameplate_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate_background.add_theme_stylebox_override("panel", _make_nameplate_background_style())
	nameplate.add_child(nameplate_background)

	nameplate_label = Label.new()
	nameplate_label.name = "NameLabel"
	nameplate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nameplate_label.label_settings = _make_nameplate_label_settings()
	nameplate.add_child(nameplate_label)

	_sync_nameplate()


func _initialize_quest_markers() -> void:
	if not _get_npc_metadata_id().is_empty():
		await _load_npc_metadata()
	_refresh_quest_marker()


func _setup_quest_marker() -> void:
	if quest_marker != null:
		return
	quest_marker = PanelContainer.new()
	quest_marker.name = "QuestMarker"
	quest_marker.visible = false
	quest_marker.z_index = 513
	quest_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_marker.position = Vector2(-15.0, -116.0)
	quest_marker.custom_minimum_size = Vector2(30.0, 30.0)
	add_child(quest_marker)

	quest_marker_label = Label.new()
	quest_marker_label.name = "Icon"
	quest_marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_marker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quest_marker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_marker_label.add_theme_font_size_override("font_size", 20)
	quest_marker_label.add_theme_constant_override("outline_size", 4)
	quest_marker_label.add_theme_color_override("font_outline_color", Color("#07111cff"))
	quest_marker.add_child(quest_marker_label)


func _refresh_quest_marker() -> void:
	if quest_marker_bindings.is_empty():
		if quest_marker != null:
			quest_marker.visible = false
		return
	_setup_quest_marker()
	var story_service := get_node_or_null("/root/StoryService")
	if story_service == null:
		quest_marker.visible = false
		return
	var selected_type := ""
	for binding: Dictionary in quest_marker_bindings:
		var quest: Dictionary = story_service.get_quest(str(binding.get("questId", "")))
		if quest.is_empty() or not _quest_marker_binding_matches(binding, quest):
			continue
		var quest_type := str(
			binding.get("markerType", quest.get("questType", "side"))
		).strip_edges().to_lower()
		if selected_type == "" or quest_type == "main":
			selected_type = quest_type
		if selected_type == "main":
			break
	quest_marker.visible = selected_type != ""
	if selected_type == "main":
		quest_marker_label.text = "!"
		quest_marker_label.add_theme_color_override("font_color", Color("#ffd75aff"))
		quest_marker.add_theme_stylebox_override("panel", _quest_marker_style(Color("#9a691fff")))
	elif selected_type == "side":
		quest_marker_label.text = "✦"
		quest_marker_label.add_theme_color_override("font_color", Color("#75ddffff"))
		quest_marker.add_theme_stylebox_override("panel", _quest_marker_style(Color("#176b8fff")))


func _quest_marker_binding_matches(binding: Dictionary, quest: Dictionary) -> bool:
	var visibility_quest_id := str(binding.get("visibilityQuestId", "")).strip_edges()
	if (
		not visibility_quest_id.is_empty()
		and not StoryService.is_requirement_met(
			visibility_quest_id,
			str(binding.get("visibilityQuestStepId", "")).strip_edges(),
			str(binding.get("visibilityQuestStatus", "completed")).strip_edges()
		)
	):
		return false
	var statuses_value: Variant = binding.get("statuses", [])
	var statuses: Array[String] = []
	if statuses_value is Array:
		for value: Variant in statuses_value as Array:
			statuses.append(str(value).strip_edges().to_lower())
	if not statuses.is_empty() and str(quest.get("status", "")).to_lower() not in statuses:
		return false
	var step_id := str(binding.get("stepId", "")).strip_edges()
	if step_id.is_empty():
		return true
	var steps_value: Variant = quest.get("steps", [])
	if not (steps_value is Array):
		return false
	for step_value: Variant in steps_value as Array:
		if not (step_value is Dictionary):
			continue
		var step := step_value as Dictionary
		if str(step.get("stepId", "")) == step_id:
			return str(step.get("status", "")).to_lower() in statuses
	return false


func _quest_marker_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#081521ed")
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 3
	return style


func _sync_nameplate() -> void:
	if nameplate == null or nameplate_label == null:
		return

	var name_text := display_name.strip_edges()
	if pickpocket_enabled and player_nearby:
		name_text += "  [T]"
	nameplate_label.text = name_text
	nameplate.visible = name_text != ""
	nameplate_label.visible = name_text != ""

	var name_width := clampf(
		_get_nameplate_label_text_width(nameplate_label) + NAMEPLATE_TEXT_PADDING,
		NAMEPLATE_MIN_NAME_WIDTH,
		NAMEPLATE_MAX_NAME_WIDTH
	)
	nameplate_label.offset_left = NAMEPLATE_CENTER_X - (name_width * 0.5)
	nameplate_label.offset_right = nameplate_label.offset_left + name_width
	nameplate_label.offset_top = 0.0
	nameplate_label.offset_bottom = 22.0

	if nameplate_background != null:
		nameplate_background.offset_left = nameplate_label.offset_left - 5.0
		nameplate_background.offset_right = nameplate_label.offset_right + 5.0
		nameplate_background.offset_top = 2.0
		nameplate_background.offset_bottom = 20.0


func _make_nameplate_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.070, 0.078, 0.64)
	style.border_color = Color(0.24, 0.86, 0.76, 0.36)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 2
	return style


func _make_nameplate_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = 12
	settings.font_color = Color(0.68, 1.0, 0.88, 1.0)
	settings.outline_size = 3
	settings.outline_color = Color(0.015, 0.025, 0.030, 0.88)
	settings.shadow_size = 1
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	return settings


func _get_nameplate_label_text_width(label: Label) -> float:
	var text := label.text.strip_edges()
	if text == "":
		return 0.0

	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if label.label_settings != null:
		font_size = label.label_settings.font_size
	if font == null:
		return float(text.length() * max(font_size, 10) * 0.6)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _get_idle_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "idle_down"
	if direction == Vector2.UP:
		return "idle_up"
	if direction == Vector2.LEFT:
		return "idle_left"
	if direction == Vector2.RIGHT:
		return "idle_right"

	return ""


func _get_walk_animation_name(direction: Vector2) -> String:
	if direction == Vector2.DOWN:
		return "walk_down"
	if direction == Vector2.UP:
		return "walk_up"
	if direction == Vector2.LEFT:
		return "walk_left"
	if direction == Vector2.RIGHT:
		return "walk_right"

	return ""


func _get_directional_sprite_frames(source_sprite_frames: SpriteFrames) -> SpriteFrames:
	if _has_all_directional_animations(source_sprite_frames):
		return source_sprite_frames

	var atlas_texture := _get_first_atlas_texture(source_sprite_frames)
	if atlas_texture == null or atlas_texture.atlas == null:
		return source_sprite_frames

	var frame_size: Vector2 = atlas_texture.region.size
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return source_sprite_frames

	var atlas_size := atlas_texture.atlas.get_size()
	if atlas_size.x < frame_size.x * 4.0 or atlas_size.y < frame_size.y * 4.0:
		return source_sprite_frames

	var generated_sprite_frames := SpriteFrames.new()
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "down", 0)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "left", 1)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "right", 2)
	_add_directional_animation(generated_sprite_frames, atlas_texture.atlas, frame_size, "up", 3)
	_copy_missing_animations(source_sprite_frames, generated_sprite_frames)
	return generated_sprite_frames


func _copy_missing_animations(source: SpriteFrames, target: SpriteFrames) -> void:
	for animation_name: StringName in source.get_animation_names():
		if target.has_animation(animation_name) and target.get_frame_count(animation_name) > 0:
			continue

		if not target.has_animation(animation_name):
			target.add_animation(animation_name)
		target.set_animation_loop(animation_name, source.get_animation_loop(animation_name))
		target.set_animation_speed(animation_name, source.get_animation_speed(animation_name))
		for frame_index: int in range(source.get_frame_count(animation_name)):
			target.add_frame(
				animation_name,
				source.get_frame_texture(animation_name, frame_index),
				source.get_frame_duration(animation_name, frame_index)
			)


func _get_first_atlas_texture(source_sprite_frames: SpriteFrames) -> AtlasTexture:
	for animation_name: StringName in source_sprite_frames.get_animation_names():
		var frame_count: int = source_sprite_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var frame_texture: Texture2D = source_sprite_frames.get_frame_texture(animation_name, frame_index)
			var atlas_texture: AtlasTexture = frame_texture as AtlasTexture
			if atlas_texture != null and atlas_texture.atlas != null:
				return atlas_texture

	return null


func _has_all_directional_animations(source_sprite_frames: SpriteFrames) -> bool:
	return (
		(source_sprite_frames.has_animation("walk_down") or source_sprite_frames.has_animation("idle_down"))
		and (source_sprite_frames.has_animation("walk_up") or source_sprite_frames.has_animation("idle_up"))
		and (source_sprite_frames.has_animation("walk_left") or source_sprite_frames.has_animation("idle_left"))
		and (source_sprite_frames.has_animation("walk_right") or source_sprite_frames.has_animation("idle_right"))
	)


func _add_directional_animation(
	target_sprite_frames: SpriteFrames,
	atlas: Texture2D,
	frame_size: Vector2,
	direction_name: String,
	row: int
) -> void:
	var idle_animation_name := "idle_%s" % direction_name
	var walk_animation_name := "walk_%s" % direction_name

	target_sprite_frames.add_animation(idle_animation_name)
	target_sprite_frames.set_animation_loop(idle_animation_name, true)
	target_sprite_frames.set_animation_speed(idle_animation_name, 5.0)
	target_sprite_frames.add_frame(idle_animation_name, _create_atlas_frame(atlas, frame_size, 0, row))

	target_sprite_frames.add_animation(walk_animation_name)
	target_sprite_frames.set_animation_loop(walk_animation_name, true)
	target_sprite_frames.set_animation_speed(walk_animation_name, 5.0)
	for column: int in range(4):
		target_sprite_frames.add_frame(walk_animation_name, _create_atlas_frame(atlas, frame_size, column, row))


func _create_atlas_frame(atlas: Texture2D, frame_size: Vector2, column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = atlas
	frame.region = Rect2(
		Vector2(frame_size.x * float(column), frame_size.y * float(row)),
		frame_size
	)
	return frame


func _process_base_npc() -> void:
	if Engine.is_editor_hint():
		return

	_update_sort_z()
	await _process_npc_movement()
	if _can_start_pickpocket():
		await _start_pickpocket(nearby_player)
		return
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)


func _process_npc_movement() -> void:
	if movement_behavior == "idle":
		return

	if is_npc_moving or is_interacting:
		return

	if player_nearby:
		return

	if GameState.is_overworld_input_locked():
		return

	if _is_ui_typing():
		return

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return

	if Time.get_ticks_msec() < movement_next_step_at_msec:
		return

	await _try_step_npc_movement()


func _try_step_npc_movement() -> void:
	var direction := _get_movement_axis_direction() * float(movement_direction_sign)
	if direction == Vector2.ZERO:
		_schedule_next_npc_movement_step()
		return

	var target_offset := movement_current_offset_tiles + movement_direction_sign
	var max_tiles := maxi(movement_tiles, 1)
	if abs(target_offset) > max_tiles:
		movement_direction_sign *= -1
		_set_idle_frame(_get_movement_axis_direction() * float(movement_direction_sign))
		_update_directional_sensors()
		_schedule_next_npc_movement_step()
		return

	var current_tile := _to_tile(get_feet_position())
	var target_tile := current_tile + Vector2i(int(direction.x), int(direction.y))
	var target_feet_position := _tile_to_world(target_tile)
	if not _can_npc_move_to(target_feet_position):
		movement_direction_sign *= -1
		_set_idle_frame(_get_movement_axis_direction() * float(movement_direction_sign))
		_update_directional_sensors()
		_schedule_next_npc_movement_step()
		return

	is_npc_moving = true
	facing_direction = direction
	_play_walk_animation(direction)
	_update_directional_sensors()

	var target_global_position := global_position + (target_feet_position - get_feet_position())
	var speed := maxf(movement_speed_pixels, 1.0)
	var duration := global_position.distance_to(target_global_position) / speed
	movement_reserved_tile = target_tile
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_global_position, duration)
	await tween.finished

	movement_current_offset_tiles = target_offset
	_set_idle_frame(direction)
	_update_directional_sensors()
	_update_sort_z()
	movement_reserved_tile = Vector2i.ZERO
	is_npc_moving = false
	_schedule_next_npc_movement_step()


func _get_movement_axis_direction() -> Vector2:
	if movement_behavior == "pace_horizontal":
		return Vector2.RIGHT
	if movement_behavior == "pace_vertical":
		return Vector2.DOWN
	return Vector2.ZERO


func _schedule_next_npc_movement_step() -> void:
	var wait_msec := int(maxf(movement_wait_seconds, 0.0) * 1000.0)
	movement_next_step_at_msec = Time.get_ticks_msec() + wait_msec


func _can_npc_move_to(world_position: Vector2) -> bool:
	var current_map: Node = GameState.current_map
	if current_map == null:
		return true

	for candidate: Node in get_tree().get_nodes_in_group("player"):
		var player_node := candidate as Node2D
		if player_node != null and _to_tile(_get_body_target_feet_position(player_node)) == _to_tile(world_position):
			return false

	var collision_tilemap := MapLayerResolverScript.find_tilemap_layer(current_map, ["Collision"])
	if collision_tilemap != null:
		var local_position := collision_tilemap.to_local(world_position)
		var tile_position := collision_tilemap.local_to_map(local_position)
		if collision_tilemap.get_cell_source_id(tile_position) != -1:
			return false
		if collision_tilemap.get_cell_tile_data(tile_position) != null:
			return false

	if current_map.has_method("is_position_blocked_by_character"):
		return not bool(current_map.call("is_position_blocked_by_character", world_position))

	return not MapCharacterBlocking.is_position_blocked_by_character(current_map, world_position)


func _update_directional_sensors() -> void:
	if has_method("_configure_vision_area"):
		call("_configure_vision_area")


func _can_start_manual_interaction() -> bool:
	if not story_visibility_active:
		return false
	if is_interacting:
		return false

	if not player_nearby or nearby_player == null:
		return false

	if GameState.is_overworld_input_locked():
		return false

	if _is_ui_typing():
		return false

	if not Input.is_action_just_pressed("interact"):
		return false
	if not _is_player_facing_npc(nearby_player):
		return false

	var dialogue_box := _get_dialogue_box()
	if dialogue_box != null and dialogue_box.is_open:
		return false

	return true


func _can_start_pickpocket() -> bool:
	if not pickpocket_enabled or not story_visibility_active or is_interacting:
		return false
	if not player_nearby or nearby_player == null:
		return false
	if GameState.is_overworld_input_locked() or _is_ui_typing():
		return false
	if not Input.is_action_just_pressed("pickpocket") or not _is_player_facing_npc(nearby_player):
		return false
	var dialogue_box := _get_dialogue_box()
	return dialogue_box == null or not dialogue_box.is_open


func _start_pickpocket(body: Node2D) -> void:
	is_interacting = true
	GameState.lock_overworld_input()
	_face_body(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())

	var target_id := _get_npc_metadata_id().strip_edges().to_lower()
	if ThievingService.state_loaded and ThievingService.get_level() < pickpocket_required_level:
		_add_system_warning(LocalizationManager.text(
			"ui.thieving.level_required",
			{"level": pickpocket_required_level}
		))
	elif ThievingService.is_npc_attempted_today(target_id):
		_add_system_warning(LocalizationManager.text("ui.thieving.already_attempted"))
	else:
		if body.has_method("set_activity_style"):
			body.call("set_activity_style", CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET)
		await get_tree().create_timer(0.55).timeout
		if is_instance_valid(body) and body.has_method("get_activity_style") \
				and CharacterAppearanceService.normalize_movement_style(str(body.call("get_activity_style"))) \
				== CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET:
			body.call("clear_activity_style")
		var result: Dictionary = await ThievingService.attempt_pickpocket(target_id)
		if bool(result.get("success", false)):
			if str(result.get("outcome", "")) == "success":
				_add_system_message(LocalizationManager.text(
					"ui.thieving.success",
					{
						"amount": int(result.get("rewardCurrency", 0)),
						"wanted": int((result.get("state", {}) as Dictionary).get("wanted", 0)),
					}
				))
		else:
			_add_system_warning(str(result.get("error", LocalizationManager.text("ui.thieving.unavailable"))))

	GameState.unlock_overworld_input()
	is_interacting = false


func _is_player_facing_npc(body: Node2D) -> bool:
	if body == null:
		return false
	var direction_value: Variant = body.get("last_direction")
	if not direction_value is Vector2:
		return false
	var direction := direction_value as Vector2
	if direction == Vector2.ZERO:
		return false
	var player_tile := _to_tile(_get_body_feet_position(body))
	var cardinal_direction := Vector2i(roundi(direction.x), roundi(direction.y))
	var npc_tile := _to_tile(get_feet_position())
	for distance: int in range(1, manual_interaction_reach_tiles + 1):
		if player_tile + cardinal_direction * distance == npc_tile:
			return true
	return false


func _start_manual_interaction(body: Node2D) -> void:
	is_interacting = true
	GameState.lock_overworld_input()
	_face_body(body)
	if body.has_method("face_world_position"):
		body.face_world_position(get_feet_position())
	await get_tree().create_timer(MANUAL_INTERACTION_DELAY_SECONDS).timeout

	var result := await _run_story_or_legacy_interaction(body, "interact")
	if str(result.get("status", "")) != "pending_battle":
		GameState.unlock_overworld_input()
	is_interacting = false


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	var story_hook := _find_story_hook()
	if story_hook == null or not bool(story_hook.call("is_configured")):
		await interact_with_player(body)
		return {"success": true, "handled": false, "legacy": true}

	var result_value: Variant = await story_hook.call(
		"try_handle_interaction",
		self,
		body,
		trigger
	)
	if not (result_value is Dictionary):
		await GameErrorDialogService.show_report_to_staff_message()
		return {"success": false, "handled": true, "status": "invalid_story_hook_result"}

	var result: Dictionary = result_value as Dictionary
	if bool(result.get("success", false)) and result.has("handled") and not bool(result.get("handled", true)):
		await interact_with_player(body)
		var fallback_result := result.duplicate(true)
		fallback_result["legacy"] = true
		return fallback_result
	if bool(result.get("success", false)) and bool(result.get("handled", false)):
		await _after_story_interaction(body, result)
	return result


func _find_story_hook() -> Node:
	for child: Node in get_children():
		if child.has_method("try_handle_interaction") and child.has_method("is_configured"):
			return child
	return null


func interact_with_player(_player: Node2D) -> void:
	await show_dialogue()


func _after_story_interaction(_player: Node2D, _result: Dictionary) -> void:
	pass


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> bool:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null:
		push_warning("%s: DialogueBox/Box not found." % name)
		return false

	var source_dialogue_lines := lines
	if source_dialogue_lines.is_empty():
		if not _get_npc_metadata_id().is_empty():
			var metadata_response: Dictionary = await _load_npc_metadata()
			if not metadata_response.get("success", false):
				await GameErrorDialogService.show_report_to_staff_message(dialogue_box)
				return false
		source_dialogue_lines = dialogue_lines

	var valid_dialogue_lines := _get_valid_dialogue_lines(source_dialogue_lines)
	if valid_dialogue_lines.is_empty():
		push_error("%s has no dialogue lines." % name)
		dialogue_box.start_dialogue(MISSING_DIALOGUE_LINES, "System")
		await dialogue_box.dialogue_finished
		return false

	var speaker_name := speaker_name_override
	if speaker_name.is_empty():
		speaker_name = display_name
	if speaker_name.is_empty():
		speaker_name = name

	dialogue_box.start_dialogue(valid_dialogue_lines, speaker_name, mugshot)
	await dialogue_box.dialogue_finished
	return true


func _load_npc_metadata() -> Dictionary:
	var metadata_id := _get_npc_metadata_id()
	if metadata_id.is_empty():
		return {
			"success": true,
			"metadata": {},
		}

	if npc_metadata_loaded:
		return {
			"success": true,
			"metadata": {},
		}

	if npc_metadata_load_failed:
		return {
			"success": false,
			"error": "NPC metadata already failed for %s" % metadata_id,
		}

	var response: Dictionary = await NpcMetadataService.get_npc_metadata(metadata_id)
	if not response.get("success", false):
		npc_metadata_load_failed = true
		push_error("%s metadata failed for %s: %s" % [
			name,
			metadata_id,
			str(response.get("error", "Unknown API error")),
		])
		return response

	var metadata: Dictionary = response.get("metadata", {})
	_apply_npc_metadata(metadata)
	npc_metadata_loaded = true
	return response


func _get_npc_metadata_id() -> String:
	var explicit_metadata_id := npc_metadata_id.strip_edges()
	if not explicit_metadata_id.is_empty():
		return explicit_metadata_id
	var placed_npc_id := npc_id.strip_edges()
	if not placed_npc_id.is_empty():
		return placed_npc_id
	var definition_id := npc_definition_id.strip_edges()
	if not definition_id.is_empty():
		return definition_id
	return ""


func _apply_npc_metadata(metadata: Dictionary) -> void:
	var metadata_required_quest_id := str(
		metadata.get("requiredQuestId", metadata.get("required_quest_id", ""))
	).strip_edges()
	if not metadata_required_quest_id.is_empty():
		required_quest_id = metadata_required_quest_id
		required_quest_step_id = str(
			metadata.get(
				"requiredQuestStepId",
				metadata.get("required_quest_step_id", required_quest_step_id)
			)
		).strip_edges()
		var metadata_required_quest_status := str(
			metadata.get(
				"requiredQuestStatus",
				metadata.get("required_quest_status", required_quest_status)
			)
		).strip_edges().to_lower()
		if metadata_required_quest_status in ["active", "completed"]:
			required_quest_status = metadata_required_quest_status

	metadata_dialogue_id = str(
		metadata.get("dialogueId", metadata.get("dialogue_id", ""))
	).strip_edges()

	var metadata_name := str(metadata.get("name", ""))
	if (
		(display_name.strip_edges().is_empty() or display_name == metadata_display_name)
		and not metadata_name.is_empty()
	):
		display_name = metadata_name
		metadata_display_name = metadata_name
		_sync_nameplate()

	var metadata_dialogue: Array[String] = _get_string_array(metadata.get("dialogue", []))
	if not metadata_dialogue.is_empty():
		dialogue_lines = metadata_dialogue

	var pickpocket_profile: Variant = metadata.get("pickpocketProfile", {})
	if pickpocket_profile is Dictionary:
		var profile := pickpocket_profile as Dictionary
		pickpocket_enabled = not profile.is_empty()
		pickpocket_npc_type = str(profile.get("npcType", "")).strip_edges().to_lower()
		pickpocket_required_level = clampi(int(profile.get("requiredLevel", 1)), 1, 100)

	quest_marker_bindings.clear()
	var marker_values: Variant = metadata.get("questMarkers", [])
	if marker_values is Array:
		for marker_value: Variant in marker_values as Array:
			if marker_value is Dictionary:
				quest_marker_bindings.append((marker_value as Dictionary).duplicate(true))
	_refresh_quest_marker()


func _on_locale_changed(_locale: String) -> void:
	npc_metadata_loaded = false
	npc_metadata_load_failed = false
	metadata_dialogue_id = ""
	quest_marker_bindings.clear()
	_refresh_quest_marker()
	if preload_quest_markers:
		_initialize_quest_markers.call_deferred()


func _on_story_changed(_revision: int) -> void:
	_apply_story_visibility(true)
	_refresh_quest_marker()


func _apply_story_visibility(allow_deferred_hide := false) -> void:
	var next_visibility := _is_story_visibility_active()
	if (
		allow_deferred_hide
		and defer_story_hide_until_reload
		and story_visibility_active
		and not next_visibility
	):
		return
	story_visibility_active = next_visibility
	visible = story_visibility_active
	if interaction_area != null:
		interaction_area.monitoring = story_visibility_active
		interaction_area.monitorable = story_visibility_active
	if not story_visibility_active:
		player_nearby = false
		nearby_player = null
		if quest_marker != null:
			quest_marker.visible = false


func _is_story_visibility_active() -> bool:
	var required_id := visibility_required_quest_id.strip_edges()
	if (
		not required_id.is_empty()
		and not StoryService.is_requirement_met(
			required_id,
			visibility_required_quest_step_id,
			visibility_required_quest_status
		)
	):
		return false
	var hidden_id := visibility_hidden_quest_id.strip_edges()
	if (
		not hidden_id.is_empty()
		and StoryService.is_requirement_met(
			hidden_id,
			visibility_hidden_quest_step_id,
			visibility_hidden_quest_status
		)
	):
		return false
	return true


func _get_dialogue_override_id() -> String:
	return dialogue_id.strip_edges()


func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))

	return _get_valid_dialogue_lines(strings)


func _get_valid_dialogue_lines(lines: Array[String]) -> Array[String]:
	var valid_dialogue_lines: Array[String] = []
	for line: String in lines:
		if not line.strip_edges().is_empty():
			valid_dialogue_lines.append(line)

	return valid_dialogue_lines


func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if story_visibility_active and body.name == "Player":
		player_nearby = true
		nearby_player = body
		_sync_nameplate()


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		if body == nearby_player:
			nearby_player = null
		_sync_nameplate()


func _wait_for_body_tile_movement(body: Node2D) -> void:
	while body != null and body.has_method("is_tile_moving") and body.is_tile_moving():
		await get_tree().process_frame


func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit


func _add_system_message(message: String) -> void:
	get_tree().call_group("ui_overlay", "add_system_message", message)


func _add_system_warning(message: String) -> void:
	get_tree().call_group("ui_overlay", "add_system_warning", message)


func _update_sort_z() -> void:
	var npc_feet_y: float = get_feet_position().y
	var sort_z := floori(npc_feet_y)
	var sprite_sort_z := 0
	var player_for_sorting := _get_player_for_sorting()
	if player_for_sorting != null:
		var player_feet_y: float = _get_body_feet_position(player_for_sorting).y
		var player_canvas_item := player_for_sorting as CanvasItem
		if player_canvas_item != null:
			var player_sort_z := player_canvas_item.z_index
			if npc_feet_y > player_feet_y + PLAYER_OVERLAP_SORT_Y_EPSILON:
				sort_z = maxi(sort_z, player_sort_z + 1)
				sprite_sort_z = _get_player_visual_sort_depth(player_for_sorting) + 1
			elif npc_feet_y < player_feet_y - PLAYER_OVERLAP_SORT_Y_EPSILON:
				sort_z = mini(sort_z, player_sort_z - 1)

	z_index = clampi(sort_z, SORT_Z_MIN, SORT_Z_MAX)
	if sprite != null:
		sprite.z_index = sprite_sort_z


func _get_player_for_sorting() -> Node2D:
	if nearby_player != null and is_instance_valid(nearby_player):
		return nearby_player

	var tree := get_tree()
	if tree == null:
		return null

	for candidate: Node in tree.get_nodes_in_group("player"):
		var player_node := candidate as Node2D
		if player_node != null and is_instance_valid(player_node):
			return player_node

	return null


func _get_player_visual_sort_depth(player_node: Node2D) -> int:
	var look_node := player_node.get_node_or_null("Look")
	if look_node == null:
		return DEFAULT_PLAYER_VISUAL_SORT_DEPTH

	return maxi(_get_max_relative_z_index(look_node), DEFAULT_PLAYER_VISUAL_SORT_DEPTH)


func _get_max_relative_z_index(node: Node) -> int:
	var max_z := 0
	var canvas_item := node as CanvasItem
	if canvas_item != null and canvas_item.z_as_relative:
		max_z = maxi(max_z, canvas_item.z_index)

	for child: Node in node.get_children():
		max_z = maxi(max_z, _get_max_relative_z_index(child))

	return max_z


func _get_cardinal_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.DOWN

	if abs(direction.x) > abs(direction.y):
		return Vector2(sign(direction.x), 0)

	return Vector2(0, sign(direction.y))
