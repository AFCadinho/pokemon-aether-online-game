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
	var request_dialog := overlay_instance.get("global_heal_request_dialog") as ConfirmationDialog
	var disable_checkbox := overlay_instance.get("global_heal_request_disable_checkbox") as CheckBox
	_check(request_dialog != null, "Global Heal creates its request dialog at runtime")
	_check(
		disable_checkbox != null
			and disable_checkbox.get_parent() == request_dialog
			and is_equal_approx(disable_checkbox.anchor_bottom, 1.0),
		"the request opt-out is anchored above the dialog buttons"
	)
	_check(
		request_dialog.get_ok_button().focus_mode == Control.FOCUS_ALL
			and request_dialog.get_cancel_button().focus_mode == Control.FOCUS_ALL,
		"the request dialog enables keyboard and controller focus"
	)
	request_dialog.popup_centered(Vector2i(520, 250))
	await process_frame
	await process_frame
	_check(
		disable_checkbox.visible
			and disable_checkbox.get_global_rect().end.y
				<= request_dialog.get_ok_button().get_global_rect().position.y,
		"the request opt-out stays visible above the confirmation buttons"
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
