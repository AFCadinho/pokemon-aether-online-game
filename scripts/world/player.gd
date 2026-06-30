extends CharacterBody2D

const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const RUN_TILE_MOVE_DURATION := 0.14
const MOVE_EASE_AMOUNT := 0.0
const INPUT_BUFFER_DURATION := 0.14
const CONTINUOUS_MOVE_HOLD_DELAY := 0.0
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const RUN_WALK_ANIMATION_SPEED := 11.5
const PLAYER_SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
const TEXT_INPUT_WINDOW_GROUP := "text_input_windows"
const HIDDEN_FOR_MISSING_ANIMATION_META := "hidden_for_missing_animation"
const UNEQUIPPED_APPEARANCE_PART_META := "unequipped_appearance_part"
const BASE_SPRITE_OFFSET_META := "base_sprite_offset"
const ACTIVITY_BASE_SPRITE_OFFSET_META := "activity_base_sprite_offset"
const FACE_GEAR_SPRITE_NAME := "FaceGearSprite"
const BODY_SPRITE_NAME := "BodySprite"
const HAIR_SPRITE_NAME := "HairSprite"
const HEADGEAR_SPRITE_NAME := "HeadgearSprite"
const TOP_SPRITE_NAME := "TopSprite"
const BOTTOM_SPRITE_NAME := "BottomSprite"
const SHOES_SPRITE_NAME := "ShoesSprite"
const EYES_SPRITE_NAME := "EyesSprite"
const EYEBROWS_SPRITE_NAME := "EyebrowsSprite"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const APPEARANCE_PART_SPRITES := {
	"hair": HAIR_SPRITE_NAME,
	"headgear": HEADGEAR_SPRITE_NAME,
	"facegear": FACE_GEAR_SPRITE_NAME,
	"top": TOP_SPRITE_NAME,
	"bottom": BOTTOM_SPRITE_NAME,
	"shoes": SHOES_SPRITE_NAME,
	"eyes": EYES_SPRITE_NAME,
	"eyebrows": EYEBROWS_SPRITE_NAME,
}
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
const ACTIVITY_LAYER_OFFSETS := {
	"fish": {
		"default": {
			"hair": Vector2(0.0, 1.0),
			"headgear": Vector2(0.0, 1.0),
			"facegear": Vector2(0.0, 2.0),
			"eyes": Vector2(0.0, 2.0),
			"eyebrows": Vector2(0.0, 2.0),
		},
		"left": {
			"hair": Vector2(12.0, 1.0),
			"headgear": Vector2(12.0, 1.0),
			"facegear": Vector2(12.0, 2.0),
			"eyes": Vector2(12.0, 2.0),
			"eyebrows": Vector2(12.0, 2.0),
		},
		"right": {
			"hair": Vector2(-12.0, 1.0),
			"headgear": Vector2(-12.0, 1.0),
			"facegear": Vector2(-12.0, 2.0),
			"eyes": Vector2(-12.0, 2.0),
			"eyebrows": Vector2(-12.0, 2.0),
		},
	},
	"ride": {
		"default": {
			"hair": Vector2(0.0, 2.0),
			"headgear": Vector2(0.0, 2.0),
			"facegear": Vector2(0.0, 2.0),
			"eyes": Vector2(0.0, 2.0),
			"eyebrows": Vector2(0.0, 2.0),
		},
	},
}
const ACTIVITY_VISUAL_OFFSETS := {
	"fish": {
		"left": Vector2(-6.0, 0.0),
		"right": Vector2(6.0, 0.0),
		"up": Vector2(0.0, -2.0),
		"down": Vector2(0.0, 2.0),
	},
}
const WATER_TILEMAP_NAMES: Array[String] = ["Water"]
const FISHING_ACTIVITY_DURATION := 1.35

@onready var look_node: Node2D = $Look
@onready var feet_marker: Marker2D = $FeetMarker
@onready var nameplate: Control = $Nameplate
@onready var nameplate_label: Label = $Nameplate/NameLabel
@onready var role_badge_panel: Panel = $Nameplate/RoleBadgePanel
@onready var role_badge_label: Label = $Nameplate/RoleBadgePanel/RoleBadge

# TileMapLayer nodes die speciale map-informatie bevatten.
# Collision bevat de onzichtbare/blokkerende tegels.
# TallGrass kan later gebruikt worden voor encounters/effects.
var collision_tilemap: TileMapLayer
var grass_tilemap: TileMapLayer
var water_tilemap: TileMapLayer
var ledge_down_tilemap: TileMapLayer
var ledge_up_tilemap: TileMapLayer
var ledge_left_tilemap: TileMapLayer
var ledge_right_tilemap: TileMapLayer

# Movement state.
# is_moving voorkomt dat je nieuwe input verwerkt terwijl de speler nog naar
# de volgende tile aan het lopen is.
var is_moving := false

# target_position is een wereldpositie in pixels.
var target_position := Vector2.ZERO
var move_start_position := Vector2.ZERO
var move_elapsed := 0.0
var move_duration := TILE_MOVE_DURATION

# Onthoudt de laatste kijkrichting, zodat de idle frame goed blijft staan.
var last_direction := Vector2.DOWN
var input_action_priority := ["move_right", "move_left", "move_down", "move_up"]
var buffered_direction := Vector2.ZERO
var input_buffer_time_left := 0.0
var held_direction := Vector2.ZERO
var held_direction_time := 0.0
var route_gate_interaction_in_progress := false
var frame_opaque_center_y_cache := {}
var appearance_sprites: Array[AnimatedSprite2D] = []
var master_appearance_sprite: AnimatedSprite2D
var pokemon_follower: PokemonFollower
var body_sprite_frames_movement_style := ""
var activity_style := CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
var fishing_activity_active := false
var fishing_activity_time_left := 0.0
var base_look_position := Vector2.ZERO

func get_feet_position() -> Vector2:
	return feet_marker.global_position

func get_target_feet_position() -> Vector2:
	return target_position + (feet_marker.global_position - global_position)

func is_tile_moving() -> bool:
	return is_moving

func get_current_move_duration() -> float:
	return move_duration if is_moving else _get_current_tile_move_duration()

func set_running_shoes_enabled(enabled: bool) -> void:
	GameState.running_shoes_enabled = enabled
	_sync_body_sprite_frames_for_movement()
	_sync_appearance_animation_speeds()

