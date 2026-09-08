extends Node2D

class_name RemotePlayerAvatar

signal interaction_requested(player_state: Dictionary, world_position: Vector2)

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const MountService := preload("res://scripts/services/mount_service.gd")
const GuildEmblemTexture := preload("res://scripts/ui/guild_emblem_texture.gd")
const NameplateLayout := preload("res://scripts/ui/nameplate_layout.gd")
const RoleBadgeTexture := preload("res://scripts/ui/role_badge_texture.gd")
const MapChatBubbleScript := preload("res://scripts/world/map_chat_bubble.gd")
const HorizontalStairElevationScript := preload("res://scripts/world/horizontal_stair_elevation.gd")
const AethernetTeleportEffectScript := preload("res://scripts/world/aethernet_teleport_effect.gd")
const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const SNAP_DISTANCE := 96.0
const REMOTE_MOVE_SPEED := 150.0
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const WALK_ANIMATION_HOLD_DURATION := 0.18
const INTERPOLATION_DELAY_SECONDS := 0.16
const MAX_POSITION_SAMPLES := 8
const ROLE_BADGE_COLORS := {
	"alpha": Color(0.851, 0.722, 1.0),
	"gamemaster": Color(0.0, 0.749, 1.0),
	"senior_staff": Color(0.957, 0.773, 0.259),
	"developer": Color(0.0, 0.898, 0.659),
	"moderator": Color(0.482, 0.173, 0.749),
}
const STAFF_ROLE_CATEGORY := "staff"
const LEGACY_STAFF_ROLE_IDS := ["staff", "owner", "senior_staff", "developer", "moderator", "gamemaster", "alpha", "patreon"]
const NAMEPLATE_WIDTH := 164.0
const NAMEPLATE_CENTER_X := NAMEPLATE_WIDTH * 0.5
const ROLE_BADGE_TEXT_HEIGHT := 13.0
const ROLE_BADGE_ICON_SIZE := Vector2(28.0, 28.0)
const ROLE_BADGE_DEFAULT_WIDTH := 30.0
const NAMEPLATE_MAX_NAME_WIDTH := 132.0
const NAMEPLATE_LAYER_GAP := 2.0
const BODY_SPRITE_NAME := "BodySprite"
const MOUNT_SPRITE_NAME := "MountSprite"
const MOUNT_FOREGROUND_SPRITE_NAME := "MountForegroundSprite"
const UNEQUIPPED_APPEARANCE_PART_META := "unequipped_appearance_part"
const ACTIVITY_BASE_SPRITE_OFFSET_META := "activity_base_sprite_offset"
const ACTIVITY_LAYER_OFFSETS := {
	"fish": {
		"default": {
			"hair": Vector2(0.0, 1.0),
			"headgear": Vector2(0.0, 1.0),
			"facial_hair": Vector2(0.0, 2.0),
			"facegear": Vector2(0.0, 2.0),
			"eyes": Vector2(0.0, 2.0),
			"eyebrows": Vector2(0.0, 2.0),
		},
		"down": {
			"hair": Vector2(0.0, -10.0),
			"headgear": Vector2(0.0, -10.0),
			"facial_hair": Vector2(0.0, -10.0),
			"facegear": Vector2(0.0, -10.0),
			"eyes": Vector2(0.0, -10.0),
			"eyebrows": Vector2(0.0, -10.0),
		},
		"left": {
			"hair": Vector2(12.0, 1.0),
			"headgear": Vector2(12.0, 1.0),
			"facial_hair": Vector2(12.0, 2.0),
			"facegear": Vector2(12.0, 2.0),
			"eyes": Vector2(12.0, 2.0),
			"eyebrows": Vector2(12.0, 2.0),
		},
		"right": {
			"hair": Vector2(-12.0, 1.0),
			"headgear": Vector2(-12.0, 1.0),
			"facial_hair": Vector2(-12.0, 2.0),
			"facegear": Vector2(-12.0, 2.0),
			"eyes": Vector2(-12.0, 2.0),
			"eyebrows": Vector2(-12.0, 2.0),
		},
	},
	"ride": {
		"default": {
			"hair": Vector2(0.0, 4.0),
			"headgear": Vector2(0.0, 4.0),
			"facial_hair": Vector2(0.0, 4.0),
			"facegear": Vector2(0.0, 4.0),
			"eyes": Vector2(0.0, 4.0),
			"eyebrows": Vector2(0.0, 4.0),
		},
		"down": {
			"hair": Vector2(0.0, 4.0),
			"headgear": Vector2(0.0, 4.0),
			"facial_hair": Vector2(0.0, 4.0),
			"facegear": Vector2(0.0, 4.0),
			"eyes": Vector2(0.0, 6.0),
			"eyebrows": Vector2(0.0, 5.0),
		},
		"up": {
			"hair": Vector2.ZERO,
			"headgear": Vector2.ZERO,
			"facial_hair": Vector2.ZERO,
			"facegear": Vector2.ZERO,
			"eyes": Vector2.ZERO,
			"eyebrows": Vector2.ZERO,
		},
		"left": {
			"hair": Vector2(-4.0, 4.0),
			"headgear": Vector2(-4.0, 4.0),
			"facial_hair": Vector2(-4.0, 4.0),
			"facegear": Vector2(-4.0, 4.0),
			"eyes": Vector2(-4.0, 4.0),
			"eyebrows": Vector2(-4.0, 4.0),
		},
		"right": {
			"hair": Vector2(4.0, 4.0),
			"headgear": Vector2(4.0, 4.0),
			"facial_hair": Vector2(4.0, 4.0),
			"facegear": Vector2(4.0, 4.0),
			"eyes": Vector2(4.0, 4.0),
			"eyebrows": Vector2(4.0, 4.0),
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
# Keep remote Surf-fishing riders aligned with the same existing-pose saddle
# offsets used locally. Normal land fishing continues to use the fish offsets.
const SURF_FISH_RIDER_OFFSETS := {
	"down": Vector2i(-2, 18),
	"left": Vector2i(-20, 4),
	"right": Vector2i(20, 4),
	"up": Vector2i(-2, 10),
}
const SURF_FISH_BODY_HIDDEN_REGIONS := {
	"down": Rect2i(30, 48, 4, 16),
}
const APPEARANCE_PART_SPRITES := {
	"hair": "HairSprite",
	"headgear": "HeadgearSprite",
	"facial_hair": "FacialHairSprite",
	"facegear": "FaceGearSprite",
	"top": "TopSprite",
	"bottom": "BottomSprite",
	"shoes": "ShoesSprite",
	"eyes": "EyesSprite",
	"eyebrows": "EyebrowsSprite",
}
const RIDE_STATIC_PART_CATEGORIES := ["hair", "headgear", "facial_hair", "facegear", "eyes", "eyebrows"]

var user_id := 0
var username := ""
var display_name := ""
var roles: Array = []
var selected_role_badge := ""
var target_position := Vector2.ZERO
var walk_animation_hold_timer := 0.0
var position_samples: Array[Dictionary] = []
var tile_move_start_position := Vector2.ZERO
var tile_move_target_position := Vector2.ZERO
var tile_move_elapsed := 0.0
var tile_move_duration := 0.22
var is_replaying_tile_move := false
var stair_elevation := HorizontalStairElevationScript.ELEVATION_NONE
var stair_visual_offset := Vector2.ZERO
var pending_tile_moves: Array[Dictionary] = []
var last_direction := Vector2.DOWN
var look_node: Node2D
var mount_sprite: AnimatedSprite2D
var mount_foreground_sprite: AnimatedSprite2D
var rider_node: Node2D
var base_look_position := Vector2.ZERO
var base_rider_position := Vector2.ZERO
var appearance_sprites: Array[AnimatedSprite2D] = []
var nameplate: Control
var nameplate_background: Panel
var nameplate_label: Label
var guild_emblem_background: Panel
var guild_emblem: TextureRect
var role_badge_panel: Panel
var role_badge_label: Label
var role_badge_icon: TextureRect
var map_chat_bubble: PanelContainer
var interaction_hit_area: Area2D
var pokemon_follower: PokemonFollower
var current_follower_species := ""
var current_follower_shiny := false
var current_body_id := ""
var current_body_gender := ""
var current_body_movement_style := CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
var current_activity_style := CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
var current_mount_id := ""
var current_gender := "male"
var current_appearance_state: Dictionary = {}
var current_appearance_signature := ""
var has_position := false
var presence_state: Dictionary = {}
var creator_nameplate_visibility_override_active := false
var creator_nameplate_visible := true
var gameplay_nameplate_visibility_override_active := false
var gameplay_nameplate_visible := true
var gameplay_identity_mask_override_active := false
var gameplay_identity_masked := false
var gameplay_identity_placeholder := "???"
var last_aethernet_effect_sequence := -1
var active_aethernet_effect: Node
var _rendered_emblem: Dictionary = {}
var _emblem_initialized := false
var _rendered_animation_state: Array = []


func _ready() -> void:
	add_to_group("remote_player_avatar")
	z_as_relative = false
	y_sort_enabled = true
	_create_visual()
	visibility_changed.connect(_on_visual_visibility_changed)
	_on_visual_visibility_changed()
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
	presence_state = state.duplicate(true)
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
	selected_role_badge = str(state.get("selectedRoleBadge", selected_role_badge)).strip_edges().to_lower()
	_apply_guild_emblem(_dictionary_from_value(state.get("guildEmblem", {})))
	_update_nameplate()
	_apply_aethernet_effect_state(_dictionary_from_value(state.get("aethernetEffect", {})))

	var position_data := _dictionary_from_value(state.get("position", {}))
	var new_target_position := Vector2(
		float(position_data.get("x", target_position.x)),
		float(position_data.get("y", target_position.y))
	)
	var movement_data := _dictionary_from_value(state.get("movement", {}))
	current_activity_style = _resolve_activity_style(state, movement_data)
	var next_mount_id := MountService.normalize_mount_id(str(
		movement_data.get("mountId", state.get("mountId", ""))
	))
	if next_mount_id != current_mount_id:
		current_mount_id = next_mount_id
		current_appearance_signature = ""
		current_body_movement_style = ""
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
	_sync_mount_visual()
	_apply_follower_state(_dictionary_from_value(state.get("follower", {})))
	_update_sort_z()


func _apply_aethernet_effect_state(effect_state: Dictionary) -> void:
	var phase := str(effect_state.get("phase", "")).strip_edges().to_lower()
	if phase not in ["depart", "arrive"]:
		if active_aethernet_effect != null and is_instance_valid(active_aethernet_effect):
			active_aethernet_effect.call("cancel_and_restore")
		active_aethernet_effect = null
		var restored_modulate := modulate
		restored_modulate.a = 1.0
		modulate = restored_modulate
		return
	var sequence := int(effect_state.get("sequence", -1))
	if sequence < 0 or sequence == last_aethernet_effect_sequence:
		return
	last_aethernet_effect_sequence = sequence
	_play_aethernet_effect.call_deferred(phase)


func _play_aethernet_effect(phase: String) -> void:
	if active_aethernet_effect != null and is_instance_valid(active_aethernet_effect):
		active_aethernet_effect.call("cancel_and_restore")
	if get_parent() == null:
		return
	var effect_value: Variant = AethernetTeleportEffectScript.new()
	if not effect_value is Node2D:
		return
	var effect := effect_value as Node2D
	get_parent().add_child(effect)
	active_aethernet_effect = effect
	effect.call("start", self, phase, false)
	await effect.finished
	if active_aethernet_effect == effect:
		active_aethernet_effect = null


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
	_merge_appearance_alias(appearance_state, "facial_hair_color", "facialHairColor")
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
		_merge_appearance_alias(appearance_state, "facial_hair_color", "facialHairColor")
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
	_merge_presence_appearance_value(appearance_state, container, "facial_hair", ["appearanceFacialHair", "facial_hair", "facialHair"])
	_merge_presence_appearance_value(appearance_state, container, "facegear", ["appearanceFacegear", "facegear"])
	_merge_presence_appearance_value(appearance_state, container, "top", ["appearanceTop", "top"])
	_merge_presence_appearance_value(appearance_state, container, "bottom", ["appearanceBottom", "bottom", "legs"])
	_merge_presence_appearance_value(appearance_state, container, "shoes", ["appearanceShoes", "shoes", "feet"])
	_merge_presence_appearance_value(appearance_state, container, "hair_color", ["appearanceHairColor", "hair_color", "hairColor"])
	_merge_presence_appearance_value(appearance_state, container, "skin_tone", ["appearanceSkinTone", "skin_tone", "skinTone"])
	_merge_presence_appearance_value(appearance_state, container, "eye_color", ["appearanceEyeColor", "eye_color", "eyeColor"])
	_merge_presence_appearance_value(appearance_state, container, "facegear_color", ["appearanceFacegearColor", "facegear_color", "facegearColor"])
	_merge_presence_appearance_value(appearance_state, container, "facial_hair_color", ["appearanceFacialHairColor", "facial_hair_color", "facialHairColor"])
	_merge_presence_appearance_value(appearance_state, container, "top_color", ["appearanceTopColor", "top_color", "topColor"])
	_merge_presence_appearance_value(appearance_state, container, "bottom_color", ["appearanceBottomColor", "bottom_color", "bottomColor"])
	_merge_presence_appearance_value(appearance_state, container, "shoes_color", ["appearanceShoesColor", "shoes_color", "shoesColor"])


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


func _resolve_activity_style(state: Dictionary, movement_state: Dictionary) -> String:
	var activity_value: Variant = movement_state.get("activityStyle", state.get("activityStyle", ""))
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(str(activity_value))
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_RUN:
		return CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
	return normalized_style


func get_feet_position() -> Vector2:
	return global_position


func get_target_feet_position() -> Vector2:
	return tile_move_target_position if is_replaying_tile_move else global_position


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
	var source_body_id: String = str(appearance_state.get("body", fallback_body_id)).strip_edges()
	if source_body_id == "":
		source_body_id = fallback_body_id
	var body_id := CharacterAppearanceService.resolve_body_model_id(source_body_id, current_gender)
	var next_appearance_state: Dictionary = appearance_state.duplicate()
	next_appearance_state["body"] = body_id
	next_appearance_state["skin_tone"] = CharacterAppearanceService.resolve_skin_tone(
		source_body_id,
		str(appearance_state.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE)),
		current_gender
	)
	var next_body_movement_style: String = _get_current_body_movement_style(
		tile_move_duration if is_replaying_tile_move else TILE_MOVE_DURATION
	)
	var signature: String = _get_appearance_signature(next_appearance_state)
	if signature == current_appearance_signature \
		and current_gender == current_body_gender \
		and next_body_movement_style == current_body_movement_style:
		return

	var previous_skin_tone := str(
		current_appearance_state.get(
			"skin_tone",
			CharacterAppearanceService.DEFAULT_SKIN_TONE
		)
	)
	current_appearance_state = next_appearance_state
	_rendered_animation_state.clear()
	current_appearance_signature = signature
	if body_id != current_body_id \
		or current_gender != current_body_gender \
		or next_body_movement_style != current_body_movement_style \
		or str(next_appearance_state.get("skin_tone", "")) != previous_skin_tone:
		_apply_body_frames(body_id, current_gender, next_body_movement_style)
	else:
		_apply_appearance_parts(next_body_movement_style)


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
	stair_elevation = HorizontalStairElevationScript.elevation_for_stair_exit(
		GameState.current_map,
		tile_move_start_position,
		tile_move_target_position,
		move_direction
	)
	_sync_body_frames_for_move_duration(tile_move_duration)
	_sync_appearance_animation_speeds(tile_move_duration)


func _update_replayed_tile_move(delta: float) -> void:
	tile_move_elapsed = minf(tile_move_elapsed + delta, tile_move_duration)
	var progress := clampf(tile_move_elapsed / tile_move_duration, 0.0, 1.0)
	global_position = _snap_world_position(tile_move_start_position.lerp(tile_move_target_position, progress))
	stair_visual_offset = HorizontalStairElevationScript.visual_offset(progress, stair_elevation)
	if tile_move_elapsed >= tile_move_duration:
		global_position = tile_move_target_position
		target_position = tile_move_target_position
		is_replaying_tile_move = false
		stair_elevation = HorizontalStairElevationScript.ELEVATION_NONE
		stair_visual_offset = Vector2.ZERO
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
	look_node = look_copy as Node2D
	if look_node != null:
		base_look_position = look_node.position
		mount_sprite = look_node.get_node_or_null(MOUNT_SPRITE_NAME) as AnimatedSprite2D
		mount_foreground_sprite = look_node.get_node_or_null(
			MOUNT_FOREGROUND_SPRITE_NAME
		) as AnimatedSprite2D
		rider_node = look_node.get_node_or_null("Rider") as Node2D
		if rider_node != null:
			base_rider_position = rider_node.position
	_collect_appearance_sprites(look_copy)
	_apply_appearance_state({"body": CharacterAppearanceService.DEFAULT_MALE_BODY_ID})
	_create_nameplate_from_player_scene(player_instance)
	_setup_map_chat_bubble()
	_create_interaction_hit_area()
	player_instance.queue_free()


func _sync_mount_visual() -> void:
	if mount_sprite == null:
		return
	if current_mount_id == "":
		mount_sprite.stop()
		mount_sprite.sprite_frames = null
		mount_sprite.visible = false
		mount_foreground_sprite.stop()
		mount_foreground_sprite.sprite_frames = null
		mount_foreground_sprite.visible = false
		_sync_mount_rider_delta()
		return
	var mount_frames := MountService.get_mount_frames(current_mount_id)
	if mount_frames == null:
		mount_sprite.visible = false
		return
	mount_sprite.sprite_frames = mount_frames
	mount_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mount_sprite.visible = true
	var foreground_frames := mount_frames \
		if CharacterAppearanceService.normalize_movement_style(current_body_movement_style) \
		== CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH \
		else MountService.get_mount_foreground_frames(current_mount_id)
	mount_foreground_sprite.sprite_frames = foreground_frames
	mount_foreground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mount_foreground_sprite.visible = foreground_frames != null
	_sync_mount_animation(_is_visually_moving(false), last_direction)


func _sync_mount_animation(moving: bool, direction: Vector2) -> void:
	if mount_sprite == null or not mount_sprite.visible or mount_sprite.sprite_frames == null:
		return
	var animation_name := _get_walk_animation_name(direction) \
		if moving \
		else _get_idle_animation_name(direction)
	if not mount_sprite.sprite_frames.has_animation(animation_name):
		return
	var animation_changed := mount_sprite.animation != animation_name
	if animation_changed or not moving and mount_sprite.is_playing():
		mount_sprite.animation = animation_name
		mount_sprite.frame = 0
		mount_sprite.frame_progress = 0.0
	if moving:
		mount_sprite.play(animation_name)
	else:
		mount_sprite.animation = animation_name
		mount_sprite.frame = 0
		mount_sprite.frame_progress = 0.0
		mount_sprite.stop()
	_sync_mount_foreground_frame()


func _sync_mount_foreground_frame() -> void:
	if mount_foreground_sprite == null or not mount_foreground_sprite.visible:
		return
	if mount_sprite == null or mount_sprite.sprite_frames == null:
		return
	mount_foreground_sprite.animation = mount_sprite.animation
	mount_foreground_sprite.frame = mount_sprite.frame
	mount_foreground_sprite.frame_progress = mount_sprite.frame_progress
	mount_foreground_sprite.stop()


func _sync_mount_rider_delta() -> void:
	if rider_node == null:
		return
	if mount_sprite == null or not mount_sprite.visible or current_mount_id == "":
		rider_node.position = base_rider_position
		return
	var direction := _get_activity_offset_direction()
	var rider_offset := MountService.get_rider_frame_offset(
		current_mount_id,
		direction,
		mount_sprite.frame
	)
	rider_node.position = base_rider_position + Vector2(rider_offset) \
		+ _get_surf_fish_rider_offset(direction)


func _get_surf_fish_rider_offset(direction: String) -> Vector2:
	if CharacterAppearanceService.normalize_movement_style(current_body_movement_style) \
		!= CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		return Vector2.ZERO
	return Vector2(SURF_FISH_RIDER_OFFSETS.get(direction, Vector2i.ZERO))


func _get_surf_fish_rider_offset_adjustments() -> Dictionary:
	if CharacterAppearanceService.normalize_movement_style(current_body_movement_style) \
		!= CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		return {}
	return SURF_FISH_RIDER_OFFSETS


func _get_surf_fish_body_hidden_regions() -> Dictionary:
	if CharacterAppearanceService.normalize_movement_style(current_body_movement_style) \
		!= CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		return {}
	return SURF_FISH_BODY_HIDDEN_REGIONS

func _create_interaction_hit_area() -> void:
	var hit_area := Area2D.new()
	hit_area.name = "PlayerInteractionHitArea"
	hit_area.input_pickable = true
	# Area2D input picking requires a non-zero collision layer.
	hit_area.collision_layer = 1
	hit_area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(28.0, 42.0)
	shape.shape = rectangle
	shape.position = Vector2(0.0, -10.0)
	hit_area.add_child(shape)
	hit_area.input_event.connect(_on_interaction_hit_area_input_event)
	add_child(hit_area)
	interaction_hit_area = hit_area


func set_interaction_enabled(enabled: bool) -> void:
	if interaction_hit_area != null:
		interaction_hit_area.input_pickable = enabled

func _on_interaction_hit_area_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	if presence_state.is_empty():
		return
	interaction_requested.emit(presence_state.duplicate(true), global_position)
	get_viewport().set_input_as_handled()


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
	guild_emblem_background = nameplate.get_node_or_null("GuildEmblemBackground") as Panel
	guild_emblem = nameplate.get_node_or_null("GuildEmblem") as TextureRect
	nameplate_background = nameplate.get_node_or_null("NameplateBackground") as Panel
	role_badge_panel = nameplate.get_node_or_null("RoleBadgePanel") as Panel
	role_badge_icon = nameplate.get_node_or_null("RoleBadgeIcon") as TextureRect
	if role_badge_panel != null:
		role_badge_label = role_badge_panel.get_node_or_null("RoleBadge") as Label
	if nameplate_label == null:
		nameplate.queue_free()
		nameplate = null
		return

	nameplate.visible = false
	_update_nameplate()


func show_map_chat_message(text: String) -> void:
	_setup_map_chat_bubble()
	if map_chat_bubble != null:
		map_chat_bubble.call("show_message", text)


func _setup_map_chat_bubble() -> void:
	if map_chat_bubble != null and is_instance_valid(map_chat_bubble):
		return
	var bubble_value: Variant = MapChatBubbleScript.new()
	if not bubble_value is PanelContainer:
		return
	map_chat_bubble = bubble_value as PanelContainer
	map_chat_bubble.name = "MapChatBubble"
	add_child(map_chat_bubble)


func _update_nameplate() -> void:
	if nameplate_label == null:
		return

	var name_text: String = display_name.strip_edges()
	if name_text == "":
		name_text = username.strip_edges()
	nameplate_label.text = gameplay_identity_placeholder if gameplay_identity_masked else name_text
	var should_show_nameplate := name_text != ""
	if creator_nameplate_visibility_override_active:
		should_show_nameplate = creator_nameplate_visible and name_text != ""
	if gameplay_nameplate_visibility_override_active:
		should_show_nameplate = should_show_nameplate and gameplay_nameplate_visible
	nameplate_label.visible = should_show_nameplate
	_update_role_badge()
	_sync_nameplate_layout()
	if nameplate != null:
		nameplate.visible = should_show_nameplate


func set_creator_nameplate_visible(visible: bool) -> void:
	creator_nameplate_visibility_override_active = true
	creator_nameplate_visible = visible
	_update_nameplate()


func clear_creator_nameplate_visibility_override() -> void:
	creator_nameplate_visibility_override_active = false
	_update_nameplate()


func set_gameplay_nameplate_visible(visible: bool) -> void:
	gameplay_nameplate_visibility_override_active = true
	gameplay_nameplate_visible = visible
	_update_nameplate()


func clear_gameplay_nameplate_visibility_override() -> void:
	gameplay_nameplate_visibility_override_active = false
	gameplay_nameplate_visible = true
	_update_nameplate()


func set_gameplay_identity_masked(masked: bool, placeholder := "???") -> void:
	gameplay_identity_mask_override_active = true
	gameplay_identity_masked = masked
	gameplay_identity_placeholder = str(placeholder).strip_edges()
	if gameplay_identity_placeholder.is_empty():
		gameplay_identity_placeholder = "???"
	_update_nameplate()


func clear_gameplay_identity_mask_override() -> void:
	gameplay_identity_mask_override_active = false
	gameplay_identity_masked = false
	gameplay_identity_placeholder = "???"
	_update_nameplate()


func _apply_guild_emblem(emblem: Dictionary) -> void:
	if guild_emblem == null:
		return
	if _emblem_initialized and emblem == _rendered_emblem:
		return
	_emblem_initialized = true
	_rendered_emblem = emblem.duplicate(true)
	guild_emblem.texture = GuildEmblemTexture.create_nameplate_texture(emblem)
	guild_emblem.visible = guild_emblem.texture != null
	if guild_emblem_background != null:
		guild_emblem_background.visible = guild_emblem.visible


func _update_role_badge() -> void:
	if role_badge_label == null:
		return
	if gameplay_identity_masked:
		role_badge_label.text = ""
		if role_badge_panel != null:
			role_badge_panel.visible = false
		if role_badge_icon != null:
			role_badge_icon.visible = false
		return

	var primary_role: Dictionary = _get_primary_visible_role(roles, selected_role_badge)
	if primary_role.is_empty():
		role_badge_label.text = ""
		if role_badge_panel != null:
			role_badge_panel.visible = false
		if role_badge_icon != null:
			role_badge_icon.visible = false
		return

	var role_id: String = str(primary_role.get("id", ""))
	role_badge_label.text = str(primary_role.get("badge", ""))
	var normalized_role_id := role_id.strip_edges().to_lower()
	var use_role_icon := role_badge_label.text != "" and RoleBadgeTexture.has_role_badge(normalized_role_id)
	if use_role_icon and role_badge_icon != null:
		role_badge_icon.texture = RoleBadgeTexture.get_role_badge_texture(normalized_role_id)
	use_role_icon = use_role_icon and role_badge_icon != null and role_badge_icon.texture != null
	if role_badge_panel != null:
		role_badge_panel.visible = role_badge_label.text != "" and not use_role_icon
	if role_badge_icon != null:
		role_badge_icon.visible = use_role_icon
	var role_color := _get_role_color(role_id, str(primary_role.get("color", "")))
	if role_badge_panel != null:
		role_badge_panel.add_theme_stylebox_override("panel", _make_role_badge_style(role_id, role_color))
	role_badge_label.add_theme_color_override("font_color", role_color)
	role_badge_label.add_theme_font_size_override("font_size", 8)


func _sync_nameplate_layout() -> void:
	if nameplate_label == null:
		return

	var has_role_badge: bool = role_badge_label != null and role_badge_label.text.strip_edges() != ""
	var uses_role_icon: bool = role_badge_icon != null and role_badge_icon.visible
	var has_guild_emblem: bool = guild_emblem != null and guild_emblem.texture != null
	var name_size := _get_label_text_size(nameplate_label)
	name_size.x = minf(name_size.x, NAMEPLATE_MAX_NAME_WIDTH)
	var card_layout := NameplateLayout.calculate_name_card(name_size, has_guild_emblem)
	var label_rect: Rect2 = card_layout.get("labelRect", Rect2())
	var background_rect: Rect2 = card_layout.get("backgroundRect", Rect2())
	var emblem_rect: Rect2 = card_layout.get("emblemRect", Rect2())
	var emblem_background_rect: Rect2 = card_layout.get("emblemBackgroundRect", Rect2())

	nameplate_label.offset_left = label_rect.position.x
	nameplate_label.offset_right = label_rect.end.x
	nameplate_label.offset_top = label_rect.position.y
	nameplate_label.offset_bottom = label_rect.end.y
	nameplate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if nameplate_background != null:
		nameplate_background.offset_left = background_rect.position.x
		nameplate_background.offset_right = background_rect.end.x
		nameplate_background.offset_top = background_rect.position.y
		nameplate_background.offset_bottom = background_rect.end.y
	if has_guild_emblem:
		if guild_emblem_background != null:
			guild_emblem_background.offset_left = emblem_background_rect.position.x
			guild_emblem_background.offset_right = emblem_background_rect.end.x
			guild_emblem_background.offset_top = emblem_background_rect.position.y
			guild_emblem_background.offset_bottom = emblem_background_rect.end.y
		guild_emblem.offset_left = emblem_rect.position.x
		guild_emblem.offset_right = emblem_rect.end.x
		guild_emblem.offset_top = emblem_rect.position.y
		guild_emblem.offset_bottom = emblem_rect.end.y

	var next_layer_bottom := background_rect.position.y - NAMEPLATE_LAYER_GAP
	if has_role_badge:
		var badge_width: float = (
			ROLE_BADGE_ICON_SIZE.x
			if uses_role_icon
			else _get_role_badge_width(role_badge_label.text)
		)
		var start_x := NAMEPLATE_CENTER_X - (badge_width * 0.5)
		if uses_role_icon:
			role_badge_icon.offset_left = start_x
			role_badge_icon.offset_right = start_x + ROLE_BADGE_ICON_SIZE.x
			role_badge_icon.offset_bottom = next_layer_bottom
			role_badge_icon.offset_top = next_layer_bottom - ROLE_BADGE_ICON_SIZE.y
		else:
			role_badge_panel.offset_left = start_x
			role_badge_panel.offset_right = start_x + badge_width
			role_badge_panel.offset_bottom = next_layer_bottom
			role_badge_panel.offset_top = role_badge_panel.offset_bottom - ROLE_BADGE_TEXT_HEIGHT
			role_badge_label.offset_left = 1.0
			role_badge_label.offset_right = badge_width - 1.0
			role_badge_label.offset_top = 0.0
			role_badge_label.offset_bottom = ROLE_BADGE_TEXT_HEIGHT


func _get_label_text_size(label: Label) -> Vector2:
	var text: String = label.text.strip_edges()
	if text == "":
		return Vector2.ZERO

	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if label.label_settings != null:
		if label.label_settings.font != null:
			font = label.label_settings.font
		font_size = label.label_settings.font_size
	if font == null:
		return Vector2(
			float(text.length() * max(font_size, 10) * 0.6),
			float(max(font_size, 10))
		)
	return Vector2(
		font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x,
		font.get_height(font_size)
	)


func _get_role_badge_width(badge_text: String) -> float:
	var normalized_badge := badge_text.strip_edges()
	match normalized_badge:
		"alpha":
			return 38.0
		"GM":
			return 28.0
		"SR", "DEV", "MOD":
			return 32.0
		_:
			return clampf(
				float(normalized_badge.length() * 5 + 8),
				ROLE_BADGE_DEFAULT_WIDTH,
				NAMEPLATE_MAX_NAME_WIDTH
			)


func _get_primary_visible_role(role_values: Array, selected_badge: String = "") -> Dictionary:
	var normalized_selected_badge := selected_badge.strip_edges().to_lower()
	if normalized_selected_badge == "none":
		return {}
	if normalized_selected_badge != "":
		return _find_selected_overworld_role(role_values, normalized_selected_badge)

	var primary_role: Dictionary = {}
	var primary_priority: int = -999999
	for role_value: Variant in role_values:
		if not role_value is Dictionary:
			continue

		var role: Dictionary = role_value as Dictionary
		if not _should_show_overworld_role_badge(role):
			continue
		var badge: String = _get_role_badge(role)
		if badge.is_empty():
			continue

		var role_with_badge: Dictionary = role.duplicate()
		role_with_badge["badge"] = badge
		var priority: int = int(role_with_badge.get("priority", 0))
		if primary_role.is_empty() or priority > primary_priority:
			primary_role = role_with_badge
			primary_priority = priority

	return primary_role

func _find_selected_overworld_role(role_values: Array, selected_badge: String) -> Dictionary:
	for role_value: Variant in role_values:
		if not role_value is Dictionary:
			continue
		var role := role_value as Dictionary
		if str(role.get("id", "")).strip_edges().to_lower() != selected_badge:
			continue
		if not _should_show_overworld_role_badge(role):
			return {}
		var badge := _get_role_badge(role)
		if badge.is_empty():
			return {}
		var role_with_badge := role.duplicate()
		role_with_badge["badge"] = badge
		return role_with_badge
	return {}

func _should_show_overworld_role_badge(role: Dictionary) -> bool:
	var role_id := str(role.get("id", "")).strip_edges().to_lower()
	var category := str(role.get("category", "")).strip_edges().to_lower()
	if category != STAFF_ROLE_CATEGORY and not LEGACY_STAFF_ROLE_IDS.has(role_id):
		return false
	var display: Dictionary = role.get("display", {}) if role.get("display", {}) is Dictionary else {}
	return bool(display.get("overworldBadge", true))


func _get_role_badge(role: Dictionary) -> String:
	var short_label := str(role.get("shortLabel", role.get("badge", ""))).strip_edges()
	if short_label != "":
		return short_label

	var role_id := str(role.get("id", "")).strip_edges().to_lower()
	match role_id:
		"alpha":
			return "alpha"
		"gamemaster":
			return "GM"
		"senior_staff":
			return "SR"
		"developer":
			return "DEV"
		"moderator":
			return "MOD"
		"staff":
			return "Chat Mod"
	var display_name := str(
		role.get("displayName", role.get("label", role.get("name", "")))
	).strip_edges()
	if display_name != "":
		return display_name
	return role_id.replace("_", " ").capitalize()


func _get_role_color(role_id: String, fallback: String) -> Color:
	if ROLE_BADGE_COLORS.has(role_id):
		var role_color: Color = ROLE_BADGE_COLORS[role_id]
		return role_color
	if fallback.begins_with("#"):
		return Color(fallback)
	return Color(0.847, 0.718, 0.404)


func _make_role_badge_style(role_id: String, fallback_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var normalized_role := role_id.strip_edges().to_lower()
	match normalized_role:
		"developer":
			style.bg_color = Color(0.025, 0.18, 0.165, 0.92)
			style.border_color = Color(0.22, 0.78, 0.68, 0.48)
		"gamemaster":
			style.bg_color = Color(0.030, 0.105, 0.235, 0.92)
			style.border_color = Color(0.30, 0.64, 1.0, 0.48)
		"moderator":
			style.bg_color = Color(0.18, 0.055, 0.18, 0.92)
			style.border_color = Color(0.86, 0.42, 0.84, 0.48)
		"senior_staff":
			style.bg_color = Color(0.22, 0.145, 0.035, 0.92)
			style.border_color = Color(1.0, 0.70, 0.24, 0.50)
		"alpha":
			style.bg_color = Color(0.125, 0.105, 0.19, 0.92)
			style.border_color = Color(0.76, 0.65, 1.0, 0.48)
		_:
			style.bg_color = Color(
				clampf(fallback_color.r * 0.22, 0.02, 0.22),
				clampf(fallback_color.g * 0.22, 0.02, 0.22),
				clampf(fallback_color.b * 0.22, 0.02, 0.22),
				0.92
			)
			style.border_color = Color(fallback_color.r, fallback_color.g, fallback_color.b, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 2
	return style


func _collect_appearance_sprites(node: Node) -> void:
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		if sprite.name != MOUNT_SPRITE_NAME \
			and sprite.name != MOUNT_FOREGROUND_SPRITE_NAME:
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
	var movement_style: String = _get_current_body_movement_style(move_duration)
	if movement_style == current_body_movement_style:
		return
	_apply_body_frames(current_body_id, current_body_gender, movement_style)


func _get_current_body_movement_style(move_duration: float) -> String:
	if current_activity_style != CharacterAppearanceService.BODY_MOVEMENT_DEFAULT:
		return current_activity_style
	return CharacterAppearanceService.BODY_MOVEMENT_RUN \
		if move_duration < TILE_MOVE_DURATION \
		else CharacterAppearanceService.BODY_MOVEMENT_DEFAULT


func _apply_body_frames(body_id: String, gender: String, movement_style: String) -> void:
	var normalized_gender: String = CharacterAppearanceService.normalize_gender(gender)
	var fallback_body_id: String = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID \
		if normalized_gender == "female" \
		else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
	var source_body_id: String = body_id.strip_edges()
	var normalized_body_id: String = CharacterAppearanceService.resolve_body_model_id(source_body_id, normalized_gender)
	if normalized_body_id == "":
		normalized_body_id = fallback_body_id
	var available_body_ids: Array[String] = CharacterAppearanceService.get_available_body_model_ids(normalized_gender)
	if not available_body_ids.has(normalized_body_id):
		normalized_body_id = fallback_body_id

	var body_frames: SpriteFrames = CharacterAppearanceService.get_skin_tinted_body_frames(
		normalized_body_id,
		normalized_gender,
		movement_style,
		CharacterAppearanceService.resolve_skin_tone(
			source_body_id,
			str(current_appearance_state.get("skin_tone", CharacterAppearanceService.DEFAULT_SKIN_TONE)),
			normalized_gender
		)
	)
	if body_frames == null:
		return
	body_frames = MountService.get_mounted_rider_frames(
		body_frames,
		current_mount_id,
		_get_surf_fish_rider_offset_adjustments(),
		_get_surf_fish_body_hidden_regions()
	)

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
	_apply_directional_appearance_layer_order()


func _apply_directional_appearance_layer_order() -> void:
	var facegear_sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES["facegear"]))
	if facegear_sprite == null:
		return
	facegear_sprite.z_index = CharacterAppearanceService.get_directional_part_z_index(
		"facegear",
		_get_appearance_part_id("facegear"),
		_get_activity_offset_direction(),
		8
	)


func _get_appearance_part_id(category: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category):
		"hair":
			return _get_appearance_hair_id()
		"headgear":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("headgear", CharacterAppearanceService.get_default_part_id("headgear", current_body_gender))))
		"facial_hair":
			return CharacterAppearanceService.deserialize_part_id(str(current_appearance_state.get("facial_hair", "")))
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
			return CharacterAppearanceService.get_eyebrows_for_hair(_get_appearance_hair_id(), current_body_gender)
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
	part_frames = MountService.get_mounted_rider_frames(
		part_frames,
		current_mount_id,
		_get_surf_fish_rider_offset_adjustments()
	)

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
	if _should_keep_activity_layer_idle(sprite):
		_sync_activity_idle_layer(sprite, last_direction)
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
	_restore_sprite_base_offset(sprite)
	sprite.set_meta(UNEQUIPPED_APPEARANCE_PART_META, true)


