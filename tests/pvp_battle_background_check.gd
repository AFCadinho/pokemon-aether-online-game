extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const WEATHER_SCRIPT_PATH := "res://scripts/battle/battle_weather_presentation.gd"
const PLATFORM_SCRIPT_PATH := "res://scripts/battle/battle_ui/battle_platform.gd"
const PLATFORM_SCENE_PATH := "res://scenes/battle/battle_platform.tscn"
const PVP_BACKGROUND_PATH := "res://assets/video/battle/pvp_stadium.ogv"
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
	_check_true(stadium_profile.platform_texture != grass_profile.platform_texture, "stadium profile owns a dedicated platform")
	_check_true(
		Catalog.get_profile(&"missing").environment_id == Catalog.DEFAULT_ENVIRONMENT_ID,
		"unknown environments fall back to the grass profile"
	)


func _check_video_asset() -> void:
	_check_true(FileAccess.file_exists(PVP_BACKGROUND_PATH), "optimized PvP stadium video exists")
	var video_file := FileAccess.open(PVP_BACKGROUND_PATH, FileAccess.READ)
	_check_true(video_file != null, "PvP stadium video is readable")
	if video_file != null:
		_check_true(
			video_file.get_length() <= MAX_BACKGROUND_FILE_SIZE_BYTES,
			"PvP stadium video stays below the 2 MiB asset budget"
		)
	var stream := load(PVP_BACKGROUND_PATH)
	_check_true(stream is VideoStreamTheora, "PvP stadium imports as native Ogg Theora video")


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
	_check_true(battle_source.contains("battle_background.texture = profile.background_texture"), "environment application updates the background")
	_check_true(battle_source.contains('call("set_platform_texture", profile.platform_texture)'), "environment application updates both platforms")
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
	player.stream = Catalog.get_profile(&"pvp_stadium").background_video
	root.add_child(player)
	player.play()
	await create_timer(0.25).timeout
	_check_true(player.is_playing(), "Godot starts decoding the PvP stadium video")
	_check_true(player.stream_position > 0.0, "PvP stadium playback advances")
	player.stop()
	_check_true(not player.is_playing(), "PvP stadium decoding stops cleanly")
	player.free()


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
