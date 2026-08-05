extends PanelContainer

class_name SideFieldEffectsPanel

@onready var effects_container: VBoxContainer = $MarginContainer/VBoxContainer
@onready var row_template: HBoxContainer = $MarginContainer/VBoxContainer/FieldEffectRow

const EFFECT_ICONS := {
	"stealthrock": "res://assets/battles/effect/stealth_rock.png",
	"spikes": "res://assets/battles/effect/spikes.png",
	"toxicspikes": "res://assets/background/hazards/toxic_spikes.png",
	"stickyweb": "res://assets/background/hazards/sticky_webs.png",
	"stickywebs": "res://assets/background/hazards/sticky_webs.png",
}

const HAZARD_EFFECT_KEYS := {
	"stealthrock": true,
	"spikes": true,
	"toxicspikes": true,
	"stickyweb": true,
	"stickywebs": true,
}

const EFFECT_NAME_ALIASES := {
	"lightscreen": "battle.field.effect.light_screen",
	"reflect": "battle.field.effect.reflect",
	"auroraveil": "battle.field.effect.aurora_veil",
	"tailwind": "battle.field.effect.tailwind",
	"safeguard": "battle.field.effect.safeguard",
	"mist": "battle.field.effect.mist",
	"stealthrock": "battle.field.effect.stealth_rock",
	"spikes": "battle.field.effect.spikes",
	"toxicspikes": "battle.field.effect.toxic_spikes",
	"stickyweb": "battle.field.effect.sticky_web",
	"stickywebs": "battle.field.effect.sticky_web",
}

const EFFECT_SHORT_NAMES := {
	"lightscreen": "battle.field.short.light_screen",
	"reflect": "battle.field.short.reflect",
	"auroraveil": "battle.field.short.aurora_veil",
	"tailwind": "battle.field.short.tailwind",
	"safeguard": "battle.field.short.safeguard",
	"mist": "battle.field.short.mist",
	"stealthrock": "battle.field.short.stealth_rock",
	"spikes": "battle.field.short.spikes",
	"toxicspikes": "battle.field.short.toxic_spikes",
	"stickyweb": "battle.field.short.sticky_web",
	"stickywebs": "battle.field.short.sticky_web",
}
var current_side_effects: Array = []
var current_turn := 0
var localization_manager: Node

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	clear_effects()

func clear_effects(clear_data := true) -> void:
	if clear_data:
		current_side_effects = []
		current_turn = 0
	for row in effects_container.get_children():
		if row == row_template:
			continue

		effects_container.remove_child(row)
		row.queue_free()

	row_template.visible = false
	visible = false

func set_side_effects(side_effects: Array, current_turn: int = 0) -> void:
	current_side_effects = side_effects.duplicate(true)
	self.current_turn = current_turn
	clear_effects(false)

	var has_effects: bool = false
	for effect_value in side_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var effect_key: String = _normalize_effect_key(str(effect_data.get("effect", "")))
		if effect_key == "":
			continue

		_add_effect_row(effect_key, str(effect_data.get("effect", "")), effect_data, current_turn)
		has_effects = true

	visible = has_effects

