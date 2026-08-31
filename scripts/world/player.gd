extends CharacterBody2D

signal overworld_steps_completed(step_count: int)

const TILE_SIZE := 32
const TILE_MOVE_DURATION := 0.22
const RUN_TILE_MOVE_DURATION := 0.14
const LAND_MOUNT_TILE_MOVE_DURATION := 0.065
const MOVE_EASE_AMOUNT := 0.0
const INPUT_BUFFER_DURATION := 0.14
const CONTINUOUS_MOVE_HOLD_DELAY := 0.0
const MAX_STORY_PATH_STEPS := 32
const STORY_PATH_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]
const SORT_Z_MIN := -4096
const SORT_Z_MAX := 4096
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const RUN_WALK_ANIMATION_SPEED := 11.5
const LAND_MOUNT_WALK_ANIMATION_SPEED := 18.0
const PLAYER_SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_NEAREST
const MOVE_ACTIONS := ["move_right", "move_left", "move_down", "move_up"]
const TEXT_INPUT_WINDOW_GROUP := "text_input_windows"
const HIDDEN_FOR_MISSING_ANIMATION_META := "hidden_for_missing_animation"
const UNEQUIPPED_APPEARANCE_PART_META := "unequipped_appearance_part"
const ACTIVITY_BASE_SPRITE_OFFSET_META := "activity_base_sprite_offset"
const MOUNT_SPRITE_NAME := "MountSprite"
const MOUNT_FOREGROUND_SPRITE_NAME := "MountForegroundSprite"
const FACE_GEAR_SPRITE_NAME := "FaceGearSprite"
const BODY_SPRITE_NAME := "BodySprite"
const HAIR_SPRITE_NAME := "HairSprite"
const HEADGEAR_SPRITE_NAME := "HeadgearSprite"
const FACIAL_HAIR_SPRITE_NAME := "FacialHairSprite"
const TOP_SPRITE_NAME := "TopSprite"
const BOTTOM_SPRITE_NAME := "BottomSprite"
const SHOES_SPRITE_NAME := "ShoesSprite"
const EYES_SPRITE_NAME := "EyesSprite"
const EYEBROWS_SPRITE_NAME := "EyebrowsSprite"
const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const MountService := preload("res://scripts/services/mount_service.gd")
const PixelPerfectRenderingScript := preload("res://scripts/services/pixel_perfect_rendering.gd")
const WildEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")
const MapChatBubbleScript := preload("res://scripts/world/map_chat_bubble.gd")
const MapLayerResolverScript := preload("res://scripts/world/map_layer_resolver.gd")
const LedgeDirectionResolverScript := preload("res://scripts/world/ledge_direction_resolver.gd")
const HorizontalStairElevationScript := preload("res://scripts/world/horizontal_stair_elevation.gd")
const GuildEmblemTexture := preload("res://scripts/ui/guild_emblem_texture.gd")
const NameplateLayout := preload("res://scripts/ui/nameplate_layout.gd")
const RoleBadgeTexture := preload("res://scripts/ui/role_badge_texture.gd")
const FISHING_PROMPT_ICON: Texture2D = preload("res://assets/items/icons/OLDROD.png")
const SURF_PROMPT_ICON: Texture2D = preload("res://assets/items/icons/WAVEINCENSE.png")
const APPEARANCE_PART_SPRITES := {
	"hair": HAIR_SPRITE_NAME,
	"headgear": HEADGEAR_SPRITE_NAME,
	"facial_hair": FACIAL_HAIR_SPRITE_NAME,
	"facegear": FACE_GEAR_SPRITE_NAME,
	"top": TOP_SPRITE_NAME,
	"bottom": BOTTOM_SPRITE_NAME,
	"shoes": SHOES_SPRITE_NAME,
	"eyes": EYES_SPRITE_NAME,
	"eyebrows": EYEBROWS_SPRITE_NAME,
}
const RIDE_STATIC_PART_CATEGORIES := ["hair", "headgear", "facial_hair", "facegear", "eyes", "eyebrows"]
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
const WATER_TILEMAP_NAMES: Array[String] = ["Water"]
const TALL_GRASS_VISUAL_TILEMAP_NAMES: Array[String] = ["TallGrassVisual", "Grass"]
const TALL_GRASS_DEPTH_SORTING_SCRIPT := preload("res://scripts/world/tall_grass_depth_sorting.gd")
const TALL_GRASS_RUSTLE_EFFECT_SCRIPT := preload("res://scripts/world/tall_grass_rustle_effect.gd")
const WATER_RIPPLE_EFFECT_SCRIPT := preload("res://scripts/world/water_ripple_effect.gd")
const SAND_FOOTPRINT_EFFECT_SCRIPT := preload("res://scripts/world/sand_footprint_effect.gd")
const SAND_FOOTPRINT_LAYER_OFFSETS := {
	"Sand": Vector2.ZERO,
	"SandLeft": Vector2(-8.0, 0.0),
	"SandRight": Vector2(8.0, 0.0),
	"SandUp": Vector2(0.0, -8.0),
	"SandDown": Vector2(0.0, 8.0),
}
const ENCOUNTER_TYPE_GRASS := "grass"
const ENCOUNTER_TYPE_CAVE := "cave"
const ENCOUNTER_TYPE_SURF := "surf"
const ENCOUNTER_TYPE_FISH := "fish"
const FISHING_ENCOUNTER_TYPES := {
	1: "old_rod",
	2: "good_rod",
	3: "super_rod",
}
const FISHING_STATE_NONE := "none"
const FISHING_STATE_CAST := "cast"
const FISHING_STATE_WAITING := "waiting"
const FISHING_STATE_BITE := "bite"
const FISHING_STATE_REEL_SUCCESS := "reel_success"
const FISHING_STATE_MISSED := "missed"
const FISHING_CAST_DURATION := 0.45
const FISHING_BITE_DELAY_MIN := 0.85
const FISHING_BITE_DELAY_MAX := 2.15
const FISHING_BITE_WINDOW_DURATION := 1.25
const FISHING_RESULT_HOLD_DURATION := 0.45
const FISHING_PROMPT_SIZE := Vector2(30.0, 30.0)
const FISHING_PROMPT_POSITION := Vector2(18.0, -72.0)
const FISHING_BITE_PROMPT_SIZE := Vector2(28.0, 28.0)
const FISHING_BITE_PROMPT_POSITION := Vector2(10.0, -92.0)
const SURF_PROMPT_SIZE := Vector2(30.0, 30.0)
const SURF_PROMPT_POSITION := Vector2(-48.0, -72.0)
const FISHING_RIPPLE_DISTANCE := TILE_SIZE * 1.45

@onready var look_node: Node2D = $Look
@onready var mount_sprite: AnimatedSprite2D = $Look/MountSprite
@onready var mount_foreground_sprite: AnimatedSprite2D = $Look/MountForegroundSprite
@onready var rider_node: Node2D = $Look/Rider
@onready var world_camera: Camera2D = $Camera2D
@onready var feet_marker: Marker2D = $FeetMarker
@onready var nameplate: Control = $Nameplate
@onready var nameplate_background: Panel = $Nameplate/NameplateBackground
@onready var nameplate_label: Label = $Nameplate/NameLabel
@onready var guild_emblem_background: Panel = $Nameplate/GuildEmblemBackground
@onready var guild_emblem: TextureRect = $Nameplate/GuildEmblem
@onready var role_badge_panel: Panel = $Nameplate/RoleBadgePanel
@onready var role_badge_label: Label = $Nameplate/RoleBadgePanel/RoleBadge
@onready var role_badge_icon: TextureRect = $Nameplate/RoleBadgeIcon
var map_chat_bubble: PanelContainer

# TileMapLayer nodes die speciale map-informatie bevatten.
# Collision bevat de onzichtbare/blokkerende tegels.
# TallGrass kan later gebruikt worden voor encounters/effects.
var collision_tilemap: TileMapLayer
var grass_tilemap: TileMapLayer
var grass_visual_tilemap: TileMapLayer
var water_tilemap: TileMapLayer
var sand_tilemaps: Dictionary = {}
var block_down_tilemap: TileMapLayer
var block_up_tilemap: TileMapLayer
var block_left_tilemap: TileMapLayer
var block_right_tilemap: TileMapLayer
var ledge_down_tilemap: TileMapLayer
var ledge_up_tilemap: TileMapLayer
var ledge_left_tilemap: TileMapLayer
var ledge_right_tilemap: TileMapLayer

# Movement state.
# is_moving voorkomt dat je nieuwe input verwerkt terwijl de speler nog naar
# de volgende tile aan het lopen is.
var is_moving := false
var story_path_movement_active := false
var next_sand_footprint_is_left := true

# target_position is een wereldpositie in pixels.
var target_position := Vector2.ZERO
var move_start_position := Vector2.ZERO
var move_elapsed := 0.0
var move_duration := TILE_MOVE_DURATION
var stair_elevation := HorizontalStairElevationScript.ELEVATION_NONE
var stair_visual_offset := Vector2.ZERO

# Onthoudt de laatste kijkrichting, zodat de idle frame goed blijft staan.
var last_direction := Vector2.DOWN
var creator_nameplate_visibility_override_active := false
var creator_nameplate_visible := true
var nameplate_visibility_requested := true
var input_action_priority := ["move_right", "move_left", "move_down", "move_up"]
var buffered_direction := Vector2.ZERO
var input_buffer_time_left := 0.0
var held_direction := Vector2.ZERO
var held_direction_time := 0.0
var route_gate_interaction_in_progress := false
var appearance_sprites: Array[AnimatedSprite2D] = []
var master_appearance_sprite: AnimatedSprite2D
var pokemon_follower: PokemonFollower
var body_sprite_frames_movement_style := ""
var activity_style := CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
var fishing_activity_active := false
var fishing_activity_time_left := 0.0
var fishing_activity_tier := 0
var fishing_activity_state := FISHING_STATE_NONE
var surf_activity_active := false
var land_mount_activity_active := false
var active_mount_id := ""
var base_look_position := Vector2.ZERO
var base_rider_position := Vector2.ZERO
var fishing_prompt_button: Button
var fishing_bite_prompt_button: Button
var surf_prompt_button: Button
var fishing_input_handled_frame := -1
var fishing_bite_prompt_rendered_state := ""

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
	get_tree().call_group("world", "_publish_world_presence", true)

