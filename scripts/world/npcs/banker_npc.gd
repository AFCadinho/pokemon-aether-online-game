@tool
extends DialogueNPC

class_name BankerNPC

var bank_marker: PanelContainer


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	bank_marker = PanelContainer.new()
	bank_marker.name = "BankMarker"
	bank_marker.position = Vector2(-17, -120)
	bank_marker.custom_minimum_size = Vector2(34, 24)
	bank_marker.z_index = 513
	bank_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#54c98b")
	style.border_color = Color("#d9ffe9")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	bank_marker.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "₽"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#0a2824"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bank_marker.add_child(label)
	add_child(bank_marker)


func interact_with_player(_player: Node2D) -> void:
	await _load_npc_metadata()
	var ui_overlay := (
		get_tree().current_scene.get_node_or_null("UIOverlay")
		if get_tree().current_scene != null
		else null
	)
	if ui_overlay != null and ui_overlay.has_method("open_bank"):
		ui_overlay.call("open_bank")
		return
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	var message := (
		str(localization_manager.call("text", "ui.bank.error.unavailable"))
		if localization_manager != null
		else "Banking is unavailable right now."
	)
	await show_dialogue([message])