func set_activity_style(style: String) -> void:
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(style)
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_RUN:
		normalized_style = CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
	if normalized_style == activity_style:
		return

	activity_style = normalized_style
	body_sprite_frames_movement_style = ""
	_sync_body_sprite_frames_for_movement()
	_sync_appearance_animation_speeds()
	set_idle_frame()
	_sync_activity_layer_offsets()
	_apply_activity_visual_offset()

func clear_activity_style() -> void:
	set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_DEFAULT)

func get_activity_style() -> String:
	return activity_style

func is_fishing_activity_active() -> bool:
	return fishing_activity_active

func set_body_appearance(body_id: String) -> void:
	var was_layered_body: bool = CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender)
	PlayerSave.appearance_body_id = body_id
	PlayerSave.ensure_layered_appearance_defaults(not was_layered_body)
	body_sprite_frames_movement_style = ""
	_apply_body_appearance(body_id)
	_cache_appearance_sprites()
	set_idle_frame()

func set_appearance_part(category: String, part_id: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	var normalized_part_id: String = part_id.strip_edges()
	_ensure_layered_body_for_part_appearance()
	match normalized_category:
		"hair":
			PlayerSave.appearance_hair_id = normalized_part_id
			PlayerSave.sync_hair_style_index_from_id()
		"headgear":
			PlayerSave.appearance_headgear_id = normalized_part_id
		"facegear":
			PlayerSave.appearance_facegear_id = normalized_part_id
		"top":
			PlayerSave.appearance_top_id = normalized_part_id
		"bottom":
			PlayerSave.appearance_bottom_id = normalized_part_id
		"shoes":
			PlayerSave.appearance_shoes_id = normalized_part_id
		_:
			return

	_apply_appearance_part(normalized_category, normalized_part_id, body_sprite_frames_movement_style)
	set_idle_frame()

func _ensure_layered_body_for_part_appearance() -> void:
	if CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		return
	PlayerSave.appearance_body_id = CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	if PlayerSave.gender == "female":
		PlayerSave.appearance_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID
	PlayerSave.ensure_layered_appearance_defaults()
	body_sprite_frames_movement_style = ""
	_apply_body_appearance(PlayerSave.appearance_body_id)

func refresh_appearance() -> void:
	PlayerSave.ensure_layered_appearance_defaults(false)
	body_sprite_frames_movement_style = ""
	_apply_body_appearance(PlayerSave.appearance_body_id)
	set_idle_frame()

func set_display_name(display_name: String, visible: bool = true) -> void:
	if nameplate_label == null:
		return

	nameplate_label.text = display_name.strip_edges()
	_sync_nameplate_visibility(visible)

func set_role_badge(role_badge: String, role_color: Color = Color(0.847, 0.718, 0.404)) -> void:
	if role_badge_label == null:
		return

	role_badge_label.text = role_badge.strip_edges()
	if role_badge_panel != null:
		role_badge_panel.visible = role_badge_label.text != ""
	role_badge_label.add_theme_color_override("font_color", role_color)
	_sync_nameplate_visibility(nameplate_label != null and nameplate_label.text != "")

func set_role_from_user(user: Dictionary) -> void:
	var primary_role: Dictionary = _get_primary_visible_role(user)
	if primary_role.is_empty():
		set_role_badge("")
		return

	set_role_badge(
		str(primary_role.get("badge", "")),
		_get_role_color(str(primary_role.get("id", "")), str(primary_role.get("color", "")))
	)

func get_network_movement_state() -> Dictionary:
	var movement_state := {
		"isMoving": is_moving,
		"startPosition": {
			"x": move_start_position.x,
			"y": move_start_position.y,
		},
		"targetPosition": {
			"x": target_position.x,
			"y": target_position.y,
		},
		"elapsed": move_elapsed,
		"duration": move_duration,
	}
	if activity_style != CharacterAppearanceService.BODY_MOVEMENT_DEFAULT:
		movement_state["activityStyle"] = activity_style
	return movement_state

func get_persistent_world_position() -> Vector2:
	return _snap_world_position(target_position if is_moving else global_position)

func reset_movement_state() -> void:
	var persistent_position := get_persistent_world_position()
	_finish_fishing_activity()
	is_moving = false
	global_position = persistent_position
	target_position = global_position
	move_start_position = global_position
	move_elapsed = 0.0
	move_duration = _get_current_tile_move_duration()
	_clear_input_buffer()
	_clear_held_direction()
	set_idle_frame()
	if pokemon_follower != null:
		pokemon_follower.reset_follow_position()

func face_world_position(world_position: Vector2) -> void:
	var delta := world_position - get_feet_position()
	if delta == Vector2.ZERO:
		return
	
	if abs(delta.x) > abs(delta.y):
		last_direction = Vector2.RIGHT if delta.x > 0 else Vector2.LEFT
	else:
		last_direction = Vector2.DOWN if delta.y > 0 else Vector2.UP
	
	set_idle_frame()

func _ready() -> void:
	add_to_group("player")
	z_as_relative = false
	base_look_position = look_node.position
	PlayerSave.ensure_body_matches_gender(false)
	_apply_body_appearance(PlayerSave.appearance_body_id)
	_cache_appearance_sprites()
	set_display_name(PlayerSave.player_name, true)
	set_role_from_user(AuthService.current_user)

	# Haal de TileMapLayer nodes uit de huidige map op als die al geldig is.
	# Bij scene switches kan de vorige map al freed zijn terwijl de autoload nog
	# even naar die node wijst.
	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		grass_tilemap = GameState.current_map.get_node_or_null("TallGrass")
		water_tilemap = _find_tilemap_layer(GameState.current_map, WATER_TILEMAP_NAMES)
		collision_tilemap = GameState.current_map.get_node_or_null("Collision")
		ledge_down_tilemap = GameState.current_map.get_node_or_null("LedgeDown")
		ledge_up_tilemap = GameState.current_map.get_node_or_null("LedgeUp")
		ledge_left_tilemap = GameState.current_map.get_node_or_null("LedgeLeft")
		ledge_right_tilemap = GameState.current_map.get_node_or_null("LedgeRight")
	
	# Zet speler terug op laatst bekende positie in de juiste richting.
	if GameState.has_player_position:
		global_position = _snap_world_position(GameState.player_position)
		last_direction = GameState.player_direction
	
	# De eerste target is waar de speler nu al staat.
	# Daardoor begint hij niet meteen ergens heen te bewegen.
	target_position = _snap_world_position(global_position)
	move_start_position = target_position
	move_duration = _get_current_tile_move_duration()
	global_position = target_position
	set_idle_frame()
	_update_sort_z()
	_setup_pokemon_follower.call_deferred()

func _exit_tree() -> void:
	if not fishing_activity_active:
		return

	fishing_activity_active = false
	fishing_activity_time_left = 0.0
	activity_style = CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
	_restore_activity_visual_offset()
	GameState.unlock_overworld_input()

func _sync_nameplate_visibility(visible: bool) -> void:
	if nameplate == null or nameplate_label == null:
		return

	_sync_nameplate_layout()
	nameplate_label.visible = visible and nameplate_label.text != ""
	nameplate.visible = visible and nameplate_label.text != ""

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

func _get_primary_visible_role(user: Dictionary) -> Dictionary:
	var roles_value: Variant = user.get("roles", [])
	if not roles_value is Array:
		return {}

	var roles: Array = roles_value as Array
	var primary_role: Dictionary = {}
	var primary_priority: int = -999999
	for role_value: Variant in roles:
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

func _process(delta: float) -> void:
	_update_sort_z()
	_sync_body_sprite_frames_for_movement()
	_sync_appearance_sprite_frames()
	_update_fishing_activity(delta)

	if _try_start_fishing_interaction():
		return

	if _can_accept_movement_input():
		_update_input_priority()
		_update_held_direction(delta)
		_update_input_buffer(delta)
	else:
		_clear_input_buffer()
		_clear_held_direction()

	if is_moving:
		# Beweeg per render-frame naar de volgende tile.
		# De tile-logica blijft deterministisch; alleen de visual interpolation is soepeler.
		move_elapsed = minf(move_elapsed + delta, move_duration)
		var move_progress := move_elapsed / move_duration
		var interpolated_position: Vector2 = move_start_position.lerp(target_position, _get_move_interpolation(move_progress))
		global_position = _snap_world_position(interpolated_position)
		_update_sort_z()

		# Als de bestemming is bereikt.
		if _has_reached_target():
			global_position = _snap_world_position(target_position)
			is_moving = false

			if check_for_map_exit():
				return
			
			if is_standing_on_tall_grass():
				check_for_grass_encounter()

			if _can_accept_movement_input():
				var next_direction := _get_next_movement_direction()
				if next_direction != Vector2.ZERO and _try_start_move(next_direction):
					return

			set_idle_frame()
		return

	if not _can_accept_movement_input():
		set_idle_frame()
		return

	var direction := _get_next_movement_direction()

	if direction != Vector2.ZERO:
		if not _try_start_move(direction):
			set_idle_frame()

func refresh_pokemon_follower() -> void:
	_ensure_pokemon_follower_parent()
	if pokemon_follower == null or not is_instance_valid(pokemon_follower):
		return

	var lead_pokemon: Pokemon = null
	if GameState.show_follower and not PlayerSave.party.is_empty():
		lead_pokemon = PlayerSave.party[0]

	pokemon_follower.set_pokemon(lead_pokemon)

func set_show_follower(show_follower: bool) -> void:
	GameState.show_follower = show_follower
	refresh_pokemon_follower()

func reset_pokemon_follower_position() -> void:
	_ensure_pokemon_follower_parent()
	if pokemon_follower != null and is_instance_valid(pokemon_follower):
		pokemon_follower.reset_follow_position()

func _setup_pokemon_follower() -> void:
	if pokemon_follower != null and is_instance_valid(pokemon_follower):
		_ensure_pokemon_follower_parent()
		return

	pokemon_follower = PokemonFollower.new()
	pokemon_follower.name = "PokemonFollower"
	_get_pokemon_follower_parent().add_child(pokemon_follower)
	pokemon_follower.setup(self)
	refresh_pokemon_follower()

	var refresh_callable: Callable = Callable(self, "refresh_pokemon_follower")
	if not PlayerSave.party_changed.is_connected(refresh_callable):
		PlayerSave.party_changed.connect(refresh_callable)

func _ensure_pokemon_follower_parent() -> void:
	if pokemon_follower != null and not is_instance_valid(pokemon_follower):
		pokemon_follower = null
	if pokemon_follower == null:
		_setup_pokemon_follower()
		return

	var follower_parent := _get_pokemon_follower_parent()
	if pokemon_follower.get_parent() == follower_parent:
		return

	var follower_position := pokemon_follower.global_position
	if pokemon_follower.get_parent() != null:
		pokemon_follower.get_parent().remove_child(pokemon_follower)
	follower_parent.add_child(pokemon_follower)
	pokemon_follower.global_position = follower_position

func _get_pokemon_follower_parent() -> Node:
	var world := GameState.get_world()
	if world != null and is_instance_valid(world):
		return world
	var parent := get_parent()
	if parent != null:
		return parent
	return self

func _can_accept_movement_input() -> bool:
	return not fishing_activity_active \
		and not GameState.is_overworld_input_locked() \
		and not _is_ui_typing()

func _try_start_fishing_interaction() -> bool:
	if fishing_activity_active or is_moving:
		return false
	if not Input.is_action_just_pressed("interact"):
		return false
	if not _can_accept_movement_input():
		return false
	if not _is_facing_water_tile():
		return false

	_start_fishing_activity()
	return true

func _start_fishing_activity() -> void:
	fishing_activity_active = true
	fishing_activity_time_left = FISHING_ACTIVITY_DURATION
	_clear_input_buffer()
	_clear_held_direction()
	GameState.lock_overworld_input()
	set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_FISH)
	_debug_activity_layer_offsets("fishing-start")