func clear_activity_style() -> void:
	set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_DEFAULT)

func get_activity_style() -> String:
	return activity_style

func get_active_mount_id() -> String:
	return active_mount_id


func get_active_land_mount_id() -> String:
	return active_mount_id if land_mount_activity_active else ""

func _sync_mount_visual() -> void:
	if mount_sprite == null:
		return
	var normalized_mount_id := MountService.normalize_mount_id(active_mount_id)
	if normalized_mount_id == "":
		mount_sprite.stop()
		mount_sprite.sprite_frames = null
		mount_sprite.visible = false
		mount_foreground_sprite.stop()
		mount_foreground_sprite.sprite_frames = null
		mount_foreground_sprite.visible = false
		_sync_mount_rider_delta()
		return

	var mount_frames := MountService.get_mount_frames(normalized_mount_id)
	if mount_frames == null:
		mount_sprite.visible = false
		return
	mount_sprite.sprite_frames = mount_frames
	mount_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	mount_sprite.visible = true
	var foreground_frames := MountService.get_mount_foreground_frames(normalized_mount_id)
	mount_foreground_sprite.sprite_frames = foreground_frames
	mount_foreground_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	mount_foreground_sprite.visible = foreground_frames != null
	_sync_mount_animation(is_moving, last_direction)

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
	if mount_sprite == null or not mount_sprite.visible or active_mount_id == "":
		rider_node.position = base_rider_position
		return
	var direction := _get_activity_offset_direction()
	var rider_offset := MountService.get_rider_frame_offset(
		active_mount_id,
		direction,
		mount_sprite.frame
	)
	rider_node.position = base_rider_position + Vector2(rider_offset)

func is_fishing_activity_active() -> bool:
	return fishing_activity_active

func is_surfing_activity_active() -> bool:
	return surf_activity_active

func is_land_mount_activity_active() -> bool:
	return land_mount_activity_active

func sync_activity_state_for_current_tile() -> void:
	refresh_map_layers()

	if _is_water_tile_at(global_position):
		# Reaching water is gated when the tile is entered. Once a persisted or
		# battle-return position is already on water, restore Surf unconditionally
		# so asynchronous party/charm loading cannot strand the player.
		if not surf_activity_active:
			_start_surf_activity(false)
		return

	if surf_activity_active:
		_finish_surf_activity("left_water")

func can_fish_here() -> bool:
	if GameState.selected_fishing_rod_item_id.is_empty():
		return false
	if not bool(GameState.fishing_unlocked):
		return false
	if int(GameState.fishing_tier) <= 0:
		return false
	if fishing_activity_active or land_mount_activity_active or is_moving:
		return false
	if GameState.is_overworld_input_locked() or _is_ui_typing():
		return false
	return _is_facing_water_tile()

func start_fishing(fishing_tier: int = -1) -> bool:
	if not can_fish_here():
		return false

	var resolved_tier: int = fishing_tier
	if resolved_tier <= 0:
		resolved_tier = int(GameState.fishing_tier)
	resolved_tier = clampi(resolved_tier, 1, 3)
	_start_fishing_activity(resolved_tier)
	return true

func toggle_land_mount() -> bool:
	if land_mount_activity_active:
		_finish_land_mount_activity()
		return true
	return _start_land_mount_activity()


func restore_land_mount(mount_id: String) -> bool:
	var resolved_mount_id := MountService.resolve_mount_id_for_mode(
		mount_id,
		SettingsManager.MOUNT_MODE_LAND
	)
	if resolved_mount_id.is_empty() or not _is_mount_owned(resolved_mount_id):
		return false
	if not SettingsManager.set_selected_mount_id(
		SettingsManager.MOUNT_MODE_LAND,
		resolved_mount_id
	):
		return false
	return _start_land_mount_activity()

func can_surf_here() -> bool:
	return bool(get_surf_check_result().get("allowed", false))

func start_surf() -> bool:
	var surf_check := get_surf_check_result()
	if not bool(surf_check.get("allowed", false)):
		_debug_surf_check("start-blocked", surf_check)
		return false

	var surf_direction := last_direction
	_finish_land_mount_activity()
	_start_surf_activity()
	var did_start_move := _try_start_move(surf_direction)
	if not did_start_move:
		_finish_surf_activity()
		_debug_surf_check("start-failed", {
			"allowed": false,
			"reason": "move_failed",
			"target_position": surf_check.get("target_position", Vector2.ZERO),
		})
		return false

	_show_field_move_system_message("surf")
	_debug_surf_check("start", surf_check)
	return true

func get_surf_check_result() -> Dictionary:
	var target_position_value := _get_facing_tile_position()
	var result := {
		"allowed": false,
		"reason": "not_facing_water",
		"target_position": target_position_value,
	}

	if last_direction == Vector2.ZERO:
		result["reason"] = "no_direction"
		return result
	if not _is_water_tile_at(target_position_value):
		return result
	if surf_activity_active:
		result["reason"] = "already_surfing"
		return result
	if fishing_activity_active:
		result["reason"] = "busy_fishing"
		return result
	if is_moving:
		result["reason"] = "moving"
		return result
	if GameState.is_overworld_input_locked():
		result["reason"] = "overworld_locked"
		return result
	if _is_ui_typing():
		result["reason"] = "ui_typing"
		return result
	if not bool(GameState.surf_unlocked):
		result["reason"] = "surf_locked"
		return result
	if not _has_party_field_move("surf"):
		result["reason"] = "no_party_surf"
		return result

	result["allowed"] = true
	result["reason"] = "ok"
	return result

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
		"facial_hair":
			PlayerSave.appearance_facial_hair_id = normalized_part_id
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
	if normalized_category == "hair":
		_apply_appearance_part(
			"eyebrows",
			CharacterAppearanceService.get_eyebrows_for_hair(
				PlayerSave.appearance_hair_id,
				PlayerSave.gender
			),
			body_sprite_frames_movement_style
		)
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


func set_creator_nameplate_visible(visible: bool) -> void:
	creator_nameplate_visibility_override_active = true
	creator_nameplate_visible = visible
	_sync_nameplate_visibility(nameplate_visibility_requested)


func clear_creator_nameplate_visibility_override() -> void:
	creator_nameplate_visibility_override_active = false
	_sync_nameplate_visibility(nameplate_visibility_requested)

func set_guild_emblem(emblem: Dictionary) -> void:
	if guild_emblem == null:
		return
	guild_emblem.texture = GuildEmblemTexture.create_nameplate_texture(emblem)
	guild_emblem.visible = guild_emblem.texture != null
	if guild_emblem_background != null:
		guild_emblem_background.visible = guild_emblem.visible
	_sync_nameplate_visibility(nameplate_label != null and nameplate_label.text != "")

func set_role_badge(role_badge: String, role_color: Color = Color(0.847, 0.718, 0.404), role_id: String = "") -> void:
	if role_badge_label == null:
		return

	role_badge_label.text = role_badge.strip_edges()
	var normalized_role_id := role_id.strip_edges().to_lower()
	var use_role_icon := role_badge_label.text != "" and RoleBadgeTexture.has_role_badge(normalized_role_id)
	if use_role_icon and role_badge_icon != null:
		role_badge_icon.texture = RoleBadgeTexture.get_role_badge_texture(normalized_role_id)
	use_role_icon = use_role_icon and role_badge_icon != null and role_badge_icon.texture != null
	if role_badge_panel != null:
		role_badge_panel.visible = role_badge_label.text != "" and not use_role_icon
		role_badge_panel.add_theme_stylebox_override("panel", _make_role_badge_style(role_id, role_color))
	if role_badge_icon != null:
		role_badge_icon.visible = use_role_icon
	role_badge_label.add_theme_color_override("font_color", role_color)
	role_badge_label.add_theme_font_size_override("font_size", 8)
	_sync_nameplate_visibility(nameplate_label != null and nameplate_label.text != "")