func _apply_body_modulate(body_sprite: AnimatedSprite2D, body_id: String, gender: String) -> void:
	if body_sprite == null:
		return
	body_sprite.modulate = Color.WHITE


func _get_appearance_part_modulate(category: String) -> Color:
	return Color.WHITE


func _apply_appearance_part_visuals(sprite: AnimatedSprite2D, category: String) -> void:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	sprite.material = null
	sprite.modulate = _get_appearance_part_modulate(normalized_category)
	_apply_activity_layer_offset(sprite, normalized_category)


func _apply_activity_layer_offset(sprite: AnimatedSprite2D, category: String) -> void:
	if sprite == null:
		return
	if not sprite.has_meta(ACTIVITY_BASE_SPRITE_OFFSET_META):
		sprite.set_meta(ACTIVITY_BASE_SPRITE_OFFSET_META, sprite.offset)

	var base_offset: Vector2 = sprite.get_meta(ACTIVITY_BASE_SPRITE_OFFSET_META)
	sprite.offset = base_offset + _get_activity_layer_offset(category)


func _apply_activity_visual_offset() -> void:
	if look_node == null:
		return
	look_node.position = base_look_position + _get_activity_visual_offset() + stair_visual_offset


func _get_activity_visual_offset() -> Vector2:
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(current_body_movement_style)
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		return Vector2.ZERO
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


