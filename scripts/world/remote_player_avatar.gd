extends Node2D

class_name RemotePlayerAvatar

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const SORT_Z_MIN := -256
const SORT_Z_MAX := 256
const SNAP_DISTANCE := 96.0
const REMOTE_MOVE_SPEED := 150.0
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const WALK_ANIMATION_HOLD_DURATION := 0.18
const INTERPOLATION_DELAY_SECONDS := 0.16
const MAX_POSITION_SAMPLES := 8
const ROLE_BADGE_COLORS := {
	"gamemaster": Color(0.0, 0.749, 1.0),
	"developer": Color(0.0, 0.898, 0.659),
	"moderator": Color(0.482, 0.173, 0.749),
}
const NAMEPLATE_WIDTH := 164.0
const NAMEPLATE_CENTER_X := NAMEPLATE_WIDTH * 0.5
const NAMEPLATE_TEXT_PADDING := 6.0
const ROLE_BADGE_GAP := -5.0
const ROLE_BADGE_TEXT_HEIGHT := 11.0
const ROLE_BADGE_DEFAULT_WIDTH := 20.0
const NAMEPLATE_MIN_NAME_WIDTH := 44.0
const NAMEPLATE_MAX_NAME_WIDTH := 132.0
const BODY_SPRITE_NAME := "BodySprite"
const UNEQUIPPED_APPEARANCE_PART_META := "unequipped_appearance_part"
const APPEARANCE_PART_SPRITES := {
	"hair": "HairSprite",
	"headgear": "HeadgearSprite",
	"facegear": "FaceGearSprite",
	"top": "TopSprite",
	"bottom": "BottomSprite",
	"shoes": "ShoesSprite",
	"eyes": "EyesSprite",
	"eyebrows": "EyebrowsSprite",
}

var user_id := 0
var username := ""
var display_name := ""
var roles: Array = []
var target_position := Vector2.ZERO
var walk_animation_hold_timer := 0.0
var position_samples: Array[Dictionary] = []
var tile_move_start_position := Vector2.ZERO
var tile_move_target_position := Vector2.ZERO
var tile_move_elapsed := 0.0
var tile_move_duration := 0.22
var is_replaying_tile_move := false
var pending_tile_moves: Array[Dictionary] = []
var last_direction := Vector2.DOWN
var appearance_sprites: Array[AnimatedSprite2D] = []
var nameplate: Control
var nameplate_label: Label
var role_badge_panel: Panel
var role_badge_label: Label
var pokemon_follower: PokemonFollower
var current_follower_species := ""
var current_follower_shiny := false
var current_body_id := ""
var current_body_gender := ""
var current_body_movement_style := CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
var current_gender := "male"
var current_appearance_state: Dictionary = {}
var current_appearance_signature := ""
var has_position := false


func _ready() -> void:
	z_as_relative = false
	_create_visual()
	_update_animation(false)
	_update_sort_z()


func _process(delta: float) -> void:
	if not has_position:
		return

	var previous_position := global_position
	walk_animation_hold_timer = maxf(walk_animation_hold_timer - delta, 0.0)
	if is_replaying_tile_move:
		_update_replayed_tile_move(delta)
	elif not pending_tile_moves.is_empty():
		_start_next_pending_tile_move()
	else:
		_update_interpolated_position()

	var moved_this_frame := previous_position.distance_to(global_position) > 0.1
	_update_animation(_is_visually_moving(moved_this_frame))
	_update_sort_z()


func apply_state(state: Dictionary) -> void:
	user_id = int(state.get("userId", user_id))
	username = str(state.get("username", username))
	var display_name_value: Variant = state.get("displayName", display_name)
	display_name = username if display_name_value == null else str(display_name_value)
	var appearance_state: Dictionary = _get_appearance_state_from_presence(state)
	current_gender = _resolve_state_gender(state, appearance_state)
	if current_gender == "":
		current_gender = "male"
	var roles_value: Variant = state.get("roles", roles)
	if roles_value is Array:
		roles = roles_value as Array
	else:
		roles = []
	_update_nameplate()

	var position_data := _dictionary_from_value(state.get("position", {}))
	var new_target_position := Vector2(
		float(position_data.get("x", target_position.x)),
		float(position_data.get("y", target_position.y))
	)
	var movement_data := _dictionary_from_value(state.get("movement", {}))
	var packet_direction := _direction_from_name(str(state.get("facingDirection", "down")))
	if not has_position:
		target_position = new_target_position
		if bool(movement_data.get("isMoving", false)):
			global_position = _vector2_from_payload(movement_data.get("startPosition", {}), target_position)
			_reset_position_samples(global_position)
			has_position = true
			_apply_tile_movement_state(movement_data, packet_direction)
		else:
			global_position = target_position
			_reset_position_samples(target_position)
			has_position = true
			last_direction = packet_direction
	else:
		target_position = new_target_position
		if bool(movement_data.get("isMoving", false)):
			_apply_tile_movement_state(movement_data, packet_direction)
		else:
			if not is_replaying_tile_move and pending_tile_moves.is_empty():
				last_direction = packet_direction
				_add_position_sample(target_position)

	_update_animation(_is_visually_moving(false))
	_apply_appearance_state(appearance_state)
	_apply_follower_state(_dictionary_from_value(state.get("follower", {})))
	_update_sort_z()


