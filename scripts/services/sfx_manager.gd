extends Node

const PokemonCryResolver := preload("res://scripts/services/pokemon_cry_resolver.gd")
const DEFAULT_BUS := SettingsManager.SFX_BUS
const POKEMON_CRY_VOLUME_DB := -7.0
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
	"ranked_match_found": {
		"path": "res://assets/audio/sfx/ui/ranked_match_found.ogg",
		"volume_db": -2.0,
	},
	"item_found": {
		"path": "res://assets/audio/sfx/overworld/item_found.ogg",
		"volume_db": 0.0,
	},
	"item_received": {
		"path": "res://assets/audio/sfx/overworld/item_received.ogg",
		"volume_db": -3.0,
	},
	"pokemon_recovery": {
		"path": "res://assets/audio/sfx/overworld/pokemon_recovery.ogg",
		"volume_db": 0.0,
	},
	"aethernet_teleport": {
		"path": "res://assets/battles/animations/teleport/PRSFX- Teleport.wav",
		"volume_db": -3.0,
	},
}

var stream_cache: Dictionary = {}
var pokemon_cry_resolver := PokemonCryResolver.new()


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


func play_pokemon_cry(species: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var cry_key := _get_pokemon_cry_key(species)
	if cry_key == "":
		return

	var sound_path := "%s/%s.ogg" % [PokemonCryResolver.POKEMON_CRY_DIR, cry_key]
	if not ResourceLoader.exists(sound_path):
		return

	var stream := _get_stream("pokemon_cry:%s" % cry_key, {
		"path": sound_path,
	})
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsManager.POKEMON_CRY_BUS
	player.volume_db = POKEMON_CRY_VOLUME_DB + volume_offset_db
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


func _get_pokemon_cry_key(species: String) -> String:
	return pokemon_cry_resolver.get_cry_key(species)
