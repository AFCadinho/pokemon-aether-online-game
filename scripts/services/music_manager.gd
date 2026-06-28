extends Node

const DEFAULT_OVERWORLD_MUSIC_PATH := "res://assets/music/overworld/kanto/routes/route1.ogg"
const LOGIN_MUSIC_PATH := "res://assets/music/login/lugia_theme_lofi.ogg"
const DEFAULT_WILD_BATTLE_MUSIC_PATH := "res://assets/music/battle/wild/Kanto Wild Battle.ogg"
const DEFAULT_TRAINER_BATTLE_MUSIC_PATH := "res://assets/music/battle/trainer/Kalos Trainer Battle.ogg"
const MUSIC_RES_ROOT := "res://assets/music"
const MUSIC_RELATIVE_ROOT := "assets/music"
const DEFAULT_BATTLE_MUSIC_ID := "default"
const BATTLE_MUSIC_TRACKS := {
	"default": {
		"label": "Default Battle Theme",
		"path": "res://assets/music/overworld/kanto/routes/route1.ogg",
	},
}
const FADE_SECONDS := 0.35

var music_player: AudioStreamPlayer
var current_track_path := ""
var current_map_music_path := DEFAULT_OVERWORLD_MUSIC_PATH
var current_tween: Tween
var external_music_root := ""


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = SettingsManager.MUSIC_BUS
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)


func play_overworld_music() -> void:
	play_music(current_map_music_path)


func play_login_music() -> void:
	play_music(LOGIN_MUSIC_PATH)


func play_map_music(map_node: Node) -> void:
	var track_path: String = get_map_music_path(map_node)
	current_map_music_path = track_path
	play_music(current_map_music_path)


func play_battle_music() -> void:
	play_music(get_battle_music_path(SettingsManager.battle_music_track))

func play_wild_battle_music() -> void:
	play_music(DEFAULT_WILD_BATTLE_MUSIC_PATH)

func play_trainer_battle_music() -> void:
	play_music(DEFAULT_TRAINER_BATTLE_MUSIC_PATH)


func get_map_music_path(map_node: Node) -> String:
	if map_node != null and map_node.has_method("get_music_track_path"):
		var map_track_path: String = str(map_node.call("get_music_track_path")).strip_edges()
		if map_track_path != "":
			return map_track_path

	if map_node != null:
		var map_music_node: Node = map_node.get_node_or_null("MapMusic")
		if map_music_node != null and map_music_node.has_method("get_music_track_path"):
			var component_track_path: String = str(map_music_node.call("get_music_track_path")).strip_edges()
			if component_track_path != "":
				return component_track_path

	return DEFAULT_OVERWORLD_MUSIC_PATH


func get_battle_music_path(track_id: String) -> String:
	var normalized_track_id: String = track_id.strip_edges()
	if normalized_track_id == "":
		normalized_track_id = DEFAULT_BATTLE_MUSIC_ID

	var track_data: Dictionary = BATTLE_MUSIC_TRACKS.get(
		normalized_track_id,
		BATTLE_MUSIC_TRACKS[DEFAULT_BATTLE_MUSIC_ID]
	) as Dictionary
	return str(track_data.get("path", ""))


func get_battle_music_track_ids() -> Array[String]:
	var track_ids: Array[String] = []
	for track_id_value: Variant in BATTLE_MUSIC_TRACKS.keys():
		track_ids.append(str(track_id_value))

	return track_ids


func get_battle_music_track_label(track_id: String) -> String:
	var track_data: Dictionary = BATTLE_MUSIC_TRACKS.get(track_id, {}) as Dictionary
	return str(track_data.get("label", track_id))


func play_music(track_path: String) -> void:
	if current_track_path == track_path and music_player.playing:
		return

	var stream: AudioStream = _load_music_stream(track_path)
	if stream == null:
		push_warning("Could not load music track: %s" % track_path)
		return

	current_track_path = track_path
	_fade_to_stream(stream)


func stop_music() -> void:
	current_track_path = ""
	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.tween_property(music_player, "volume_db", -80.0, FADE_SECONDS)
	current_tween.tween_callback(music_player.stop)


func _fade_to_stream(stream: AudioStream) -> void:
	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	if music_player.playing:
		current_tween.tween_property(music_player, "volume_db", -80.0, FADE_SECONDS)

	current_tween.tween_callback(_start_stream.bind(stream))
	current_tween.tween_property(music_player, "volume_db", 0.0, FADE_SECONDS)


func _start_stream(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.volume_db = -80.0
	music_player.play()


func _on_music_finished() -> void:
	if current_track_path == "":
		return

	music_player.play()


func _load_music_stream(track_path: String) -> AudioStream:
	for candidate_path: String in _build_music_track_paths(track_path):
		var stream: AudioStream = _load_music_stream_from_path(candidate_path)
		if stream != null:
			return stream

	return null


func _build_music_track_paths(track_path: String) -> Array[String]:
	var paths: Array[String] = []
	if track_path.begins_with(MUSIC_RES_ROOT):
		var relative_path: String = track_path.trim_prefix("res://")
		for root: String in _get_external_music_roots():
			paths.append(root.path_join(relative_path.trim_prefix(MUSIC_RELATIVE_ROOT + "/")))

	paths.append(track_path)
	return paths


func _get_external_music_roots() -> Array[String]:
	if not external_music_root.is_empty():
		return [external_music_root]

	var executable_dir := OS.get_executable_path().get_base_dir()
	var candidates: Array[String] = [
		executable_dir.path_join(MUSIC_RELATIVE_ROOT),
		executable_dir.get_base_dir().path_join(MUSIC_RELATIVE_ROOT),
	]
	for candidate: String in candidates:
		if DirAccess.dir_exists_absolute(candidate):
			external_music_root = candidate
			return [external_music_root]

	return []


func _load_music_stream_from_path(path: String) -> AudioStream:
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
		return null

	if not FileAccess.file_exists(path):
		return null

	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		_:
			push_warning("Unsupported external music format: %s" % path)
			return null
