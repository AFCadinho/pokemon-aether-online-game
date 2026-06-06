extends PanelContainer

class_name FieldTimersPanel

@onready var condition_icon: TextureRect = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionIcon
@onready var condition_label: Label = $MarginContainer/VBoxContainer/FieldConditionRow/ConditionLabel
@onready var effects_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var row_template: HBoxContainer = $MarginContainer/VBoxContainer/FieldConditionRow

const FIELD_ICON_ROOT := "res://assets/battles/field"
const EFFECT_ICON_ALIASES := {
	"RainDance": "rain",
	"SunnyDay": "sun",
	"Hail": "snow",
}

var effect_timer_cache: Dictionary = {}

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

func _add_effect_row(text: String, icon: Texture2D = null) -> void:
	var row: HBoxContainer = row_template.duplicate() as HBoxContainer
	effects_container.add_child(row)
	row.visible = true

	var icon_node: TextureRect = row.get_node("ConditionIcon")
	icon_node.texture = icon
	icon_node.visible = icon != null

	var label_node: Label = row.get_node("ConditionLabel")
	label_node.text = text
	label_node.tooltip_text = text

func _format_effect_label(effect_data: Dictionary, current_turn: int) -> String:
	var effect := _format_effect_name(str(effect_data.get("effect", "")))
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
	var started_turn := int(effect_data.get("startedTurn", 0))
	var duration := int(effect_data.get(duration_key, 0))
	if duration > 0 and current_turn > 0:
		var duration_cache_entry: Dictionary = _get_or_create_timer_cache_entry(effect_data, current_turn, remaining_key, duration_key)
		var cached_started_turn: int = int(duration_cache_entry.get("started_turn", current_turn))
		var effective_started_turn: int = max(started_turn, 1) if started_turn > 0 else max(cached_started_turn, 1)
		var elapsed: int = max(current_turn - effective_started_turn, 0)
		return max(duration - elapsed, 0)

	var remaining := int(effect_data.get(remaining_key, 0))
	if remaining > 0:
		var remaining_cache_entry: Dictionary = _get_or_create_timer_cache_entry(effect_data, current_turn, remaining_key, duration_key)
		var first_turn: int = int(remaining_cache_entry.get("first_turn", current_turn))
		var initial_remaining: int = int(remaining_cache_entry.get("initial_remaining", remaining))
		var elapsed: int = max(current_turn - first_turn, 0)
		return max(initial_remaining - elapsed, 0)

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
		str(effect_data.get("effect", "")),
	]

func _format_effect_name(effect: String) -> String:
	var cleaned := effect
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	match cleaned:
		"RainDance":
			return "Rain"
		"SunnyDay":
			return "Sun"
		"Sandstorm":
			return "Sandstorm"
		"Hail":
			return "Hail"
		"Snow":
			return "Snow"

	cleaned = cleaned.replace("Dance", " Dance")
	cleaned = cleaned.replace("Room", " Room")
	cleaned = cleaned.replace("Terrain", " Terrain")
	cleaned = cleaned.replace("Rock", " Rock")
	cleaned = cleaned.replace("Web", " Web")
	cleaned = cleaned.replace("Spikes", " Spikes")

	return cleaned.strip_edges()

func _load_effect_icon(effect_data: Dictionary) -> Texture2D:
	var icon_path := _get_effect_icon_path(effect_data)
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null

	return load(icon_path)

func _get_effect_icon_path(effect_data: Dictionary) -> String:
	var effect := str(effect_data.get("effect", ""))
	var folder := _get_effect_icon_folder(effect_data)
	var file_stem := _get_effect_icon_file_stem(effect)
	if folder == "" or file_stem == "":
		return ""

	return "%s/%s/%s.png" % [FIELD_ICON_ROOT, folder, file_stem]

func _get_effect_icon_folder(effect_data: Dictionary) -> String:
	var effect_type := str(effect_data.get("effectType", ""))
	var effect_group := str(effect_data.get("effectGroup", ""))
	var effect_key := _normalize_effect_icon_key(str(effect_data.get("effect", "")))

	if effect_type == "weather":
		return "weather"

	if effect_group == "terrain" or effect_key.ends_with("Terrain"):
		return "terrain"

	return "conditions"

func _get_effect_icon_file_stem(effect: String) -> String:
	var effect_key := _normalize_effect_icon_key(effect)
	if EFFECT_ICON_ALIASES.has(effect_key):
		return str(EFFECT_ICON_ALIASES[effect_key])

	return _to_kebab_case(effect_key)

func _normalize_effect_icon_key(effect: String) -> String:
	var cleaned := effect.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.replace(" ", "")

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
