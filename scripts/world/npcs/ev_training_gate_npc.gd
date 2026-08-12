@tool
extends DialogueNPC

class_name EvTrainingGateNPC

signal stat_selected(stat: String)

const STATS := [
	{"id": "hp", "label": "HP"},
	{"id": "atk", "label": "Attack"},
	{"id": "def", "label": "Defense"},
	{"id": "spa", "label": "Sp. Attack"},
	{"id": "spd", "label": "Sp. Defense"},
	{"id": "spe", "label": "Speed"},
]

@export var inside_marker_path: NodePath
@export var outside_marker_path: NodePath
@export var inside_direction := Vector2.DOWN

var choice_layer: CanvasLayer
var choice_root: Control


func interact_with_player(player: Node2D) -> void:
	if _is_player_inside(player):
		await _leave_training_area(player)
	else:
		await _enter_training_area(player)


func _enter_training_area(player: Node2D) -> void:
	var status: Dictionary = await EvTrainingService.get_session()
	if not bool(status.get("success", false)):
		await GameErrorDialogService.show_response(status, "EV training is currently unavailable.")
		return
	var session: Dictionary = status.get("session", {})
	if bool(session.get("active", false)):
		var stat_label := _stat_label(str(session.get("stat", "")))
		await show_dialogue([
			"Your %s training session is still active. Head back in whenever you're ready." % stat_label,
		], display_name)
		_teleport_player(player, inside_marker_path, -inside_direction)
		return

	await show_dialogue([
		"This is Viridian City's focused EV training field.",
		"For ₽%d, every wild Pokémon you meet during this visit will train one stat of your choice." % int(session.get("fee", 500)),
		"Your session ends when you leave through either entrance. Which stat do you want to train?",
	], display_name)
	var selected_stat := await _show_stat_prompt(int(session.get("fee", 500)))
	if selected_stat.is_empty():
		return
	var response: Dictionary = await EvTrainingService.start_session(selected_stat)
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "Could not start EV training.")
		return
	await show_dialogue([
		"All set. The field is now prepared for %s training. Good luck!" % _stat_label(selected_stat),
	], display_name)
	_teleport_player(player, inside_marker_path, -inside_direction)


func _leave_training_area(player: Node2D) -> void:
	var response: Dictionary = await EvTrainingService.end_session()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response, "Could not end EV training.")
		return
	await show_dialogue([
		"Training session complete. Come back whenever you want to focus on another stat.",
	], display_name)
	_teleport_player(player, outside_marker_path, inside_direction)


func _is_player_inside(player: Node2D) -> bool:
	return (player.global_position - global_position).dot(inside_direction) > 0.0


func _teleport_player(player: Node2D, marker_path: NodePath, facing: Vector2) -> void:
	var marker := get_node_or_null(marker_path) as Marker2D
	if marker == null:
		push_error("%s is missing teleport marker %s." % [name, marker_path])
		return
	if player.has_method("teleport_within_current_map"):
		player.call("teleport_within_current_map", marker.global_position, facing)
	else:
		player.global_position = marker.global_position


func _show_stat_prompt(fee: int) -> String:
	_ensure_choice_panel(fee)
	choice_root.show()
	return await stat_selected


func _ensure_choice_panel(fee: int) -> void:
	if choice_root != null and is_instance_valid(choice_root):
		return
	choice_layer = CanvasLayer.new()
	choice_layer.name = "EvTrainingChoiceLayer"
	choice_layer.layer = 90
	add_child(choice_layer)
	choice_root = Control.new()
	choice_root.name = "EvTrainingChoiceRoot"
	choice_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_root.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_root.hide()
	choice_layer.add_child(choice_root)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -195.0
	panel.offset_top = -170.0
	panel.offset_right = 195.0
	panel.offset_bottom = 170.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	choice_root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var title := Label.new()
	title.text = "Focused EV Training"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.847, 0.718, 0.404))
	layout.add_child(title)
	var prompt := Label.new()
	prompt.text = "Choose one stat · ₽%d" % fee
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.957, 0.941, 0.871))
	layout.add_child(prompt)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)
	for stat: Dictionary in STATS:
		grid.add_child(_choice_button(str(stat.label), str(stat.id)))
	var cancel := _choice_button(LocalizationManager.text("common.cancel"), "")
	layout.add_child(cancel)


func _choice_button(label: String, stat: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(165, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_select_stat.bind(stat))
	return button


func _select_stat(stat: String) -> void:
	choice_root.hide()
	stat_selected.emit(stat)


func _stat_label(stat: String) -> String:
	for definition: Dictionary in STATS:
		if str(definition.id) == stat:
			return str(definition.label)
	return stat.to_upper()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.043, 0.075, 0.97)
	style.border_color = Color(0.847, 0.718, 0.404)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	return style