func _update_fishing_activity(delta: float) -> void:
	if not fishing_activity_active:
		return

	fishing_activity_time_left = maxf(fishing_activity_time_left - delta, 0.0)
	if fishing_activity_time_left <= 0.0:
		_finish_fishing_activity()

func _finish_fishing_activity() -> void:
	if not fishing_activity_active:
		return

	fishing_activity_active = false
	fishing_activity_time_left = 0.0
	clear_activity_style()
	GameState.unlock_overworld_input()

func _is_facing_water_tile() -> bool:
	if last_direction == Vector2.ZERO:
		return false
	if water_tilemap == null:
		refresh_map_layers()
	if water_tilemap == null:
		return false

	var target_position_value: Vector2 = _snap_world_position(global_position) + (last_direction * TILE_SIZE)
	return _tilemap_has_tile_at(water_tilemap, target_position_value)

func _update_input_priority() -> void:
	for action_name in MOVE_ACTIONS:
		if Input.is_action_just_pressed(action_name):
			input_action_priority.erase(action_name)
			input_action_priority.insert(0, action_name)

func _update_held_direction(delta: float) -> void:
	var direction := _get_input_direction()
	if direction == Vector2.ZERO:
		_clear_held_direction()
		return

	if direction != held_direction:
		held_direction = direction
		held_direction_time = 0.0
		return

	held_direction_time += delta

