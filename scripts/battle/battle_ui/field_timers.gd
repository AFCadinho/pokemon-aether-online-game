extends PanelContainer

class_name FieldTimersPanel

@onready var condition_icon: TextureRect = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionIcon
@onready var condition_label: Label = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionLabel
@onready var effects_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var row_template: HBoxContainer = $MarginContainer/VBoxContainer/FieldConditionRow

const FIELD_ICON_ROOT := "res://assets/battles/field"
const ANIMATED_ICON_ROOT := "res://assets/battles/field/animated"
const ANIMATED_ICON_FRAME_SIZE := Vector2i(40, 24)
const ANIMATED_ICON_FPS := 6.0
const EFFECT_ICON_ALIASES := {
	"RainDance": "rain",
	"PrimordialSea": "rain",
	"SunnyDay": "sun",
	"HarshSun": "sun",
	"DesolateLand": "sun",
	"DeltaStream": "snow",
	"Hail": "snow",
}

var effect_timer_cache: Dictionary = {}
var animated_icon_rows: Array[Dictionary] = []

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if animated_icon_rows.is_empty():
		set_process(false)
		return

	var frame_duration: float = 1.0 / ANIMATED_ICON_FPS
	var active_rows: Array[Dictionary] = []
	for row_data in animated_icon_rows:
		var icon_node: TextureRect = row_data.get("icon_node") as TextureRect
		var atlas_texture: AtlasTexture = row_data.get("texture") as AtlasTexture
		if icon_node == null or not is_instance_valid(icon_node) or atlas_texture == null:
			continue

		var frame_count: int = int(row_data.get("frame_count", 1))
		if frame_count <= 1:
			active_rows.append(row_data)
			continue

		var elapsed: float = float(row_data.get("elapsed", 0.0)) + delta
		var frame_index: int = int(row_data.get("frame_index", 0))
		while elapsed >= frame_duration:
			elapsed -= frame_duration
			frame_index = (frame_index + 1) % frame_count

		row_data["elapsed"] = elapsed
		row_data["frame_index"] = frame_index
		atlas_texture.region = Rect2(
			Vector2(frame_index * ANIMATED_ICON_FRAME_SIZE.x, 0),
			Vector2(ANIMATED_ICON_FRAME_SIZE)
		)
		active_rows.append(row_data)

	animated_icon_rows = active_rows
	if animated_icon_rows.is_empty():
		set_process(false)

func reset_timers() -> void:
	visible = false
	effect_timer_cache.clear()
	_clear_effect_rows()
	
func set_condition(text: String, icon: Texture2D = null) -> void:
	_clear_effect_rows()
	if text != "":
		_add_effect_row(text, icon)

	visible = text != ""

func set_effects(effects: Array, current_turn := 0) -> void:
	_clear_effect_rows()
	if effects.is_empty():
		reset_timers()
		return

	var has_effects := false
	var active_effect_keys: Dictionary = {}

	for effect_data in effects:
		if not (effect_data is Dictionary):
			continue

		var effect_dict: Dictionary = effect_data as Dictionary
		if not _should_show_field_timer_effect(effect_dict):
			continue

		var effect_key: String = _get_effect_timer_base_key(effect_dict)
		if effect_key != "":
			active_effect_keys[effect_key] = true

		var label := _format_effect_label(effect_dict, current_turn)
		if label == "":
			continue

		_add_effect_row(label, _load_effect_icon(effect_dict))
		has_effects = true

	_prune_timer_cache(active_effect_keys)
	visible = has_effects

func _should_show_field_timer_effect(effect_data: Dictionary) -> bool:
	var effect_type: String = str(effect_data.get("effectType", ""))
	if effect_type == "sideCondition":
		return false

	var scope: String = str(effect_data.get("scope", ""))
	if scope == "side":
		return false

	return true

func _clear_effect_rows() -> void:
	animated_icon_rows.clear()
	set_process(false)

	for row in effects_container.get_children():
		if row == row_template:
			continue

		effects_container.remove_child(row)
		row.queue_free()

	condition_icon.texture = null
	condition_icon.visible = false
	condition_label.text = ""
	condition_label.tooltip_text = ""
	row_template.visible = false

func _add_effect_row(text: String, icon: Variant = null) -> void:
	var row: HBoxContainer = row_template.duplicate() as HBoxContainer
	effects_container.add_child(row)
	row.visible = true

	var icon_node: TextureRect = row.get_node("ConditionIcon")
	_apply_effect_icon(icon_node, icon)

	var label_node: Label = row.get_node("ConditionLabel")
	label_node.text = text
	label_node.tooltip_text = text

