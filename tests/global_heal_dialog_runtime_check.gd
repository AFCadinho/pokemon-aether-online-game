extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_script := load(OVERLAY_PATH) as Script
	_check(overlay_script != null, "Global Heal dialog runtime check loads the overlay")
	if overlay_script == null:
		quit(1)
		return

	var overlay_instance: Node = overlay_script.new()
	var dialog_host := Control.new()
	root.add_child(dialog_host)
	overlay_instance.set("root_control", dialog_host)
	overlay_instance.call("_setup_global_heal_request_dialog")
	var request_dialog := overlay_instance.get("global_heal_request_dialog") as AetherConfirmationDialog
	var disable_checkbox := overlay_instance.get("global_heal_request_disable_checkbox") as CheckBox
	_check(request_dialog != null, "Global Heal uses the shared Aether confirmation dialog")
	_check(
		disable_checkbox != null
			and disable_checkbox.get_parent() == request_dialog.get_node("Center/Panel/Margin/Content"),
		"the request opt-out participates in the styled dialog layout"
	)
	request_dialog.configure(
		"Global Heal available",
		"Admin used Global Heal. Fully heal your party?",
		"Heal party",
		"Decline"
	)
	request_dialog.configure_option("Do not show future Global Heal requests")
	_check(
		request_dialog.confirm_button.focus_mode == Control.FOCUS_ALL
			and request_dialog.cancel_button.focus_mode == Control.FOCUS_ALL,
		"the request dialog enables keyboard and controller focus"
	)
	request_dialog.popup_centered(Vector2i(540, 280))
	await process_frame
	await process_frame
	_check(
		disable_checkbox.visible
			and disable_checkbox.get_global_rect().end.y <= request_dialog.confirm_button.get_global_rect().position.y,
		"the request opt-out stays visible above the confirmation buttons"
	)
	_check(
		request_dialog.panel.get_theme_stylebox("panel") is StyleBoxFlat
			and request_dialog.confirm_button.get_theme_stylebox("normal") is StyleBoxFlat
			and disable_checkbox.get_theme_icon("unchecked") is ImageTexture,
		"the request panel, actions, and opt-out replace default Godot styling"
	)

	dialog_host.free()
	overlay_instance.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
