extends RefCounted

class_name ItemIconResolver

const ICON_ROOT := "res://assets/items/icons/"
const MOVE_TYPE_INDEX_PATH := "res://data/move_type_index.json"
const CharacterAppearanceServiceScript := preload("res://scripts/services/character_appearance_service.gd")
const MountServiceScript := preload("res://scripts/services/mount_service.gd")

static var _move_type_index: Dictionary = {}
static var _move_type_index_loaded := false


static func load_icon(
	item_id: String,
	machine_kind: String = "",
	machine_move_type: String = "",
	cosmetic_gender: String = "male"
) -> Texture2D:
	var canonical_id := _canonical_item_id(item_id)
	if canonical_id == "escape-rope-action":
		canonical_id = "escape-rope"
	if canonical_id.is_empty():
		return _load_texture(ICON_ROOT + "000.png")

	var cosmetic_icon := CharacterAppearanceServiceScript.get_cosmetic_item_icon(
		canonical_id,
		cosmetic_gender
	)
	if cosmetic_icon != null:
		return cosmetic_icon

	var mount_id := MountServiceScript.get_mount_id_for_unlock_item(canonical_id)
	if not mount_id.is_empty():
		var mount_icon := MountServiceScript.get_mount_icon_texture(mount_id)
		if mount_icon != null:
			return mount_icon

	var normalized_stem := canonical_id.to_upper().replace("-", "").replace("_", "").replace(" ", "")
	var candidates: Array[String] = [
		ICON_ROOT + "field_move_charms/" + normalized_stem + ".png",
	]
	if normalized_stem == "POKEDEX":
		candidates.append("res://assets/ui/pokedex.svg")
	var machine_path := _machine_icon_path(canonical_id, machine_kind, machine_move_type)
	if not machine_path.is_empty():
		candidates.append(machine_path)
	candidates.append_array([
		ICON_ROOT + normalized_stem + ".png",
		ICON_ROOT + canonical_id + ".png",
		ICON_ROOT + "000.png",
	])
	for path: String in candidates:
		var texture := _load_texture(path)
		if texture != null:
			return texture
	return null


static func _machine_icon_path(item_id: String, machine_kind: String, machine_move_type: String) -> String:
	var resolved_kind := machine_kind.strip_edges().to_lower()
	var resolved_type := machine_move_type.strip_edges().to_upper()
	if resolved_kind.is_empty():
		if item_id.begins_with("tm-"):
			resolved_kind = "tm"
		elif item_id.begins_with("hm-"):
			resolved_kind = "hm"
	if resolved_type.is_empty() and resolved_kind in ["tm", "hm"]:
		var move_id := item_id.trim_prefix("%s-" % resolved_kind)
		resolved_type = _move_type(move_id).to_upper()
	if resolved_kind not in ["tm", "hm"] or resolved_type.is_empty():
		return ""
	var prefix := "machine_tr_" if resolved_kind == "hm" else "machine_"
	return ICON_ROOT + prefix + resolved_type + ".png"


static func _move_type(move_id: String) -> String:
	_ensure_move_type_index()
	var normalized_id := move_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	return str(_move_type_index.get(normalized_id, ""))


static func _ensure_move_type_index() -> void:
	if _move_type_index_loaded:
		return
	_move_type_index_loaded = true
	if not FileAccess.file_exists(MOVE_TYPE_INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_TYPE_INDEX_PATH))
	if parsed is Dictionary:
		_move_type_index = parsed as Dictionary


static func _canonical_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-").trim_suffix("-bound")


static func _load_texture(path: String) -> Texture2D:
	return ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null
