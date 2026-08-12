extends CanvasLayer

class_name TransitMenu

signal resolved(destination_id: String)

var _resolved := false
var _confirmation: ConfirmationDialog
var _pending_destination_id := ""


func open(network: Dictionary) -> void:
	layer = 120
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 300)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var title := Label.new()
	title.text = LocalizationManager.text("ui.transit.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	var tier := Label.new()
	var wallet := network.get("wallet", {}) as Dictionary
	var discounted := bool(network.get("membershipDiscountActive", false))
	tier.text = LocalizationManager.text(
		"ui.transit.summary",
		{
			"tier": LocalizationManager.text("ui.transit.tier.blessing" if discounted else "ui.transit.tier.standard"),
			"money": int(wallet.get("money", 0)),
		}
	)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(tier)
	var separator := HSeparator.new()
	content.add_child(separator)
	var destination_list := VBoxContainer.new()
	destination_list.add_theme_constant_override("separation", 6)
	content.add_child(destination_list)
	for value: Variant in network.get("destinations", []):
		if not value is Dictionary:
			continue
		var destination := value as Dictionary
		var destination_id := str(destination.get("destinationId", ""))
		var button := Button.new()
		var attuned := bool(destination.get("attuned", false))
		var current := destination_id == str(network.get("sourceMapId", ""))
		button.text = LocalizationManager.text("ui.transit.destination.fare", {
			"name": str(destination.get("name", destination_id)),
			"fare": int(destination.get("fare", 0)),
		})
		button.disabled = not attuned or current
		if not attuned:
			button.text = LocalizationManager.text("ui.transit.destination.unattuned", {"name": str(destination.get("name", destination_id))})
		elif current:
			button.text = LocalizationManager.text("ui.transit.destination.current", {"name": str(destination.get("name", destination_id))})
		button.pressed.connect(_request_confirmation.bind(destination))
		destination_list.add_child(button)
	var close_button := Button.new()
	close_button.text = LocalizationManager.text("ui.transit.close")
	close_button.pressed.connect(_finish.bind(""))
	content.add_child(close_button)

	_confirmation = ConfirmationDialog.new()
	_confirmation.title = LocalizationManager.text("ui.transit.confirm_title")
	_confirmation.confirmed.connect(_confirm_travel)
	add_child(_confirmation)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish("")


func _request_confirmation(destination: Dictionary) -> void:
	_pending_destination_id = str(destination.get("destinationId", ""))
	_confirmation.dialog_text = LocalizationManager.text("ui.transit.confirm", {
		"name": str(destination.get("name", "")),
		"fare": int(destination.get("fare", 0)),
	})
	_confirmation.popup_centered()


func _confirm_travel() -> void:
	_finish(_pending_destination_id)


func _finish(destination_id: String) -> void:
	if _resolved:
		return
	_resolved = true
	resolved.emit(destination_id)
	queue_free()
