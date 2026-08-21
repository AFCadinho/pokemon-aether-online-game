class_name MegaChampionsCatalog
extends RefCounted

const CATALOG_PATH := "res://data/mega_champions_catalog.generated.json"
const EXPECTED_SCHEMA_VERSION := 1
const EXPECTED_CATALOG_ID := "mega-champions-v1"
const EXPECTED_FORM_COUNT := 49
const EXPECTED_ITEM_COUNT := 45

static var _loaded := false
static var _catalog: Dictionary = {}
static var _entries_by_mega: Dictionary = {}
static var _entries_by_base_item: Dictionary = {}
static var _load_error := ""


static func all_entries() -> Array[Dictionary]:
	if not _ensure_loaded():
		return []
	var entries: Array[Dictionary] = []
	for value: Variant in _catalog.get("forms", []):
		if value is Dictionary:
			entries.append((value as Dictionary).duplicate(true))
	return entries


static func catalog_manifest() -> Dictionary:
	if not _ensure_loaded():
		return {
			"success": false,
			"error": _load_error,
		}
	var item_ids: Dictionary = {}
	var readiness_counts: Dictionary = {}
	for state: Variant in _catalog.get("readinessStates", []):
		readiness_counts[str(state)] = 0
	var calculator_pending_count := 0
	var calculator_supported_count := 0
	for entry: Dictionary in all_entries():
		var activation: Dictionary = entry.get("activation", {})
		item_ids[str(activation.get("showdownItemId", ""))] = true
		var readiness := str(entry.get("readiness", ""))
		readiness_counts[readiness] = int(readiness_counts.get(readiness, 0)) + 1
		var calculator: Dictionary = entry.get("calculator", {})
		if str(calculator.get("supportStatus", "")) == "pending":
			calculator_pending_count += 1
		elif str(calculator.get("supportStatus", "")) == "supported":
			calculator_supported_count += 1
	return {
		"success": true,
		"catalogId": str(_catalog.get("catalogId", "")),
		"schemaVersion": int(_catalog.get("schemaVersion", 0)),
		"catalogRevision": str(_catalog.get("catalogRevision", "")),
		"pokemonShowdownVersion": str(
			(_catalog.get("source", {}) as Dictionary).get("pokemonShowdownVersion", "")
		),
		"formCount": all_entries().size(),
		"activationItemCount": item_ids.size(),
		"calculatorPendingCount": calculator_pending_count,
		"calculatorSupportedCount": calculator_supported_count,
		"readinessCounts": readiness_counts,
		"publicAvailability": "disabled",
	}


static func get_entry_for_mega_species(species: String) -> Dictionary:
	if not _ensure_loaded():
		return {}
	var entry: Variant = _entries_by_mega.get(_normalize_id(species), {})
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}


static func get_entry_for_base_and_item(base_species: String, item: String) -> Dictionary:
	if not _ensure_loaded():
		return {}
	var key := "%s:%s" % [_normalize_id(base_species), _normalize_id(item)]
	var entry: Variant = _entries_by_base_item.get(key, {})
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}


static func is_mega_champions_species(species: String) -> bool:
	return not get_entry_for_mega_species(species).is_empty()


static func _ensure_loaded() -> bool:
	if _loaded:
		return _load_error == ""
	_loaded = true

	if not FileAccess.file_exists(CATALOG_PATH):
		return _fail("MEGA_CATALOG_MISSING")
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return _fail("MEGA_CATALOG_UNREADABLE")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("MEGA_CATALOG_INVALID_JSON")
	_catalog = parsed as Dictionary
	if int(_catalog.get("schemaVersion", 0)) != EXPECTED_SCHEMA_VERSION:
		return _fail("MEGA_CATALOG_SCHEMA_VERSION")
	if str(_catalog.get("catalogId", "")) != EXPECTED_CATALOG_ID:
		return _fail("MEGA_CATALOG_ID")
	var revision := str(_catalog.get("catalogRevision", ""))
	if not revision.begins_with("sha256:") or revision.length() != 71:
		return _fail("MEGA_CATALOG_REVISION")

	var raw_entries: Variant = _catalog.get("forms", [])
	if not raw_entries is Array or (raw_entries as Array).size() != EXPECTED_FORM_COUNT:
		return _fail("MEGA_CATALOG_FORM_COUNT")
	var item_ids: Dictionary = {}
	for value: Variant in raw_entries as Array:
		if not value is Dictionary:
			return _fail("MEGA_CATALOG_ENTRY")
		var entry := value as Dictionary
		if str(entry.get("readiness", "")) != "engine_only":
			return _fail("MEGA_CATALOG_NOT_DORMANT")
		var activation: Dictionary = entry.get("activation", {})
		if str(activation.get("kind", "")) != "mega_stone":
			return _fail("MEGA_CATALOG_ACTIVATION")
		item_ids[str(activation.get("showdownItemId", ""))] = true
		if not _index_entry(entry):
			return false
	if item_ids.size() != EXPECTED_ITEM_COUNT:
		return _fail("MEGA_CATALOG_ITEM_COUNT")
	return true


static func _index_entry(entry: Dictionary) -> bool:
	for value: String in [
		str(entry.get("pokeaetherSpeciesId", "")),
		str(entry.get("showdownSpeciesId", "")),
		str(entry.get("showdownSpeciesName", "")),
	]:
		if not _add_unique(_entries_by_mega, _normalize_id(value), entry):
			return _fail("MEGA_CATALOG_LOOKUP_COLLISION")

	var activation: Dictionary = entry.get("activation", {})
	var item_values: Array[String] = [
		str(activation.get("pokeaetherItemId", "")),
		str(activation.get("showdownItemId", "")),
		str(activation.get("showdownItemName", "")),
	]
	var base_forms: Variant = entry.get("baseForms", [])
	if not base_forms is Array or (base_forms as Array).is_empty():
		return _fail("MEGA_CATALOG_BASE_FORMS")
	for base_value: Variant in base_forms as Array:
		if not base_value is Dictionary:
			return _fail("MEGA_CATALOG_BASE_FORM")
		var base := base_value as Dictionary
		var base_values: Array[String] = [
			str(base.get("pokeaetherSpeciesId", "")),
			str(base.get("showdownSpeciesId", "")),
			str(base.get("showdownSpeciesName", "")),
		]
		for base_id: String in base_values:
			for item_id: String in item_values:
				var key := "%s:%s" % [_normalize_id(base_id), _normalize_id(item_id)]
				if not _add_unique(_entries_by_base_item, key, entry):
					return _fail("MEGA_CATALOG_BASE_ITEM_COLLISION")
	return true


static func _add_unique(index: Dictionary, key: String, entry: Dictionary) -> bool:
	if key == "":
		return false
	var existing: Variant = index.get(key)
	if existing is Dictionary:
		return str((existing as Dictionary).get("catalogEntryId", "")) == str(
			entry.get("catalogEntryId", "")
		)
	index[key] = entry
	return true


static func _normalize_id(value: String) -> String:
	var normalized := ""
	for character: String in value.strip_edges().to_lower():
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			normalized += character
	return normalized


static func _fail(reason: String) -> bool:
	_load_error = reason
	push_error(reason)
	return false
