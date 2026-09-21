extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const WEATHER_SCRIPT_PATH := "res://scripts/battle/battle_weather_presentation.gd"
const PLATFORM_SCRIPT_PATH := "res://scripts/battle/battle_ui/battle_platform.gd"
const PLATFORM_SCENE_PATH := "res://scenes/battle/battle_platform.tscn"
const PVP_BACKGROUND_PATH := "res://assets/video/battle/pvp_stadium.ogv"
const PVP_RENDERED_BACKGROUND_PATH := "res://assets/video/battle/pvp_stadium_rendered.ogv"
const PVP_RENDERED_FALLBACK_PATH := "res://assets/background/battle/pvp_stadium_rendered_fallback.jpg"
const PVP_PLATFORM_PATH := "res://assets/background/platform/pvp_stadium_platform.png"
const Catalog := preload("res://scripts/battle/battle_environment_catalog.gd")
const MAX_BACKGROUND_FILE_SIZE_BYTES := 2 * 1024 * 1024

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_check_environment_profiles()
	_check_video_asset()
	_check_platform_asset()
	_check_scene_layer()
	_check_environment_application_contract()
	_check_weather_modulation()
	await _check_video_playback()
	quit(1 if failed else 0)


func _check_environment_profiles() -> void:
	var grass_profile := Catalog.get_profile(&"grass")
	var stadium_profile := Catalog.get_profile(&"pvp-stadium")
	_check_true(grass_profile != null and grass_profile.is_valid(), "grass environment profile is valid")
	_check_true(stadium_profile != null and stadium_profile.is_valid(), "PvP stadium environment profile is valid")
	_check_true(grass_profile.background_video == null, "grass profile keeps a static background")
	_check_true(stadium_profile.background_video is VideoStreamTheora, "stadium profile owns the Theora background")
	_check_true(stadium_profile.rendered_arena_background_video is VideoStreamTheora, "stadium profile offers a fixed-camera rendered loop")
	_check_true(stadium_profile.platform_texture != grass_profile.platform_texture, "stadium profile owns a dedicated platform")
	var original := stadium_profile.resolve_background("original_2d")
	var rendered := stadium_profile.resolve_background("rendered_arena")
	var automatic := stadium_profile.resolve_background("automatic")
	var grass_fallback := grass_profile.resolve_background("rendered_arena")
	_check_true(original.video == stadium_profile.background_video, "original background choice preserves the existing stadium loop")
	_check_true(rendered.video == stadium_profile.rendered_arena_background_video, "rendered background choice selects the fixed-camera arena loop")
	_check_true(automatic.video == stadium_profile.rendered_arena_background_video, "automatic background choice selects an available rendered loop")
	_check_true(rendered.platform_texture == stadium_profile.platform_texture, "rendered loop reuses the readable 2D battle platforms")
	_check_true(grass_fallback.resolved_style == "original_2d", "arenas without a rendered loop fall back to original 2D")
	_check_true(grass_fallback.texture == grass_profile.background_texture, "rendered fallback keeps the original arena art")
	_check_true(
		Catalog.get_profile(&"missing").environment_id == Catalog.DEFAULT_ENVIRONMENT_ID,
		"unknown environments fall back to the grass profile"
	)


func _check_video_asset() -> void:
	_check_true(FileAccess.file_exists(PVP_BACKGROUND_PATH), "optimized PvP stadium video exists")
	_check_true(FileAccess.file_exists(PVP_RENDERED_BACKGROUND_PATH), "fixed-camera PvP stadium video exists")
	_check_true(FileAccess.file_exists(PVP_RENDERED_FALLBACK_PATH), "fixed-camera PvP stadium fallback image exists")
	for asset_path: String in [PVP_BACKGROUND_PATH, PVP_RENDERED_BACKGROUND_PATH]:
		var video_file := FileAccess.open(asset_path, FileAccess.READ)
		_check_true(video_file != null, "%s is readable" % asset_path.get_file())
		if video_file != null:
			_check_true(
				video_file.get_length() <= MAX_BACKGROUND_FILE_SIZE_BYTES,
				"%s stays below the 2 MiB browser asset budget" % asset_path.get_file()
			)
		_check_true(load(asset_path) is VideoStreamTheora, "%s imports as native Ogg Theora video" % asset_path.get_file())
	_check_true(load(PVP_RENDERED_FALLBACK_PATH) is Texture2D, "fixed-camera fallback imports as a texture")


