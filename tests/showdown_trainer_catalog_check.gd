extends SceneTree

const CATALOG_PATH := "res://data/npc_portraits/showdown_trainer_catalog.json"
const ASSET_ROOT := "res://assets/sprites/trainer_cards/showdown/"

var failed := false


func _init() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check_true(file != null, "Showdown trainer catalog is readable")
	if file == null:
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check_true(parsed is Dictionary, "Showdown trainer catalog is valid JSON")
	if not (parsed is Dictionary):
		quit(1)
		return

	var entries: Variant = (parsed as Dictionary).get("entries", [])
	_check_true(entries is Array, "Showdown trainer catalog has an entries array")
	if not (entries is Array):
		quit(1)
		return

	_check_true((entries as Array).size() >= 800, "Showdown catalog contains the complete credited collection")
	var ids := {}
	for entry_value: Variant in entries as Array:
		_check_true(entry_value is Dictionary, "Every catalog entry is an object")
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		var entry_id := str(entry.get("id", "")).strip_edges()
		var filename := str(entry.get("filename", "")).strip_edges()
		var artist := str(entry.get("artist", "")).strip_edges()
		var source := str(entry.get("source", "")).strip_edges()
		_check_true(not entry_id.is_empty(), "Every catalog entry has an id")
		_check_true(not ids.has(entry_id), "Catalog IDs are unique: %s" % entry_id)
		ids[entry_id] = true
		_check_true(not filename.is_empty(), "Catalog entry has a filename: %s" % entry_id)
		_check_true(not artist.is_empty(), "Catalog entry has an artist: %s" % entry_id)
		_check_true(source.begins_with("https://play.pokemonshowdown.com/sprites/trainers/"), "Catalog entry has a Showdown source: %s" % entry_id)
		_check_true(FileAccess.file_exists(ASSET_ROOT + filename), "Catalog asset exists: %s" % filename)

	quit(1 if failed else 0)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