func _get_activity_layer_offset(category: String) -> Vector2:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(current_body_movement_style)
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		normalized_style = CharacterAppearanceService.BODY_MOVEMENT_FISH
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
	var body_sprite := _get_body_sprite()
	if body_sprite != null:
		var animation_name: String = str(body_sprite.animation)
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


func _get_appearance_part_frames(category: String, part_id: String, movement_style: String) -> SpriteFrames:
	var normalized_category: String = CharacterAppearanceService.normalize_part_category(category)
	if normalized_category == "eyes":
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(
				CharacterAppearanceService.resolve_eye_color(
					str(current_appearance_state.get("eye_color", "")),
					current_body_gender
				),
				Color.WHITE
			)
		)
	if normalized_category == "eyebrows" or (
		normalized_category == "hair"
		and CharacterAppearanceService.is_tintable_part(category, part_id)
	):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(
				CharacterAppearanceService.resolve_hair_color(
					str(current_appearance_state.get("hair_color", "")),
					current_body_gender
				),
				Color.WHITE
			),
			true
		)
	if normalized_category == "facial_hair" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(
				str(current_appearance_state.get("facial_hair_color", "#ffffff")),
				Color.WHITE
			),
			true
		)
	if normalized_category == "facegear" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("facegear_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "top" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("top_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "bottom" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("bottom_color", "#ffffff")), Color.WHITE),
			true
		)
	if normalized_category == "shoes" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			current_body_gender,
			movement_style,
			_parse_appearance_color(str(current_appearance_state.get("shoes_color", "#ffffff")), Color.WHITE),
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
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(appearance_state.get("body", "")),
		str(appearance_state.get("hair", "")),
		str(appearance_state.get("hair_style_index", "")),
		str(appearance_state.get("headgear", "")),
		str(appearance_state.get("facial_hair", "")),
		str(appearance_state.get("facegear", "")),
		str(appearance_state.get("top", "")),
		str(appearance_state.get("bottom", appearance_state.get("legs", ""))),
		str(appearance_state.get("shoes", appearance_state.get("feet", ""))),
		str(appearance_state.get("hair_color", "")),
		str(appearance_state.get("skin_tone", "")),
		str(appearance_state.get("eye_color", "")),
		str(appearance_state.get("facegear_color", "")),
		str(appearance_state.get("facial_hair_color", "")),
		str(appearance_state.get("top_color", "")),
		str(appearance_state.get("bottom_color", "")),
		str(appearance_state.get("shoes_color", "")),
	]


