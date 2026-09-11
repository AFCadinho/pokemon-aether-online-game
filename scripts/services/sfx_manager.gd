extends Node

const PokemonCryResolver := preload("res://scripts/services/pokemon_cry_resolver.gd")
const WebAudioBridge := preload("res://scripts/services/web_audio_bridge.gd")
const DEFAULT_BUS := SettingsManager.SFX_BUS
const POKEMON_CRY_VOLUME_DB := -7.0
const FIELD_MOVE_SOUND_IDS := {
	"cut": "field_move_cut",
	"rock-smash": "field_move_rock_smash",
	"rain-dance": "field_move_rain_dance",
	"snowscape": "field_move_snowscape",
	"sunny-day": "field_move_sunny_day",
}
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
	"npc_shop_purchase": {
		"path": "res://assets/audio/sfx/overworld/npc_shop_purchase.ogg",
		"volume_db": 0.0,
	},
	"pokemon_recovery": {
		"path": "res://assets/audio/sfx/overworld/pokemon_recovery.ogg",
		"volume_db": 0.0,
	},
	"pokemon_item_heal": {
		"path": "res://assets/audio/sfx/overworld/pokemon_item_heal.ogg",
		"volume_db": 0.0,
	},
	"pokemon_level_up": {
		"path": "res://assets/audio/sfx/overworld/pokemon_level_up.ogg",
		"volume_db": 0.0,
	},
	"global_buff_activated": {
		"path": "res://assets/audio/sfx/battle/capture_success.ogg",
		"volume_db": -9.0,
	},
	"aethernet_teleport": {
		"path": "res://assets/battles/animations/teleport/PRSFX- Teleport.wav",
		"volume_db": -3.0,
	},
	"aether_beacon_attuned": {
		"path": "res://assets/battles/animations/wish/PRSFX- Wish.wav",
		"volume_db": -4.0,
	},
	"field_move_cut": {
		"path": "res://assets/battles/animations/razorleaf/PRSFX- Razor Leaf1.wav",
		"volume_db": -4.0,
	},
	"field_move_rock_smash": {
		"path": "res://assets/battles/animations/rocksmash/PRSFX- Rock Smash.wav",
		"volume_db": -4.0,
	},
	"field_move_rain_dance": {
		"path": "res://assets/battles/animations/weatherball/PRSFX- Weather Ball1.wav",
		"volume_db": -5.0,
	},
	"field_move_snowscape": {
		"path": "res://assets/battles/animations/powdersnow/PRSFX- Powder Snow1.wav",
		"volume_db": -5.0,
	},
	"field_move_sunny_day": {
		"path": "res://assets/battles/animations/charge/PRSFX- Solar Beam1.wav",
		"volume_db": -5.0,
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
	var sound_path := str(sound_data.get("path", "")).strip_edges()
	if OS.has_feature("web"):
		WebAudioBridge.play_sfx(sound_path, _web_sfx_volume(float(sound_data.get("volume_db", 0.0)) + volume_offset_db), pitch_scale)
		return

	var stream := _get_stream(sound_key, sound_data)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsManager.get_audio_output_bus(DEFAULT_BUS)
	player.volume_db = float(sound_data.get("volume_db", 0.0)) + volume_offset_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_field_move(move_id: String) -> void:
	var normalized_move_id := move_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	var sound_id := str(FIELD_MOVE_SOUND_IDS.get(normalized_move_id, ""))
	if sound_id != "":
		play(sound_id)


func play_pokemon_cry(species: String, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var cry_key := _get_pokemon_cry_key(species)
	if cry_key == "":
		return

	var sound_path := "%s/%s.ogg" % [PokemonCryResolver.POKEMON_CRY_DIR, cry_key]
	if not ResourceLoader.exists(sound_path):
		return
	if OS.has_feature("web"):
		WebAudioBridge.play_sfx(sound_path, _web_cry_volume(volume_offset_db), pitch_scale)
		return

	var stream := _get_stream("pokemon_cry:%s" % cry_key, {
		"path": sound_path,
	})
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsManager.get_audio_output_bus(SettingsManager.POKEMON_CRY_BUS)
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


func _web_sfx_volume(volume_db: float) -> float:
	return clampf(
		SettingsManager.master_volume / 100.0 * SettingsManager.sfx_volume / 100.0 * db_to_linear(volume_db),
		0.0,
		1.0
	)


func _web_cry_volume(volume_offset_db: float) -> float:
	return clampf(
		SettingsManager.master_volume / 100.0 * SettingsManager.pokemon_cry_volume / 100.0 * db_to_linear(POKEMON_CRY_VOLUME_DB + volume_offset_db),
		0.0,
		1.0
	)
