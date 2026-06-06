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

const EFFECT_NAME_ALIASES := {
	"lightscreen": "Light Screen",
	"reflect": "Reflect",
	"auroraveil": "Aurora Veil",
	"tailwind": "Tailwind",
	"safeguard": "Safeguard",
	"mist": "Mist",
	"stealthrock": "Stealth Rock",
	"spikes": "Spikes",
	"toxicspikes": "Toxic Spikes",
	"stickyweb": "Sticky Web",
	"stickywebs": "Sticky Web",
}

func _ready() -> void:
	clear_effects()

func clear_effects() -> void:
	for row in effects_container.get_children():
		if row == row_template:
			continue

		effects_container.remove_child(row)
		row.queue_free()

	row_template.visible = false
	visible = false

func set_side_effects(side_effects: Array, current_turn: int = 0) -> void:
	clear_effects()

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
	label_node.text = _format_effect_name(effect_key, raw_effect)

	var amount_node: Label = row.get_node("EffectAmount")
	var amount_text: String = _format_effect_amount(effect_key, effect_data, current_turn)
	amount_node.text = amount_text
	amount_node.visible = amount_text != ""

func _format_effect_name(effect_key: String, raw_effect: String) -> String:
	if EFFECT_NAME_ALIASES.has(effect_key):
		return str(EFFECT_NAME_ALIASES[effect_key])

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
			return "%sx" % amount
		if amount == 1 and _is_layered_effect(effect_key):
			return "1x"

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
