extends SceneTree

const MapChatBubbleScript := preload("res://scripts/world/map_chat_bubble.gd")

var failed := false


func _init() -> void:
	var bubble := MapChatBubbleScript.new() as PanelContainer
	root.add_child(bubble)
	await process_frame
	bubble.call("show_message", "Hello from Pallet Town!")
	_check(bubble.visible and bubble.modulate.a == 0.0, "first bubble lays out transparently")
	await _wait_for_bubble_layout()

	_check(bubble.visible, "map chat bubble becomes visible")
	_check(bubble.message_label.text == "Hello from Pallet Town!", "map chat bubble shows the message")
	_check(bubble.hide_timer.time_left > 0.0, "map chat bubble schedules temporary visibility")
	_check(bubble.position.y < -bubble.size.y, "map chat bubble sits above the character")
	_check(bubble.size.x <= 144.0, "map chat bubble keeps a compact maximum width")
	bubble.call("show_message", "Hi")
	await _wait_for_bubble_layout()
	_check(bubble.size.x < 100.0, "short map messages use a smaller content-sized bubble")
	_check(bubble.size.y <= 32.0, "short first messages do not create a tall block")
	_check(bubble.modulate.a == 1.0, "bubble becomes opaque after its layout is stable")
	var repeated_message := "What are you doing here, trainer?"
	bubble.call("show_message", repeated_message)
	await _wait_for_bubble_layout()
	var warmed_bubble_height := bubble.size.y
	var fresh_bubble := MapChatBubbleScript.new() as PanelContainer
	root.add_child(fresh_bubble)
	await process_frame
	fresh_bubble.call("show_message", repeated_message)
	await _wait_for_bubble_layout()
	_check(
		is_equal_approx(fresh_bubble.size.y, warmed_bubble_height),
		"first and repeated messages use the same calculated bubble height"
	)
	fresh_bubble.queue_free()

	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var remote_avatar_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	_check(
		overlay_source.contains("CHAT_TAB_MAP") and overlay_source.contains("CHAT_CHANNEL_MAP"),
		"Map is a dedicated top-level chat tab and channel"
	)
	_check(
		overlay_source.contains('_show_map_chat_bubble(user, text, str(message.get("mapId", "")))'),
		"incoming map text is forwarded to the overworld"
	)
	_check(
		overlay_source.contains('current_user_id_text := AuthService.get_user_id_text()')
		and overlay_source.contains(
			'local_player.call("show_map_chat_message", text)'
		),
		"the authenticated sender is routed directly to the local character"
	)
	_check(
		overlay_source.contains('sender_username == current_username'),
		"local sender recognition has a username fallback"
	)
	_check(
		overlay_source.contains(
			'if message_map_id != "" and current_map_id != "" and message_map_id != current_map_id:'
		),
		"a temporarily empty local presence map does not suppress a valid bubble"
	)
	_check(
		settings_source.contains("CHAT_TAB_MAP") and settings_source.contains("CHAT_TAB_MAP: true"),
		"Map tab is visible by default and persisted"
	)
	_check(
		settings_source.contains(
			"CHAT_TAB_ALL,\n\tCHAT_TAB_GENERAL,\n\tCHAT_TAB_SYSTEM,\n\tCHAT_TAB_MAP,\n\tCHAT_TAB_PM,\n\tCHAT_TAB_CLAN,"
		),
		"default top tab order is All, General, System, Map, PM, Clan"
	)
	_check(
		settings_source.contains("order.insert(system_index + 1, CHAT_TAB_MAP)"),
		"older saved tab orders place the newly added Map tab after System"
	)
	_check(
		overlay_source.contains("var active_chat_tab: String = CHAT_TAB_ALL")
		and overlay_source.contains("var selected_general_chat_tab := CHAT_TAB_GENERAL")
		and overlay_source.contains("func _setup_all_chat_tab()")
		and not overlay_source.contains('_add_chat_context_option("All", CHAT_TAB_ALL'),
		"All is a main tab and General defaults to Global"
	)
	_check(
		overlay_source.contains('chat_input.placeholder_text = "All messages · reply sends to Global"')
		and overlay_source.contains("if active_chat_tab == CHAT_TAB_ALL:\n\t\treturn CHAT_CHANNEL_GLOBAL"),
		"All is an aggregate view that sends through Global"
	)
	_check(
		overlay_source.contains("CHAT_CHANNEL_MAP,\n\t\t\tCHAT_CHANNEL_TRADE,")
		and overlay_source.contains("CHAT_TAB_PM,\n\t\t\tCHAT_TAB_CLAN,"),
		"All includes Map, PM, and Clan messages alongside the public channels"
	)
	_check(
		overlay_source.contains("func _create_chat_channel_prefix")
		and overlay_source.contains('prefix.text = "[Global]"')
		and overlay_source.contains('prefix_color = Color("#d8b767")')
		and overlay_source.contains("prefix.flat = true")
		and overlay_source.contains("StyleBoxEmpty.new()")
		and overlay_source.contains("func _on_all_channel_badge_pressed")
		and overlay_source.contains("func _on_all_pm_channel_pressed"),
		"All messages use a muted text channel prefix that can navigate to its chat"
	)
	_check(
		overlay_source.contains("func _apply_chat_row_emphasis")
		and overlay_source.contains("CHAT_ALL_SECONDARY_CONTENT_ALPHA := 0.68")
		and overlay_source.contains(
			'category not in [CHAT_CHANNEL_GLOBAL, CHAT_CATEGORY_USER]'
		)
		and overlay_source.contains(
			'for node_name: StringName in [&"RoleBadge", &"SenderName", &"MessageText"]'
		),
		"All keeps Global prominent and softens secondary channel message content"
	)
	_check(
		overlay_source.contains(
			"sender,\n\t\tdisplay_name,\n\t\tbody,\n\t\tCHAT_TAB_PM,\n\t\tpokemon_attachments,\n\t\tsender_key"
		),
		"incoming private messages are mirrored into All"
	)
	_check(
		world_source.contains(
			"func show_map_chat_message(user_id: int, text: String, force_local: bool = false)"
		)
		and world_source.contains("if force_local:"),
		"world routes authenticated local map chat directly to the player"
	)
	_check(remote_avatar_source.contains("func show_map_chat_message"), "remote players can show map chat bubbles")

	bubble.queue_free()
	quit(1 if failed else 0)


func _wait_for_bubble_layout() -> void:
	for frame_index in range(3):
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
