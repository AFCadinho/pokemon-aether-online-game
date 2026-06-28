extends Node

const DEFAULT_BUS := SettingsManager.SFX_BUS
const SOUND_DATA := {
	"battle_item_use": {
		"path": "res://assets/audio/sfx/battle/battle_item_use.ogg",
		"volume_db": -4.0,
	},
	"capture_throw": {
		"path": "res://assets/audio/sfx/battle/capture_throw.ogg",
		"volume_db": -2.0,
	},
	"capture_absorb": {
		"path": "res://assets/audio/sfx/battle/capture_absorb.ogg",
		"volume_db": -1.0,
	},
	"capture_shake": {
		"path": "res://assets/audio/sfx/battle/capture_shake.ogg",
		"volume_db": -1.0,
	},
	"capture_break": {
		"path": "res://assets/audio/sfx/battle/capture_break.ogg",
		"volume_db": -2.0,
	},
	"capture_success": {
		"path": "res://assets/audio/sfx/battle/capture_success.ogg",
		"volume_db": -2.0,
	},
	"summon_throw": {
		"path": "res://assets/audio/sfx/battle/capture_throw.ogg",
		"volume_db": -3.0,
	},
	"summon_release": {
		"path": "res://assets/audio/sfx/battle/capture_absorb.ogg",
		"volume_db": -8.0,
	},
}

var stream_cache: Dictionary = {}


func play(sound_id: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sound_key := sound_id.strip_edges()
	if sound_key.is_empty():
		return

	var sound_data: Dictionary = SOUND_DATA.get(sound_key, {}) as Dictionary
	if sound_data.is_empty():
		return

	var stream := _get_stream(sound_key, sound_data)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = DEFAULT_BUS
	player.volume_db = float(sound_data.get("volume_db", 0.0)) + volume_offset_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _get_stream(sound_key: String, sound_data: Dictionary) -> AudioStream:
	if stream_cache.has(sound_key):
		return stream_cache[sound_key] as AudioStream

	var sound_path := str(sound_data.get("path", "")).strip_edges()
	if sound_path.is_empty():
		return null
	if not ResourceLoader.exists(sound_path):
		return null

	var stream := load(sound_path) as AudioStream
	if stream != null:
		stream_cache[sound_key] = stream
	return stream
