extends PanelContainer

class_name MoveHoverCard

const TYPE_ICON_PATH := "res://assets/sprites/types/%s.png"
const CARD_WIDTH := 300.0
const CATEGORY_ICON_PATHS := {
	"Physical": "res://assets/battles/physical_move.png",
	"Special": "res://assets/battles/special_move.png",
	"Status": "res://assets/battles/status_move.png",
}

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var type_node: Node = $MarginContainer/VBoxContainer/MetaRow/TypeLabel
@onready var category_node: Node = $MarginContainer/VBoxContainer/MetaRow/TypeLabel2
@onready var power_row: HBoxContainer = $MarginContainer/VBoxContainer/BasePowerRow
@onready var power_value_label: Label = $MarginContainer/VBoxContainer/BasePowerRow/PowerValueLabel
@onready var accuracy_value_label: Label = $MarginContainer/VBoxContainer/BasePowerRow2/AccuracyLabel2
@onready var z_effect_row: HBoxContainer = $MarginContainer/VBoxContainer/ZEffectRow
@onready var z_effect_value_label: Label = $MarginContainer/VBoxContainer/ZEffectRow/ZEffectValueLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel

var current_move_data: Dictionary = {}
var localization_manager: Node

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
		if not localization_manager.locale_changed.is_connected(_on_locale_changed):
			localization_manager.locale_changed.connect(_on_locale_changed)
	custom_minimum_size.x = CARD_WIDTH
	size.x = CARD_WIDTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	hide_card()


func show_for_move(move_data: Dictionary) -> void:
	_set_move_data(move_data)
	visible = true


func hide_card() -> void:
	visible = false


func position_near_mouse(mouse_position: Vector2, viewport_size: Vector2) -> void:
	var padding := 12.0
	custom_minimum_size.x = CARD_WIDTH
	var card_size: Vector2 = size
	var target_position := mouse_position + Vector2(padding, padding)

	if target_position.x + card_size.x > viewport_size.x:
		target_position.x = mouse_position.x - card_size.x - padding
	if target_position.y + card_size.y > viewport_size.y:
		target_position.y = mouse_position.y - card_size.y - padding

	global_position = target_position


func position_near_rect(anchor_rect: Rect2, viewport_size: Vector2) -> void:
	var padding := 10.0
	custom_minimum_size.x = CARD_WIDTH
	reset_size()
	var card_size: Vector2 = size
	var target_position := Vector2(anchor_rect.position.x, anchor_rect.position.y - card_size.y - padding)

	if target_position.y < padding:
		target_position.y = anchor_rect.end.y + padding
	if target_position.x + card_size.x > viewport_size.x - padding:
		target_position.x = viewport_size.x - card_size.x - padding
	if target_position.x < padding:
		target_position.x = padding

	global_position = target_position


func _set_move_data(move_data: Dictionary) -> void:
	current_move_data = move_data.duplicate(true)
	name_label.text = str(move_data.get(
		"name",
		move_data.get("move", move_data.get("id", _t("battle.move.unknown"))),
	))
	_set_icon_or_text(type_node, str(move_data.get("type", "")), TYPE_ICON_PATH)
	var category := str(move_data.get("category", ""))
	_set_category_icon_or_text(category)
	power_row.visible = category.to_lower() != "status"
	power_value_label.text = _format_power(move_data.get("basePower", move_data.get("base_power", "")))
	accuracy_value_label.text = _format_accuracy(move_data.get("accuracy", ""))
	var z_effect := str(move_data.get("zEffect", move_data.get("z_effect", ""))).strip_edges()
	z_effect_row.visible = z_effect != ""
	z_effect_value_label.text = z_effect
	_set_description(move_data)


func _set_category_icon_or_text(category: String) -> void:
	var icon_path: String = str(CATEGORY_ICON_PATHS.get(category, ""))
	if icon_path != "":
		_set_texture_or_text(category_node, icon_path, category)
		return

	_set_icon_or_text(category_node, category, "")


func _set_icon_or_text(node: Node, value: String, path_template: String) -> void:
	if value == "":
		_set_node_visible(node, false)
		return

	var icon_path := ""
	if path_template != "":
		icon_path = path_template % value.to_lower()

	_set_texture_or_text(node, icon_path, value)


func _set_texture_or_text(node: Node, texture_path: String, fallback_text: String) -> void:
	if node is TextureRect:
		var texture_rect: TextureRect = node as TextureRect
		var texture: Texture2D = null
		if texture_path != "" and ResourceLoader.exists(texture_path):
			texture = load(texture_path) as Texture2D
		texture_rect.texture = texture
		texture_rect.visible = texture != null
		return

	if node is Label:
		var label: Label = node as Label
		label.text = fallback_text
		label.visible = fallback_text != ""


func _set_node_visible(node: Node, is_visible: bool) -> void:
	if node is CanvasItem:
		var canvas_item: CanvasItem = node as CanvasItem
		canvas_item.visible = is_visible


func _format_power(power_value: Variant) -> String:
	if power_value == null or str(power_value) == "":
		return "--"

	var power: int = int(power_value)
	if power <= 0:
		return "--"

	return str(power)


func _format_accuracy(accuracy_value: Variant) -> String:
	if accuracy_value is bool:
		return _t("battle.move.always_hits") if bool(accuracy_value) else "--"
	if accuracy_value == null or str(accuracy_value) == "":
		return "--"

	return "%d%%" % int(accuracy_value)


func _set_description(move_data: Dictionary) -> void:
	var description: String = str(move_data.get("shortDesc", move_data.get("short_desc", ""))).strip_edges()
	if description == "":
		description = str(move_data.get("desc", "")).strip_edges()

	description_label.visible = description != ""
	description_label.text = description


func _on_locale_changed(_locale: String) -> void:
	if localization_manager != null:
		localization_manager.call("localize_tree", self)
	if not current_move_data.is_empty():
		_set_move_data(current_move_data)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
