extends SceneTree

const CONTROLLER_PATH := "res://scripts/ui/fishing_action_controller.gd"
const OVERLAY_PATH := "res://scenes/interface/ui_overlay.tscn"
const WORLD_PATH := "res://scripts/world/world.gd"
const PLAYER_PATH := "res://scripts/world/player.gd"
const APPEARANCE_SERVICE_PATH := "res://scripts/services/character_appearance_service.gd"
const REMOTE_PLAYER_PATH := "res://scripts/world/remote_player_avatar.gd"
const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"
const MOUNT_SERVICE_PATH := "res://scripts/services/mount_service.gd"
const CharacterAppearanceServiceScript := preload(
	"res://scripts/services/character_appearance_service.gd"
)
const MountServiceScript := preload("res://scripts/services/mount_service.gd")

var failed := false


func _init() -> void:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var appearance_source := FileAccess.get_file_as_string(APPEARANCE_SERVICE_PATH)
	var remote_player_source := FileAccess.get_file_as_string(REMOTE_PLAYER_PATH)
	var settings_manager_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var settings_menu_source := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)
	var mount_service_source := FileAccess.get_file_as_string(MOUNT_SERVICE_PATH)

	for activity_asset_path: String in [
		"res://assets/player/male/top/fish/Adinho_Shirt_fish.png",
		"res://assets/player/male/top/fish/Adinho_Shirt_Chroma_fish.png",
		"res://assets/player/male/bottom/fish/Adinho_Trousers_fish.png",
		"res://assets/player/male/bottom/fish/Adinho_Trousers_Chroma_fish.png",
		"res://assets/player/male/shoes/fish/Adinho_Shoes_fish.png",
		"res://assets/player/male/shoes/fish/Adinho_Shoes_Chroma_fish.png",
		"res://assets/player/male/top/ride/Adinho_Shirt_ride.png",
		"res://assets/player/male/top/ride/Adinho_Shirt_Chroma_ride.png",
		"res://assets/player/male/bottom/ride/Adinho_Trousers_ride.png",
		"res://assets/player/male/bottom/ride/Adinho_Trousers_Chroma_ride.png",
		"res://assets/player/male/shoes/ride/Adinho_Shoes_ride.png",
		"res://assets/player/male/shoes/ride/Adinho_Shoes_Chroma_ride.png",
	]:
		_check(
			ResourceLoader.exists(activity_asset_path),
			"Adinho activity asset exists: %s" % activity_asset_path.get_file()
		)

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
		settings_manager_source.contains('CONFIGURABLE_INPUT_ACTIONS: Array[String] = [')
		and settings_manager_source.contains('"fish",')
		and settings_manager_source.contains('"mount",')
		and settings_manager_source.contains('"pickpocket",')
		and settings_manager_source.contains('"input_bindings": input_bindings')
		and settings_manager_source.contains("InputMap.action_erase_events(action)")
		and settings_manager_source.contains("func get_input_binding_label(action: String)"),
		"Fishing cast and reel use one persisted configurable Input Map action"
	)
	_check(
		settings_menu_source.contains('"Controls", "ui.settings.tab.controls", "ui.settings.section.controls_subtitle"')
		and settings_menu_source.contains('binding_button.name = "%sBindingButton" % control_name')
		and settings_menu_source.contains("SettingsManager.set_input_binding"),
		"Settings expose a Fishing hotkey capture control"
	)
	_check(
		controller_source.contains("action_slot.visible = GameState.fishing_skill_unlocked"),
		"the fishing action remains hidden until the Guru unlocks the skill"
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
		and controller_source.contains('"ui.fishing.no_rod.stow"')
		and controller_source.contains("ACTIVE_GREEN_BG"),
		"players can deactivate fishing with localized copy and active rods use the green toolbar state"
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
		and not appearance_source.contains("SURF_FISH_BODY_CUTOFFS")
		and not appearance_source.contains("func _build_surf_fishing_body_frames("),
		"Surf fishing avoids fragile per-pixel body composition"
	)
	_check(
		CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "body")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "top")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "bottom")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH
		and CharacterAppearanceServiceScript.resolve_layer_movement_style("surf_fish", "shoes")
			== CharacterAppearanceServiceScript.BODY_MOVEMENT_FISH,
		"Surf fishing resolves every appearance layer to one consistent fishing pose"
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
	var custom_top_frames := CharacterAppearanceServiceScript.get_part_frames(
		"top",
		"Adinho_Shirt",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF_FISH
	)
	var custom_chroma_top_frames := CharacterAppearanceServiceScript.get_part_frames(
		"top",
		"Adinho_Shirt_Chroma",
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
	var custom_surf_top_frames := CharacterAppearanceServiceScript.get_part_frames(
		"top",
		"Adinho_Shirt",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_SURF
	)
	var custom_mount_bottom_frames := CharacterAppearanceServiceScript.get_part_frames(
		"bottom",
		"Adinho_Trousers",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_MOUNT
	)
	var custom_ride_shoes_frames := CharacterAppearanceServiceScript.get_part_frames(
		"shoes",
		"Adinho_Shoes",
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_RIDE
	)
	_check(
		_frame_atlas_path(combined_body_frames).contains("/body/fish/")
		and _frame_atlas_path(combined_top_frames).contains("/top/fish/")
		and _frame_atlas_path(combined_bottom_frames).contains("/bottom/fish/"),
		"Surf fishing loads matching authored fishing textures"
	)
	_check(
		_frame_atlas_path(custom_top_frames).contains("/top/fish/Adinho_Shirt_fish.png")
		and _frame_atlas_path(custom_chroma_top_frames).contains(
			"/top/fish/Adinho_Shirt_Chroma_fish.png"
		)
		and _frame_atlas_path(custom_bottom_frames).contains(
			"/bottom/fish/Adinho_Trousers_fish.png"
		)
		and _frame_atlas_path(custom_shoes_frames).contains(
			"/shoes/fish/Adinho_Shoes_fish.png"
		),
		"Adinho cosmetics keep their authored outfit while fishing"
	)
	_check(
		_frame_atlas_path(custom_surf_top_frames).contains(
			"/top/ride/Adinho_Shirt_ride.png"
		)
		and _frame_atlas_path(custom_mount_bottom_frames).contains(
			"/bottom/ride/Adinho_Trousers_ride.png"
		)
		and _frame_atlas_path(custom_ride_shoes_frames).contains(
			"/shoes/ride/Adinho_Shoes_ride.png"
		),
		"Adinho cosmetics keep their authored outfit while Surfing or mounted"
	)
	_check(
		remote_player_source.contains(
			"normalized_style == CharacterAppearanceService.BODY_MOVEMENT_SURF_FISH"
		)
		and player_source.contains(
			'get_tree().call_group("world", "_publish_world_presence", true)'
		),
		"Surf fishing pose is published and rendered for remote avatars"
	)
	_check(
		player_source.contains('"hair": Vector2(0.0, -10.0)')
		and player_source.contains('"eyes": Vector2(0.0, -10.0)')
		and remote_player_source.contains('"headgear": Vector2(0.0, -10.0)')
		and remote_player_source.contains('"eyebrows": Vector2(0.0, -10.0)'),
		"down-facing fishing aligns static head layers with the raised fishing body"
	)
	_check(
		_function_source(player_source, "_get_surf_fish_rider_offset").contains(
			"BODY_MOVEMENT_SURF_FISH"
		)
		and player_source.contains('"down": Vector2i(0, 18)')
		and player_source.contains('"left": Vector2i(0, 4)')
		and player_source.contains('"right": Vector2i(0, 4)')
		and player_source.contains('"up": Vector2i(0, 10)')
		and _function_source(player_source, "_get_activity_visual_offset").contains(
			"return Vector2.ZERO"
		)
		and player_source.contains("_get_surf_fish_rider_offset_adjustments()")
		and remote_player_source.contains("func _get_surf_fish_rider_offset")
		and remote_player_source.contains("_get_surf_fish_rider_offset_adjustments()")
		and mount_service_source.contains("rider_offset_adjustments: Dictionary = {}")
		and mount_service_source.contains("_get_rider_offset_adjustment"),
		"Surf fishing aligns and masks existing fishing frames to the saddle locally and remotely"
	)
	_check(
		player_source.contains('"left": Vector2(-6.0, 0.0)')
		and player_source.contains('"right": Vector2(6.0, 0.0)')
		and remote_player_source.contains('"left": Vector2(-6.0, 0.0)')
		and remote_player_source.contains('"right": Vector2(6.0, 0.0)'),
		"normal land fishing retains its existing visual offsets"
	)
	var surf_fish_offsets := {
		"down": Vector2i(0, 18),
		"left": Vector2i(0, 4),
		"right": Vector2i(0, 4),
		"up": Vector2i(0, 10),
	}
	var masked_surf_fish_frames := MountServiceScript.get_mounted_rider_frames(
		combined_body_frames,
		"lapras",
		surf_fish_offsets
	)
	var unmasked_surf_fish_image := combined_body_frames.get_frame_texture("idle_left", 0).get_image()
	var masked_surf_fish_image := masked_surf_fish_frames.get_frame_texture("idle_left", 0).get_image()
	_check(
		_opaque_pixel_count(masked_surf_fish_image) < _opaque_pixel_count(unmasked_surf_fish_image),
		"Lapras's existing rider mask hides the lower side-facing Surf-fishing body pixels"
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
		and world_source.contains('"ui.world.reward.fishing_level"'),
		"world refreshes regional progression and reports localized Fishing XP levels"
	)
	_check(
		world_source.contains('if reason == "caught":')
		and world_source.contains('_notify_fishing_treasure_award(reward.get("items", []))')
		and world_source.contains('!= "fishing_treasure"')
		and world_source.contains('SfxManager.play("item_found")'),
		"completed Fishing wins and catches report authoritative treasure rewards"
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


func _opaque_pixel_count(image: Image) -> int:
	if image == null:
		return 0
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.001:
				count += 1
	return count
