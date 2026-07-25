extends RefCounted

class_name TypeColors

const TYPE_SLOT_COLORS_PATH := "res://data/type_slot_colors.json"

static var _slot_colors := {}
	
static func _ensure_loaded() -> void:
	if not _slot_colors.is_empty():
		return
	
	if not FileAccess.file_exists(TYPE_SLOT_COLORS_PATH):
		return
		
	var file := FileAccess.open(TYPE_SLOT_COLORS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
		
	_slot_colors = parsed

static func get_slot_color(type_name: String, fallback := Color("#2b2b2b")) -> Color:
	return get_slot_background(type_name, fallback)


static func get_slot_background(type_name: String, fallback := Color("#2b2b2b")) -> Color:
	_ensure_loaded()
	
	var key := type_name.to_lower()
	var colors = _slot_colors.get(key, {})
	if typeof(colors) != TYPE_DICTIONARY:
		return fallback
		
	return Color(str(colors.get("background", fallback.to_html(false))))
	
static func get_slot_border(type_name: String, fallback := Color("#555555")) -> Color:
	_ensure_loaded()
	
	var key := type_name.to_lower()
	var colors = _slot_colors.get(key, {})
	if typeof(colors) != TYPE_DICTIONARY:
		return fallback
		
	return Color(str(colors.get("border", fallback.to_html(false))))

static func get_slot_accent(type_name: String, fallback := Color("#d8dee9")) -> Color:
	_ensure_loaded()

	var key := type_name.to_lower()
	var colors = _slot_colors.get(key, {})
	if typeof(colors) != TYPE_DICTIONARY:
		return fallback

	return Color(str(colors.get("accent", fallback.to_html(false))))
