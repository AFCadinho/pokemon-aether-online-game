extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_script := load("res://scripts/ui/ui_overlay.gd")
	if overlay_script == null:
		push_error("Discord chat check: overlay could not load")
		quit(1)
		return
	var overlay: CanvasLayer = overlay_script.new()
	var template := RichTextLabel.new()
	overlay.set("message_entry_template", template)
	var user := {"id": 7, "username": "ash", "displayName": "Ash"}
	var context: Dictionary = overlay.call("_chat_message_context", user, "Ash", "hello", "2026-10-07T12:00:00Z")
	context["origin"] = "discord"
	var line: Control = overlay.call("_create_chat_sender_message_line", "Ash", "#ffffff", "hello", "global", 0, "", "", context)
	_check(line.get_node_or_null("Header/DiscordOriginBadge") != null, "Discord origin is visibly marked")
	_check(context["user"]["id"] == 7 and context["display_name"] == "Ash", "game identity stays intact for moderation")
	var copied := str(overlay.call("_format_full_chat_message", context))
	_check(copied.contains("[Discord] Ash: hello"), "copied messages retain Discord origin")
	line.free()
	context["origin"] = "game"
	line = overlay.call("_create_chat_sender_message_line", "Ash", "#ffffff", "hello", "global", 0, "", "", context)
	_check(line.get_node_or_null("Header/DiscordOriginBadge") == null, "game messages do not receive a Discord badge")
	line.free()
	template.free()
	overlay.free()
	if failures == 0:
		print("Discord chat bridge checks passed")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("Discord chat check: " + message)