func _update_input_buffer(delta: float) -> void:
	if input_buffer_time_left > 0.0:
		input_buffer_time_left = maxf(input_buffer_time_left - delta, 0.0)
		if input_buffer_time_left == 0.0:
			buffered_direction = Vector2.ZERO

	for action_name in input_action_priority:
		if not Input.is_action_just_pressed(action_name):
			continue

		buffered_direction = _get_action_direction(action_name)
		input_buffer_time_left = INPUT_BUFFER_DURATION
		return

func _get_next_movement_direction() -> Vector2:
	var direction := _consume_buffered_direction()
	if direction != Vector2.ZERO:
		return direction

	if held_direction_time >= CONTINUOUS_MOVE_HOLD_DELAY:
		return held_direction

	return Vector2.ZERO

func _consume_buffered_direction() -> Vector2:
	if input_buffer_time_left <= 0.0:
		buffered_direction = Vector2.ZERO
		return Vector2.ZERO

	var direction := buffered_direction
	buffered_direction = Vector2.ZERO
	input_buffer_time_left = 0.0
	return direction

func _clear_input_buffer() -> void:
	buffered_direction = Vector2.ZERO
	input_buffer_time_left = 0.0

func _clear_held_direction() -> void:
	held_direction = Vector2.ZERO
	held_direction_time = 0.0

func _has_reached_target() -> bool:
	return move_elapsed >= move_duration

func _get_current_tile_move_duration() -> float:
	if _is_activity_pose_active():
		return TILE_MOVE_DURATION
	return RUN_TILE_MOVE_DURATION if GameState.running_shoes_enabled else TILE_MOVE_DURATION

func _get_current_walk_animation_speed() -> float:
	if _is_activity_pose_active():
		return WALK_ANIMATION_SPEED
	return RUN_WALK_ANIMATION_SPEED if GameState.running_shoes_enabled else WALK_ANIMATION_SPEED

func _is_activity_pose_active() -> bool:
	return activity_style != CharacterAppearanceService.BODY_MOVEMENT_DEFAULT

func _get_current_body_movement_style() -> String:
	if _is_activity_pose_active():
		return activity_style
	return CharacterAppearanceService.BODY_MOVEMENT_RUN \
		if GameState.running_shoes_enabled \
		else CharacterAppearanceService.BODY_MOVEMENT_DEFAULT

func _get_move_interpolation(progress: float) -> float:
	var linear_progress := clampf(progress, 0.0, 1.0)
	if MOVE_EASE_AMOUNT <= 0.0:
		return linear_progress

	var eased_progress := linear_progress * linear_progress * (3.0 - (2.0 * linear_progress))
	return linear_progress + ((eased_progress - linear_progress) * MOVE_EASE_AMOUNT)

func _snap_world_position(position: Vector2) -> Vector2:
	return Vector2(roundf(position.x), roundf(position.y))

func _get_input_direction() -> Vector2:
	for action_name in input_action_priority:
		if Input.is_action_pressed(action_name):
			return _get_action_direction(action_name)

	return Vector2.ZERO

func _get_action_direction(action_name: String) -> Vector2:
	match action_name:
		"move_right":
			return Vector2.RIGHT
		"move_left":
			return Vector2.LEFT
		"move_down":
			return Vector2.DOWN
		"move_up":
			return Vector2.UP

	return Vector2.ZERO

func _try_start_move(direction: Vector2) -> bool:
	last_direction = direction

	# Bepaal de volgende wereldpositie.
	# Voorbeeld: Vector2.RIGHT * 32 = Vector2(32, 0), dus 1 tile naar rechts.
	var new_target_position := _snap_world_position(global_position) + (direction * TILE_SIZE)
	var movement_target_position := new_target_position

	if _try_trigger_route_gate(new_target_position):
		set_idle_frame()
		return false

	var ledge_direction: Vector2 = _get_ledge_direction_for_tile(new_target_position)
	if ledge_direction != Vector2.ZERO:
		if direction != ledge_direction:
			return false

		movement_target_position = _snap_world_position(new_target_position + (ledge_direction * TILE_SIZE))

	# Check eerst of de target tile vrij is.
	# Alleen als can_move_to true teruggeeft, starten we de beweging.
	if not can_move_to(movement_target_position):
		return false

	target_position = _snap_world_position(movement_target_position)
	move_start_position = _snap_world_position(global_position)
	global_position = move_start_position
	move_elapsed = 0.0
	move_duration = _get_current_tile_move_duration()
	is_moving = true
	play_walk_animation(direction)
	return true

func play_walk_animation(direction: Vector2) -> void:
	var animation_name := _get_walk_animation_name(direction)
	var should_restart_animation := master_appearance_sprite == null \
		or master_appearance_sprite.animation != animation_name \
		or not master_appearance_sprite.is_playing()

	for sprite in appearance_sprites:
		if _sprite_has_animation(sprite, animation_name):
			_restore_layer_visibility_if_needed(sprite)
			sprite.animation = animation_name
			if should_restart_animation:
				sprite.frame = 0
				sprite.frame_progress = 0.0
			_apply_face_gear_frame_alignment(sprite)
			sprite.play(animation_name)
		else:
			_hide_layer_for_missing_animation(sprite)

func can_move_to(check_position: Vector2) -> bool:
	refresh_map_layers()

	if collision_tilemap == null:
		push_warning("Player.can_move_to: Collision TileMapLayer is missing; allowing movement as fallback.")
		return true
	
	var current_map: Node = _resolve_current_map()
	if current_map != null:
		var is_blocked_by_character := false
		if current_map.has_method("is_position_blocked_by_character"):
			is_blocked_by_character = bool(current_map.is_position_blocked_by_character(check_position))
		else:
			is_blocked_by_character = MapCharacterBlocking.is_position_blocked_by_character(current_map, check_position)

		if is_blocked_by_character:
			return false
	
	# check_position is een global/world pixelpositie.
	# TileMapLayer.local_to_map() verwacht juist een lokale positie binnen die TileMapLayer.
	# Daarom zetten we eerst world -> local om.
	var local_position := collision_tilemap.to_local(check_position)

	# Zet de lokale pixelpositie om naar een tile/grid coördinaat.
	# Voorbeeld bij 32x32 tiles: lokale pixelpositie (64, 96) wordt ongeveer tile (2, 3).
	var tile_position := collision_tilemap.local_to_map(local_position)

	# Vraag tiledata op voor die tile.
	# In deze setup betekent: geen tile_data = geen collision tile = vrij lopen.
	# Wel tile_data = er ligt een collision tile = blokkeren.
	var source_id: int = collision_tilemap.get_cell_source_id(tile_position)
	if source_id != -1:
		return false

	var tile_data := collision_tilemap.get_cell_tile_data(tile_position)

	return tile_data == null

