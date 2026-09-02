extends Node

const CATALOG_PATH := "res://data/npc_portraits/showdown_trainer_catalog.json"
const ASSIGNMENTS_PATH := "res://data/npc_portraits/npc_portrait_assignments.json"

var _is_loaded := false
var _entries_by_id: Dictionary = {}
var _npc_id_assignments: Dictionary = {}
var _definition_id_assignments: Dictionary = {}
var _preserved_npc_ids: Dictionary = {}
var _texture_cache: Dictionary = {}


func resolve_portrait_id(
		explicit_portrait_id: String,
		npc_id: String,
		npc_definition_id: String
) -> String:
	_ensure_loaded()
	var explicit_id := explicit_portrait_id.strip_edges()
	if not explicit_id.is_empty():
		return explicit_id
	var normalized_npc_id := npc_id.strip_edges()
	if _preserved_npc_ids.has(normalized_npc_id):
		return ""
	if _npc_id_assignments.has(normalized_npc_id):
		return str(_npc_id_assignments[normalized_npc_id])
	var normalized_definition_id := npc_definition_id.strip_edges()
	return str(_definition_id_assignments.get(normalized_definition_id, ""))


## Battle art shares the local Showdown files with dialogue portraits, but its
## identity remains separately configurable. An explicit battle choice wins;
## otherwise the established NPC/profile portrait assignment is reused.
func resolve_battle_sprite_id(
		explicit_battle_sprite_id: String,
		portrait_id: String,
		npc_id: String,
		npc_definition_id: String
) -> String:
	_ensure_loaded()
	var explicit_id := explicit_battle_sprite_id.strip_edges()
	if not explicit_id.is_empty():
		return explicit_id if _entries_by_id.has(explicit_id) else ""

	var portrait_candidate := portrait_id.strip_edges()
	if _entries_by_id.has(portrait_candidate):
		return portrait_candidate

	var assigned_id := resolve_portrait_id("", npc_id, npc_definition_id)
	return assigned_id if _entries_by_id.has(assigned_id) else ""


func get_texture(portrait_id: String) -> Texture2D:
	_ensure_loaded()
	var normalized_id := portrait_id.strip_edges()
	if normalized_id.is_empty() or not _entries_by_id.has(normalized_id):
		return null
	if _texture_cache.has(normalized_id):
		return _texture_cache[normalized_id] as Texture2D
	var entry := _entries_by_id[normalized_id] as Dictionary
	var texture_path := str(entry.get("texture", ""))
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Trainer portrait could not be loaded: %s" % texture_path)
		return null
	_texture_cache[normalized_id] = texture
	return texture


func has_portrait(portrait_id: String) -> bool:
	_ensure_loaded()
	return _entries_by_id.has(portrait_id.strip_edges())


func get_entry(portrait_id: String) -> Dictionary:
	_ensure_loaded()
	return (_entries_by_id.get(portrait_id.strip_edges(), {}) as Dictionary).duplicate(true)


func get_assignments() -> Dictionary:
	_ensure_loaded()
	return {
		"npc_ids": _npc_id_assignments.duplicate(true),
		"npc_definition_ids": _definition_id_assignments.duplicate(true),
		"preserve_existing": _preserved_npc_ids.keys(),
	}


func _ensure_loaded() -> void:
	if _is_loaded:
		return
	_is_loaded = true
	var catalog := _read_json_dictionary(CATALOG_PATH)
	for raw_entry in catalog.get("entries", []):
		if raw_entry is not Dictionary:
			continue
		var entry := raw_entry as Dictionary
		var portrait_id := str(entry.get("id", "")).strip_edges()
		if not portrait_id.is_empty():
			_entries_by_id[portrait_id] = entry

	var assignments := _read_json_dictionary(ASSIGNMENTS_PATH)
	_npc_id_assignments = assignments.get("npc_ids", {}) as Dictionary
	_definition_id_assignments = assignments.get("npc_definition_ids", {}) as Dictionary
	for raw_npc_id in assignments.get("preserve_existing", []):
		var preserved_npc_id := str(raw_npc_id).strip_edges()
		if not preserved_npc_id.is_empty():
			_preserved_npc_ids[preserved_npc_id] = true


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Trainer portrait data is missing: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Trainer portrait data could not be opened: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("Trainer portrait data is invalid: %s" % path)
		return {}
	return parsed as Dictionary