func set_role_from_user(user: Dictionary) -> void:
	var primary_role: Dictionary = _get_primary_visible_role(user)
	if primary_role.is_empty():
		set_role_badge("")
		return

	set_role_badge(
		str(primary_role.get("badge", "")),
		_get_role_color(str(primary_role.get("id", "")), str(primary_role.get("color", ""))),
		str(primary_role.get("id", ""))
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
	if active_mount_id != "":
		movement_state["mountId"] = active_mount_id
	return movement_state

func get_persistent_world_position() -> Vector2:
	return _snap_world_position(target_position if is_moving else global_position)

func reset_movement_state() -> void:
	var persistent_position := get_persistent_world_position()
	_finish_fishing_activity()
	_finish_surf_activity()
	_finish_land_mount_activity()
	is_moving = false
	story_path_movement_active = false
	global_position = persistent_position
	target_position = global_position
	move_start_position = global_position
	move_elapsed = 0.0
	move_duration = _get_current_tile_move_duration()
	_clear_stair_visual_offset()
	_clear_input_buffer()
	_clear_held_direction()
	set_idle_frame()
	if pokemon_follower != null:
		pokemon_follower.reset_follow_position()


func teleport_within_current_map(world_position: Vector2, facing_direction := Vector2.ZERO) -> void:
	_finish_fishing_activity()
	_finish_surf_activity()
	_finish_land_mount_activity()
	is_moving = false
	story_path_movement_active = false
	global_position = _snap_world_position(world_position)
	target_position = global_position
	move_start_position = global_position
	move_elapsed = 0.0
	move_duration = _get_current_tile_move_duration()
	_clear_stair_visual_offset()
	_clear_input_buffer()
	_clear_held_direction()
	if facing_direction != Vector2.ZERO:
		last_direction = facing_direction.normalized()
	set_idle_frame()
	refresh_map_layers()
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

func can_story_move_path(path: Array[String]) -> bool:
	if (
		path.is_empty()
		or path.size() > MAX_STORY_PATH_STEPS
		or is_moving
		or fishing_activity_active
		or surf_activity_active
		or story_path_movement_active
	):
		return false
	for direction_name: String in path:
		if direction_name not in STORY_PATH_DIRECTIONS:
			return false
	return true

func story_move_path(path: Array[String]) -> bool:
	if not can_story_move_path(path) or not _preflight_story_move_path(path):
		return false

	story_path_movement_active = true
	for direction_name: String in path:
		var direction := _story_path_direction(direction_name)
		var current_position := _snap_world_position(global_position)
		var next_position := current_position + direction * TILE_SIZE

		last_direction = direction
		target_position = _snap_world_position(next_position)
		move_start_position = current_position
		global_position = current_position
		move_elapsed = 0.0
		move_duration = _get_current_tile_move_duration()
		stair_elevation = HorizontalStairElevationScript.elevation_for_stair_exit(
			_resolve_current_map(),
			move_start_position,
			target_position,
			direction
		)
		is_moving = true
		play_walk_animation(direction)
		while is_inside_tree() and is_moving:
			await get_tree().process_frame
		if not is_inside_tree():
			return false

	story_path_movement_active = false
	set_idle_frame()
	return true

func _preflight_story_move_path(path: Array[String]) -> bool:
	if not _has_story_movement_context():
		return false
	var current_position := _snap_world_position(global_position)
	for direction_name: String in path:
		var direction := _story_path_direction(direction_name)
		var next_position := current_position + direction * TILE_SIZE
		if _is_story_grid_step_blocked(current_position, next_position, direction):
			return false
		current_position = _snap_world_position(next_position)
	return true

func _has_story_movement_context() -> bool:
	if not is_inside_tree():
		return false
	if not GameState.is_overworld_input_locked():
		return false
	var current_map := _resolve_current_map()
	if current_map == null or not is_instance_valid(current_map):
		return false
	refresh_map_layers()
	return collision_tilemap != null

func _is_story_grid_step_blocked(
	current_position: Vector2,
	next_position: Vector2,
	direction: Vector2
) -> bool:
	if not _has_story_movement_context():
		return true
	if _is_world_barrier_step_blocked(current_position, next_position):
		return true
	if direction == Vector2.DOWN and _tilemap_has_tile_at(block_down_tilemap, current_position):
		return true
	if direction == Vector2.UP and _tilemap_has_tile_at(block_up_tilemap, current_position):
		return true
	if direction == Vector2.LEFT and _tilemap_has_tile_at(block_left_tilemap, current_position):
		return true
	if direction == Vector2.RIGHT and _tilemap_has_tile_at(block_right_tilemap, current_position):
		return true
	if not _get_ledge_directions_for_tile(next_position).is_empty():
		return true
	var current_map := _resolve_current_map()
	if (
		current_map != null
		and current_map.has_method("get_closed_route_gate_npc")
		and current_map.call("get_closed_route_gate_npc", next_position) != null
	):
		return true
	return not can_move_to(next_position)

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

func _ready() -> void:
	add_to_group("player")
	if not SettingsManager.world_pixel_scale_changed.is_connected(_on_world_pixel_scale_changed):
		SettingsManager.world_pixel_scale_changed.connect(_on_world_pixel_scale_changed)
	if not SettingsManager.mount_loadout_changed.is_connected(_on_mount_loadout_changed):
		SettingsManager.mount_loadout_changed.connect(_on_mount_loadout_changed)
	if not SettingsManager.input_binding_changed.is_connected(_on_input_binding_changed):
		SettingsManager.input_binding_changed.connect(_on_input_binding_changed)
	if not get_viewport().size_changed.is_connected(_on_render_viewport_size_changed):
		get_viewport().size_changed.connect(_on_render_viewport_size_changed)
	_apply_world_pixel_scale()
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	z_as_relative = false
	base_look_position = look_node.position
	base_rider_position = rider_node.position
	PlayerSave.ensure_body_matches_gender(false)
	_cache_appearance_sprites()
	_apply_body_appearance(PlayerSave.appearance_body_id)
	set_display_name(PlayerSave.player_name, true)
	set_role_from_user(AuthService.current_user)
	set_guild_emblem(_current_guild_emblem())
	if not GuildService.guild_changed.is_connected(_on_guild_changed):
		GuildService.guild_changed.connect(_on_guild_changed)
	_setup_map_chat_bubble()
	_setup_fishing_prompt()
	_setup_surf_prompt()
	FieldMoveService.refresh_owned_charms.call_deferred()

	# Haal de TileMapLayer nodes uit de huidige map op als die al geldig is.
	# Bij scene switches kan de vorige map al freed zijn terwijl de autoload nog
	# even naar die node wijst.
	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		grass_tilemap = _find_tall_grass_tilemap(GameState.current_map)
		water_tilemap = _find_tilemap_layer(GameState.current_map, WATER_TILEMAP_NAMES)
		_refresh_sand_tilemaps(GameState.current_map)
		collision_tilemap = _find_tilemap_layer(GameState.current_map, ["Collision"])
		block_down_tilemap = _find_tilemap_layer(GameState.current_map, ["BlockDown"])
		block_up_tilemap = _find_tilemap_layer(GameState.current_map, ["BlockUp"])
		block_left_tilemap = _find_tilemap_layer(GameState.current_map, ["BlockLeft"])
		block_right_tilemap = _find_tilemap_layer(GameState.current_map, ["BlockRight"])
		ledge_down_tilemap = _find_tilemap_layer(GameState.current_map, ["LedgeDown"])
		ledge_up_tilemap = _find_tilemap_layer(GameState.current_map, ["LedgeUp"])
		ledge_left_tilemap = _find_tilemap_layer(GameState.current_map, ["LedgeLeft"])
		ledge_right_tilemap = _find_tilemap_layer(GameState.current_map, ["LedgeRight"])
	
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

func _on_world_pixel_scale_changed(_scale: float) -> void:
	_apply_world_pixel_scale()


func _on_mount_loadout_changed(movement_mode: String, mount_id: String) -> void:
	if movement_mode == SettingsManager.MOUNT_MODE_LAND and land_mount_activity_active:
		active_mount_id = MountService.resolve_mount_id_for_mode(
			mount_id,
			SettingsManager.MOUNT_MODE_LAND
		)
		if active_mount_id.is_empty() or not _is_mount_owned(active_mount_id):
			_finish_land_mount_activity()
			return
		_sync_mount_visual()
		_sync_body_sprite_frames_for_movement()
		return
	if movement_mode != SettingsManager.MOUNT_MODE_SURF or not surf_activity_active:
		return
	active_mount_id = MountService.resolve_mount_id_for_mode(
		mount_id,
		SettingsManager.MOUNT_MODE_SURF,
		true
	)
	_sync_mount_visual()
	_sync_body_sprite_frames_for_movement()


func _on_render_viewport_size_changed() -> void:
	_apply_world_pixel_scale()

func _apply_world_pixel_scale() -> void:
	if world_camera == null or not is_instance_valid(world_camera):
		return
	var window := get_window()
	var viewport := world_camera.get_viewport()
	# Map teardown removes the player and its camera from the active Window
	# before Aether Clash restores its temporary zoom. The next map reapplies
	# the correct baseline, so a detached player must simply skip this update.
	if window == null or viewport == null:
		return
	var window_size := window.size
	var effective_scale := PixelPerfectRenderingScript.resolve_world_scale_for_area(
		SettingsManager.get_effective_world_pixel_scale(window_size),
		_get_current_map_world_access_area_type()
	)
	var canvas_scale := viewport.get_screen_transform().get_scale()
	var baseline_zoom := PixelPerfectRenderingScript.camera_zoom_for_output_scale(
		effective_scale,
		canvas_scale
	)
	var photo_mode := get_tree().get_first_node_in_group("content_creator_photo_mode")
	if (
		photo_mode != null
		and photo_mode.has_method("apply_camera_baseline_zoom")
		and bool(photo_mode.call("apply_camera_baseline_zoom", world_camera, baseline_zoom))
	):
		return
	PixelPerfectRenderingScript.apply_to_camera(
		world_camera,
		effective_scale,
		window_size
	)


func _get_current_map_world_access_area_type() -> String:
	var current_map := _resolve_current_map()
	if current_map == null:
		return ""
	if current_map.has_method("get_world_access_area_type"):
		return str(current_map.call("get_world_access_area_type")).strip_edges().to_lower()
	for property: Dictionary in current_map.get_property_list():
		if str(property.get("name", "")) == "world_access_area_type":
			return str(current_map.get("world_access_area_type")).strip_edges().to_lower()
	return ""

func _exit_tree() -> void:
	var had_activity := fishing_activity_active or surf_activity_active or land_mount_activity_active
	var should_unlock_overworld := fishing_activity_active

	fishing_activity_active = false
	fishing_activity_time_left = 0.0
	fishing_activity_tier = 0
	fishing_activity_state = FISHING_STATE_NONE
	_sync_fishing_bite_prompt_visibility()
	surf_activity_active = false
	land_mount_activity_active = false
	active_mount_id = ""
	_sync_mount_visual()
	if had_activity:
		activity_style = CharacterAppearanceService.BODY_MOVEMENT_DEFAULT
		_restore_activity_visual_offset()
	if should_unlock_overworld:
		GameState.unlock_overworld_input()

func _sync_nameplate_visibility(visible: bool) -> void:
	if nameplate == null or nameplate_label == null:
		return

	nameplate_visibility_requested = visible
	_sync_nameplate_layout()
	var should_show_nameplate: bool = visible and SettingsManager.display_own_name and nameplate_label.text != ""
	if creator_nameplate_visibility_override_active:
		should_show_nameplate = creator_nameplate_visible and nameplate_label.text != ""
	nameplate_label.visible = should_show_nameplate
	nameplate.visible = should_show_nameplate


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


func _current_guild_emblem() -> Dictionary:
	var guild_value: Variant = GuildService.current_guild
	if not guild_value is Dictionary:
		return {}
	var emblem_value: Variant = (guild_value as Dictionary).get("emblem", {})
	return emblem_value as Dictionary if emblem_value is Dictionary else {}


func _on_guild_changed(guild: Dictionary) -> void:
	var emblem_value: Variant = guild.get("emblem", {})
	set_guild_emblem(emblem_value as Dictionary if emblem_value is Dictionary else {})


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

func _get_primary_visible_role(user: Dictionary) -> Dictionary:
	var roles_value: Variant = user.get("roles", [])
	if not roles_value is Array:
		return {}

	var roles: Array = roles_value as Array
	var selected_badge := str(user.get("selectedRoleBadge", "")).strip_edges().to_lower()
	if selected_badge == "none":
		return {}
	if selected_badge != "":
		return _find_selected_overworld_role(roles, selected_badge)

	var primary_role: Dictionary = {}
	var primary_priority: int = -999999
	for role_value: Variant in roles:
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

func _find_selected_overworld_role(roles: Array, selected_badge: String) -> Dictionary:
	for role_value: Variant in roles:
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

func _setup_fishing_prompt() -> void:
	if fishing_prompt_button != null:
		return

	fishing_prompt_button = Button.new()
	fishing_prompt_button.name = "FishingPromptButton"
	fishing_prompt_button.visible = false
	fishing_prompt_button.text = ""
	fishing_prompt_button.icon = FISHING_PROMPT_ICON
	fishing_prompt_button.expand_icon = true
	fishing_prompt_button.focus_mode = Control.FOCUS_NONE
	fishing_prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP
	fishing_prompt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fishing_prompt_button.custom_minimum_size = FISHING_PROMPT_SIZE
	fishing_prompt_button.size = FISHING_PROMPT_SIZE
	fishing_prompt_button.position = FISHING_PROMPT_POSITION
	fishing_prompt_button.z_index = 560
	fishing_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.fish")
	_apply_fishing_prompt_style(fishing_prompt_button)
	fishing_prompt_button.pressed.connect(Callable(self, "_on_fishing_prompt_pressed"))
	add_child(fishing_prompt_button)
	_setup_fishing_bite_prompt()

func _setup_fishing_bite_prompt() -> void:
	if fishing_bite_prompt_button != null:
		return

	fishing_bite_prompt_button = Button.new()
	fishing_bite_prompt_button.name = "FishingBitePromptButton"
	fishing_bite_prompt_button.visible = false
	fishing_bite_prompt_button.text = "!"
	fishing_bite_prompt_button.focus_mode = Control.FOCUS_NONE
	fishing_bite_prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP
	fishing_bite_prompt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fishing_bite_prompt_button.custom_minimum_size = FISHING_BITE_PROMPT_SIZE
	fishing_bite_prompt_button.size = FISHING_BITE_PROMPT_SIZE
	fishing_bite_prompt_button.position = FISHING_BITE_PROMPT_POSITION
	fishing_bite_prompt_button.z_index = 570
	fishing_bite_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.reel")
	_apply_fishing_bite_prompt_style(fishing_bite_prompt_button)
	fishing_bite_prompt_button.button_down.connect(Callable(self, "_on_fishing_bite_prompt_button_down"))
	fishing_bite_prompt_button.gui_input.connect(Callable(self, "_on_fishing_bite_prompt_gui_input"))
	fishing_bite_prompt_button.pressed.connect(Callable(self, "_on_fishing_bite_prompt_pressed"))
	add_child(fishing_bite_prompt_button)

func _setup_surf_prompt() -> void:
	if surf_prompt_button != null:
		return

	surf_prompt_button = Button.new()
	surf_prompt_button.name = "SurfPromptButton"
	surf_prompt_button.visible = false
	surf_prompt_button.text = ""
	surf_prompt_button.icon = SURF_PROMPT_ICON
	surf_prompt_button.expand_icon = true
	surf_prompt_button.focus_mode = Control.FOCUS_NONE
	surf_prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP
	surf_prompt_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	surf_prompt_button.custom_minimum_size = SURF_PROMPT_SIZE
	surf_prompt_button.size = SURF_PROMPT_SIZE
	surf_prompt_button.position = SURF_PROMPT_POSITION
	surf_prompt_button.z_index = 560
	surf_prompt_button.tooltip_text = LocalizationManager.text("ui.field_move.surf")
	_apply_surf_prompt_style(surf_prompt_button)
	surf_prompt_button.pressed.connect(Callable(self, "_on_surf_prompt_pressed"))
	add_child(surf_prompt_button)

func _apply_fishing_prompt_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_fishing_prompt_style(Color(0.98, 0.95, 0.86, 0.94), Color(0.18, 0.14, 0.20, 0.88)))
	button.add_theme_stylebox_override("hover", _make_fishing_prompt_style(Color(1.0, 0.98, 0.90, 0.98), Color(0.30, 0.22, 0.34, 0.95)))
	button.add_theme_stylebox_override("pressed", _make_fishing_prompt_style(Color(0.90, 0.86, 0.78, 0.98), Color(0.12, 0.10, 0.14, 0.95)))
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color(0.92, 0.92, 0.92, 1.0))
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("icon_max_width", 22)