func _get_ledge_direction_for_tile(check_position: Vector2) -> Vector2:
	refresh_map_layers()

	if _tilemap_has_tile_at(ledge_down_tilemap, check_position):
		return Vector2.DOWN
	if _tilemap_has_tile_at(ledge_up_tilemap, check_position):
		return Vector2.UP
	if _tilemap_has_tile_at(ledge_left_tilemap, check_position):
		return Vector2.LEFT
	if _tilemap_has_tile_at(ledge_right_tilemap, check_position):
		return Vector2.RIGHT

	return Vector2.ZERO

func _tilemap_has_tile_at(tilemap: TileMapLayer, check_position: Vector2) -> bool:
	if tilemap == null:
		return false

	var local_position: Vector2 = tilemap.to_local(check_position)
	var tile_position: Vector2i = tilemap.local_to_map(local_position)
	var source_id: int = tilemap.get_cell_source_id(tile_position)
	if source_id != -1:
		return true

	var tile_data: TileData = tilemap.get_cell_tile_data(tile_position)
	return tile_data != null

func _try_trigger_route_gate(check_position: Vector2) -> bool:
	if route_gate_interaction_in_progress:
		return true

	var current_map: Node = _resolve_current_map()
	if current_map == null or not current_map.has_method("get_closed_route_gate_npc"):
		return false

	var gate_npc: Node = current_map.get_closed_route_gate_npc(check_position)
	if gate_npc == null:
		return false

	route_gate_interaction_in_progress = true
	Callable(self, "_handle_route_gate_interaction").call_deferred(gate_npc)
	return true

func _handle_route_gate_interaction(gate_npc: Node) -> void:
	if gate_npc.has_method("on_route_gate_blocked"):
		await gate_npc.on_route_gate_blocked(self)

	route_gate_interaction_in_progress = false
	
func set_idle_frame() -> void:
	for sprite in appearance_sprites:
		sprite.stop()
		_set_idle_animation(sprite, last_direction)
	_apply_activity_visual_offset()
	
func refresh_map_layers() -> void:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		collision_tilemap = null
		grass_tilemap = null	
		water_tilemap = null
		ledge_down_tilemap = null
		ledge_up_tilemap = null
		ledge_left_tilemap = null
		ledge_right_tilemap = null
		push_warning("Player.refresh_map_layers: could not resolve current map.")
		return

	GameState.current_map = current_map
	collision_tilemap = current_map.get_node_or_null("Collision")
	grass_tilemap = current_map.get_node_or_null("TallGrass")
	water_tilemap = _find_tilemap_layer(current_map, WATER_TILEMAP_NAMES)
	ledge_down_tilemap = current_map.get_node_or_null("LedgeDown")
	ledge_up_tilemap = current_map.get_node_or_null("LedgeUp")
	ledge_left_tilemap = current_map.get_node_or_null("LedgeLeft")
	ledge_right_tilemap = current_map.get_node_or_null("LedgeRight")

	if collision_tilemap == null:
		push_warning("Player.refresh_map_layers: Collision layer missing on %s." % current_map.name)

func _find_tilemap_layer(parent: Node, layer_names: Array[String]) -> TileMapLayer:
	if parent == null:
		return null

	for layer_name: String in layer_names:
		var direct_layer := parent.get_node_or_null(layer_name) as TileMapLayer
		if direct_layer != null:
			return direct_layer

	return _find_tilemap_layer_recursive(parent, layer_names)

func _find_tilemap_layer_recursive(node: Node, layer_names: Array[String]) -> TileMapLayer:
	var tilemap_layer := node as TileMapLayer
	if tilemap_layer != null and layer_names.has(tilemap_layer.name):
		return tilemap_layer

	for child: Node in node.get_children():
		var child_layer := _find_tilemap_layer_recursive(child, layer_names)
		if child_layer != null:
			return child_layer

	return null
	
func is_standing_on_tall_grass() -> bool:
	if grass_tilemap == null:
		refresh_map_layers()

	if grass_tilemap == null:
		return false
		
	var local_position := grass_tilemap.to_local(global_position)
	var tile_position := grass_tilemap.local_to_map(local_position)
	var tile_data := grass_tilemap.get_cell_tile_data(tile_position)
	
	return tile_data != null
		
func check_for_grass_encounter() -> void:
	var current_map := GameState.current_map
	
	if current_map == null:
		return
		
	if not current_map.has_method("get_wild_encounter_area_id"):
		return
		
	var area_id: String = str(current_map.call("get_wild_encounter_area_id"))
	if area_id == "":
		return

	if GameState.repel_enabled:
		return

	if current_map.has_method("should_trigger_wild_encounter"):
		if not bool(current_map.call("should_trigger_wild_encounter", "grass")):
			return
	
	var world := GameState.get_world()
	if world != null and world.has_method("start_triggered_wild_battle_for_area"):
		world.start_triggered_wild_battle_for_area(area_id, "grass")

func _is_ui_typing() -> bool:
	if _is_text_input_control(get_viewport().gui_get_focus_owner()):
		return true

	var tree := get_tree()
	if tree == null:
		return false

	for node: Node in tree.get_nodes_in_group(TEXT_INPUT_WINDOW_GROUP):
		if not (node is Window):
			continue

		var window := node as Window
		if not window.visible:
			continue

		if _is_text_input_control(window.gui_get_focus_owner()):
			return true

	return false

func _is_text_input_control(control: Control) -> bool:
	return control is LineEdit or control is TextEdit

func check_for_map_exit() -> bool:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		return false

	var exits := current_map.get_node_or_null("Exits")
	if exits == null:
		return false

	for exit_node: Node in exits.get_children():
		if not (exit_node is Area2D):
			continue

		var exit_area := exit_node as Area2D
		if _is_inside_exit_area(exit_area):
			if exit_area.has_method("_on_body_entered"):
				exit_area.call("_on_body_entered", self)
				return true

	return false