func _resolve_state_gender(state: Dictionary, appearance_state: Dictionary) -> String:
	var normalized_gender: String = CharacterAppearanceService.normalize_gender(str(state.get("gender", "")))
	if normalized_gender != "":
		return normalized_gender

	normalized_gender = CharacterAppearanceService.normalize_gender(str(appearance_state.get("gender", "")))
	if normalized_gender != "":
		return normalized_gender

	normalized_gender = CharacterAppearanceService.infer_gender_from_body_id(str(appearance_state.get("body", "")))
	if normalized_gender != "":
		return normalized_gender

	return current_gender


func _get_appearance_state_from_presence(state: Dictionary) -> Dictionary:
	var appearance_state: Dictionary = _dictionary_from_value(state.get("appearance", {}))
	_merge_appearance_alias(appearance_state, "hair_style_index", "hairStyleIndex")
	_merge_appearance_alias(appearance_state, "hair_color", "hairColor")
	_merge_appearance_alias(appearance_state, "skin_tone", "skinTone")
	_merge_appearance_alias(appearance_state, "eye_color", "eyeColor")
	_merge_presence_appearance_values_from_container(appearance_state, state)
	var movement_state: Dictionary = _dictionary_from_value(state.get("movement", {}))
	var movement_appearance: Dictionary = _dictionary_from_value(movement_state.get("appearance", {}))
	if not movement_appearance.is_empty():
		for key: Variant in movement_appearance.keys():
			appearance_state[key] = movement_appearance[key]
		_merge_appearance_alias(appearance_state, "hair_style_index", "hairStyleIndex")
		_merge_appearance_alias(appearance_state, "hair_color", "hairColor")
		_merge_appearance_alias(appearance_state, "skin_tone", "skinTone")
		_merge_appearance_alias(appearance_state, "eye_color", "eyeColor")
	_merge_presence_appearance_values_from_container(appearance_state, movement_state)
	_merge_encoded_body_appearance(appearance_state)
	return appearance_state


func _merge_appearance_alias(appearance_state: Dictionary, appearance_key: String, alias_key: String) -> void:
	if not appearance_state.has(appearance_key) and appearance_state.has(alias_key):
		appearance_state[appearance_key] = appearance_state.get(alias_key)


func _merge_presence_appearance_value(appearance_state: Dictionary, state: Dictionary, appearance_key: String, top_level_keys: Array) -> void:
	for top_level_key: String in top_level_keys:
		if state.has(top_level_key):
			appearance_state[appearance_key] = state.get(top_level_key)
			return


func _merge_presence_appearance_values_from_container(appearance_state: Dictionary, container: Dictionary) -> void:
	_merge_presence_appearance_value(appearance_state, container, "body", ["appearanceBody", "body"])
	_merge_presence_appearance_value(appearance_state, container, "hair", ["appearanceHair", "hair"])
	_merge_presence_appearance_value(appearance_state, container, "hair_style_index", ["appearanceHairStyleIndex", "hair_style_index", "hairStyleIndex"])
	_merge_presence_appearance_value(appearance_state, container, "headgear", ["appearanceHeadgear", "headgear"])
	_merge_presence_appearance_value(appearance_state, container, "facegear", ["appearanceFacegear", "facegear"])
	_merge_presence_appearance_value(appearance_state, container, "top", ["appearanceTop", "top"])
	_merge_presence_appearance_value(appearance_state, container, "bottom", ["appearanceBottom", "bottom", "legs"])
	_merge_presence_appearance_value(appearance_state, container, "shoes", ["appearanceShoes", "shoes", "feet"])
	_merge_presence_appearance_value(appearance_state, container, "hair_color", ["appearanceHairColor", "hair_color", "hairColor"])
	_merge_presence_appearance_value(appearance_state, container, "skin_tone", ["appearanceSkinTone", "skin_tone", "skinTone"])
	_merge_presence_appearance_value(appearance_state, container, "eye_color", ["appearanceEyeColor", "eye_color", "eyeColor"])