func _apply_surf_prompt_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_fishing_prompt_style(Color(0.82, 0.94, 1.0, 0.94), Color(0.05, 0.22, 0.38, 0.88)))
	button.add_theme_stylebox_override("hover", _make_fishing_prompt_style(Color(0.90, 0.98, 1.0, 0.98), Color(0.05, 0.32, 0.52, 0.95)))
	button.add_theme_stylebox_override("pressed", _make_fishing_prompt_style(Color(0.68, 0.84, 0.94, 0.98), Color(0.03, 0.16, 0.28, 0.95)))
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color(0.92, 0.96, 1.0, 1.0))
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_constant_override("icon_max_width", 22)

func _make_fishing_prompt_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style

func _apply_fishing_bite_prompt_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_fishing_prompt_style(Color(1.0, 0.92, 0.30, 0.96), Color(0.20, 0.12, 0.02, 0.95)))
	button.add_theme_stylebox_override("hover", _make_fishing_prompt_style(Color(1.0, 0.98, 0.44, 1.0), Color(0.32, 0.18, 0.02, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_fishing_prompt_style(Color(0.92, 0.78, 0.18, 1.0), Color(0.14, 0.08, 0.02, 1.0)))
	button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.02, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.05, 0.01, 1.0))
	button.add_theme_font_size_override("font_size", 20)

func _sync_fishing_prompt_visibility() -> void:
	if fishing_prompt_button == null:
		return
	fishing_prompt_button.visible = can_fish_here()

func refresh_fishing_prompt() -> void:
	_sync_fishing_prompt_visibility()

func _sync_surf_prompt_visibility() -> void:
	if surf_prompt_button == null:
		return
	surf_prompt_button.visible = can_surf_here()

func _sync_fishing_bite_prompt_visibility() -> void:
	if fishing_bite_prompt_button == null:
		return
	_sync_fishing_bite_prompt_state()
	fishing_bite_prompt_button.visible = fishing_activity_active and (
		fishing_activity_state == FISHING_STATE_BITE
		or fishing_activity_state == FISHING_STATE_REEL_SUCCESS
		or fishing_activity_state == FISHING_STATE_MISSED
	)

func _sync_fishing_bite_prompt_state() -> void:
	if fishing_bite_prompt_button == null:
		return
	if fishing_bite_prompt_rendered_state == fishing_activity_state:
		return

	fishing_bite_prompt_rendered_state = fishing_activity_state

	match fishing_activity_state:
		FISHING_STATE_REEL_SUCCESS:
			fishing_bite_prompt_button.text = "OK"
			fishing_bite_prompt_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_fishing_bite_result_style(
				fishing_bite_prompt_button,
				Color(0.46, 0.94, 0.48, 0.98),
				Color(0.04, 0.23, 0.06, 0.95),
				Color(0.02, 0.12, 0.03, 1.0),
				13
			)
		FISHING_STATE_MISSED:
			fishing_bite_prompt_button.text = "X"
			fishing_bite_prompt_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_fishing_bite_result_style(
				fishing_bite_prompt_button,
				Color(0.96, 0.42, 0.34, 0.98),
				Color(0.26, 0.04, 0.03, 0.95),
				Color(0.14, 0.02, 0.02, 1.0),
				16
			)
		_:
			fishing_bite_prompt_button.text = "!"
			fishing_bite_prompt_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_fishing_bite_prompt_style(fishing_bite_prompt_button)

func _apply_fishing_bite_result_style(button: Button, background_color: Color, border_color: Color, font_color: Color, font_size: int) -> void:
	button.add_theme_stylebox_override("normal", _make_fishing_prompt_style(background_color, border_color))
	button.add_theme_stylebox_override("hover", _make_fishing_prompt_style(background_color, border_color))
	button.add_theme_stylebox_override("pressed", _make_fishing_prompt_style(background_color, border_color))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_font_size_override("font_size", font_size)

func _on_fishing_prompt_pressed() -> void:
	start_fishing()
	_sync_fishing_prompt_visibility()

func _on_surf_prompt_pressed() -> void:
	start_surf()
	_sync_surf_prompt_visibility()
	_sync_fishing_prompt_visibility()

func _on_fishing_bite_prompt_pressed() -> void:
	_handle_fishing_bite_prompt_activation()

func _on_fishing_bite_prompt_button_down() -> void:
	_handle_fishing_bite_prompt_activation()

func _on_fishing_bite_prompt_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_handle_fishing_bite_prompt_activation()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_fishing_bite_prompt_activation()
			get_viewport().set_input_as_handled()

func _handle_fishing_bite_prompt_activation() -> void:
	_try_reel_fishing_bite()
	_sync_fishing_bite_prompt_visibility()

