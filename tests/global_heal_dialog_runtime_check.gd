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

	var game_state := root.get_node_or_null("GameState")
	_check(game_state != null, "Global Heal cooldown sync check can access GameState")
	var original_requests_enabled := bool(game_state.get("global_heal_requests_enabled"))
	game_state.set("global_heal_requests_enabled", false)
	overlay_instance.set("global_buffs_data", [{
		"id": "global_heal",
		"state": "available",
		"cost": 25000,
		"cooldownUntil": "",
	}])
	overlay_instance.call("_receive_global_heal_request", {
		"eventId": "event-sync-test",
		"displayName": "Admin",
		"expiresAt": "2099-08-29T22:00:00+00:00",
		"cooldownUntil": "2099-08-29T22:00:00+00:00",
	})
	var synced_buffs: Array = overlay_instance.get("global_buffs_data") as Array
	var synced_heal: Dictionary = synced_buffs[0] as Dictionary
	_check(
		str(synced_heal.get("state", "")) == "cooldown"
		and int(synced_heal.get("cooldownSeconds", 0)) > 0,
		"realtime Global Heal requests immediately synchronize the cooldown UI"
	)
	_check(
		(overlay_instance.get("pending_global_heal_request") as Dictionary).is_empty(),
		"cooldown synchronization does not force a disabled heal prompt"
	)
	game_state.set("global_heal_requests_enabled", original_requests_enabled)

	dialog_host.free()
	overlay_instance.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
