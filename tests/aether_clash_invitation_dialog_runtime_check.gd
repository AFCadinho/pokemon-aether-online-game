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
		"tierName": "Aether OU",
		"stakeAmount": 100000,
		"stakePotAmount": 200000,
		"expiresAt": "2099-08-30T12:00:00+00:00",
	})
	overlay_instance.call("_render_aether_clash_challenge_dialog")
	await process_frame
	await process_frame

	var dialog := overlay_instance.get("aether_clash_challenge_dialog") as AetherConfirmationDialog
	var countdown := overlay_instance.get("aether_clash_challenge_countdown_label") as Label
	var spectator_policy := overlay_instance.get("aether_clash_challenge_spectator_label") as Label
	var contract := overlay_instance.get("aether_clash_challenge_contract_label") as Label
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
		contract != null
		and contract.text.contains("Aether OU")
		and contract.text.contains("100,000")
		and contract.text.contains("200,000"),
		"incoming challenge shows its immutable tier and Guild Bank stake contract"
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

	overlay_instance.call("_setup_aether_clash_entry_callout")
	overlay_instance.call("_set_aether_clash_entry_callout", {
		"id": "entry-callout-test",
		"status": "entry_open",
		"challengerGuild": {"id": 7, "name": "AFC squad"},
		"challengedGuild": {"id": 8, "name": "Godz"},
		"entryClosesAt": Time.get_datetime_string_from_unix_time(
			int(Time.get_unix_time_from_system()) + 90,
			true
		) + "Z",
	})
	await process_frame
	var entry_callout := overlay_instance.get("aether_clash_entry_callout") as PanelContainer
	var entry_title := overlay_instance.get("aether_clash_entry_title_label") as Label
	var entry_countdown := overlay_instance.get("aether_clash_entry_countdown_label") as Label
	var entry_hint := overlay_instance.get("aether_clash_entry_hint_label") as Label
	_check(entry_callout != null and entry_callout.visible, "accepted Aether Clash opens a persistent gathering callout")
	_check(
		entry_title != null and entry_title.text.contains("AFC squad") and entry_title.text.contains("Godz"),
		"gathering callout identifies both participating Guilds"
	)
	_check(entry_countdown != null and entry_countdown.text.contains(":"), "gathering callout shows the live portal timer")
	_check(entry_hint != null and entry_hint.text.to_lower().contains("red"), "gathering callout directs members to the red Guild Duel portal")
	_check(
		entry_callout != null
		and entry_callout.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and entry_title.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and entry_countdown.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and entry_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"gathering callout does not block movement toward the portal"
	)
	overlay_instance.call("_set_aether_clash_entry_callout", {
		"id": "expired-entry-callout-test",
		"status": "entry_open",
		"entryClosesAt": "2000-01-01T00:00:00Z",
	})
	_check(not entry_callout.visible, "gathering callout closes when portal entry expires")

	overlay_instance.call("show_aether_clash_result", {
		"sessionId": "result-dialog-test",
		"outcome": "victory",
		"challengerGuild": {"id": 7, "name": "AFC squad"},
		"challengedGuild": {"id": 8, "name": "Godz"},
		"winnerGuild": {"id": 7, "name": "AFC squad"},
		"remainingCounts": {"challenger": 2, "challenged": 0},
		"durationSeconds": 428,
	})
	await process_frame
	await process_frame
	var result_dialog := dialog_host.find_child("AetherClashResultDialog", true, false) as AetherConfirmationDialog
	_check(result_dialog != null and result_dialog.visible, "finished Guild Duel opens a result modal")
	_check(
		result_dialog != null
		and result_dialog.title_label.text.contains("victory")
		and result_dialog.message_label.text.contains("AFC squad")
		and result_dialog.message_label.text.contains("07:08"),
		"result modal identifies the winner and duel duration"
	)
	_check(result_dialog != null and not result_dialog.cancel_button.visible, "result modal has one clear continuation action")
	_check(
		result_dialog != null
		and result_dialog.panel.get_theme_stylebox("panel") is StyleBoxFlat,
		"result modal uses the themed Aether styling"
	)

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(
		overlay_source.contains('notification.get("aetherClashSessionId"'),
		"realtime notification identifies the exact authoritative challenge"
	)
	_check(
		overlay_source.contains('kind == "aether_clash_accepted"')
		and overlay_source.contains("_refresh_aether_clash_entry_callout_from_server.call_deferred()"),
		"accepted challenge notifications activate the gathering callout for every notified Guild member"
	)
	_check(
		overlay_source.contains('_set_aether_clash_entry_callout(_dictionary_from_value(result.get("challenge", {})))'),
		"the accepting Guild staff member sees the gathering callout immediately"
	)
	localization_manager.call("set_locale", original_locale)
	if dialog != null and is_instance_valid(dialog):
		dialog.free()
	if entry_callout != null and is_instance_valid(entry_callout):
		entry_callout.free()
	if result_dialog != null and is_instance_valid(result_dialog):
		result_dialog.free()
	dialog = null
	countdown = null
	spectator_policy = null
	entry_callout = null
	entry_title = null
	entry_countdown = null
	entry_hint = null
	result_dialog = null
	dialog_host.free()
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