func _input(event: InputEvent) -> void:
	if _try_handle_fishing_input_event(event):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_update_sort_z()
	_sync_body_sprite_frames_for_movement()
	_sync_appearance_sprite_frames()
	_sync_mount_rider_delta()
	_sync_mount_foreground_frame()
	_update_fishing_activity(delta)
	_sync_fishing_prompt_visibility()
	_sync_surf_prompt_visibility()
	_sync_fishing_bite_prompt_visibility()

	if _try_start_fishing_skill_input():
		_sync_fishing_prompt_visibility()
		_sync_surf_prompt_visibility()
		return

	if _try_toggle_land_mount_input():
		return

	if _try_check_surf_interaction_input():
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
		_update_stair_visual_offset(move_progress)
		_update_sort_z()

		# Als de bestemming is bereikt.
		if _has_reached_target():
			global_position = _snap_world_position(target_position)
			is_moving = false
			_clear_stair_visual_offset()

			if not story_path_movement_active:
				var completed_tiles := maxi(int(round(move_start_position.distance_to(target_position) / float(TILE_SIZE))), 1)
				overworld_steps_completed.emit(completed_tiles)
				if check_for_map_exit():
					return

				_sync_surf_state_after_move()

				var standing_on_tall_grass := is_standing_on_tall_grass()
				if standing_on_tall_grass:
					_spawn_tall_grass_rustle_effect()
				_spawn_sand_footprint_effect()

				if surf_activity_active:
					check_for_wild_encounter(ENCOUNTER_TYPE_SURF)
				elif standing_on_tall_grass:
					check_for_grass_encounter()
				elif _is_cave_encounter_map():
					check_for_wild_encounter(ENCOUNTER_TYPE_CAVE)

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
	if (
		GameState.show_follower
		and not land_mount_activity_active
		and not PlayerSave.party.is_empty()
	):
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

func _try_handle_fishing_input_event(event: InputEvent) -> bool:
	if event == null or not event.is_action_pressed("fish", false):
		return false
	if _is_ui_typing():
		return false

	return _handle_fishing_skill_trigger()

func _try_start_fishing_skill_input() -> bool:
	if fishing_input_handled_frame == Engine.get_process_frames():
		return false
	if not Input.is_action_just_pressed("fish"):
		return false
	if _is_ui_typing():
		return false

	return _handle_fishing_skill_trigger()

func _handle_fishing_skill_trigger() -> bool:
	if fishing_activity_active:
		var was_handled := _try_reel_fishing_bite()
		if was_handled:
			_mark_fishing_input_handled_frame()
		return was_handled

	var did_start := start_fishing()
	if did_start:
		_mark_fishing_input_handled_frame()
	return did_start

func _mark_fishing_input_handled_frame() -> void:
	fishing_input_handled_frame = Engine.get_process_frames()

func _try_check_surf_interaction_input() -> bool:
	if not Input.is_action_just_pressed("interact"):
		return false
	if _is_ui_typing():
		return false
	if not _is_facing_water_tile():
		return false

	var surf_check := get_surf_check_result()
	_debug_surf_check("interact", surf_check)
	if bool(surf_check.get("allowed", false)):
		start_surf()
	return true


func _try_toggle_land_mount_input() -> bool:
	if not Input.is_action_just_pressed("mount"):
		return false
	if _is_ui_typing():
		return false
	if is_moving or fishing_activity_active or surf_activity_active \
		or GameState.is_overworld_input_locked():
		return true
	if not toggle_land_mount():
		var message_key := "ui.mounts.interior_blocked" \
			if _get_current_map_world_access_area_type() == "interior" \
			else "ui.mounts.license_required" \
			if not _has_mount_license_for_current_region() \
			else "ui.mounts.unavailable"
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text(message_key)
		)
	return true


func _has_party_field_move(move_id: String) -> bool:
	return bool(FieldMoveService.can_use_field_move(move_id).get("success", false))


func _show_field_move_system_message(move_id: String) -> void:
	var field_move_result := FieldMoveService.can_use_field_move(move_id)
	if not bool(field_move_result.get("success", false)):
		return
	var charm_name := str(field_move_result.get("itemName", "")).strip_edges()
	if charm_name != "":
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.field_move.item_used", {"item": charm_name})
		)
		return
	var pokemon: Pokemon = field_move_result.get("pokemon") as Pokemon
	var pokemon_name := (
		ContentLocalization.display_name("species", pokemon.species, pokemon.species)
		if pokemon != null
		else LocalizationManager.text("pokemon.generic")
	)
	var move_name := ContentLocalization.display_name(
		"moves",
		move_id,
		move_id.replace("_", "-").replace("-", " ").capitalize()
	)
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text(
			"ui.field_move.pokemon_used",
			{"pokemon": pokemon_name, "move": move_name}
		)
	)


func _on_locale_changed(_locale: String) -> void:
	if fishing_prompt_button != null:
		fishing_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.fish")
	if fishing_bite_prompt_button != null:
		fishing_bite_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.reel")
	if surf_prompt_button != null:
		surf_prompt_button.tooltip_text = LocalizationManager.text("ui.field_move.surf")


func _on_input_binding_changed(action: String, _keycode: Key) -> void:
	if action != "fish":
		return
	if fishing_prompt_button != null:
		fishing_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.fish")
	if fishing_bite_prompt_button != null:
		fishing_bite_prompt_button.tooltip_text = _fishing_prompt_tooltip("ui.fishing.prompt.reel")


func _fishing_prompt_tooltip(translation_key: String) -> String:
	return LocalizationManager.text(translation_key, {
		"hotkey": SettingsManager.get_input_binding_label("fish"),
	})

func _start_surf_activity(clear_input := true) -> void:
	surf_activity_active = true
	active_mount_id = MountService.resolve_mount_id_for_mode(
		SettingsManager.get_selected_mount_id(SettingsManager.MOUNT_MODE_SURF),
		SettingsManager.MOUNT_MODE_SURF,
		true
	)
	_sync_mount_visual()
	if clear_input:
		_clear_input_buffer()
		_clear_held_direction()
	set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_SURF)
	_sync_fishing_prompt_visibility()
	_sync_surf_prompt_visibility()
	_debug_activity_layer_offsets("surf-start" if clear_input else "surf-resume")
	_spawn_water_ripple_effect(global_position, "surf_start")

func _start_land_mount_activity() -> bool:
	if _get_current_map_world_access_area_type() == "interior":
		return false
	if not _has_mount_license_for_current_region():
		return false
	var mount_id := MountService.resolve_mount_id_for_mode(
		SettingsManager.get_selected_mount_id(SettingsManager.MOUNT_MODE_LAND),
		SettingsManager.MOUNT_MODE_LAND
	)
	if mount_id.is_empty() or not _is_mount_owned(mount_id):
		return false
	land_mount_activity_active = true
	active_mount_id = mount_id
	refresh_pokemon_follower()
	set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_RIDE)
	_sync_mount_visual()
	_clear_input_buffer()
	_clear_held_direction()
	return true

func _finish_land_mount_activity() -> void:
	if not land_mount_activity_active:
		return
	land_mount_activity_active = false
	active_mount_id = ""
	_sync_mount_visual()
	clear_activity_style()
	refresh_pokemon_follower()
	reset_pokemon_follower_position()

func _is_mount_owned(mount_id: String) -> bool:
	var unlock_item_id := MountService.get_mount_unlock_item_id(mount_id)
	if unlock_item_id.is_empty():
		return true
	var inventory_service := get_node_or_null("/root/InventoryService")
	return (
		inventory_service != null
		and inventory_service.has_method("has_item")
		and bool(inventory_service.call("has_item", unlock_item_id))
	)


func _has_mount_license_for_current_region() -> bool:
	var inventory_service := get_node_or_null("/root/InventoryService")
	return (
		inventory_service != null
		and inventory_service.has_method("has_mount_license_for_region")
		and bool(inventory_service.call(
			"has_mount_license_for_region",
			_get_current_map_region_id()
		))
	)


func _get_current_map_region_id() -> String:
	var current_map := _resolve_current_map()
	if current_map == null:
		return ""
	if current_map.has_method("get_location_metadata"):
		var metadata_value: Variant = current_map.call("get_location_metadata")
		if metadata_value is Dictionary:
			var region_id := str((metadata_value as Dictionary).get("regionId", "")).strip_edges()
			if not region_id.is_empty():
				return region_id.to_lower()
	if current_map.has_method("get_map_region_name"):
		var region_name := str(current_map.call("get_map_region_name")).strip_edges()
		if not region_name.is_empty():
			return region_name.to_lower().replace(" ", "_")
	if current_map.has_method("get_map_id"):
		return str(current_map.call("get_map_id")).strip_edges().to_lower().get_slice("_", 0)
	return ""

func _finish_surf_activity(reason := "left_water") -> void:
	if not surf_activity_active:
		return

	surf_activity_active = false
	active_mount_id = ""
	_sync_mount_visual()
	clear_activity_style()
	_sync_fishing_prompt_visibility()
	_sync_surf_prompt_visibility()
	_debug_surf_check("finish", {
		"allowed": false,
		"reason": reason,
		"target_position": global_position,
	})

func _sync_surf_state_after_move() -> void:
	if not surf_activity_active:
		return
	if _is_water_tile_at(global_position):
		_spawn_water_ripple_effect(global_position, "surf_step")
		return

	_finish_surf_activity()

func _start_fishing_activity(fishing_tier: int = 1) -> void:
	fishing_activity_active = true
	fishing_activity_state = FISHING_STATE_CAST
	fishing_activity_time_left = FISHING_CAST_DURATION
	fishing_activity_tier = clampi(fishing_tier, 1, 3)
	_clear_input_buffer()
	_clear_held_direction()
	GameState.lock_overworld_input()
	set_activity_style(
		CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH
		if surf_activity_active
		else CharacterAppearanceService.BODY_MOVEMENT_FISH
	)
	_sync_fishing_bite_prompt_visibility()
	_debug_activity_layer_offsets("fishing-start")
	_spawn_water_ripple_effect(_get_fishing_ripple_position(), "fish_cast", false)

func _update_fishing_activity(delta: float) -> void:
	if not fishing_activity_active:
		return

	fishing_activity_time_left = maxf(fishing_activity_time_left - delta, 0.0)
	if fishing_activity_time_left > 0.0:
		return

	match fishing_activity_state:
		FISHING_STATE_CAST:
			_enter_fishing_waiting_state()
		FISHING_STATE_WAITING:
			_enter_fishing_bite_state()
		FISHING_STATE_BITE:
			_enter_fishing_missed_state()
		FISHING_STATE_REEL_SUCCESS, FISHING_STATE_MISSED:
			_finish_fishing_activity()
		_:
			_finish_fishing_activity()