func _update_animation(is_moving: bool) -> void:
	if is_inside_tree() and not is_visible_in_tree():
		_rendered_animation_state.clear()
		return
	var next_state: Array = [is_moving, last_direction, current_activity_style,
		current_mount_id, current_appearance_signature, current_body_movement_style]
	if next_state == _rendered_animation_state:
		if is_moving:
			_sync_all_part_sprites_to_body()
			_sync_mount_rider_delta()
			_sync_mount_foreground_frame()
		return
	_rendered_animation_state = next_state
	_apply_directional_appearance_layer_order()
	_sync_activity_layer_offsets()
	var uses_static_pose := _uses_static_activity_movement_pose()
	var should_animate_movement := is_moving and not uses_static_pose
	var animation_name := _get_walk_animation_name(last_direction) \
		if should_animate_movement \
		else _get_idle_animation_name(last_direction)
	for sprite in appearance_sprites:
		if _is_unequipped_appearance_part_sprite(sprite):
			sprite.visible = false
			sprite.stop()
			continue
		if _should_keep_activity_layer_idle(sprite):
			_sync_activity_idle_layer(sprite, last_direction)
			continue
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
			continue
		sprite.animation = animation_name
		if should_animate_movement:
			sprite.play(animation_name)
		else:
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.stop()
	_sync_all_part_sprites_to_body()
	_sync_mount_animation(is_moving, last_direction)
	_sync_mount_rider_delta()
	_sync_mount_foreground_frame()
	_apply_activity_visual_offset()


