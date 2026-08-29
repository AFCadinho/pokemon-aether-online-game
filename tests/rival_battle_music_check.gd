extends SceneTree

const TrainerBattleMusicResolverScript := preload(
	"res://scripts/world/npcs/trainer_battle_music_resolver.gd"
)
const MUSIC_CATALOG_PATH := "res://data/music_catalog.json"
const RIVAL_BATTLE_MUSIC_ID := "battle.rival.blue_green_remix_zame"
const RIVAL_BATTLE_MUSIC_PATH := "res://assets/music/battle/rival/rival_blue_green_remix_zame.ogg"

var failed := false


func _init() -> void:
	var catalog := JSON.parse_string(FileAccess.get_file_as_string(MUSIC_CATALOG_PATH)) as Dictionary
	var tracks: Dictionary = catalog.get("tracks", {}) as Dictionary
	_check(
		str((tracks.get(RIVAL_BATTLE_MUSIC_ID, {}) as Dictionary).get("path", ""))
		== RIVAL_BATTLE_MUSIC_PATH,
		"Rival battle music is registered in the catalog"
	)
	_check(FileAccess.file_exists(RIVAL_BATTLE_MUSIC_PATH), "Rival battle OGG is included in the project")
	_check(ResourceLoader.exists(RIVAL_BATTLE_MUSIC_PATH), "Godot recognizes the Rival battle OGG resource")
	var stream := load(RIVAL_BATTLE_MUSIC_PATH) as AudioStream
	_check(stream != null and stream.get_length() > 160.0, "Rival battle OGG decodes as a complete audio stream")

	var rival_track_id: String = TrainerBattleMusicResolverScript.resolve_track_id({
		"id": "test-rival",
		"trainer_class": "rival",
	})
	_check(
		rival_track_id == RIVAL_BATTLE_MUSIC_ID,
		"Rival-class Trainers select the dedicated Rival battle track"
	)
	var regular_track_id: String = TrainerBattleMusicResolverScript.resolve_track_id({
		"id": "test-youngster",
		"trainer_class": "youngster",
	})
	_check(
		regular_track_id.is_empty(),
		"Regular Trainers keep the default Trainer battle track"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
