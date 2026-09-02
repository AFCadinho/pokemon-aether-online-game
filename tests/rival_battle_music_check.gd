extends SceneTree

const TrainerBattleMusicResolverScript := preload(
	"res://scripts/world/npcs/trainer_battle_music_resolver.gd"
)
const MUSIC_CATALOG_PATH := "res://data/music_catalog.json"
const DESKTOP_DEPLOY_WORKFLOW_PATH := "res://.github/workflows/deploy-desktop-r2.yml"
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
	var music_is_local := FileAccess.file_exists(RIVAL_BATTLE_MUSIC_PATH)
	var workflow_source := FileAccess.get_file_as_string(DESKTOP_DEPLOY_WORKFLOW_PATH)
	var music_pack_version := _workflow_env_value(workflow_source, "MUSIC_ASSET_VERSION")
	var music_pack_size := _workflow_env_value(workflow_source, "MUSIC_ASSET_SIZE")
	var music_pack_sha256 := _workflow_env_value(workflow_source, "MUSIC_ASSET_SHA256")
	var external_music_pack_registered := (
		music_pack_version.begins_with("music-")
		and music_pack_version.length() > "music-".length()
		and music_pack_size.is_valid_int()
		and int(music_pack_size) > 0
		and music_pack_sha256.length() == 64
		and _is_lower_hex(music_pack_sha256)
		and workflow_source.contains(
			'register_external_pack "music" "${MUSIC_ASSET_VERSION}" "${MUSIC_ASSET_SIZE}" "${MUSIC_ASSET_SHA256}"'
		)
	)
	_check(
		music_is_local or external_music_pack_registered,
		"Rival battle OGG is available locally or through the published music pack"
	)
	if music_is_local:
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
	var blue_track_id: String = TrainerBattleMusicResolverScript.resolve_track_id({
		"id": "test-gary",
		"trainer_class": "blue",
	})
	_check(
		blue_track_id == RIVAL_BATTLE_MUSIC_ID,
		"Blue/Gary Trainers select the dedicated Rival battle track"
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


func _workflow_env_value(workflow_source: String, variable_name: String) -> String:
	var prefix := "%s:" % variable_name
	for line: String in workflow_source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with(prefix):
			return stripped.trim_prefix(prefix).strip_edges()
	return ""


func _is_lower_hex(value: String) -> bool:
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