func _merge_encoded_body_appearance(appearance_state: Dictionary) -> void:
	var encoded_body: String = str(appearance_state.get("body", "")).strip_edges()
	if encoded_body == "":
		return

	var decoded_appearance: Dictionary = CharacterAppearanceService.decode_presence_body_appearance(encoded_body)
	if decoded_appearance.is_empty():
		appearance_state["body"] = CharacterAppearanceService.get_presence_body_base_id(encoded_body)
		return

	for key: Variant in decoded_appearance.keys():
		appearance_state[key] = decoded_appearance[key]


func get_feet_position() -> Vector2:
	return global_position


func get_current_move_duration() -> float:
	return tile_move_duration if is_replaying_tile_move else TILE_MOVE_DURATION


func _apply_tile_movement_state(movement_data: Dictionary, packet_direction: Vector2) -> void:
	var start_position := _vector2_from_payload(movement_data.get("startPosition", {}), global_position)
	var move_target_position := _vector2_from_payload(movement_data.get("targetPosition", {}), target_position)
	var duration := maxf(float(movement_data.get("duration", TILE_MOVE_DURATION)), 0.001)
	if _has_tile_move(start_position, move_target_position):
		return

	pending_tile_moves.append({
		"start": start_position,
		"target": move_target_position,
		"duration": duration,
		"direction": _get_move_direction(start_position, move_target_position, packet_direction),
	})
	position_samples.clear()
	walk_animation_hold_timer = WALK_ANIMATION_HOLD_DURATION

	if not is_replaying_tile_move:
		_start_next_pending_tile_move()


func _apply_follower_state(follower_state: Dictionary) -> void:
	if not bool(follower_state.get("visible", false)):
		current_follower_species = ""
		current_follower_shiny = false
		if pokemon_follower != null and is_instance_valid(pokemon_follower):
			pokemon_follower.set_pokemon(null)
		return

	var species: String = str(follower_state.get("species", "")).strip_edges()
	var shiny: bool = bool(follower_state.get("shiny", false))
	if species == "":
		return

	_ensure_pokemon_follower()
	if pokemon_follower == null or not is_instance_valid(pokemon_follower):
		return
	if current_follower_species == species and current_follower_shiny == shiny:
		return

	current_follower_species = species
	current_follower_shiny = shiny
	var follower_pokemon: Pokemon = Pokemon.new(species, 100, "", "", "Hardy", {}, {}, {}, [], "", 0, shiny)
	pokemon_follower.set_pokemon(follower_pokemon)
	pokemon_follower.reset_follow_position()


func _apply_appearance_state(appearance_state: Dictionary) -> void:
	var fallback_body_id: String = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID if current_gender == "female" else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	var body_id: String = str(appearance_state.get("body", fallback_body_id)).strip_edges()
	if body_id == "":
		body_id = fallback_body_id
	var next_appearance_state: Dictionary = appearance_state.duplicate()
	next_appearance_state["body"] = body_id
	var signature: String = _get_appearance_signature(next_appearance_state)
	if signature == current_appearance_signature and current_gender == current_body_gender:
		return

	current_appearance_state = next_appearance_state
	current_appearance_signature = signature
	if body_id != current_body_id or current_gender != current_body_gender:
		_apply_body_frames(body_id, current_gender, current_body_movement_style)
	else:
		_apply_appearance_parts(current_body_movement_style)


func _ensure_pokemon_follower() -> void:
	if pokemon_follower != null and is_instance_valid(pokemon_follower):
		return

	pokemon_follower = PokemonFollower.new()
	pokemon_follower.name = "RemotePokemonFollower"
	add_child(pokemon_follower)
	pokemon_follower.setup(self)


