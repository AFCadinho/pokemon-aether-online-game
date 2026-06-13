extends Node

const DEFAULT_OVERWORLD_MUSIC_PATH := "res://assets/audio/music/overworld/overworld_theme.ogg"
const DEFAULT_BATTLE_MUSIC_ID := "default"
const BATTLE_MUSIC_TRACKS := {
	"default": {
		"label": "Default Battle Theme",
		"path": "res://assets/audio/music/battle/battle_theme.ogg",
	},
}
const FADE_SECONDS := 0.35

var music_player: AudioStreamPlayer
var current_track_path := ""
var current_map_music_path := DEFAULT_OVERWORLD_MUSIC_PATH
var current_tween: Tween


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = SettingsManager.MUSIC_BUS
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)


func play_overworld_music() -> void:
	play_music(current_map_music_path)


func play_map_music(map_node: Node) -> void:
	var track_path: String = get_map_music_path(map_node)
	current_map_music_path = track_path
	play_music(current_map_music_path)


func play_battle_music() -> void:
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

	if not ResourceLoader.exists(track_path):
		push_warning("Music track does not exist: %s" % track_path)
		return

	var stream: AudioStream = load(track_path) as AudioStream
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