func _is_inside_exit_area(exit_area: Area2D) -> bool:
	for child: Node in exit_area.get_children():
		if not (child is CollisionShape2D):
			continue

		var shape_node := child as CollisionShape2D
		if shape_node.disabled:
			continue

		var shape: Shape2D = shape_node.shape
		if shape is RectangleShape2D:
			var rectangle_shape := shape as RectangleShape2D
			var local_position := shape_node.to_local(global_position)
			var shape_rect := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
			if shape_rect.has_point(local_position):
				return true

	return false

func _resolve_current_map() -> Node:
	var parent_node := get_parent()
	while parent_node != null:
		if parent_node.get_node_or_null("Collision") != null or parent_node.get_node_or_null("TallGrass") != null:
			return parent_node

		parent_node = parent_node.get_parent()

	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		return GameState.current_map

	return null

func _update_sort_z() -> void:
	z_index = clampi(floori(get_feet_position().y), SORT_Z_MIN, SORT_Z_MAX)

func _cache_appearance_sprites() -> void:
	appearance_sprites.clear()
	_collect_appearance_sprites(look_node)
	master_appearance_sprite = _get_master_appearance_sprite()
	_sync_appearance_animation_speeds()

func _collect_appearance_sprites(parent: Node) -> void:
	for child: Node in parent.get_children():
		var sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if sprite != null:
			sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
			appearance_sprites.append(sprite)

		_collect_appearance_sprites(child)

func _get_master_appearance_sprite() -> AnimatedSprite2D:
	for sprite in appearance_sprites:
		if sprite.name == BODY_SPRITE_NAME:
			return sprite

	if appearance_sprites.is_empty():
		return null

	return appearance_sprites[0]

func _apply_body_appearance(body_id: String) -> void:
	var body_sprite := look_node.get_node_or_null(BODY_SPRITE_NAME) as AnimatedSprite2D
	if body_sprite == null:
		push_warning("Player: BodySprite node is missing.")
		return

	var normalized_body_id: String = body_id.strip_edges()
	var available_body_ids: Array[String] = CharacterAppearanceService.get_available_body_ids(PlayerSave.gender)
	if normalized_body_id == "" or not available_body_ids.has(normalized_body_id):
		normalized_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID \
			if PlayerSave.gender == "female" \
			else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
		PlayerSave.appearance_body_id = normalized_body_id
		PlayerSave.ensure_layered_appearance_defaults()

	var movement_style: String = _get_current_body_movement_style()
	var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(
		normalized_body_id,
		PlayerSave.gender,
		movement_style
	)
	if body_frames == null:
		push_warning("Player: body appearance '%s' could not be loaded." % normalized_body_id)
		return

	body_sprite.sprite_frames = body_frames
	body_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	_apply_body_modulate(body_sprite, normalized_body_id)
	body_sprite_frames_movement_style = movement_style
	_apply_appearance_parts(movement_style)

func _sync_body_sprite_frames_for_movement() -> void:
	var body_sprite := look_node.get_node_or_null(BODY_SPRITE_NAME) as AnimatedSprite2D
	if body_sprite == null:
		return

	var movement_style: String = _get_current_body_movement_style()
	if movement_style == body_sprite_frames_movement_style:
		return

	var current_animation: StringName = body_sprite.animation
	var current_frame: int = body_sprite.frame
	var current_frame_progress: float = body_sprite.frame_progress
	var was_playing: bool = body_sprite.is_playing()
	var body_frames: SpriteFrames = CharacterAppearanceService.get_body_frames(
		PlayerSave.appearance_body_id,
		PlayerSave.gender,
		movement_style
	)
	if body_frames == null:
		return

	body_sprite.sprite_frames = body_frames
	body_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	_apply_body_modulate(body_sprite, PlayerSave.appearance_body_id)
	body_sprite_frames_movement_style = movement_style
	_apply_appearance_parts(movement_style)
	_sync_appearance_animation_speeds()

	if body_frames.has_animation(current_animation):
		body_sprite.animation = current_animation
		var frame_count: int = body_frames.get_frame_count(current_animation)
		if frame_count > 0:
			body_sprite.frame = mini(current_frame, frame_count - 1)
			body_sprite.frame_progress = current_frame_progress
		if was_playing:
			body_sprite.play(current_animation)
		else:
			body_sprite.stop()
		return

	set_idle_frame()

func _apply_appearance_parts(movement_style: String) -> void:
	var normalized_movement_style: String = CharacterAppearanceService.normalize_movement_style(movement_style)

	if not CharacterAppearanceService.body_supports_layered_parts(PlayerSave.appearance_body_id, PlayerSave.gender):
		for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
			_clear_appearance_part_sprite(str(category_value))
		return

	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category: String = str(category_value)
		var part_id: String = _get_player_appearance_part_id(category)
		_apply_appearance_part(category, part_id, normalized_movement_style)

func _get_player_appearance_part_id(category: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category):
		"hair":
			return PlayerSave.appearance_hair_id
		"headgear":
			return PlayerSave.appearance_headgear_id
		"facegear":
			return PlayerSave.appearance_facegear_id
		"top":
			return PlayerSave.appearance_top_id
		"bottom":
			return PlayerSave.appearance_bottom_id
		"shoes":
			return PlayerSave.appearance_shoes_id
		"eyes":
			return CharacterAppearanceService.get_default_part_id("eyes", PlayerSave.gender)
		"eyebrows":
			return CharacterAppearanceService.get_default_part_id("eyebrows", PlayerSave.gender)
		_:
			return ""

func _apply_appearance_part(category: String, part_id: String, movement_style: String = "") -> void:
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

	var normalized_movement_style: String = movement_style
	if normalized_movement_style == "":
		normalized_movement_style = CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
	normalized_movement_style = CharacterAppearanceService.normalize_movement_style(normalized_movement_style)
	var part_frames: SpriteFrames = _get_appearance_part_frames(normalized_category, normalized_part_id, normalized_movement_style)
	if part_frames == null:
		_clear_appearance_part_sprite(normalized_category)
		return

	sprite.sprite_frames = part_frames
	sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	sprite.set_meta(UNEQUIPPED_APPEARANCE_PART_META, false)
	_apply_appearance_part_visuals(sprite, normalized_category)
	sprite.visible = true
	sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false)
	_sync_part_sprite_to_animation(sprite)