func _has_tile_move(start_position: Vector2, target_position_value: Vector2) -> bool:
	if is_replaying_tile_move \
			and tile_move_start_position.distance_to(start_position) <= 0.5 \
			and tile_move_target_position.distance_to(target_position_value) <= 0.5:
		return true

	for move in pending_tile_moves:
		if typeof(move) != TYPE_DICTIONARY:
			continue
		var move_dictionary: Dictionary = move
		var queued_start := _get_sample_position({"position": move_dictionary.get("start", start_position)}, start_position)
		var queued_target := _get_sample_position({"position": move_dictionary.get("target", target_position_value)}, target_position_value)
		if queued_start.distance_to(start_position) <= 0.5 and queued_target.distance_to(target_position_value) <= 0.5:
			return true

	return false


func _start_next_pending_tile_move() -> void:
	if pending_tile_moves.is_empty():
		return

	var move_value: Variant = pending_tile_moves.pop_front()
	if typeof(move_value) != TYPE_DICTIONARY:
		return

	var move: Dictionary = move_value
	var start_position := _get_sample_position({"position": move.get("start", global_position)}, global_position)
	var move_target_position := _get_sample_position({"position": move.get("target", target_position)}, target_position)
	var move_direction := _get_direction_from_value(move.get("direction", last_direction), last_direction)
	if global_position.distance_to(start_position) > SNAP_DISTANCE:
		global_position = start_position

	tile_move_start_position = _snap_world_position(global_position)
	tile_move_target_position = _snap_world_position(move_target_position)
	tile_move_duration = maxf(float(move.get("duration", TILE_MOVE_DURATION)), 0.001)
	tile_move_elapsed = 0.0
	is_replaying_tile_move = true
	last_direction = move_direction
	_sync_body_frames_for_move_duration(tile_move_duration)
	_sync_appearance_animation_speeds(tile_move_duration)


func _update_replayed_tile_move(delta: float) -> void:
	tile_move_elapsed = minf(tile_move_elapsed + delta, tile_move_duration)
	var progress := clampf(tile_move_elapsed / tile_move_duration, 0.0, 1.0)
	global_position = _snap_world_position(tile_move_start_position.lerp(tile_move_target_position, progress))
	if tile_move_elapsed >= tile_move_duration:
		global_position = tile_move_target_position
		target_position = tile_move_target_position
		is_replaying_tile_move = false
		_sync_body_frames_for_move_duration(TILE_MOVE_DURATION)
		_reset_position_samples(global_position)
		if not pending_tile_moves.is_empty():
			_start_next_pending_tile_move()


func _add_position_sample(position: Vector2) -> void:
	if not position_samples.is_empty():
		var last_sample: Dictionary = position_samples[position_samples.size() - 1]
		var last_position: Vector2 = _get_sample_position(last_sample, position)
		if last_position.distance_to(position) <= 0.5:
			return

	position_samples.append({
		"time": _get_time_seconds(),
		"position": position,
	})

	while position_samples.size() > MAX_POSITION_SAMPLES:
		position_samples.remove_at(0)

	walk_animation_hold_timer = WALK_ANIMATION_HOLD_DURATION


func _update_interpolated_position() -> void:
	if position_samples.is_empty():
		return

	var render_time := _get_time_seconds() - INTERPOLATION_DELAY_SECONDS
	var first_sample: Dictionary = position_samples[0]
	var first_position: Vector2 = _get_sample_position(first_sample, global_position)
	if global_position.distance_to(first_position) > SNAP_DISTANCE:
		global_position = first_position
		return

	if position_samples.size() == 1:
		global_position = global_position.move_toward(first_position, REMOTE_MOVE_SPEED * get_process_delta_time())
		return

	while position_samples.size() >= 2:
		var next_sample: Dictionary = position_samples[1]
		var next_time := float(next_sample.get("time", 0.0))
		if next_time > render_time:
			break
		position_samples.remove_at(0)

	var from_sample: Dictionary = position_samples[0]
	var from_position: Vector2 = _get_sample_position(from_sample, global_position)
	if position_samples.size() < 2:
		global_position = global_position.move_toward(from_position, REMOTE_MOVE_SPEED * get_process_delta_time())
		return

	var to_sample: Dictionary = position_samples[1]
	var from_time := float(from_sample.get("time", render_time))
	var to_time := float(to_sample.get("time", render_time))
	var to_position: Vector2 = _get_sample_position(to_sample, from_position)
	var sample_duration := maxf(to_time - from_time, 0.001)
	var progress := clampf((render_time - from_time) / sample_duration, 0.0, 1.0)
	global_position = from_position.lerp(to_position, progress)


func _reset_position_samples(position: Vector2) -> void:
	position_samples.clear()
	position_samples.append({
		"time": _get_time_seconds(),
		"position": position,
	})


