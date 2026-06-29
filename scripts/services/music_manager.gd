extends Node

const DEFAULT_OVERWORLD_MUSIC_PATH := "res://assets/music/overworld/kanto/routes/route1.ogg"
const LOGIN_MUSIC_PATH := "res://assets/music/login/lugia_theme_lofi.ogg"
const DEFAULT_WILD_BATTLE_MUSIC_PATH := "res://assets/music/battle/wild/Kanto Wild Battle.ogg"
const DEFAULT_TRAINER_BATTLE_MUSIC_PATH := "res://assets/music/battle/trainer/Kalos Trainer Battle.ogg"
const DEFAULT_PVP_BATTLE_MUSIC_PATH := "res://assets/music/battle/pvp/lysandre_remix_pokemon_legends_z_a_zame.ogg"
const PVP_BATTLE_MUSIC_RES_DIR := "res://assets/music/battle/pvp"
const PVP_BATTLE_MUSIC_RELATIVE_DIR := "battle/pvp"
const MUSIC_RES_ROOT := "res://assets/music"
const MUSIC_RELATIVE_ROOT := "assets/music"
const DEFAULT_BATTLE_MUSIC_ID := "lysandre_remix_pokemon_legends_z_a_zame"
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


func play_pvp_battle_music() -> void:
	play_music(get_battle_music_path(SettingsManager.battle_music_track))


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

	var tracks := _get_pvp_battle_music_tracks()
	var track_data: Dictionary = tracks.get(normalized_track_id, {}) as Dictionary
	if track_data.is_empty():
		track_data = tracks.get(DEFAULT_BATTLE_MUSIC_ID, {}) as Dictionary
	if track_data.is_empty() and not tracks.is_empty():
		var fallback_track_ids := tracks.keys()
		fallback_track_ids.sort()
		track_data = tracks[str(fallback_track_ids[0])] as Dictionary
	if track_data.is_empty():
		return DEFAULT_PVP_BATTLE_MUSIC_PATH

	return str(track_data.get("path", ""))


func get_battle_music_track_ids() -> Array[String]:
	var track_ids: Array[String] = []
	var tracks := _get_pvp_battle_music_tracks()
	for track_id_value: Variant in tracks.keys():
		track_ids.append(str(track_id_value))
	track_ids.sort()

	return track_ids


func get_battle_music_track_label(track_id: String) -> String:
	var track_data: Dictionary = _get_pvp_battle_music_tracks().get(track_id, {}) as Dictionary
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


func _get_pvp_battle_music_tracks() -> Dictionary:
	var tracks := {}
	for directory_path: String in _get_pvp_battle_music_directories():
		for track_path: String in _get_ogg_files_in_directory(directory_path):
			var track_id := _get_music_track_id(track_path)
			if track_id == "" or tracks.has(track_id):
				continue
			tracks[track_id] = {
				"label": _get_music_track_label_from_path(track_path),
				"path": track_path,
			}

	if tracks.is_empty() or not tracks.has(DEFAULT_BATTLE_MUSIC_ID):
		tracks[DEFAULT_BATTLE_MUSIC_ID] = {
			"label": _get_music_track_label_from_path(DEFAULT_PVP_BATTLE_MUSIC_PATH),
			"path": DEFAULT_PVP_BATTLE_MUSIC_PATH,
		}

	return tracks


func _get_pvp_battle_music_directories() -> Array[String]:
	var directories: Array[String] = []
	for root: String in _get_external_music_roots():
		directories.append(root.path_join(PVP_BATTLE_MUSIC_RELATIVE_DIR))
	directories.append(PVP_BATTLE_MUSIC_RES_DIR)
	return directories


func _get_ogg_files_in_directory(directory_path: String) -> Array[String]:
	var file_paths: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return file_paths

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "ogg":
			file_paths.append(directory_path.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	file_paths.sort()
	return file_paths


func _get_music_track_id(track_path: String) -> String:
	return track_path.get_file().get_basename().strip_edges()


func _get_music_track_label_from_path(track_path: String) -> String:
	var label := _get_music_track_id(track_path).replace("_", " ").replace("-", " ").strip_edges()
	if label == "":
		return track_path.get_file().get_basename()
	return label.capitalize()


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