func _on_visual_visibility_changed() -> void:
	_rendered_animation_state.clear()
	if look_node != null:
		look_node.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED


func _uses_static_activity_movement_pose() -> bool:
	return CharacterAppearanceService.normalize_movement_style(current_activity_style) \
		== CharacterAppearanceService.BODY_MOVEMENT_RIDE


func _sync_activity_idle_layer(sprite: AnimatedSprite2D, direction: Vector2) -> void:
	if sprite == null:
		return

	var animation_name := _get_idle_animation_name(direction)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		animation_name = _get_walk_animation_name(direction)
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		sprite.visible = false
		sprite.stop()
		return

	sprite.visible = true
	sprite.animation = animation_name
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.stop()


func _should_keep_activity_layer_idle(sprite: AnimatedSprite2D) -> bool:
	if sprite == null or sprite == _get_body_sprite():
		return false
	if not _uses_static_activity_movement_pose():
		return false

	var category := _get_appearance_category_for_sprite(sprite)
	return RIDE_STATIC_PART_CATEGORIES.has(category)


func _get_appearance_category_for_sprite(sprite: AnimatedSprite2D) -> String:
	if sprite == null:
		return ""

	var sprite_name := str(sprite.name)
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category := str(category_value)
		if str(APPEARANCE_PART_SPRITES[category]) == sprite_name:
			return category
	return ""


func _sync_activity_layer_offsets() -> void:
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category := str(category_value)
		var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[category]))
		_apply_activity_layer_offset(sprite, category)


func _is_unequipped_appearance_part_sprite(sprite: AnimatedSprite2D) -> bool:
	return sprite != null and bool(sprite.get_meta(UNEQUIPPED_APPEARANCE_PART_META, false))


func _update_sort_z() -> void:
	var sort_z := floori(global_position.y)
	var current_map := GameState.current_map
	if current_map != null and current_map.has_method("get_actor_sort_z_floor"):
		sort_z = maxi(sort_z, int(current_map.call("get_actor_sort_z_floor", global_position)))
	z_index = clampi(sort_z, SORT_Z_MIN, SORT_Z_MAX)


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
