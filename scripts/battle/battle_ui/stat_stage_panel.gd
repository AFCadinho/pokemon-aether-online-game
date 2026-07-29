extends PanelContainer

class_name StatStagePanel

const BOOST_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const STAT_ORDER: Array[String] = ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]
const BADGE_LINE_STAGE := "stage"
const BADGE_LINE_MODIFIER := "modifier"

@onready var stat_stage_row: HBoxContainer = $MarginContainer/VBoxContainer/StatStageRow
@onready var ability_modifier_row: HBoxContainer = $MarginContainer/VBoxContainer/AbilityModifierRow
@onready var badge_template: PanelContainer = $MarginContainer/VBoxContainer/StatStageRow/StatStageBadgeTemplate

var current_stages: Dictionary = {}
var localization_manager: Node

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_template.visible = false
	clear()


func set_stat_stages(stages: Dictionary) -> void:
	current_stages = stages.duplicate(true)
	var badges: Array[Dictionary] = []
	var visible_stages: Dictionary = _get_visible_stat_stages(stages)
	for stat_key in STAT_ORDER:
		if not visible_stages.has(stat_key):
			continue

		var stage_value: int = int(visible_stages.get(stat_key, 0))
		badges.append({
			"label": _format_stat_stage_name(stat_key),
			"value": _format_stat_stage_value(stage_value),
			"color": BOOST_COLOR if stage_value > 0 else DROP_COLOR,
			"line": BADGE_LINE_STAGE,
		})

	set_badges(badges)


func set_badges(badges: Array) -> void:
	_clear_generated_badges()
	visible = not badges.is_empty()
	if badges.is_empty():
		return

	for badge_value in badges:
		if not (badge_value is Dictionary):
			continue

		_add_badge(badge_value as Dictionary)

	stat_stage_row.visible = _row_has_visible_badges(stat_stage_row)
	ability_modifier_row.visible = _row_has_visible_badges(ability_modifier_row)


func clear() -> void:
	current_stages.clear()
	_clear_generated_badges()
	visible = false


func _add_badge(badge_data: Dictionary) -> void:
	var badge := badge_template.duplicate() as PanelContainer
	badge.visible = true
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_badge_row(str(badge_data.get("line", BADGE_LINE_STAGE))).add_child(badge)

	var stat_label := badge.get_node_or_null("MarginContainer/HBoxContainer/StatLabel") as Label
	var value_label := badge.get_node_or_null("MarginContainer/HBoxContainer/ValueLabel") as Label
	if stat_label != null:
		stat_label.text = str(badge_data.get("label", ""))
	if value_label != null:
		var value_text := str(badge_data.get("value", ""))
		value_label.text = value_text
		value_label.visible = value_text != ""

	var color: Color = badge_data.get("color", BOOST_COLOR) as Color
	_apply_badge_text_color(badge, color)


func _apply_badge_text_color(node: Node, color: Color) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_color_override("font_color", color)

	for child in node.get_children():
		_apply_badge_text_color(child, color)


func _clear_generated_badges() -> void:
	_clear_generated_badges_from_row(stat_stage_row)
	_clear_generated_badges_from_row(ability_modifier_row)
	stat_stage_row.visible = false
	ability_modifier_row.visible = false

func _clear_generated_badges_from_row(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child == badge_template:
			continue
		row.remove_child(child)
		child.queue_free()

func _get_badge_row(line: String) -> HBoxContainer:
	if line == BADGE_LINE_MODIFIER:
		return ability_modifier_row

	return stat_stage_row

func _row_has_visible_badges(row: HBoxContainer) -> bool:
	for child in row.get_children():
		if child == badge_template:
			continue
		if child is CanvasItem and (child as CanvasItem).visible:
			return true

	return false


func _get_visible_stat_stages(stages: Dictionary) -> Dictionary:
	var visible_stages: Dictionary = {}
	for stat_key in STAT_ORDER:
		var value: int = int(stages.get(stat_key, 0))
		if value != 0:
			visible_stages[stat_key] = value

	return visible_stages


func _format_stat_stage_name(stat_key: String) -> String:
	match stat_key:
		"atk":
			return _t("battle.stat.short.attack")
		"def":
			return _t("battle.stat.short.defense")
		"spa":
			return _t("battle.stat.short.special_attack")
		"spd":
			return _t("battle.stat.short.special_defense")
		"spe":
			return _t("battle.stat.short.speed")
		"accuracy":
			return _t("battle.stat.short.accuracy")
		"evasion":
			return _t("battle.stat.short.evasion")

	return stat_key.capitalize()


func _format_stat_stage_value(stage_value: int) -> String:
	if stage_value > 0:
		return "+%s" % stage_value

	return str(stage_value)


func _on_locale_changed(_locale: String) -> void:
	if not current_stages.is_empty():
		set_stat_stages(current_stages)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
