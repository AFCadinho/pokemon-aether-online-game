extends SceneTree

const DIALOG_SCENE := "res://scenes/interface/aether_confirmation_dialog.tscn"

var failed := false


func _init() -> void:
	var packed := load(DIALOG_SCENE) as PackedScene
	_check(packed != null, "Aether confirmation dialog scene loads")
	if packed == null:
		quit(1)
		return

	var screen_layer := CanvasLayer.new()
	root.add_child(screen_layer)
	await process_frame
	var dialog := packed.instantiate() as AetherConfirmationDialog
	screen_layer.add_child(dialog)
	dialog.configure("Set Aether Anchor", "Set Pewter City as your Aether Anchor?", "Confirm", "Cancel")
	var stake_input := SpinBox.new()
	stake_input.min_value = 0
	stake_input.max_value = 2147483647
	stake_input.step = 1
	stake_input.custom_arrow_step = 1000
	stake_input.value = 0
	stake_input.update_on_text_changed = true
	dialog.style_spin_box(stake_input)
	dialog.add_custom_control(stake_input)
	dialog.popup_centered()
	dialog.focus_spin_box(stake_input)
	await process_frame
	await process_frame

	_check(dialog.visible, "Aether confirmation dialog opens as a modal overlay")
	_check(
		dialog.size.is_equal_approx(root.get_visible_rect().size),
		"Aether confirmation dialog fills the viewport on its first opening"
	)
	_check(dialog.get_node("Shade").visible, "Aether confirmation dialog dims the world")
	_check(
		(dialog.get_node("Center/Panel/Margin/Content/Header/Title") as Label).text == "Set Aether Anchor",
		"Aether confirmation dialog renders its configured title"
	)
	var confirm_button := dialog.get_node(
		"Center/Panel/Margin/Content/Actions/ConfirmButton"
	) as Button
	var panel := dialog.get_node("Center/Panel") as PanelContainer
	_check(confirm_button.text == "Confirm", "Aether confirmation dialog renders localized actions")
	_check(not dialog.option_checkbox.visible, "optional confirmation setting stays hidden by default")
	dialog.configure_option("Remember this choice")
	_check(
		dialog.option_checkbox.visible
			and dialog.option_checkbox.get_theme_icon("unchecked") is ImageTexture,
		"optional confirmation setting uses the shared styled checkbox"
	)
	_check(
		confirm_button.get_theme_stylebox("normal") is StyleBoxFlat,
		"Aether confirmation primary action replaces default Godot styling"
	)
	_check(
		panel.get_theme_stylebox("panel") is StyleBoxFlat,
		"Aether confirmation panel uses the shared Aethernet surface"
	)
	var panel_center := panel.get_global_rect().get_center()
	var viewport_center := root.get_visible_rect().get_center()
	_check(
		panel_center.is_equal_approx(viewport_center),
		"Aether confirmation panel is centered on its first opening"
	)
	var stake_line_edit := stake_input.get_line_edit()
	_check(stake_input.editable, "Aether numeric inputs are directly editable")
	_check(
		stake_input.step == 1.0 and stake_input.custom_arrow_step == 1000.0,
		"Aether stake input accepts exact amounts while arrows retain thousand-unit jumps"
	)
	_check(
		stake_line_edit.has_focus() and stake_line_edit.get_selected_text() == "0",
		"Aether stake input opens focused with its initial value selected"
	)
	stake_line_edit.text = "100000"
	stake_line_edit.text_changed.emit(stake_line_edit.text)
	await process_frame
	_check(int(stake_input.value) == 100000, "Aether stake input accepts a typed amount immediately")
	screen_layer.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
