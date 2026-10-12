extends SceneTree

const FORMATTER = preload("res://scripts/ui/wild_announcement_formatter.gd")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var event := {"displayName": "Adinho", "species": "Pidgey", "shiny": true, "phase": "encountered"}
	_check(FORMATTER.format_event(event) == "Adinho encountered a wild Shiny Pidgey.", "Shiny encounter includes its identity")
	event["phase"] = "fainted"
	_check(FORMATTER.format_event(event) == "Adinho has fainted a Shiny Pidgey.", "Defeated Shiny is reported")
	event.merge({"species": "Zapdos", "shiny": false, "phase": "caught"}, true)
	_check(FORMATTER.format_event(event) == "Adinho caught a Zapdos.", "Caught Legendary is reported")
	var script := load("res://scripts/ui/ui_overlay.gd") as Script
	_check(script != null, "Overlay loads")
	if script == null:
		quit(1)
		return
	var overlay = script.new()
	for tab: String in ["all", "general", "map", "trade", "guild", "language_zh", "language_pt", "system", "pm"]:
		overlay.set("active_chat_tab", tab)
		_check(overlay.call("_should_show_chat_category", "wild_system"), "Wild System notices appear in %s" % tab)
	overlay.set("active_chat_tab", "help")
	_check(not overlay.call("_should_show_chat_category", "wild_system"), "Help excludes wild notices")
	var messages := VBoxContainer.new()
	var template := RichTextLabel.new()
	messages.add_child(template)
	overlay.set("message_list", messages)
	overlay.set("message_entry_template", template)
	event.merge({"announcementId": "test-announcement", "sentAt": "2026-10-12T12:00:00+00:00"}, true)
	overlay.call("_on_chat_realtime_message_received", event.merged({"type": "system.wild_encounter"}))
	overlay.call("_on_chat_realtime_message_received", event.merged({"type": "system.wild_encounter"}))
	_check(messages.get_child_count() == 2, "Repeated server notices produce one System row")
	var row := messages.get_child(1) as RichTextLabel
	_check(not row.visible, "Incoming notice remains hidden in Help")
	_check(row.get_parsed_text() == "SYSTEM: Adinho caught a Zapdos.", "Notice uses the System identity")
	var pm_messages := VBoxContainer.new()
	overlay.set("pm_message_list", pm_messages)
	overlay.call("_render_pm_wild_notices")
	_check(pm_messages.get_child_count() == 1, "PM view also renders System notices")
	_check((pm_messages.get_child(0) as RichTextLabel).get_parsed_text() == row.get_parsed_text(), "PM keeps the same System message")
	overlay.set("active_chat_tab", "pm")
	event.merge({"announcementId": "test-second-notice", "phase": "encountered"}, true)
	overlay.call("_add_wild_system_announcement", event)
	var live_pm_rows := pm_messages.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion())
	_check(live_pm_rows.size() == 2, "Receiving a notice refreshes the PM view")
	overlay.free()
	messages.free()
	pm_messages.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
