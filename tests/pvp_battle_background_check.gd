extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const WEATHER_SCRIPT_PATH := "res://scripts/battle/battle_weather_presentation.gd"
const PVP_BACKGROUND_PATH := "res://assets/video/battle/pvp_stadium.ogv"
const MAX_BACKGROUND_FILE_SIZE_BYTES := 2 * 1024 * 1024

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_check_video_asset()
	_check_scene_layer()
	_check_playback_contract()
	_check_weather_modulation()
	await _check_video_playback()
	quit(1 if failed else 0)


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


func _check_scene_layer() -> void:
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var video_start := scene_source.find('[node name="PvpBattleBackground"')
	_check_true(video_start >= 0, "battle stage contains the PvP video layer")
	if video_start < 0:
		return
	var video_end := scene_source.find("\n\n", video_start)
	var video_block := scene_source.substr(video_start, video_end - video_start)
	_check_true(video_block.contains("visible = false"), "PvP video starts hidden behind the static fallback")
	_check_true(video_block.contains("expand = true"), "PvP video follows the fixed battle-stage bounds")
	_check_true(video_block.contains("mouse_filter = 2"), "PvP video does not intercept battle focus clicks")
	_check_true(video_block.contains('stream = ExtResource("2_pvp_video")'), "PvP video layer uses the imported Theora stream")
	_check_true(
		scene_source.find('[node name="BattleBackground"') < scene_source.find('[node name="PvpBattleBackground"')
		and scene_source.find('[node name="PvpBattleBackground"') < scene_source.find('[node name="WeatherTint"'),
		"PvP video renders above the fallback and below weather effects"
	)


func _check_playback_contract() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_true(
		battle_source.contains("_prepare_battle_setup(BattleType.TRAINER, player_pokemon, null, true)"),
		"PvP setup explicitly selects the animated background"
	)
	_check_true(
		battle_source.contains("_set_pvp_battle_background_enabled(is_pvp)"),
		"shared battle setup applies the explicit PvP background selection"
	)
	_check_true(
		battle_source.contains("pvp_battle_background.stop()"),
		"non-PvP setup stops video decoding and restores the fallback"
	)
	_check_true(
		battle_source.contains("func _on_pvp_battle_background_finished()"),
		"PvP background exposes an explicit loop callback"
	)


func _check_weather_modulation() -> void:
	var weather_source := FileAccess.get_file_as_string(WEATHER_SCRIPT_PATH)
	_check_true(
		weather_source.contains("alternate_battle_background = alternate_battle_background_node"),
		"weather presenter registers the PvP video background"
	)
	_check_true(
		weather_source.contains("alternate_battle_background.modulate = color"),
		"weather modulation reaches the PvP video background"
	)


func _check_video_playback() -> void:
	var player := VideoStreamPlayer.new()
	player.stream = load(PVP_BACKGROUND_PATH) as VideoStream
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