func _get_sample_position(sample: Dictionary, fallback: Vector2) -> Vector2:
	var position_value: Variant = sample.get("position", fallback)
	if position_value is Vector2:
		return position_value as Vector2
	return fallback


func _is_visually_moving(moved_this_frame: bool) -> bool:
	return moved_this_frame or is_replaying_tile_move or position_samples.size() > 1 or walk_animation_hold_timer > 0.0


func _get_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _vector2_from_payload(value: Variant, fallback: Vector2) -> Vector2:
	var dictionary := _dictionary_from_value(value)
	if dictionary.is_empty():
		return fallback
	return Vector2(
		float(dictionary.get("x", fallback.x)),
		float(dictionary.get("y", fallback.y))
	)


func _get_move_direction(start_position: Vector2, target_position_value: Vector2, fallback: Vector2) -> Vector2:
	var delta := target_position_value - start_position
	if abs(delta.x) > abs(delta.y):
		return Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
	if abs(delta.y) > 0.0:
		return Vector2.DOWN if delta.y > 0.0 else Vector2.UP
	return fallback


func _get_direction_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	return fallback


func _snap_world_position(position: Vector2) -> Vector2:
	return Vector2(roundf(position.x), roundf(position.y))


func _create_visual() -> void:
	var player_instance := PLAYER_SCENE.instantiate()
	var source_look := player_instance.get_node_or_null("Look")
	if source_look == null:
		player_instance.queue_free()
		push_warning("RemotePlayerAvatar: player scene has no Look node.")
		return

	var look_copy := source_look.duplicate()
	add_child(look_copy)
	_collect_appearance_sprites(look_copy)
	_apply_appearance_state({"body": CharacterAppearanceService.DEFAULT_MALE_BODY_ID})
	_create_nameplate_from_player_scene(player_instance)
	player_instance.queue_free()


func _create_nameplate_from_player_scene(player_instance: Node) -> void:
	var source_nameplate: Node = player_instance.get_node_or_null("Nameplate")
	if source_nameplate == null:
		return

	var nameplate_copy: Node = source_nameplate.duplicate()
	add_child(nameplate_copy)
	nameplate = nameplate_copy as Control
	if nameplate == null:
		nameplate_copy.queue_free()
		return

	nameplate_label = nameplate.get_node_or_null("NameLabel") as Label
	role_badge_panel = nameplate.get_node_or_null("RoleBadgePanel") as Panel
	if role_badge_panel != null:
		role_badge_label = role_badge_panel.get_node_or_null("RoleBadge") as Label
	if nameplate_label == null:
		nameplate.queue_free()
		nameplate = null
		return

	nameplate.visible = false
	_update_nameplate()


func _update_nameplate() -> void:
	if nameplate_label == null:
		return

	var name_text: String = display_name.strip_edges()
	if name_text == "":
		name_text = username.strip_edges()
	nameplate_label.text = name_text
	nameplate_label.visible = name_text != ""
	_update_role_badge()
	_sync_nameplate_layout()
	if nameplate != null:
		nameplate.visible = name_text != ""


func _update_role_badge() -> void:
	if role_badge_label == null:
		return

	var primary_role: Dictionary = _get_primary_visible_role(roles)
	if primary_role.is_empty():
		role_badge_label.text = ""
		if role_badge_panel != null:
			role_badge_panel.visible = false
		return

	var role_id: String = str(primary_role.get("id", ""))
	role_badge_label.text = str(primary_role.get("badge", ""))
	if role_badge_panel != null:
		role_badge_panel.visible = role_badge_label.text != ""
	role_badge_label.add_theme_color_override("font_color", _get_role_color(role_id, str(primary_role.get("color", ""))))


