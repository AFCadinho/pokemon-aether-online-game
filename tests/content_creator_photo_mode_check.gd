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
	"ui.creator.photo.lighting",
	"ui.creator.photo.exposure",
	"ui.creator.photo.weather_effects",
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
	_check(scene_source.contains('[node name="ZoomSlider" type="HSlider"'), "Zoom control is present")
	_check(scene_source.contains('[node name="LightingPresetSelect" type="OptionButton"'), "Lighting presets are present")
	_check(scene_source.contains('[node name="ExposureSlider" type="HSlider"'), "Brightness control is present")
	_check(scene_source.contains('[node name="WeatherEffectsToggle" type="CheckButton"'), "Weather effects toggle is present")
	_check(scene_source.contains('[node name="CaptureButton" type="Button"'), "Capture control is present")
	_check(scene_source.contains('[node name="OpenFolderButton" type="Button"'), "Screenshot folder control is present")


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