func _check_platform_asset() -> void:
	var texture := load(PVP_PLATFORM_PATH) as Texture2D
	_check_true(texture != null, "PvP stadium platform imports as a texture")
	if texture != null:
		_check_true(texture.get_width() == 1536 and texture.get_height() == 1024, "stadium platform matches the existing platform canvas")
		var image := texture.get_image()
		_check_true(image.detect_alpha() != Image.ALPHA_NONE, "stadium platform preserves transparent surroundings")
	var platform_source := FileAccess.get_file_as_string(PLATFORM_SCRIPT_PATH)
	_check_true(platform_source.contains("func set_platform_texture(texture: Texture2D)"), "battle platforms accept environment textures at runtime")
	var platform := (load(PLATFORM_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(platform)
	platform.call("set_platform_texture", texture)
	_check_true(platform.call("get_platform_texture") == texture, "battle platform applies the selected environment texture")
	platform.free()


func _check_scene_layer() -> void:
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var video_start := scene_source.find('[node name="BattleBackgroundVideo"')
	_check_true(video_start >= 0, "battle stage contains a reusable video layer")
	if video_start < 0:
		return
	var video_end := scene_source.find("\n\n", video_start)
	var video_block := scene_source.substr(video_start, video_end - video_start)
	_check_true(video_block.contains("visible = false"), "video layer starts hidden behind the static fallback")
	_check_true(video_block.contains("expand = true"), "video layer follows the fixed battle-stage bounds")
	_check_true(video_block.contains("mouse_filter = 2"), "video layer does not intercept battle focus clicks")
	_check_true(not video_block.contains("stream ="), "environment profile supplies the video instead of the shared scene")
	_check_true(
		scene_source.find('[node name="BattleBackground"') < scene_source.find('[node name="BattleBackgroundVideo"')
		and scene_source.find('[node name="BattleBackgroundVideo"') < scene_source.find('[node name="WeatherTint"'),
		"environment video renders above its fallback and below weather effects"
	)


func _check_environment_application_contract() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_true(
		battle_source.contains("environment_id: StringName = BATTLE_ENVIRONMENT_CATALOG.PVP_STADIUM_ENVIRONMENT_ID"),
		"PvP setup defaults to the stadium environment profile"
	)
	_check_true(battle_source.contains("func _apply_battle_environment(environment_id: StringName)"), "battle setup applies one environment profile centrally")
	_check_true(
		battle_source.contains("profile.resolve_background(SettingsManager.battle_background_style)"),
		"environment application resolves the player's background choice"
	)
	_check_true(battle_source.contains('background.get("texture")'), "environment application updates the chosen background")
	_check_true(battle_source.contains('background.get("platform_texture")'), "environment application updates both platforms")
	_check_true(battle_source.contains("battle_background_video.stop()"), "environment switches stop the previous video decoder")
	_check_true(battle_source.contains("func _on_battle_background_video_finished()"), "animated environments expose an explicit loop callback")


func _check_weather_modulation() -> void:
	var weather_source := FileAccess.get_file_as_string(WEATHER_SCRIPT_PATH)
	_check_true(
		weather_source.contains("alternate_battle_background = alternate_battle_background_node"),
		"weather presenter registers the optional video background"
	)
	_check_true(
		weather_source.contains("alternate_battle_background.modulate = color"),
		"weather modulation reaches animated environment backgrounds"
	)


func _check_video_playback() -> void:
	var player := VideoStreamPlayer.new()
	root.add_child(player)
	var profile := Catalog.get_profile(&"pvp_stadium")
	for style: String in ["original_2d", "rendered_arena"]:
		player.stream = profile.resolve_background(style).video
		player.play()
		await create_timer(0.25).timeout
		_check_true(player.is_playing(), "Godot starts decoding the %s PvP stadium video" % style)
		_check_true(player.stream_position > 0.0, "%s PvP stadium playback advances" % style)
		player.stop()
		_check_true(not player.is_playing(), "%s PvP stadium decoding stops cleanly" % style)
	player.free()


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
