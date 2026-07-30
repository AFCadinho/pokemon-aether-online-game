extends SceneTree

const PHOTO_SCENE_PATH := "res://scenes/interface/content_creator_photo_mode.tscn"
const PHOTO_SCRIPT_PATH := "res://scripts/ui/content_creator_photo_mode.gd"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const REQUIRED_LOCALIZATION_KEYS := [
	"ui.navigation.alpha_tools",
	"ui.navigation.content_creator",
	"ui.staff.creator.title",
	"ui.staff.creator.subtitle",
	"ui.staff.creator.photo_mode",
	"ui.staff.creator.photo_mode_description",
	"ui.creator.photo.title",
	"ui.creator.photo.help",
	"ui.creator.photo.section.camera",
	"ui.creator.photo.section.scene",
	"ui.creator.photo.section.capture",
	"ui.creator.photo.hide_hud",
	"ui.creator.photo.hide_controls",
	"ui.creator.photo.zoom",
	"ui.creator.photo.direction",
	"ui.creator.photo.direction.current",
	"ui.creator.photo.direction.down",
	"ui.creator.photo.direction.left",
	"ui.creator.photo.direction.right",
	"ui.creator.photo.direction.up",
	"ui.creator.photo.lighting",
	"ui.creator.photo.exposure",
	"ui.creator.photo.weather_effects",
	"ui.creator.photo.other_players",
	"ui.creator.photo.nameplates",
	"ui.creator.photo.composition_grid",
	"ui.creator.photo.timer",
	"ui.creator.photo.timer.off",
	"ui.creator.photo.timer.seconds",
	"ui.creator.photo.lighting.current",
	"ui.creator.photo.lighting.dawn",
	"ui.creator.photo.lighting.day",
	"ui.creator.photo.lighting.golden_hour",
	"ui.creator.photo.lighting.night",
	"ui.creator.photo.reset",
	"ui.creator.photo.capture",
	"ui.creator.photo.open_folder",
	"ui.creator.photo.hidden_hint",
	"ui.creator.photo.status_ready",
	"ui.creator.photo.status_saved",
	"ui.creator.photo.status_failed",
	"ui.creator.photo.folder_failed",
	"ui.creator.photo.tooltip.drag_panel",
	"ui.creator.photo.tooltip.zoom",
	"ui.creator.photo.tooltip.direction",
	"ui.creator.photo.tooltip.reset",
	"ui.creator.photo.tooltip.lighting",
	"ui.creator.photo.tooltip.exposure",
	"ui.creator.photo.tooltip.weather",
	"ui.creator.photo.tooltip.other_players",
	"ui.creator.photo.tooltip.nameplates",
	"ui.creator.photo.tooltip.hud",
	"ui.creator.photo.tooltip.controls",
	"ui.creator.photo.tooltip.grid",
	"ui.creator.photo.tooltip.timer",
	"ui.creator.photo.tooltip.capture",
	"ui.creator.photo.tooltip.folder",
]

var failures := 0


func _init() -> void:
	_check_sources()
	_check_localization()
	_check_scene()
	if failures == 0:
		print("Content creator photo mode checks passed.")
	quit(failures)


