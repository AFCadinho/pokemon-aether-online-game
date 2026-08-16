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
	dialog.popup_centered()
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
	screen_layer.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