func _sync_part_sprite_to_animation(sprite: AnimatedSprite2D) -> void:
	if sprite == null or master_appearance_sprite == null:
		return

	var animation_name: StringName = master_appearance_sprite.animation
	if not _sprite_has_animation(sprite, animation_name):
		_hide_layer_for_missing_animation(sprite)
		return

	_restore_layer_visibility_if_needed(sprite)
	sprite.animation = animation_name
	var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count > 0:
		sprite.frame = mini(master_appearance_sprite.frame, frame_count - 1)
		sprite.frame_progress = master_appearance_sprite.frame_progress
	if master_appearance_sprite.is_playing():
		sprite.play(animation_name)
	else:
		sprite.stop()

func _get_appearance_sprite(sprite_name: String) -> AnimatedSprite2D:
	if look_node == null:
		return null
	return look_node.get_node_or_null(sprite_name) as AnimatedSprite2D

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
	_restore_sprite_base_offset(sprite)
	sprite.set_meta(UNEQUIPPED_APPEARANCE_PART_META, true)
	sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false)

func _apply_body_modulate(body_sprite: AnimatedSprite2D, body_id: String) -> void:
	if body_sprite == null:
		return
	if CharacterAppearanceService.body_supports_layered_parts(body_id, PlayerSave.gender):
		body_sprite.modulate = _parse_appearance_color(PlayerSave.appearance_skin_tone, Color.WHITE)
	else:
		body_sprite.modulate = Color.WHITE

func _get_appearance_part_modulate(category: String) -> Color:
	return Color.WHITE

func _apply_appearance_part_visuals(sprite: AnimatedSprite2D, category: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	sprite.material = null
	sprite.modulate = _get_appearance_part_modulate(normalized_category)
	if normalized_category != "facegear":
		_apply_activity_layer_offset(sprite, normalized_category)

func _apply_activity_layer_offset(sprite: AnimatedSprite2D, category: String) -> void:
	if sprite == null:
		return
	if not sprite.has_meta(ACTIVITY_BASE_SPRITE_OFFSET_META):
		sprite.set_meta(ACTIVITY_BASE_SPRITE_OFFSET_META, sprite.offset)

	var base_offset: Vector2 = sprite.get_meta(ACTIVITY_BASE_SPRITE_OFFSET_META)
	sprite.offset = base_offset + _get_activity_layer_offset(category)

func _sync_activity_layer_offsets() -> void:
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category: String = str(category_value)
		if category == "facegear":
			continue
		var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[category]))
		if sprite == null or _is_unequipped_appearance_part_sprite(sprite):
			continue
		_apply_activity_layer_offset(sprite, category)

func _apply_activity_visual_offset() -> void:
	if look_node == null:
		return
	look_node.position = base_look_position + _get_activity_visual_offset()

func _restore_activity_visual_offset() -> void:
	if look_node == null:
		return
	look_node.position = base_look_position

func _get_activity_visual_offset() -> Vector2:
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(activity_style)
	var style_offsets: Variant = ACTIVITY_VISUAL_OFFSETS.get(normalized_style, {})
	if not style_offsets is Dictionary:
		return Vector2.ZERO

	var direction_offsets: Dictionary = style_offsets as Dictionary
	var direction_name: String = _get_activity_offset_direction()
	if direction_offsets.has(direction_name):
		return direction_offsets[direction_name] as Vector2
	return Vector2.ZERO

func _restore_sprite_base_offset(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	if sprite.has_meta(ACTIVITY_BASE_SPRITE_OFFSET_META):
		sprite.offset = sprite.get_meta(ACTIVITY_BASE_SPRITE_OFFSET_META)
	elif sprite.has_meta(BASE_SPRITE_OFFSET_META):
		sprite.offset = sprite.get_meta(BASE_SPRITE_OFFSET_META)

func _get_activity_layer_offset(category: String) -> Vector2:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(body_sprite_frames_movement_style)
	var style_offsets: Variant = ACTIVITY_LAYER_OFFSETS.get(normalized_style, {})
	if not style_offsets is Dictionary:
		return Vector2.ZERO

	var category_offsets: Dictionary = style_offsets as Dictionary
	var direction_offsets: Variant = category_offsets.get(_get_activity_offset_direction(), category_offsets.get("default", {}))
	if direction_offsets is Dictionary:
		var directional_category_offsets: Dictionary = direction_offsets as Dictionary
		if directional_category_offsets.has(normalized_category):
			return directional_category_offsets[normalized_category] as Vector2

	if category_offsets.has(normalized_category):
		return category_offsets[normalized_category] as Vector2
	return Vector2.ZERO

func _get_activity_offset_direction() -> String:
	if master_appearance_sprite != null:
		var animation_name: String = str(master_appearance_sprite.animation)
		if animation_name.ends_with("_left"):
			return "left"
		if animation_name.ends_with("_right"):
			return "right"
		if animation_name.ends_with("_up"):
			return "up"
		if animation_name.ends_with("_down"):
			return "down"

	if last_direction == Vector2.LEFT:
		return "left"
	if last_direction == Vector2.RIGHT:
		return "right"
	if last_direction == Vector2.UP:
		return "up"
	return "down"

func _debug_activity_layer_offsets(reason: String) -> void:
	if not GameState.world_debug_enabled:
		return

	GameState.debug_world("[activity-pose] %s style=%s direction=%s body_style=%s position=%s look=%s visual_offset=%s" % [
		reason,
		activity_style,
		_get_activity_offset_direction(),
		body_sprite_frames_movement_style,
		str(global_position),
		str(look_node.position if look_node != null else Vector2.ZERO),
		str(_get_activity_visual_offset()),
	])
	var body_sprite := _get_appearance_sprite(BODY_SPRITE_NAME)
	if body_sprite != null:
		GameState.debug_world("[activity-pose] layer=body visible=%s offset=%s animation=%s frame=%d" % [
			str(body_sprite.visible),
			str(body_sprite.offset),
			str(body_sprite.animation),
			body_sprite.frame,
		])
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category: String = str(category_value)
		var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[category]))
		if sprite == null:
			continue
		GameState.debug_world("[activity-pose] layer=%s visible=%s offset=%s activity_offset=%s animation=%s frame=%d" % [
			category,
			str(sprite.visible),
			str(sprite.offset),
			str(_get_activity_layer_offset(category)),
			str(sprite.animation),
			sprite.frame,
		])

func _get_appearance_part_frames(category: String, part_id: String, movement_style: String) -> SpriteFrames:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_eye_color, Color.WHITE)
		)
	if normalized_category == "hair" or normalized_category == "eyebrows":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_hair_color, Color.WHITE),
			true
		)
	return CharacterAppearanceService.get_part_frames(
		category,
		part_id,
		PlayerSave.gender,
		movement_style
	)