func _sync_nameplate_layout() -> void:
	if nameplate_label == null:
		return

	var has_role_badge: bool = role_badge_panel != null and role_badge_label != null and role_badge_label.text.strip_edges() != ""
	var name_width: float = clampf(
		_get_label_text_width(nameplate_label) + NAMEPLATE_TEXT_PADDING,
		NAMEPLATE_MIN_NAME_WIDTH,
		NAMEPLATE_MAX_NAME_WIDTH
	)
	nameplate_label.offset_left = NAMEPLATE_CENTER_X - (name_width * 0.5)
	nameplate_label.offset_right = nameplate_label.offset_left + name_width
	nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if has_role_badge:
		var badge_width: float = _get_role_badge_width(role_badge_label.text)
		var name_center_y: float = (nameplate_label.offset_top + nameplate_label.offset_bottom) / 2.0
		var start_x: float = nameplate_label.offset_left - ROLE_BADGE_GAP - badge_width
		role_badge_panel.offset_left = start_x
		role_badge_panel.offset_right = start_x + badge_width
		role_badge_panel.offset_top = name_center_y - (ROLE_BADGE_TEXT_HEIGHT * 0.5)
		role_badge_panel.offset_bottom = name_center_y + (ROLE_BADGE_TEXT_HEIGHT * 0.5)
		role_badge_label.offset_left = 1.0
		role_badge_label.offset_right = badge_width - 1.0
		role_badge_label.offset_top = 0.0
		role_badge_label.offset_bottom = ROLE_BADGE_TEXT_HEIGHT


func _get_label_text_width(label: Label) -> float:
	var text: String = label.text.strip_edges()
	if text == "":
		return 0.0

	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null:
		return float(text.length() * max(font_size, 10) * 0.6)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


func _get_role_badge_width(badge_text: String) -> float:
	match badge_text.strip_edges():
		"GM":
			return 16.0
		"DEV", "MOD":
			return 20.0
		_:
			return ROLE_BADGE_DEFAULT_WIDTH


func _get_primary_visible_role(role_values: Array) -> Dictionary:
	var primary_role: Dictionary = {}
	var primary_priority: int = -999999
	for role_value: Variant in role_values:
		if not role_value is Dictionary:
			continue

		var role: Dictionary = role_value as Dictionary
		var role_id: String = str(role.get("id", ""))
		var badge: String = _get_role_badge(role_id)
		if badge.is_empty():
			continue

		var role_with_badge: Dictionary = role.duplicate()
		role_with_badge["badge"] = badge
		var priority: int = int(role_with_badge.get("priority", 0))
		if primary_role.is_empty() or priority > primary_priority:
			primary_role = role_with_badge
			primary_priority = priority

	return primary_role


func _get_role_badge(role_id: String) -> String:
	match role_id:
		"gamemaster":
			return "GM"
		"developer":
			return "DEV"
		"moderator":
			return "MOD"
		_:
			return ""


func _get_role_color(role_id: String, fallback: String) -> Color:
	if ROLE_BADGE_COLORS.has(role_id):
		var role_color: Color = ROLE_BADGE_COLORS[role_id]
		return role_color
	if fallback.begins_with("#"):
		return Color(fallback)
	return Color(0.847, 0.718, 0.404)


func _collect_appearance_sprites(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		appearance_sprites.append(sprite)

	for child in node.get_children():
		_collect_appearance_sprites(child)


func _sync_appearance_animation_speeds(move_duration: float = TILE_MOVE_DURATION) -> void:
	var idle_animation_names: Array[String] = ["idle_down", "idle_left", "idle_right", "idle_up"]
	var walk_animation_names: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]
	var walk_speed := WALK_ANIMATION_SPEED * (TILE_MOVE_DURATION / maxf(move_duration, 0.001))

	for sprite in appearance_sprites:
		if sprite.sprite_frames == null:
			continue

		for animation_name: String in idle_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)

		for animation_name: String in walk_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, walk_speed)


func _sync_body_frames_for_move_duration(move_duration: float) -> void:
	var movement_style: String = CharacterAppearanceService.BODY_MOVEMENT_RUN \
		if move_duration < TILE_MOVE_DURATION \
		else CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
	if movement_style == current_body_movement_style:
		return
	_apply_body_frames(current_body_id, current_body_gender, movement_style)