func _add_effect_row(effect_key: String, raw_effect: String, effect_data: Dictionary, current_turn: int) -> void:
	var row: HBoxContainer = row_template.duplicate() as HBoxContainer
	effects_container.add_child(row)
	row.visible = true

	var icon_node: TextureRect = row.get_node("EffectIcon")
	var icon_path: String = str(EFFECT_ICONS.get(effect_key, ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_node.texture = load(icon_path)
		icon_node.visible = true
	else:
		icon_node.visible = false

	var label_node: Label = row.get_node("EffectLabel")
	var full_effect_name := _format_effect_name(effect_key, raw_effect)
	# Hazards stay visible for long stretches and need to be readable at a
	# glance. Short-lived screens and side effects keep their compact labels.
	var short_name_key := str(EFFECT_SHORT_NAMES.get(effect_key, ""))
	label_node.text = (
		full_effect_name
		if HAZARD_EFFECT_KEYS.has(effect_key)
		else _t(short_name_key) if short_name_key != "" else full_effect_name
	)
	label_node.visible = label_node.text != ""
	row.tooltip_text = full_effect_name
	icon_node.tooltip_text = full_effect_name
	label_node.tooltip_text = full_effect_name

	var amount_node: Label = row.get_node("EffectAmount")
	var amount_text: String = _format_effect_amount(effect_key, effect_data, current_turn)
	amount_node.text = amount_text
	amount_node.visible = amount_text != ""
	amount_node.tooltip_text = full_effect_name

func _format_effect_name(effect_key: String, raw_effect: String) -> String:
	if EFFECT_NAME_ALIASES.has(effect_key):
		return _t(str(EFFECT_NAME_ALIASES[effect_key]))

	var cleaned_effect: String = raw_effect.strip_edges()
	if cleaned_effect.contains(": "):
		cleaned_effect = cleaned_effect.split(": ")[1]
	if cleaned_effect != "":
		return _split_effect_name(cleaned_effect)

	return _split_effect_name(effect_key)

func _format_effect_amount(effect_key: String, effect_data: Dictionary, current_turn: int) -> String:
	for key in ["layers", "layer", "count"]:
		if not effect_data.has(key):
			continue

		var amount: int = int(effect_data.get(key, 0))
		if amount > 1:
			return "×%s" % amount
		if amount == 1 and _is_layered_effect(effect_key):
			return "×1"

	var min_remaining: int = _get_remaining_turns(effect_data, current_turn, "minRemainingTurns", "minDuration")
	var max_remaining: int = _get_remaining_turns(effect_data, current_turn, "maxRemainingTurns", "maxDuration")
	if min_remaining > 0 and max_remaining > 0:
		if min_remaining == max_remaining:
			return str(min_remaining)

		return "%s-%s" % [min_remaining, max_remaining]
	if min_remaining > 0:
		return str(min_remaining)
	if max_remaining > 0:
		return str(max_remaining)

	var remaining: int = _get_remaining_turns(effect_data, current_turn, "remainingTurns", "duration")
	if remaining > 0:
		return str(remaining)

	var turns: int = _get_remaining_turns(effect_data, current_turn, "turns", "duration")
	if turns > 0:
		return str(turns)

	return ""

func _get_remaining_turns(effect_data: Dictionary, current_turn: int, remaining_key: String, duration_key: String) -> int:
	var started_turn: int = int(effect_data.get("startedTurn", 0))
	var duration: int = int(effect_data.get(duration_key, 0))
	if started_turn > 0 and duration > 0 and current_turn > 0:
		var elapsed: int = max(current_turn - started_turn, 0)
		return max(duration - elapsed, 0)

	var remaining: int = int(effect_data.get(remaining_key, 0))
	if remaining > 0:
		return remaining

	return 0

func _normalize_effect_key(effect: String) -> String:
	var cleaned: String = effect.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.to_lower().replace(" ", "").replace("_", "").replace("-", "")

func _is_layered_effect(effect_key: String) -> bool:
	match effect_key:
		"spikes", "toxicspikes":
			return true

	return false

func _split_effect_name(effect_name: String) -> String:
	var cleaned_name: String = effect_name.replace("_", " ").replace("-", " ").strip_edges()
	var result: String = ""
	for index in range(cleaned_name.length()):
		var character: String = cleaned_name.substr(index, 1)
		if index == 0:
			result += character.to_upper()
		elif character == character.to_upper() and character != character.to_lower():
			result += " " + character
		else:
			result += character

	return result.strip_edges()


func _on_locale_changed(_locale: String) -> void:
	if not current_side_effects.is_empty():
		set_side_effects(current_side_effects, current_turn)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