func _enter_fishing_waiting_state() -> void:
	fishing_activity_state = FISHING_STATE_WAITING
	fishing_activity_time_left = randf_range(FISHING_BITE_DELAY_MIN, FISHING_BITE_DELAY_MAX)
	_sync_fishing_bite_prompt_visibility()
	_debug_fishing_state("waiting")

func _enter_fishing_bite_state() -> void:
	fishing_activity_state = FISHING_STATE_BITE
	fishing_activity_time_left = FISHING_BITE_WINDOW_DURATION
	_sync_fishing_bite_prompt_visibility()
	_debug_fishing_state("bite")
	_spawn_water_ripple_effect(_get_fishing_ripple_position(), "fish_bite", false)

func _enter_fishing_missed_state(reason: String = "missed") -> void:
	fishing_activity_state = FISHING_STATE_MISSED
	fishing_activity_time_left = FISHING_RESULT_HOLD_DURATION
	_sync_fishing_bite_prompt_visibility()
	_debug_fishing_state(reason)

func _try_reel_fishing_bite() -> bool:
	if not fishing_activity_active:
		return false
	if fishing_activity_state != FISHING_STATE_BITE:
		if fishing_activity_state == FISHING_STATE_CAST or fishing_activity_state == FISHING_STATE_WAITING:
			_enter_fishing_missed_state("early")
		return true

	fishing_activity_state = FISHING_STATE_REEL_SUCCESS
	fishing_activity_time_left = FISHING_RESULT_HOLD_DURATION
	_sync_fishing_bite_prompt_visibility()
	_debug_fishing_state("reel-success")
	_spawn_water_ripple_effect(_get_fishing_ripple_position(), "fish_reel", false)
	return true

func _finish_fishing_activity() -> void:
	if not fishing_activity_active:
		return

	var should_check_fishing_encounter := fishing_activity_state == FISHING_STATE_REEL_SUCCESS
	var fishing_encounter_position := _get_facing_tile_position()
	var fishing_encounter_type := _fishing_encounter_type_for_tier(fishing_activity_tier)

	fishing_activity_active = false
	fishing_activity_time_left = 0.0
	fishing_activity_tier = 0
	fishing_activity_state = FISHING_STATE_NONE
	if surf_activity_active:
		set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_SURF)
	else:
		clear_activity_style()
	_sync_fishing_bite_prompt_visibility()
	GameState.unlock_overworld_input()

	if should_check_fishing_encounter:
		check_for_wild_encounter(fishing_encounter_type, fishing_encounter_position)

func _fishing_encounter_type_for_tier(fishing_tier: int) -> String:
	return str(FISHING_ENCOUNTER_TYPES.get(clampi(fishing_tier, 1, 3), "old_rod"))

func _is_facing_water_tile() -> bool:
	return last_direction != Vector2.ZERO and _is_water_tile_at(_get_facing_tile_position())

func _get_facing_tile_position() -> Vector2:
	return _snap_world_position(global_position) + (last_direction * TILE_SIZE)

func _get_fishing_ripple_position() -> Vector2:
	if last_direction == Vector2.ZERO:
		return _get_facing_tile_position()
	return _snap_world_position(global_position) + (last_direction.normalized() * FISHING_RIPPLE_DISTANCE)

func _is_water_tile_at(check_position: Vector2) -> bool:
	if water_tilemap == null:
		if _resolve_current_map() == null:
			return false
		refresh_map_layers()
	if water_tilemap == null:
		return false
	return _tilemap_has_tile_at(water_tilemap, check_position)

func _can_enter_water_tile(_check_position: Vector2) -> bool:
	return surf_activity_active

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
	if land_mount_activity_active:
		return LAND_MOUNT_TILE_MOVE_DURATION
	if surf_activity_active:
		return RUN_TILE_MOVE_DURATION if GameState.running_shoes_enabled else TILE_MOVE_DURATION
	if _is_activity_pose_active():
		return TILE_MOVE_DURATION
	return RUN_TILE_MOVE_DURATION if GameState.running_shoes_enabled else TILE_MOVE_DURATION

func _get_current_walk_animation_speed() -> float:
	if land_mount_activity_active:
		return LAND_MOUNT_WALK_ANIMATION_SPEED
	if surf_activity_active:
		return RUN_WALK_ANIMATION_SPEED if GameState.running_shoes_enabled else WALK_ANIMATION_SPEED
	if _is_activity_pose_active():
		return WALK_ANIMATION_SPEED
	return RUN_WALK_ANIMATION_SPEED if GameState.running_shoes_enabled else WALK_ANIMATION_SPEED

func _is_activity_pose_active() -> bool:
	return activity_style != CharacterAppearanceService.BODY_MOVEMENT_DEFAULT

func _uses_static_activity_movement_pose() -> bool:
	return CharacterAppearanceService.normalize_movement_style(activity_style) == CharacterAppearanceService.BODY_MOVEMENT_RIDE

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
	if _is_direction_blocked_by_current_tile(direction):
		set_idle_frame()
		return false

	# Bepaal de volgende wereldpositie.
	# Voorbeeld: Vector2.RIGHT * 32 = Vector2(32, 0), dus 1 tile naar rechts.
	var new_target_position := _snap_world_position(global_position) + (direction * TILE_SIZE)
	var movement_target_position := new_target_position

	if _try_trigger_route_gate(new_target_position):
		set_idle_frame()
		return false

	var ledge_directions := _get_ledge_directions_for_tile(new_target_position)
	if not ledge_directions.is_empty():
		if not ledge_directions.has(direction):
			return false

		movement_target_position = _snap_world_position(new_target_position + (direction * TILE_SIZE))

	# Check eerst of de target tile vrij is.
	# Alleen als can_move_to true teruggeeft, starten we de beweging.
	if _is_world_barrier_step_blocked(global_position, movement_target_position):
		return false
	if not can_move_to(movement_target_position):
		return false
	if _is_world_actor_step_blocked(global_position, movement_target_position):
		return false

	target_position = _snap_world_position(movement_target_position)
	move_start_position = _snap_world_position(global_position)
	global_position = move_start_position
	move_elapsed = 0.0
	move_duration = _get_current_tile_move_duration()
	stair_elevation = HorizontalStairElevationScript.elevation_for_stair_exit(
		_resolve_current_map(),
		move_start_position,
		target_position,
		direction
	)
	is_moving = true
	play_walk_animation(direction)
	return true

func play_walk_animation(direction: Vector2) -> void:
	if _uses_static_activity_movement_pose():
		_apply_static_activity_idle_pose(direction)
		_sync_mount_animation(true, direction)
		return

	_apply_directional_appearance_layer_order(direction)
	var animation_name := _get_walk_animation_name(direction)
	var should_restart_animation := master_appearance_sprite == null \
		or master_appearance_sprite.animation != animation_name \
		or not master_appearance_sprite.is_playing()

	for sprite in appearance_sprites:
		if _should_keep_activity_layer_idle(sprite):
			_sync_activity_idle_layer(sprite, direction)
			continue
		if _sprite_has_animation(sprite, animation_name):
			_restore_layer_visibility_if_needed(sprite)
			sprite.animation = animation_name
			if should_restart_animation:
				sprite.frame = 0
				sprite.frame_progress = 0.0
			sprite.play(animation_name)
		else:
			_hide_layer_for_missing_animation(sprite)
	_sync_mount_animation(true, direction)

func can_move_to(check_position: Vector2) -> bool:
	refresh_map_layers()

	if _is_water_tile_at(check_position) and not _can_enter_water_tile(check_position):
		_debug_surf_check("movement-blocked", {
			"allowed": false,
			"reason": "not_surfing",
			"target_position": check_position,
		})
		return false

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


func _is_world_barrier_step_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	var current_map := _resolve_current_map()
	return (
		current_map != null
		and current_map.has_method("is_world_barrier_step_blocked")
		and bool(
			current_map.call(
				"is_world_barrier_step_blocked",
				from_position,
				to_position
			)
		)
	)


func _is_world_actor_step_blocked(from_position: Vector2, to_position: Vector2) -> bool:
	var current_map := _resolve_current_map()
	return (
		current_map != null
		and current_map.has_method("is_world_actor_step_blocked")
		and bool(
			current_map.call(
				"is_world_actor_step_blocked",
				from_position,
				to_position
			)
		)
	)

func _is_direction_blocked_by_current_tile(direction: Vector2) -> bool:
	if direction == Vector2.DOWN:
		return _tilemap_has_tile_at(block_down_tilemap, global_position)
	if direction == Vector2.UP:
		return _tilemap_has_tile_at(block_up_tilemap, global_position)
	if direction == Vector2.LEFT:
		return _tilemap_has_tile_at(block_left_tilemap, global_position)
	if direction == Vector2.RIGHT:
		return _tilemap_has_tile_at(block_right_tilemap, global_position)

	return false

func _get_ledge_directions_for_tile(check_position: Vector2) -> Array[Vector2]:
	refresh_map_layers()
	return LedgeDirectionResolverScript.directions_for_tile(
		check_position,
		ledge_down_tilemap,
		ledge_up_tilemap,
		ledge_left_tilemap,
		ledge_right_tilemap
	)

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
	_apply_static_activity_idle_pose(last_direction)
	_sync_mount_animation(false, last_direction)

func _apply_static_activity_idle_pose(direction: Vector2) -> void:
	_apply_directional_appearance_layer_order(direction)
	for sprite in appearance_sprites:
		sprite.stop()
		_set_idle_animation(sprite, direction)
	_sync_activity_layer_offsets()
	_apply_activity_visual_offset()
	