func _check_sources() -> void:
	var photo_source := FileAccess.get_file_as_string(PHOTO_SCRIPT_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_SCENE_PATH)
	var world_script_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var remote_player_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var overlay_scene_source := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	_check(photo_source.contains("GameState.lock_overworld_input()"), "Photo mode locks player movement")
	_check(photo_source.contains("GameState.unlock_overworld_input()"), "Photo mode restores player movement")
	_check(photo_source.contains("save_png(screenshot_path)"), "Photo mode saves PNG screenshots")
	_check(photo_source.contains("OS.shell_open(absolute_directory)"), "Photo mode can open the screenshot directory")
	_check(photo_source.contains('{"filename": screenshot_path.get_file()}'), "Saved status shows a concise filename")
	_check(photo_source.contains("set_creator_lighting_override"), "Photo mode applies local creator lighting")
	_check(photo_source.contains("clear_creator_lighting_override"), "Photo mode restores world lighting")
	_check(photo_source.contains("set_creator_weather_effects_visible"), "Photo mode can hide local weather effects")
	_check(photo_source.contains("clear_creator_weather_effects_override"), "Photo mode restores normal weather behavior")
	_check(photo_source.contains('SCREENSHOT_DIRECTORY := "user://screenshots"'), "Screenshots use a dedicated user directory")
	_check(photo_source.contains("_on_drag_handle_gui_input"), "Photo mode controls can be dragged by their header")
	_check(photo_source.contains("_clamp_controls_panel_to_viewport"), "Dragged photo controls remain inside the viewport")
	_check(
		photo_source.contains("controls_panel.size = controls_panel.get_combined_minimum_size()"),
		"Photo controls explicitly fit their runtime content size"
	)
	_check(photo_source.contains("camera.position -= mouse_motion.relative"), "Photo mode supports mouse camera panning")
	_check(photo_source.contains("MOUSE_BUTTON_WHEEL_UP"), "Photo mode supports mouse wheel zoom")
	_check(photo_source.contains("composition_grid.visible = false"), "Composition guides are excluded from screenshots")
	_check(photo_source.contains("CAPTURE_TIMER_SECONDS"), "Photo mode supports delayed captures")
	_check(photo_source.contains("_face_player_direction"), "Photo mode can pose the local player direction")
	_check(photo_source.contains("ui.creator.photo.tooltip.drag_panel"), "Photo mode exposes localized hover help")
	_check(photo_source.contains("_apply_dropdown_style"), "Photo mode styles its dropdown controls")
	_check(photo_source.contains("select.get_popup()"), "Photo mode styles opened dropdown menus")
	_check(photo_source.contains("photo_mode_dropdown_arrow.svg"), "Photo mode uses a custom dropdown arrow")
	_check(world_script_source.contains("set_creator_remote_players_visible"), "Photo mode can temporarily hide remote players")
	_check(world_script_source.contains("clear_creator_remote_players_visibility_override"), "Remote player visibility is restored")
	_check(world_script_source.contains("set_creator_nameplates_visible"), "Photo mode can temporarily hide nameplates")
	_check(player_source.contains("clear_creator_nameplate_visibility_override"), "Local nameplate visibility is restored")
	_check(remote_player_source.contains("creator_nameplate_visibility_override_active"), "Remote nameplates honor creator overrides")
	_check(world_source.contains("content_creator_photo_mode.tscn"), "World owns the photo mode layer")
	_check(overlay_source.contains("content_creator_photo_mode_button"), "Creator menu exposes Photo Mode")
	_check(overlay_source.contains("content_creator_tools_popup"), "Content Creator Tools owns a separate popup")
	_check(overlay_source.contains("alpha_tools_popup"), "Alpha Tools keeps its separate popup")
	_check(overlay_scene_source.contains('[node name="ContentCreatorToolsSlot"'), "Content Creator Tools has its own action slot")
	_check(overlay_scene_source.contains('[node name="AlphaToolsSlot"'), "Alpha Tools has its own action slot")
	_check(overlay_scene_source.contains("assets/ui/content_creator.svg"), "Content Creator Tools uses its own icon")
	_check(
		overlay_source.contains("content_creator_tools_slot.visible = can_show_staff_action_bar and can_use_content_creator_tools"),
		"Content Creator Tools visibility uses the creator-tools permission"
	)
	_check(
		overlay_source.contains("alpha_tools_slot.visible = can_show_staff_action_bar and can_use_content_creator_generation"),
		"Alpha Tools visibility stays tied to Alpha generation permission"
	)
	_check(overlay_source.contains('if not _can_use_content_creator_tools():'), "Photo Mode remains permission gated")
	_check(overlay_source.contains('"open_photo_mode"'), "Creator menu launches Photo Mode")


func _check_localization() -> void:
	for locale: String in ["en", "nl", "pt_BR"]:
		var path := "res://localization/%s.json" % locale
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s localization is valid JSON" % locale)
		if not parsed is Dictionary:
			continue
		var catalog := parsed as Dictionary
		for key: String in REQUIRED_LOCALIZATION_KEYS:
			_check(catalog.has(key), "%s contains %s" % [locale, key])


func _check_scene() -> void:
	var scene_source := FileAccess.get_file_as_string(PHOTO_SCENE_PATH)
	_check(scene_source.contains('[node name="ContentCreatorPhotoMode" type="CanvasLayer"]'), "Photo Mode uses an independent canvas layer")
	_check(scene_source.contains("layer = 900"), "Photo Mode renders above the regular HUD")
	_check(scene_source.contains('[node name="ControlsPanel" type="PanelContainer"'), "Photo controls are present")
	_check(
		scene_source.contains("offset_right = 22.0\n")
		and scene_source.contains("offset_bottom = 12.0\n"),
		"Photo controls use their content minimum size instead of a fixed panel height"
	)
	_check(scene_source.contains('[node name="HeaderRow" type="HBoxContainer"'), "Photo controls expose a drag handle")
	_check(scene_source.contains('[node name="CompositionGrid" type="Control"'), "Rule-of-thirds guides are present")
	_check(scene_source.contains('[node name="CountdownLabel" type="Label"'), "Capture countdown is present")
	_check(scene_source.contains('[node name="ZoomSlider" type="HSlider"'), "Zoom control is present")
	_check(scene_source.contains('[node name="DirectionSelect" type="OptionButton"'), "Subject direction control is present")
	_check(scene_source.contains('[node name="LightingPresetSelect" type="OptionButton"'), "Lighting presets are present")
	_check(scene_source.contains('[node name="ExposureSlider" type="HSlider"'), "Brightness control is present")
	_check(scene_source.contains('[node name="WeatherEffectsToggle" type="CheckButton"'), "Weather effects toggle is present")
	_check(scene_source.contains('[node name="OtherPlayersToggle" type="CheckButton"'), "Other-player cleanup control is present")
	_check(scene_source.contains('[node name="NameplatesToggle" type="CheckButton"'), "Nameplate cleanup control is present")
	_check(scene_source.contains('[node name="TimerSelect" type="OptionButton"'), "Capture timer control is present")
	_check(scene_source.contains('[node name="CaptureButton" type="Button"'), "Capture control is present")
	_check(scene_source.contains('[node name="OpenFolderButton" type="Button"'), "Screenshot folder control is present")


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
