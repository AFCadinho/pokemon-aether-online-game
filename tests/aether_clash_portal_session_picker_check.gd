extends Node

const PICKER_SCRIPT := preload("res://scripts/ui/aether_clash_portal_session_picker.gd")
const LOBBY_SCRIPT_PATH := "res://scripts/world/aether_clash_lobby.gd"

var failed := false


func _ready() -> void:
	var now := int(Time.get_unix_time_from_system())
	var picker := PICKER_SCRIPT.new()
	add_child(picker)
	var sessions: Array[Dictionary] = [
		{
			"role": "spectator",
			"session": {
				"id": "active-clash",
				"status": "active",
				"challengerGuild": {"name": "AFC Squad"},
				"challengedGuild": {"name": "Godz"},
				"activeCounts": {"challenger": 2, "challenged": 1},
				"startedAt": Time.get_datetime_string_from_unix_time(now - 125, true) + "Z",
				"tierName": "Aether OU",
			},
		},
		{
			"role": "participant",
			"session": {
				"id": "gathering-clash",
				"status": "entry_open",
				"challengerGuild": {"name": "Blue Wings"},
				"challengedGuild": {"name": "Red Comets"},
				"entryCounts": {"challenger": 3, "challenged": 4},
				"entryClosesAt": Time.get_datetime_string_from_unix_time(now + 90, true) + "Z",
				"tierName": "Aether UU",
			},
		},
	]
	picker.configure(sessions)
	await get_tree().process_frame

	var choices := picker.find_child("AetherClashPortalSessionSelect", true, false) as OptionButton
	var matchup := picker.find_child("Matchup", true, false) as Label
	var status := picker.find_child("Status", true, false) as Label
	var access := picker.find_child("Access", true, false) as Label
	var details := picker.find_child("AetherClashPortalSessionDetails", true, false) as PanelContainer
	_check(choices != null and choices.item_count == 2, "Portal picker lists every accessible Clash")
	_check(
		choices != null
		and choices.get_item_text(0).contains("AFC Squad")
		and choices.get_item_text(0).contains("Godz")
		and choices.get_item_text(0).contains("2")
		and choices.get_item_text(0).contains("1"),
		"Portal options identify the Guilds and current player counts"
	)
	_check(
		matchup != null
		and matchup.text.contains("AFC Squad")
		and matchup.text.contains("Godz"),
		"Selected Clash shows its full matchup"
	)
	_check(status != null and status.text.contains("02:05"), "Active Clash shows live elapsed duel time")
	_check(access != null and access.text.contains("Aether OU"), "Selected Clash shows entry role context and tier")
	_check(details != null and details.custom_minimum_size.y == 104.0, "Clash details stay compact")

	choices.select(1)
	picker.call("_on_session_selected", 1)
	var entry_timer_pattern := RegEx.new()
	entry_timer_pattern.compile("01:(29|30)")
	_check(
		matchup.text.contains("Blue Wings")
		and matchup.text.contains("Red Comets")
		and matchup.text.contains("3")
		and matchup.text.contains("4"),
		"Changing the selection updates gathered player counts"
	)
	_check(
		entry_timer_pattern.search(status.text) != null,
		"Gathering Clash shows the live portal countdown"
	)
	_check(access.text.contains("Aether UU"), "Changing the selection updates the tier and role summary")
	_check(
		str((picker.selected_session().get("session", {}) as Dictionary).get("id", "")) == "gathering-clash",
		"Picker returns the explicitly selected session"
	)

	var lobby_source := FileAccess.get_file_as_string(LOBBY_SCRIPT_PATH)
	_check(
		lobby_source.contains("AETHER_CLASH_PORTAL_SESSION_PICKER")
		and lobby_source.contains("picker.selected_session()"),
		"Lobby portal enters the session chosen in the detailed picker"
	)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		var catalog := parsed as Dictionary if parsed is Dictionary else {}
		for key: String in [
			"world.aether_clash.portal.option",
			"world.aether_clash.portal.status.entry_open",
			"world.aether_clash.portal.status.active",
			"world.aether_clash.portal.players.entry_open",
			"world.aether_clash.portal.players.active",
			"world.aether_clash.portal.summary.players",
			"world.aether_clash.portal.timer.entry_open",
			"world.aether_clash.portal.timer.active",
			"world.aether_clash.portal.summary.access",
		]:
			_check(catalog.has(key), "%s contains portal picker key %s" % [locale, key])

	await _check_camera_space(sessions)
	picker.queue_free()
	get_tree().quit(1 if failed else 0)


func _check_camera_space(sessions: Array[Dictionary]) -> void:
	var original_scene := get_tree().current_scene
	var world := Node2D.new()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	# Attach the controller after entering the tree so its full lobby setup is
	# unnecessary for exercising the real portal dialog flow.
	world.set_script(load(LOBBY_SCRIPT_PATH))
	var camera := Camera2D.new()
	camera.position = Vector2(800, 600)
	camera.zoom = Vector2(1.4, 1.4)
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	world.call("_select_session", sessions)
	await get_tree().process_frame
	await get_tree().process_frame
	var dialog := world.find_child("AetherClashPortalSessionDialog", true, false) as AetherConfirmationDialog
	_check(dialog != null, "Portal session dialog opens from a world controller")
	if dialog != null:
		var panel := dialog.panel
		var transform := panel.get_global_transform_with_canvas()
		_check(
			(transform * (panel.size / 2.0)).is_equal_approx(get_viewport().get_visible_rect().get_center()),
			"Portal session dialog stays screen-centered with a moved and zoomed camera"
		)
		_check(transform.get_scale().is_equal_approx(Vector2.ONE), "Portal session dialog avoids world camera magnification")
		var screen_layer := dialog.get_parent()
		dialog.cancel_button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not is_instance_valid(screen_layer), "Canceling the portal dialog removes its screen layer")
	get_tree().current_scene = original_scene
	world.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