func _apply_body_frames(body_id: String, gender: String, movement_style: String) -> void:
	var normalized_gender: String = CharacterAppearanceService.normalize_gender(gender)
	var fallback_body_id: String = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID \
		if normalized_gender == "female" \
		else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	var normalized_body_id: String = body_id.strip_edges()
	if normalized_body_id == "":
		normalized_body_id = fallback_body_id
	var available_body_ids: Array[String] = CharacterAppearanceService.get_available_body_ids(normalized_gender)
	if not available_body_ids.has(normalized_body_id):
		normalized_body_id = fallback_body_id

	var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(
		normalized_body_id,
		normalized_gender,
		movement_style
	)
	if body_frames == null:
		return

	for sprite in appearance_sprites:
		if sprite.name != "BodySprite":
			continue

		var current_animation: StringName = sprite.animation
		var current_frame: int = sprite.frame
		var current_frame_progress: float = sprite.frame_progress
		var was_playing: bool = sprite.is_playing()
		sprite.sprite_frames = body_frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_body_modulate(sprite, normalized_body_id, normalized_gender)
		current_body_id = normalized_body_id
		current_body_gender = normalized_gender
		current_body_movement_style = movement_style
		_apply_appearance_parts(movement_style)
		_sync_appearance_animation_speeds(tile_move_duration if is_replaying_tile_move else TILE_MOVE_DURATION)

		if body_frames.has_animation(current_animation):
			sprite.animation = current_animation
			var frame_count: int = body_frames.get_frame_count(current_animation)
			if frame_count > 0:
				sprite.frame = mini(current_frame, frame_count - 1)
				sprite.frame_progress = current_frame_progress
			if was_playing:
				sprite.play(current_animation)
			else:
				sprite.stop()
		else:
			_update_animation(_is_visually_moving(false))
		_sync_all_part_sprites_to_body()
		return


func _apply_appearance_parts(movement_style: String) -> void:
	if not CharacterAppearanceService.body_supports_layered_parts(current_body_id, current_body_gender):
		for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
			_clear_appearance_part_sprite(str(category_value))
		return

	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category: String = str(category_value)
		var part_id: String = _get_appearance_part_id(category)
		_apply_appearance_part(category, part_id, movement_style)


func _get_appearance_part_id(category: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category):
		"hair":
			return _get_appearance_hair_id()
		"headgear":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("headgear", CharacterAppearanceService.get_default_part_id("headgear", current_body_gender))))
		"facegear":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("facegear", "")))
		"top":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("top", CharacterAppearanceService.get_default_part_id("top", current_body_gender))))
		"bottom":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("bottom", current_appearance_state.get("legs", CharacterAppearanceService.get_default_part_id("bottom", current_body_gender)))))
		"shoes":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("shoes", current_appearance_state.get("feet", CharacterAppearanceService.get_default_part_id("shoes", current_body_gender)))))
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", current_body_gender)
		"eyebrows":
			return CharacterAppearanceService.get_default_part_id("eyebrows", current_body_gender)
		_:
			return ""


func _get_appearance_hair_id() -> String:
	var hair_id: String = CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("hair", "")))
	if current_appearance_state.has("hair"):
		return hair_id

	var hair_ids: Array[String] = CharacterAppearanceService.get_available_part_ids("hair", current_body_gender)
	if hair_ids.is_empty():
		return CharacterAppearanceService.get_default_part_id("hair", current_body_gender)

	var hair_style_index: int = clampi(int(current_appearance_state.get("hair_style_index", 0)), 0, hair_ids.size() - 1)
	return hair_ids[hair_style_index]


func _apply_appearance_part(category: String, part_id: String, movement_style: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	if not APPEARANCE_PART_SPRITES.has(normalized_category):
		return

	var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[normalized_category]))
	if sprite == null:
		return

	var normalized_part_id: String = part_id.strip_edges()
	if normalized_part_id == "":
		_clear_appearance_part_sprite(normalized_category)
		return

	var part_frames: SpriteFrames = _get_appearance_part_frames(normalized_category, normalized_part_id, movement_style)
	if part_frames == null:
		_clear_appearance_part_sprite(normalized_category)
		return

	sprite.sprite_frames = part_frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.set_meta(UNEQUIPPED_APPEARANCE_PART_META, false)
	_apply_appearance_part_visuals(sprite, normalized_category)
	sprite.visible = true
	_sync_sprite_to_body(sprite)


func _get_appearance_sprite(sprite_name: String) -> AnimatedSprite2D:
	for sprite in appearance_sprites:
		if sprite.name == sprite_name:
			return sprite
	return null


func _get_body_sprite() -> AnimatedSprite2D:
	return _get_appearance_sprite(BODY_SPRITE_NAME)


func _sync_all_part_sprites_to_body() -> void:
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[str(category_value)]))
		_sync_sprite_to_body(sprite)