func _apply_effect_icon(icon_node: TextureRect, icon: Variant) -> void:
	if icon is Dictionary:
		var icon_data: Dictionary = icon as Dictionary
		var icon_texture: Texture2D = icon_data.get("texture") as Texture2D
		icon_node.texture = icon_texture
		icon_node.visible = icon_texture != null
		if icon_texture != null:
			icon_node.custom_minimum_size = Vector2(ANIMATED_ICON_FRAME_SIZE)
		if bool(icon_data.get("animated", false)):
			icon_data["icon_node"] = icon_node
			animated_icon_rows.append(icon_data)
			set_process(true)
		return

	var static_texture: Texture2D = icon as Texture2D
	icon_node.texture = static_texture
	icon_node.visible = static_texture != null

func _format_effect_label(effect_data: Dictionary, current_turn: int) -> String:
	var effect: String = _format_effect_name(_get_field_effect_identifier(effect_data))
	if effect == "":
		return ""

	var min_remaining := _get_remaining_turns(effect_data, current_turn, "minRemainingTurns", "minDuration")
	var max_remaining := _get_remaining_turns(effect_data, current_turn, "maxRemainingTurns", "maxDuration")
	if min_remaining > 0 and max_remaining > 0:
		if min_remaining == max_remaining:
			return "%s: %s" % [effect, min_remaining]
		return "%s: %s-%s" % [effect, min_remaining, max_remaining]

	return effect

func _get_remaining_turns(effect_data: Dictionary, current_turn: int, remaining_key: String, duration_key: String) -> int:
	var remaining: int = int(effect_data.get(remaining_key, 0))
	if remaining > 0:
		return remaining

	var started_turn: int = int(effect_data.get("startedTurn", 0))
	var duration: int = int(effect_data.get(duration_key, 0))
	if duration > 0 and current_turn > 0:
		var duration_cache_entry: Dictionary = _get_or_create_timer_cache_entry(effect_data, current_turn, remaining_key, duration_key)
		var cached_started_turn: int = int(duration_cache_entry.get("started_turn", current_turn))
		var effective_started_turn: int = max(started_turn, 1) if started_turn > 0 else max(cached_started_turn, 1)
		var elapsed: int = max(current_turn - effective_started_turn, 0)
		return max(duration - elapsed, 0)

	return 0

func _get_or_create_timer_cache_entry(effect_data: Dictionary, current_turn: int, remaining_key: String, duration_key: String) -> Dictionary:
	var cache_key: String = "%s|%s|%s" % [_get_effect_timer_base_key(effect_data), remaining_key, duration_key]
	var cached_value: Variant = effect_timer_cache.get(cache_key, {})
	if cached_value is Dictionary:
		var cached_entry: Dictionary = cached_value as Dictionary
		if not cached_entry.is_empty():
			return cached_entry

	var started_turn: int = int(effect_data.get("startedTurn", 0))
	var remaining: int = int(effect_data.get(remaining_key, 0))
	var first_turn: int = max(current_turn, 1)
	var cached_started_turn: int = first_turn if started_turn <= 0 else max(started_turn, 1)
	var cache_entry: Dictionary = {
		"first_turn": first_turn,
		"started_turn": cached_started_turn,
		"initial_remaining": remaining,
	}
	effect_timer_cache[cache_key] = cache_entry
	return cache_entry

func _prune_timer_cache(active_effect_keys: Dictionary) -> void:
	for cache_key in effect_timer_cache.keys():
		var cache_key_string: String = str(cache_key)
		var base_key: String = cache_key_string.split("|")[0]
		if not active_effect_keys.has(base_key):
			effect_timer_cache.erase(cache_key)

func _get_effect_timer_base_key(effect_data: Dictionary) -> String:
	return "%s:%s:%s:%s" % [
		str(effect_data.get("scope", "")),
		str(effect_data.get("side", "")),
		str(effect_data.get("effectType", "")),
		_get_field_effect_identifier(effect_data),
	]

func _format_effect_name(effect: String) -> String:
	var cleaned: String = _strip_effect_prefix(effect)
	var effect_key: String = _normalize_effect_key(cleaned)

	match effect_key:
		"raindance", "rain":
			return "Rain"
		"primordialsea":
			return "Primordial Sea"
		"sunnyday", "sun":
			return "Sun"
		"desolateland":
			return "Desolate Land"
		"deltastream":
			return "Delta Stream"
		"sandstorm":
			return "Sandstorm"
		"hail":
			return "Hail"
		"snow":
			return "Snow"
		"snowscape":
			return "Snowscape"
		"trickroom":
			return "Trick Room"
		"magicroom":
			return "Magic Room"
		"wonderroom":
			return "Wonder Room"

	cleaned = cleaned.replace("Dance", " Dance")
	cleaned = cleaned.replace("Room", " Room")
	cleaned = cleaned.replace("Terrain", " Terrain")
	cleaned = cleaned.replace("Rock", " Rock")
	cleaned = cleaned.replace("Web", " Web")
	cleaned = cleaned.replace("Spikes", " Spikes")

	return cleaned.strip_edges()

