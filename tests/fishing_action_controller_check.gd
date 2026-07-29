extends SceneTree

const CONTROLLER_PATH := "res://scripts/ui/fishing_action_controller.gd"
const OVERLAY_PATH := "res://scenes/interface/ui_overlay.tscn"
const WORLD_PATH := "res://scripts/world/world.gd"
const PLAYER_PATH := "res://scripts/world/player.gd"
const APPEARANCE_SERVICE_PATH := "res://scripts/services/character_appearance_service.gd"
const REMOTE_PLAYER_PATH := "res://scripts/world/remote_player_avatar.gd"
const CharacterAppearanceServiceScript := preload(
	"res://scripts/services/character_appearance_service.gd"
)

var failed := false


func _init() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var appearance_source := FileAccess.get_file_as_string(APPEARANCE_SERVICE_PATH)
	var remote_player_source := FileAccess.get_file_as_string(REMOTE_PLAYER_PATH)

	_check(
		overlay_source.contains('path="res://scripts/ui/fishing_action_controller.gd"')
		and overlay_source.contains('[node name="FishingActionController" type="Node" parent="."]'),
		"overworld overlay installs the fishing action controller"
	)
	_check(
		controller_source.contains("actions_row.add_child(action_slot)")
		and controller_source.contains('action_button.pressed.connect(_toggle_popup)'),
		"action bar exposes a clickable rod selector"
	)
	_check(
		controller_source.contains('const FISHING_ACTION_ICON := preload("res://assets/ui/fishing_rod.svg")')
		and controller_source.contains("action_button.texture_normal = FISHING_ACTION_ICON")
		and controller_source.contains("header_icon.texture = FISHING_ACTION_ICON"),
		"toolbar and header use the dedicated vector fishing icon"
	)
	_check(
		controller_source.contains("not bool(rod.get(\"owned\", false))")
		and controller_source.contains("not bool(rod.get(\"usable\", false))")
		and controller_source.contains("InventoryService.select_fishing_rod"),
		"rod selector only submits owned and currently usable rods"
	)
	_check(
		controller_source.contains("action_button.disabled = selection_pending"),
		"players without a rod can still inspect the fishing progression panel"
	)
	_check(
		controller_source.contains('no_rod_button.pressed.connect(_select_rod.bind(""))')
		and controller_source.contains("No rod — Put rod away")
		and controller_source.contains("ACTIVE_GREEN_BG"),
		"players can deactivate fishing and active rods use the green toolbar state"
	)
	_check(
		player_source.contains("GameState.selected_fishing_rod_item_id.is_empty()")
		and player_source.contains("func refresh_fishing_prompt()"),
		"the nearby-water prompt requires and reacts to an active rod selection"
	)
	_check(
		not _function_source(player_source, "can_fish_here").contains("or surf_activity_active")
		and player_source.contains("CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH")
		and _function_source(player_source, "_finish_fishing_activity").contains(
			"set_activity_style(CharacterAppearanceService.BODY_MOVEMENT_SURF)"
		),
		"stationary Surf players can fish without losing their Surf state"
	)
	_check(
		appearance_source.contains('const BODY_MOVEMENT_SURF_FISH := "surf_fish"')
		and appearance_source.contains("func resolve_layer_movement_style(")
		and appearance_source.contains("normalized_category == BOTTOM_CATEGORY")
		and appearance_source.contains("return BODY_MOVEMENT_RIDE")
		and appearance_source.contains("return BODY_MOVEMENT_FISH"),
		"Surf fishing combines fishing upper layers with riding lower layers"
	)
	_check(
		CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "body")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "top")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "bottom")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_RIDE
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "shoes")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_RIDE,
		"combined Surf fishing resolves each appearance layer to an existing sheet"
	)
	var combined_body_frames := CharacterAppearanceServiceScript.get_body_frames(
		CharacterAppearanceServiceScript.DEFAULT_MALE_BODY_ID,
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	var combined_top_frames := CharacterAppearanceServiceScript.get_part_frames(
		"top",
		CharacterAppearanceServiceScript.DEFAULT_MALE_TOP_ID,
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	var combined_bottom_frames := CharacterAppearanceServiceScript.get_part_frames(
		"bottom",
		CharacterAppearanceServiceScript.DEFAULT_MALE_BOTTOM_ID,
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	var custom_bottom_frames := CharacterAppearanceServiceScript.get_part_frames(
		"bottom",
		"Adinho_Trousers",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	var custom_shoes_frames := CharacterAppearanceServiceScript.get_part_frames(
		"shoes",
		"Adinho_Shoes",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	_check(
		combined_body_frames != null
		and appearance_source.contains("func _build_surf_fishing_body_frames(")
		and appearance_source.contains("func _build_surf_fishing_layer_frames(")
		and appearance_source.contains("func _build_surf_fishing_upper_layer_frames(")
		and appearance_source.contains("func _build_surf_fishing_lower_layer_frames(")
		and appearance_source.contains("SURF_FISH_SIDE_LOWER_SHIFT := 12")
		and combined_top_frames != null
		and combined_bottom_frames != null,
		"combined Surf fishing removes riding arms below the fishing upper body"
	)
	_check(
		custom_bottom_frames != null
		and custom_shoes_frames != null
		and appearance_source.contains("func _get_shifted_surf_riding_pixel("),
		"cosmetics without activity sheets fall back to aligned riding lower layers"
	)
	_check(
		remote_player_source.contains(
			"normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH"
		)
		and player_source.contains(
			'get_tree().call_group("world", "_publish_world_presence", true)'
		),
		"combined Surf pose is published and rendered for remote avatars"
	)
	_check(
		controller_source.contains('button.add_theme_constant_override("icon_max_width", 32)')
		and not controller_source.contains("button.icon_max_width ="),
		"rod buttons size icons through the supported Button theme constant"
	)
	_check(
		controller_source.contains("popup.z_index = POPUP_Z_INDEX")
		and controller_source.contains("popup.move_to_front()"),
		"fishing selector renders above the action bars"
	)
	_check(
		controller_source.contains('action_slot.add_theme_stylebox_override("panel", style)')
		and controller_source.contains('popup.add_theme_stylebox_override("panel", _make_popup_style())'),
		"fishing action and selector use dedicated styled surfaces"
	)
	_check(
		controller_source.contains("experience_bar = ProgressBar.new()")
		and controller_source.contains("func _apply_rod_button_style("),
		"fishing selector presents styled XP and rod states"
	)
	_check(
		world_source.contains("await _refresh_fishing_progression()")
		and world_source.contains('reward.get("fishingProgression", {})')
		and world_source.contains('"Fishing Level increased to %d!"'),
		"world refreshes regional progression and reports Fishing XP levels"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _frame_atlas_path(frames: SpriteFrames) -> String:
	if frames == null or not frames.has_animation("idle_down"):
		return ""
	var texture := frames.get_frame_texture("idle_down", 0) as AtlasTexture
	if texture == null or texture.atlas == null:
		return ""
	return texture.atlas.resource_path