func _parse_appearance_color(color_text: String, fallback: Color) -> Color:
	var normalized_color: String = color_text.strip_edges()
	if normalized_color == "":
		return fallback
	if not normalized_color.begins_with("#"):
		return fallback
	return Color(normalized_color)

func _sync_appearance_sprite_frames() -> void:
	if master_appearance_sprite == null or not master_appearance_sprite.is_playing():
		return

	var animation_name: StringName = master_appearance_sprite.animation
	var frame: int = master_appearance_sprite.frame
	var frame_progress: float = master_appearance_sprite.frame_progress

	for sprite in appearance_sprites:
		if sprite == master_appearance_sprite:
			continue
		if not _sprite_has_animation(sprite, animation_name):
			_hide_layer_for_missing_animation(sprite)
			continue

		_restore_layer_visibility_if_needed(sprite)
		sprite.animation = animation_name
		var frame_count: int = sprite.sprite_frames.get_frame_count(animation_name)
		if frame_count <= 0:
			continue

		sprite.frame = mini(frame, frame_count - 1)
		sprite.frame_progress = frame_progress
		_apply_face_gear_frame_alignment(sprite)
		if not sprite.is_playing():
			sprite.play(animation_name)

func _sync_appearance_animation_speeds() -> void:
	var idle_animation_names: Array[String] = ["idle_down", "idle_left", "idle_right", "idle_up"]
	var walk_animation_names: Array[String] = ["walk_down", "walk_left", "walk_right", "walk_up"]

	for sprite in appearance_sprites:
		if sprite.sprite_frames == null:
			continue

		for animation_name: String in idle_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, IDLE_ANIMATION_SPEED)

		for animation_name: String in walk_animation_names:
			if sprite.sprite_frames.has_animation(animation_name):
				sprite.sprite_frames.set_animation_speed(animation_name, _get_current_walk_animation_speed())

func _set_idle_animation(sprite: AnimatedSprite2D, direction: Vector2) -> void:
	if _is_unequipped_appearance_part_sprite(sprite):
		sprite.visible = false
		sprite.stop()
		return

	var animation_name := _get_idle_animation_name(direction)
	if _sprite_has_animation(sprite, animation_name):
		_restore_layer_visibility_if_needed(sprite)
		sprite.play(animation_name)
		sprite.stop()
		_apply_face_gear_frame_alignment(sprite)
		return
	
	animation_name = _get_walk_animation_name(direction)
	if _sprite_has_animation(sprite, animation_name):
		_restore_layer_visibility_if_needed(sprite)
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()
		_apply_face_gear_frame_alignment(sprite)
		return

	_hide_layer_for_missing_animation(sprite)

func _apply_face_gear_frame_alignment(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.name != FACE_GEAR_SPRITE_NAME or sprite.sprite_frames == null:
		return

	if master_appearance_sprite == null or master_appearance_sprite.sprite_frames == null:
		return

	if not sprite.has_meta(BASE_SPRITE_OFFSET_META):
		sprite.set_meta(BASE_SPRITE_OFFSET_META, sprite.offset)

	var animation_name: StringName = sprite.animation
	if not sprite.sprite_frames.has_animation(animation_name):
		return

	if not master_appearance_sprite.sprite_frames.has_animation(animation_name):
		return

	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var master_frame_count := master_appearance_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0 or master_frame_count <= 0:
		return

	var frame_index := clampi(sprite.frame, 0, frame_count - 1)
	var master_frame_index := clampi(master_appearance_sprite.frame, 0, master_frame_count - 1)

	var reference_face_center_y := _get_frame_opaque_center_y(sprite.sprite_frames, animation_name, 0)
	var current_face_center_y := _get_frame_opaque_center_y(sprite.sprite_frames, animation_name, frame_index)
	var reference_body_center_y := _get_frame_opaque_center_y(master_appearance_sprite.sprite_frames, animation_name, 0)
	var current_body_center_y := _get_frame_opaque_center_y(master_appearance_sprite.sprite_frames, animation_name, master_frame_index)
	if reference_face_center_y < 0.0 or current_face_center_y < 0.0:
		return
	if reference_body_center_y < 0.0 or current_body_center_y < 0.0:
		return

	var base_offset: Vector2 = sprite.get_meta(BASE_SPRITE_OFFSET_META)
	var body_bob_y := current_body_center_y - reference_body_center_y
	sprite.offset = base_offset \
		+ Vector2(0.0, reference_face_center_y + body_bob_y - current_face_center_y) \
		+ _get_activity_layer_offset("facegear")

func _get_frame_opaque_center_y(sprite_frames: SpriteFrames, animation_name: StringName, frame_index: int) -> float:
	var cache_key := "%s:%s:%d" % [str(sprite_frames.get_instance_id()), str(animation_name), frame_index]
	if frame_opaque_center_y_cache.has(cache_key):
		return float(frame_opaque_center_y_cache[cache_key])

	var texture := sprite_frames.get_frame_texture(animation_name, frame_index)
	if texture == null:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var image := texture.get_image()
	if image == null:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var top_y := image.get_height()
	var bottom_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.05:
				top_y = mini(top_y, y)
				bottom_y = maxi(bottom_y, y)

	if bottom_y < top_y:
		frame_opaque_center_y_cache[cache_key] = -1.0
		return -1.0

	var center_y := (float(top_y) + float(bottom_y)) * 0.5
	frame_opaque_center_y_cache[cache_key] = center_y
	return center_y

func _hide_layer_for_missing_animation(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite == master_appearance_sprite:
		return

	if sprite.visible:
		sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, true)
		sprite.visible = false

	sprite.stop()

func _restore_layer_visibility_if_needed(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	if _is_unequipped_appearance_part_sprite(sprite):
		sprite.visible = false
		return

	if sprite.get_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false) == true:
		sprite.visible = true
		sprite.set_meta(HIDDEN_FOR_MISSING_ANIMATION_META, false)

func _sprite_has_animation(sprite: AnimatedSprite2D, animation_name: StringName) -> bool:
	return sprite != null \
		and not _is_unequipped_appearance_part_sprite(sprite) \
		and sprite.sprite_frames != null \
		and str(animation_name) != "" \
		and sprite.sprite_frames.has_animation(animation_name)

func _is_unequipped_appearance_part_sprite(sprite: AnimatedSprite2D) -> bool:
	return sprite != null and bool(sprite.get_meta(UNEQUIPPED_APPEARANCE_PART_META, false))

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