func refresh_map_layers() -> void:
	var current_map: Node = _resolve_current_map()
	if current_map == null:
		collision_tilemap = null
		grass_tilemap = null	
		grass_visual_tilemap = null
		water_tilemap = null
		sand_tilemaps.clear()
		block_down_tilemap = null
		block_up_tilemap = null
		block_left_tilemap = null
		block_right_tilemap = null
		ledge_down_tilemap = null
		ledge_up_tilemap = null
		ledge_left_tilemap = null
		ledge_right_tilemap = null
		push_warning("Player.refresh_map_layers: could not resolve current map.")
		return

	GameState.current_map = current_map
	collision_tilemap = _find_tilemap_layer(current_map, ["Collision"])
	grass_tilemap = _find_tall_grass_tilemap(current_map)
	grass_visual_tilemap = _find_tall_grass_visual_tilemap(current_map)
	water_tilemap = _find_tilemap_layer(current_map, WATER_TILEMAP_NAMES)
	_refresh_sand_tilemaps(current_map)
	block_down_tilemap = _find_tilemap_layer(current_map, ["BlockDown"])
	block_up_tilemap = _find_tilemap_layer(current_map, ["BlockUp"])
	block_left_tilemap = _find_tilemap_layer(current_map, ["BlockLeft"])
	block_right_tilemap = _find_tilemap_layer(current_map, ["BlockRight"])
	ledge_down_tilemap = _find_tilemap_layer(current_map, ["LedgeDown"])
	ledge_up_tilemap = _find_tilemap_layer(current_map, ["LedgeUp"])
	ledge_left_tilemap = _find_tilemap_layer(current_map, ["LedgeLeft"])
	ledge_right_tilemap = _find_tilemap_layer(current_map, ["LedgeRight"])

	if collision_tilemap == null:
		push_warning("Player.refresh_map_layers: Collision layer missing on %s." % current_map.name)
	_apply_world_pixel_scale()

func _find_tilemap_layer(parent: Node, layer_names: Array[String]) -> TileMapLayer:
	return MapLayerResolverScript.find_tilemap_layer(parent, layer_names)


func _find_tall_grass_tilemap(parent: Node) -> TileMapLayer:
	var scene_layer := parent.get_node_or_null("Tiles/TallGrass") as TileMapLayer
	if scene_layer != null:
		return scene_layer
	return _find_tilemap_layer(parent, ["TallGrass"])


func _find_tall_grass_visual_tilemap(parent: Node) -> TileMapLayer:
	var candidates: Array[TileMapLayer] = []
	_collect_tilemap_layers_by_name(parent, TALL_GRASS_VISUAL_TILEMAP_NAMES, candidates)
	for layer: TileMapLayer in candidates:
		if bool(layer.get_meta("tiled_visual_layer", false)):
			return layer
	return candidates[0] if not candidates.is_empty() else null


func _collect_tilemap_layers_by_name(node: Node, layer_names: Array[String], layers: Array[TileMapLayer]) -> void:
	var tilemap_layer := node as TileMapLayer
	if tilemap_layer != null and layer_names.has(tilemap_layer.name):
		layers.append(tilemap_layer)

	for child: Node in node.get_children():
		_collect_tilemap_layers_by_name(child, layer_names, layers)
	
func is_standing_on_tall_grass() -> bool:
	if grass_tilemap == null:
		refresh_map_layers()

	if grass_tilemap == null:
		return false
		
	var local_position := grass_tilemap.to_local(global_position)
	var tile_position := grass_tilemap.local_to_map(local_position)
	var tile_data := grass_tilemap.get_cell_tile_data(tile_position)
	
	return tile_data != null


func is_standing_on_water() -> bool:
	return _is_water_tile_at(global_position)
		
func check_for_grass_encounter() -> void:
	check_for_wild_encounter(ENCOUNTER_TYPE_GRASS)


func _is_cave_encounter_map() -> bool:
	var current_map := _resolve_current_map()
	if current_map == null:
		return false
	if not current_map.has_method("get_battle_environment_id"):
		return false
	if str(current_map.call("get_battle_environment_id")).strip_edges().to_lower() != ENCOUNTER_TYPE_CAVE:
		return false
	if not current_map.has_method("get_wild_encounter_area_id"):
		return false
	return not str(current_map.call("get_wild_encounter_area_id")).strip_edges().is_empty()

func _spawn_tall_grass_rustle_effect() -> void:
	var current_map := _resolve_current_map()
	var effect_parent: Node = current_map if current_map != null else get_parent()
	if effect_parent == null:
		return

	var effect_source := TALL_GRASS_DEPTH_SORTING_SCRIPT.find_depth_row_at_global_position(
		current_map,
		global_position
	)
	var effect_tilemap := effect_source.get("layer") as TileMapLayer
	var tile_position: Vector2i = effect_source.get("tile_position", Vector2i.ZERO)
	if effect_tilemap == null:
		if grass_visual_tilemap == null:
			grass_visual_tilemap = _find_tall_grass_visual_tilemap(current_map)
		if grass_visual_tilemap == null:
			return
		effect_tilemap = grass_visual_tilemap
		tile_position = effect_tilemap.local_to_map(effect_tilemap.to_local(global_position))
		if effect_tilemap.get_cell_source_id(tile_position) < 0:
			return

	var effect := TALL_GRASS_RUSTLE_EFFECT_SCRIPT.new()
	effect_parent.add_child(effect)
	effect.play(effect_tilemap, tile_position)

func _spawn_water_ripple_effect(world_position: Vector2, kind: String, require_water_tile := true) -> void:
	if require_water_tile and not _is_water_tile_at(world_position):
		return

	var current_map := _resolve_current_map()
	var effect_parent: Node = current_map if current_map != null else get_parent()
	if effect_parent == null:
		return

	var effect := WATER_RIPPLE_EFFECT_SCRIPT.new()
	effect_parent.add_child(effect)
	effect.play(_snap_world_position(world_position), kind)

func _spawn_sand_footprint_effect() -> void:
	var footprint_offset: Variant = _get_sand_footprint_offset(global_position)
	if footprint_offset == null:
		return

	var current_map := _resolve_current_map()
	var effect_parent: Node = current_map if current_map != null else get_parent()
	if effect_parent == null:
		return

	var effect := SAND_FOOTPRINT_EFFECT_SCRIPT.new()
	effect_parent.add_child(effect)
	effect.play(
		_snap_world_position(global_position + footprint_offset),
		last_direction,
		next_sand_footprint_is_left
	)
	# De afdruk kan binnen de tegel verschoven zijn, maar blijft visueel onder
	# de speler in plaats van bij een SandDown-tile vóór hem te komen.
	effect.z_index = floori(get_feet_position().y) - 1
	next_sand_footprint_is_left = not next_sand_footprint_is_left

func _get_sand_footprint_offset(check_position: Vector2) -> Variant:
	if sand_tilemaps.is_empty():
		var current_map := _resolve_current_map()
		if current_map == null:
			return null
		_refresh_sand_tilemaps(current_map)

	for layer_name: String in SAND_FOOTPRINT_LAYER_OFFSETS:
		var tilemap := sand_tilemaps.get(layer_name) as TileMapLayer
		if _tilemap_has_tile_at(tilemap, check_position):
			return SAND_FOOTPRINT_LAYER_OFFSETS[layer_name]

	return null

func _refresh_sand_tilemaps(current_map: Node) -> void:
	sand_tilemaps.clear()
	if current_map == null:
		return

	for layer_name: String in SAND_FOOTPRINT_LAYER_OFFSETS:
		var tilemap := _find_tilemap_layer(current_map, [layer_name])
		if tilemap != null:
			sand_tilemaps[layer_name] = tilemap

func check_for_wild_encounter(encounter_type: String, check_position: Vector2 = Vector2.INF) -> void:
	var current_map := GameState.current_map
	if current_map == null:
		_debug_wild_encounter("blocked", {
			"reason": "missing_map",
			"encounter_type": encounter_type,
		})
		return

	if GameState.repel_enabled and _does_repel_block_encounter(encounter_type):
		_debug_wild_encounter("blocked", {
			"reason": "repel",
			"encounter_type": encounter_type,
		})
		return

	var resolved_position := global_position if check_position == Vector2.INF else check_position
	var encounter := WildEncounterProvider.resolve_wild_encounter(current_map, resolved_position, encounter_type)
	if not bool(encounter.get("available", false)):
		_debug_wild_encounter("blocked", encounter)
		return

	var resolved_type: String = str(encounter.get("encounter_type", encounter_type))
	if bool(encounter.get("use_map_trigger", false)):
		if current_map.has_method("should_trigger_wild_encounter"):
			if not bool(current_map.call("should_trigger_wild_encounter", resolved_type)):
				_debug_wild_encounter("miss", encounter)
				return
	else:
		var encounter_chance := clampf(float(encounter.get("chance", 0.0)), 0.0, 1.0)
		if randf() > encounter_chance:
			_debug_wild_encounter("miss", encounter)
			return
	
	var world := GameState.get_world()
	if world != null and world.has_method("start_triggered_wild_battle_for_area"):
		_debug_wild_encounter("start", encounter)
		world.start_triggered_wild_battle_for_area(str(encounter.get("area_id", "")), resolved_type)
	else:
		_debug_wild_encounter("blocked", {
			"reason": "missing_world",
			"encounter_type": resolved_type,
			"area_id": str(encounter.get("area_id", "")),
		})

func _does_repel_block_encounter(encounter_type: String) -> bool:
	var normalized_type := encounter_type.strip_edges().to_lower()
	return normalized_type not in [
		ENCOUNTER_TYPE_FISH,
		"fishing",
		"old_rod",
		"good_rod",
		"super_rod",
	]

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
		if _find_tilemap_layer(parent_node, ["Collision", "TallGrass"]) != null:
			return parent_node

		parent_node = parent_node.get_parent()

	if GameState.current_map != null and is_instance_valid(GameState.current_map):
		return GameState.current_map

	return null

func _update_sort_z() -> void:
	var sort_position := get_feet_position()
	var sort_z := floori(sort_position.y)
	var current_map := _resolve_current_map()
	if current_map != null and current_map.has_method("get_actor_sort_z_floor"):
		sort_z = maxi(sort_z, int(current_map.call("get_actor_sort_z_floor", sort_position)))
	z_index = clampi(sort_z, SORT_Z_MIN, SORT_Z_MAX)