func _sync_sprite_to_body(sprite: AnimatedSprite2D) -> void:
	var body_sprite := _get_body_sprite()
	if sprite == null or body_sprite == null or sprite == body_sprite:
		return
	if _is_unequipped_appearance_part_sprite(sprite):
		sprite.visible = false
		sprite.stop()
		return
	if sprite.sprite_frames == null:
		return

	var animation_name: StringName = body_sprite.animation
	if not sprite.sprite_frames.has_animation(animation_name):
		sprite.visible = false
		sprite.stop()
		return

	sprite.visible = true
	sprite.animation = animation_name
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count > 0:
		sprite.frame = mini(body_sprite.frame, frame_count - 1)
		sprite.frame_progress = body_sprite.frame_progress
	if body_sprite.is_playing():
		sprite.play(animation_name)
	else:
		sprite.stop()


func _clear_appearance_part_sprite(category: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	if not APPEARANCE_PART_SPRITES.has(normalized_category):
		return
	var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[normalized_category]))
	if sprite == null:
		return
	sprite.stop()
	sprite.sprite_frames = null
	sprite.visible = false
	sprite.modulate = Color.WHITE
	sprite.material = null
	sprite.set_meta(UNEQUIPPED_APPEARANCE_PART_META, true)


func _apply_body_modulate(body_sprite: AnimatedSprite2D, body_id: String, gender: String) -> void:
	if body_sprite == null:
		return
	if CharacterAppearanceService.body_supports_layered_parts(body_id, gender):
		body_sprite.modulate = _parse_appearance_color(str(current_appearance_state.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE)), Color.WHITE)
	else:
		body_sprite.modulate = Color.WHITE


func _get_appearance_part_modulate(category: String) -> Color:
	return Color.WHITE


func _apply_appearance_part_visuals(sprite: AnimatedSprite2D, category: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	sprite.material = null
	sprite.modulate = _get_appearance_part_modulate(normalized_category)


func _get_appearance_part_frames(category: String, part_id: String, movement_style: String) -> SpriteFrames:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("eye_color", CharacterAppearanceService.DEFAULT_EYE_COLOR)), Color.WHITE)
		)
	if normalized_category == "hair" or normalized_category == "eyebrows":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("hair_color", CharacterAppearanceService.DEFAULT_HAIR_COLOR)), Color.WHITE),
			true
		)
	return CharacterAppearanceService.get_part_frames(
		category,
		part_id,
		current_body_gender,
		movement_style
	)


func _parse_appearance_color(color_text: String, fallback: Color) -> Color:
	var normalized_color: String = color_text.strip_edges()
	if normalized_color == "" or not normalized_color.begins_with("#"):
		return fallback
	return Color(normalized_color)


func _get_appearance_signature(appearance_state: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(appearance_state.get("body", "")),
		str(appearance_state.get("hair", "")),
		str(appearance_state.get("hair_style_index", "")),
		str(appearance_state.get("headgear", "")),
		str(appearance_state.get("facegear", "")),
		str(appearance_state.get("top", "")),
		str(appearance_state.get("bottom", appearance_state.get("legs", ""))),
		str(appearance_state.get("shoes", appearance_state.get("feet", ""))),
		str(appearance_state.get("hair_color", "")),
		str(appearance_state.get("skin_tone", "")),
		str(appearance_state.get("eye_color", "")),
	]


func _update_animation(is_moving: bool) -> void:
	var animation_name := _get_walk_animation_name(last_direction) if is_moving else _get_idle_animation_name(last_direction)
	for sprite in appearance_sprites:
		if _is_unequipped_appearance_part_sprite(sprite):
			sprite.visible = false
			sprite.stop()
			continue
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
			continue
		if sprite.animation != animation_name:
			sprite.play(animation_name)
		elif not is_moving:
			sprite.frame = 0
			sprite.stop()
	_sync_all_part_sprites_to_body()


func _is_unequipped_appearance_part_sprite(sprite: AnimatedSprite2D) -> bool:
	return sprite != null and bool(sprite.get_meta(UNEQUIPPED_APPEARANCE_PART_META, false))


func _update_sort_z() -> void:
	z_index = clampi(floori(global_position.y / TILE_SIZE) + 1, SORT_Z_MIN, SORT_Z_MAX)


func _get_idle_animation_name(direction: Vector2) -> StringName:
	if direction == Vector2.UP:
		return &"idle_up"
	if direction == Vector2.LEFT:
		return &"idle_left"
	if direction == Vector2.RIGHT:
		return &"idle_right"
	return &"idle_down"


func _get_walk_animation_name(direction: Vector2) -> StringName:
	if direction == Vector2.UP:
		return &"walk_up"
	if direction == Vector2.LEFT:
		return &"walk_left"
	if direction == Vector2.RIGHT:
		return &"walk_right"
	return &"walk_down"


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
