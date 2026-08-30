extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "en")
	var overlay_script := load(OVERLAY_PATH) as Script
	_check(overlay_script != null, "incoming Aether Clash dialog loads the overlay")
	if overlay_script == null:
		quit(1)
		return

	var overlay_instance: Node = overlay_script.new()
	var dialog_host := Control.new()
	dialog_host.size = Vector2(900, 600)
	root.add_child(dialog_host)
	overlay_instance.set("root_control", dialog_host)
	overlay_instance.call("_setup_aether_clash_challenge_dialog")
	overlay_instance.set("active_aether_clash_challenge", {
		"id": "clash-dialog-test",
		"status": "pending",
		"challengerGuild": {"id": 7, "name": "AFC squad"},
		"challengedGuild": {"id": 8, "name": "Godz"},
		"createdBy": "Admin",
		"spectatorAccess": "guilds_only",
		"expiresAt": "2099-08-30T12:00:00+00:00",
	})
	overlay_instance.call("_render_aether_clash_challenge_dialog")
	await process_frame
	await process_frame

	var dialog := overlay_instance.get("aether_clash_challenge_dialog") as AetherConfirmationDialog
	var countdown := overlay_instance.get("aether_clash_challenge_countdown_label") as Label
	var spectator_policy := overlay_instance.get("aether_clash_challenge_spectator_label") as Label
	_check(dialog != null and dialog.visible, "incoming challenge opens a direct response modal")
	_check(
		dialog != null and dialog.title_label.text.contains("Aether Clash"),
		"incoming challenge modal identifies Aether Clash"
	)
	_check(
		dialog != null
		and dialog.message_label.text.contains("AFC squad")
		and dialog.message_label.text.contains("Admin"),
		"incoming challenge modal identifies the challenging Guild and Trainer"
	)
	_check(countdown != null and countdown.text.contains(":"), "incoming challenge shows a live deadline")
	_check(
		spectator_policy != null and spectator_policy.text.to_lower().contains("guild"),
		"incoming challenge shows its spectator policy"
	)
	_check(
		dialog != null
		and dialog.confirm_button.text == "Accept"
		and dialog.cancel_button.text == "Decline",
		"incoming challenge offers direct accept and decline actions"
	)
	_check(
		dialog != null
		and dialog.panel.get_theme_stylebox("panel") is StyleBoxFlat
		and dialog.confirm_button.get_theme_stylebox("normal") is StyleBoxFlat,
		"incoming challenge replaces default Godot styling"
	)

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(
		overlay_source.contains('notification.get("aetherClashSessionId"'),
		"realtime notification identifies the exact authoritative challenge"
	)
	localization_manager.call("set_locale", original_locale)
	dialog = null
	countdown = null
	spectator_policy = null
	dialog_host.queue_free()
	await process_frame
	overlay_instance.free()
	overlay_script = null
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