func _cache_appearance_sprites() -> void:
	appearance_sprites.clear()
	_collect_appearance_sprites(look_node)
	master_appearance_sprite = _get_master_appearance_sprite()
	_sync_appearance_animation_speeds()

func _collect_appearance_sprites(parent: Node) -> void:
	for child: Node in parent.get_children():
		var sprite: AnimatedSprite2D = child as AnimatedSprite2D
		if sprite != null \
			and sprite.name != MOUNT_SPRITE_NAME \
			and sprite.name != MOUNT_FOREGROUND_SPRITE_NAME:
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
	var body_sprite := _get_appearance_sprite(BODY_SPRITE_NAME)
	if body_sprite == null:
		push_warning("Player: BodySprite node is missing.")
		return

	var source_body_id: String = body_id.strip_edges()
	var normalized_body_id: String = CharacterAppearanceService.resolve_body_model_id(source_body_id, PlayerSave.gender)
	PlayerSave.appearance_skin_tone = CharacterAppearanceService.resolve_skin_tone(
		source_body_id,
		PlayerSave.appearance_skin_tone,
		PlayerSave.gender
	)
	var available_body_ids: Array[String] = CharacterAppearanceService.get_available_body_model_ids(PlayerSave.gender)
	if normalized_body_id == "" or not available_body_ids.has(normalized_body_id):
		normalized_body_id = CharacterAppearanceService.DEFAULT_FEMALE_BODY_ID \
			if PlayerSave.gender == "female" \
			else CharacterAppearanceService.DEFAULT_MALE_BODY_ID
		PlayerSave.ensure_layered_appearance_defaults()
	PlayerSave.appearance_body_id = normalized_body_id

	var movement_style: String = _get_current_body_movement_style()
	var body_frames: SpriteFrames = CharacterAppearanceService.get_skin_tinted_body_frames(
		normalized_body_id,
		PlayerSave.gender,
		movement_style,
		PlayerSave.appearance_skin_tone
	)
	if body_frames == null:
		push_warning("Player: body appearance '%s' could not be loaded." % normalized_body_id)
		return
	body_frames = MountService.get_mounted_rider_frames(body_frames, active_mount_id)

	body_sprite.sprite_frames = body_frames
	body_sprite.texture_filter = PLAYER_SPRITE_TEXTURE_FILTER
	_apply_body_modulate(body_sprite, normalized_body_id)
	body_sprite_frames_movement_style = movement_style
	_apply_appearance_parts(movement_style)

func _sync_body_sprite_frames_for_movement() -> void:
	var body_sprite := _get_appearance_sprite(BODY_SPRITE_NAME)
	if body_sprite == null:
		return

	var movement_style: String = _get_current_body_movement_style()
	if movement_style == body_sprite_frames_movement_style:
		return

	var current_animation: StringName = body_sprite.animation
	var current_frame: int = body_sprite.frame
	var current_frame_progress: float = body_sprite.frame_progress
	var was_playing: bool = body_sprite.is_playing()
	var body_frames: SpriteFrames = CharacterAppearanceService.get_skin_tinted_body_frames(
		PlayerSave.appearance_body_id,
		PlayerSave.gender,
		movement_style,
		PlayerSave.appearance_skin_tone
	)
	if body_frames == null:
		return
	body_frames = MountService.get_mounted_rider_frames(body_frames, active_mount_id)

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
	_apply_directional_appearance_layer_order(last_direction)

func _apply_directional_appearance_layer_order(direction: Vector2) -> void:
	var facegear_sprite := _get_appearance_sprite(FACE_GEAR_SPRITE_NAME)
	if facegear_sprite == null:
		return
	var direction_id := "up" if direction == Vector2.UP else "down"
	facegear_sprite.z_index = CharacterAppearanceService.get_directional_part_z_index(
		"facegear",
		PlayerSave.appearance_facegear_id,
		direction_id,
		8
	)

func _get_player_appearance_part_id(category: String) -> String:
	match CharacterAppearanceService.normalize_part_category(category):
		"hair":
			return CharacterAppearanceService.resolve_hair_render_id(
				PlayerSave.appearance_hair_id
			)
		"headgear":
			return PlayerSave.appearance_headgear_id
		"facial_hair":
			return PlayerSave.appearance_facial_hair_id
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
			return CharacterAppearanceService.get_eyebrows_for_hair(PlayerSave.appearance_hair_id, PlayerSave.gender)
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
	part_frames = MountService.get_mounted_rider_frames(part_frames, active_mount_id)

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
	for sprite in appearance_sprites:
		if sprite.name == sprite_name:
			return sprite
	return null

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

func _sync_activity_layer_offsets() -> void:
	for category_value: Variant in APPEARANCE_PART_SPRITES.keys():
		var category: String = str(category_value)
		var sprite := _get_appearance_sprite(str(APPEARANCE_PART_SPRITES[category]))
		if sprite == null or _is_unequipped_appearance_part_sprite(sprite):
			continue
		_apply_activity_layer_offset(sprite, category)

func _apply_activity_visual_offset() -> void:
	if look_node == null:
		return
	look_node.position = base_look_position + _get_activity_visual_offset() + stair_visual_offset

func _restore_activity_visual_offset() -> void:
	if look_node == null:
		return
	look_node.position = base_look_position + stair_visual_offset


func _update_stair_visual_offset(progress: float) -> void:
	stair_visual_offset = HorizontalStairElevationScript.visual_offset(
		progress,
		stair_elevation
	)
	_apply_activity_visual_offset()


func _clear_stair_visual_offset() -> void:
	stair_elevation = HorizontalStairElevationScript.ELEVATION_NONE
	stair_visual_offset = Vector2.ZERO
	_apply_activity_visual_offset()

func _get_activity_visual_offset() -> Vector2:
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(activity_style)
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		normalized_style = CharacterAppearanceService.BODY_MOVEMENT_FISH
	elif normalized_style == CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET:
		normalized_style = CharacterAppearanceService.BODY_MOVEMENT_FISH
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
	var normalized_style: String = CharacterAppearanceService.normalize_movement_style(body_sprite_frames_movement_style)
	if normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH:
		normalized_style = CharacterAppearanceService.BODY_MOVEMENT_FISH
	elif normalized_style == CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET:
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

func _debug_fishing_state(reason: String) -> void:
	if not GameState.world_debug_enabled:
		return

	GameState.debug_world("[fishing] %s state=%s tier=%d time_left=%.2f" % [
		reason,
		fishing_activity_state,
		fishing_activity_tier,
		fishing_activity_time_left,
	])

func _debug_surf_check(reason: String, result: Dictionary) -> void:
	if not GameState.world_debug_enabled:
		return

	GameState.debug_world("[surf] %s allowed=%s reason=%s target=%s unlocked=%s surfing=%s" % [
		reason,
		str(bool(result.get("allowed", false))),
		str(result.get("reason", "")),
		str(result.get("target_position", Vector2.ZERO)),
		str(bool(GameState.surf_unlocked)),
		str(surf_activity_active),
	])

func _debug_wild_encounter(reason: String, encounter: Dictionary) -> void:
	if not GameState.world_debug_enabled:
		return

	GameState.debug_world("[encounter] %s type=%s area=%s source=%s chance=%.2f use_map_trigger=%s reason=%s region=%s" % [
		reason,
		str(encounter.get("encounter_type", "")),
		str(encounter.get("area_id", "")),
		str(encounter.get("source", "")),
		float(encounter.get("chance", 0.0)),
		str(bool(encounter.get("use_map_trigger", false))),
		str(encounter.get("reason", "")),
		str(encounter.get("region_id", "")),
	])

func _debug_activity_layer_offsets(reason: String) -> void:
	if not GameState.world_debug_enabled:
		return

	GameState.debug_world("[activity-pose] %s style=%s tier=%d direction=%s body_style=%s position=%s look=%s visual_offset=%s" % [
		reason,
		activity_style,
		fishing_activity_tier,
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
	if normalized_category == "eyebrows" or (
		normalized_category == "hair"
		and CharacterAppearanceService.is_tintable_part(category, part_id)
	):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_hair_color, Color.WHITE),
			true
		)
	if normalized_category == "facial_hair" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_facial_hair_color, Color.WHITE),
			true
		)
	if normalized_category == "facegear" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_facegear_color, Color.WHITE),
			true
		)
	if normalized_category == "top" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_top_color, Color.WHITE),
			true
		)
	if normalized_category == "bottom" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_bottom_color, Color.WHITE),
			true
		)
	if normalized_category == "shoes" and CharacterAppearanceService.is_tintable_part(category, part_id):
		return CharacterAppearanceService.get_tinted_part_frames(
			category,
			part_id,
			PlayerSave.gender,
			movement_style,
			_parse_appearance_color(PlayerSave.appearance_shoes_color, Color.WHITE),
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
		if _should_keep_activity_layer_idle(sprite):
			_sync_activity_idle_layer(sprite, last_direction)
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

func _sync_activity_idle_layer(sprite: AnimatedSprite2D, direction: Vector2) -> void:
	if sprite == null:
		return

	var animation_name := _get_idle_animation_name(direction)
	if not _sprite_has_animation(sprite, animation_name):
		animation_name = _get_walk_animation_name(direction)
	if not _sprite_has_animation(sprite, animation_name):
		_hide_layer_for_missing_animation(sprite)
		return

	_restore_layer_visibility_if_needed(sprite)
	sprite.animation = animation_name
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.stop()

func _should_keep_activity_layer_idle(sprite: AnimatedSprite2D) -> bool:
	if sprite == null or sprite == master_appearance_sprite:
		return false
	if CharacterAppearanceService.normalize_movement_style(activity_style) != CharacterAppearanceService.BODY_MOVEMENT_RIDE:
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
		return
	
	animation_name = _get_walk_animation_name(direction)
	if _sprite_has_animation(sprite, animation_name):
		_restore_layer_visibility_if_needed(sprite)
		sprite.animation = animation_name
		sprite.frame = 0
		sprite.stop()
		return

	_hide_layer_for_missing_animation(sprite)

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