func _load_effect_icon(effect_data: Dictionary) -> Variant:
	var animated_icon: Variant = _load_animated_effect_icon(effect_data)
	if animated_icon is Dictionary:
		return animated_icon

	var icon_path := _get_effect_icon_path(effect_data)
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null

	return load(icon_path)

func _load_animated_effect_icon(effect_data: Dictionary) -> Variant:
	var icon_path: String = _get_animated_effect_icon_path(effect_data)
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null

	var source_texture: Texture2D = load(icon_path) as Texture2D
	if source_texture == null:
		return null

	var frame_count: int = max(int(source_texture.get_width() / ANIMATED_ICON_FRAME_SIZE.x), 1)
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = source_texture
	atlas_texture.region = Rect2(Vector2.ZERO, Vector2(ANIMATED_ICON_FRAME_SIZE))

	return {
		"texture": atlas_texture,
		"animated": frame_count > 1,
		"frame_count": frame_count,
		"frame_index": 0,
		"elapsed": 0.0,
	}

func _get_effect_icon_path(effect_data: Dictionary) -> String:
	var effect: String = _get_field_effect_identifier(effect_data)
	var folder: String = _get_effect_icon_folder(effect_data)
	var file_stem: String = _get_effect_icon_file_stem(effect)
	if folder == "" or file_stem == "":
		return ""

	return "%s/%s/%s.png" % [FIELD_ICON_ROOT, folder, file_stem]

func _get_animated_effect_icon_path(effect_data: Dictionary) -> String:
	var effect_key: String = _normalize_effect_key(_get_field_effect_identifier(effect_data))
	var file_name := ""
	match effect_key:
		"raindance", "rain", "primordialsea":
			file_name = "weatherrain.png"
		"sunnyday", "sun", "desolateland":
			file_name = "weathersun.png"
		"deltastream":
			file_name = "weathersnow.png"
		"sandstorm":
			file_name = "weathersand.png"
		"hail":
			file_name = "weatherhail.png"
		"snow", "snowscape":
			file_name = "weathersnow.png"
		"trickroom":
			file_name = "trickroom.png"
		"magicroom":
			file_name = "magicroom.png"
		"wonderroom":
			file_name = "wonderroom.png"

	if file_name == "":
		return ""

	return "%s/%s" % [ANIMATED_ICON_ROOT, file_name]

func _get_effect_icon_folder(effect_data: Dictionary) -> String:
	var effect_type: String = str(effect_data.get("effectType", ""))
	var effect_group: String = str(effect_data.get("effectGroup", ""))
	var effect_key: String = _normalize_effect_icon_key(_get_field_effect_identifier(effect_data))

	if effect_type == "weather":
		return "weather"

	if effect_group == "terrain" or effect_key.ends_with("Terrain"):
		return "terrain"

	return "conditions"

func _get_effect_icon_file_stem(effect: String) -> String:
	var effect_key: String = _normalize_effect_icon_key(effect)
	if EFFECT_ICON_ALIASES.has(effect_key):
		return str(EFFECT_ICON_ALIASES[effect_key])

	return _to_kebab_case(effect_key)

func _normalize_effect_icon_key(effect: String) -> String:
	var cleaned: String = _strip_effect_prefix(effect)
	return cleaned.replace(" ", "")

func _get_field_effect_identifier(effect_data: Dictionary) -> String:
	var effect_id: String = str(effect_data.get("effectId", "")).strip_edges()
	if effect_id != "":
		return effect_id

	return str(effect_data.get("effect", "")).strip_edges()

func _strip_effect_prefix(effect: String) -> String:
	var cleaned: String = effect.strip_edges()
	var separator_index: int = cleaned.find(":")
	if separator_index >= 0:
		cleaned = cleaned.substr(separator_index + 1).strip_edges()

	return cleaned

func _normalize_effect_key(effect: String) -> String:
	return _strip_effect_prefix(effect).to_lower().replace(" ", "").replace("_", "").replace("-", "")

func _to_kebab_case(value: String) -> String:
	var result := ""

	for index in range(value.length()):
		var character := value.substr(index, 1)
		if character == " " or character == "_" or character == "-":
			if result != "" and not result.ends_with("-"):
				result += "-"
			continue

		var lower_character := character.to_lower()
		var is_uppercase := character == character.to_upper() and character != lower_character
		if is_uppercase and result != "" and not result.ends_with("-"):
			result += "-"

		result += lower_character

	if result.ends_with("-"):
		result = result.substr(0, result.length() - 1)

	return result.strip_edges()
