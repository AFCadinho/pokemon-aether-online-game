extends SceneTree

var failed := false
class Service extends Node:
	var state: Dictionary
	var calls: Array = []
	func base_design_library(_id: int) -> Dictionary:
		return {"success": true, "state": state}
	func change_base_design(id: int, payload: Dictionary) -> Dictionary:
		calls.append({"owner": id, "payload": payload})
		return {"success": true, "state": state}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/guild_room_designs.json"))
	var service := Service.new()
	root.add_child(service)
	service.state = {"guildId": 7, "guildName": "AFC Squad", "revision": 2, "canEdit": true, "saved": [{"id": "saved", "name": "Meeting", "roomKey": "right_room", "items": []}], "templates": [], "backups": {}, "rooms": {"right_room": {"revision": 3}, "left_room": {"revision": 4}}}
	for template: Dictionary in data.templates:
		var value := template.duplicate(true)
		value.unlocked = true
		value.bagQuantity = 1
		service.state.templates.append(value)
	var panel := PanelContainer.new()
	panel.size = Vector2(540, 500)
	root.add_child(panel)
	var menu := preload("res://scripts/ui/guild_room_design_library.gd").new()
	panel.add_child(menu)
	menu.configure(service, 7)
	await menu.refresh()
	_check(menu.rows.item_count == 1, "Own designs filter by room")
	_check(not menu.selection_panel.visible and menu.name_field == null, "Unselected designs do not show unrelated actions or an inline naming field")
	var saved_designs: Array = service.state.saved
	service.state.saved = []
	await menu.refresh()
	_check(menu.empty_state.visible and not menu.rows.visible and menu.current_room_actions.visible, "Empty library explains how to save the current room")
	service.state.saved = saved_designs
	await menu.refresh()
	menu.controls.save.pressed.emit()
	_check(menu.name_dialog.visible and menu.name_dialog.confirm_button.disabled, "Save current room opens a dedicated naming dialog")
	menu.name_field.text = "   "
	menu.name_field.text_changed.emit("   ")
	_check(menu.name_dialog.confirm_button.disabled, "Blank names cannot be saved")
	menu.name_field.text = "New design"
	menu.name_field.text_changed.emit("New design")
	menu.name_dialog.confirm_button.pressed.emit()
	await process_frame
	_check(service.calls.size() == 1 and service.calls[0].owner == 7 and service.calls[0].payload.expectedRoomRevision == 3 and service.calls[0].payload.name == "New design" and not service.calls[0].payload.has("designId"), "New save sends its own name, room revision and owner without overwriting a design")
	menu.rows.item_selected.emit(0)
	_check(menu.selection_panel.visible and menu.more_actions.visible, "Selecting a saved design reveals preview, apply and grouped management")
	menu.more_actions.get_popup().id_pressed.emit(0)
	_check(menu.name_dialog.visible and menu.name_field.text == "Meeting", "Rename uses a prefilled separate naming dialog")
	menu.name_field.text = "Team meeting"
	menu.name_field.text_changed.emit("Team meeting")
	menu.name_dialog.confirm_button.pressed.emit()
	await process_frame
	_check(service.calls.back().payload.action == "rename" and service.calls.back().payload.name == "Team meeting", "Rename sends the selected design's new name")
	menu.more_actions.get_popup().id_pressed.emit(1)
	var overwrite := menu.get_child(menu.get_child_count() - 1) as AetherConfirmationDialog
	_check(overwrite.visible and overwrite.message_label.text.contains("Meeting"), "Updating a design still requires an explicit overwrite confirmation")
	overwrite.confirm_button.pressed.emit()
	await process_frame
	_check(service.calls.back().payload.action == "save" and service.calls.back().payload.designId == "saved" and service.calls.back().payload.name == "Meeting", "Update uses the selected design's name, not a stale naming draft")
	service.state.backups.right_room = {"items": []}
	menu.selected = {}
	menu._render()
	_check(menu.controls.restore.visible and not menu.controls.restore.disabled, "Recovery is available independently of a selected design")
	menu.controls.restore.pressed.emit()
	var recovery := menu.get_child(menu.get_child_count() - 1) as AetherConfirmationDialog
	recovery.confirm_button.pressed.emit()
	await process_frame
	_check(service.calls.back().payload.source == "backup" and service.calls.back().payload.roomKey == "right_room", "Recovery targets the currently chosen room")
	service.state.backups = {}
	menu.busy = true
	menu._update_controls()
	menu.tabs[1].pressed.emit()
	_check(menu.mode == "saved" and menu.room_select.disabled, "Pending changes lock navigation")
	menu.busy = false
	menu._render()
	service.state.templates[0].unlocked = false
	service.state.templates[0].bagQuantity = 0
	menu.tabs[1].pressed.emit()
	_check(menu.rows.item_count == 0 and menu.empty_state.visible and not menu.current_room_actions.visible, "Purchased templates excludes unowned offers and explains the Gift Store flow")
	service.state.templates[0].unlocked = true
	service.state.templates[0].bagQuantity = 1
	menu.mode = "template"
	menu._render()
	menu._select(0)
	_check(str(menu.selected.id) == "guild-room-1-template" and menu.controls.redeem.disabled, "Room 1 offers its template and rejects duplicate donations")
	menu._act("preview")
	await process_frame
	var viewer: Window = menu.get_child(menu.get_child_count()-1)
	_check(viewer is Window and viewer.visible, "Full room preview opens")
	viewer.canvas.zoom_at(2, viewer.canvas.size * 0.5)
	_check(viewer.canvas.zoom == 2, "Preview zoom works")
	viewer.canvas.pan = Vector2(99999, 99999)
	viewer.canvas._clamp_pan()
	_check(viewer.canvas.pan.x < 99999, "Preview pan is bounded")
	if "--screenshot" in OS.get_cmdline_user_args():
		await process_frame
		RenderingServer.force_draw(false)
		viewer.canvas.reset_view()
		await process_frame
		RenderingServer.force_draw(false)
		viewer.get_viewport().get_texture().get_image().save_png("/tmp/guild-design-preview.png")
	viewer.queue_free()
	await process_frame
	service.state.canEdit = false
	menu.mode = "saved"
	menu._render()
	_check(menu.controls.save.disabled and menu.controls.apply.disabled, "Member cannot change layouts")
	menu.room_key = "left_room"
	menu.mode = "template"
	menu._render()
	menu._select(0)
	_check(str(menu.selected.id) == "guild-room-2-template" and not menu.controls.preview.disabled, "Room 2 offers its template and members can preview")
	menu.selected.unlocked = false
	menu._update_controls()
	_check(not menu.controls.redeem.disabled and menu.controls.apply.disabled, "Members can donate a Bag item but cannot apply layouts")
	menu._act("redeem")
	await process_frame
	var confirmation: AetherConfirmationDialog = menu.get_child(menu.get_child_count() - 1)
	_check(confirmation.visible and confirmation.message_label.text.contains("AFC Squad") and confirmation.message_label.text.contains("Grand Lounge"), "Donation confirmation names receiving Guild and template")
	confirmation.canceled.emit()
	await process_frame
	var manager := preload("res://scripts/ui/guild_base_visit_menu.gd").new()
	panel.hide()
	root.add_child(manager)
	service.state.canEdit = true
	manager.open(service, {"policy": "request", "canManage": true, "requests": []}, "", 7, {"guildId": 7})
	manager._show_page("room_designs")
	await process_frame
	_check(manager.designs_page.visible and not manager.visitor_page.visible, "Manager has a dedicated room design page")
	if "--navigation-screenshots" in OS.get_cmdline_user_args():
		service.state.saved = []
		await manager.designs_page.refresh()
		await _capture("/tmp/guild-design-navigation-empty.png")
		manager.designs_page.controls.save.pressed.emit()
		manager.designs_page.name_field.text = "Training hall"
		manager.designs_page.name_field.text_changed.emit("Training hall")
		await _capture("/tmp/guild-design-navigation-save.png")
		manager.designs_page.name_dialog.cancel_button.pressed.emit()
		await process_frame
		service.state.saved = saved_designs
		await manager.designs_page.refresh()
		manager.designs_page.rows.item_selected.emit(0)
		await _capture("/tmp/guild-design-navigation-selected.png")
	for viewport_size: Vector2i in [Vector2i(1280, 800), Vector2i(640, 480)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		manager.designs_page._select(0)
		for frame in range(4):
			await process_frame
		var manager_panel := manager.find_child("GuildBaseManagementPanel", true, false) as PanelContainer
		_check(root.get_visible_rect().encloses(manager_panel.get_global_rect()), "Management stays within the viewport: " + str(root.get_visible_rect()) + " / " + str(manager_panel.get_global_rect()))
		_check(manager.designs_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Small screens scroll vertically while Close remains outside")
		var close_button := manager.find_child("CloseGuildBaseManagement", true, false) as Button
		_check(root.get_visible_rect().encloses(close_button.get_global_rect()) and not manager.designs_scroll.is_ancestor_of(close_button), "Close remains visible independently of page scrolling")
		if viewport_size.x == 1280:
			_check(manager.designs_scroll.get_v_scroll_bar().max_value <= manager.designs_scroll.size.y + 1, "Normal screens show the selected design and save action without page scrolling")
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	for frame in range(4):
		await process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("/tmp/guild-design-manager.png")
	manager.designs_page.room_key = "left_room"
	manager.designs_page.mode = "template"
	manager.designs_page._render()
	manager.designs_page._select(0)
	manager.designs_page._act("redeem")
	await process_frame
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	manager._input(cancel_event)
	_check(not manager.closed, "Escape in a confirmation keeps manager open")
	var manager_confirmation := manager.find_child("AetherConfirmationDialog", true, false) as AetherConfirmationDialog
	_check(manager_confirmation != null and manager_confirmation.visible, "Manager donation opens the styled confirmation")
	if manager_confirmation != null:
		manager_confirmation.canceled.emit()
	manager._finish({})
	await process_frame
	for language: String in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(language)
		manager = preload("res://scripts/ui/guild_base_visit_menu.gd").new()
		root.add_child(manager)
		manager.open(service, {"policy": "request", "canManage": true, "requests": []}, "", 7, {"guildId": 7})
		manager._show_page("room_designs")
		manager.designs_page.rows.item_selected.emit(0)
		manager.designs_page.controls.save.pressed.emit()
		for frame in range(4):
			await process_frame
		_check(not manager.designs_page.empty_hint.text.begins_with("ui.") and not manager.designs_page.controls.save.text.begins_with("ui."), "Navigation messages and actions are localized: " + language)
		_check(root.get_visible_rect().encloses(manager.designs_page.name_dialog.panel.get_global_rect()), "Naming dialog fits the screen: " + language)
		manager.designs_page.name_dialog.cancel_button.pressed.emit()
		manager._finish({})
		await process_frame
	root.get_node("LocalizationManager").set_locale("en")
	var packed := load("res://scenes/interface/donator_store_popup.tscn") as PackedScene
	_check(packed != null, "Store scene loads")
	if packed != null:
		var store = packed.instantiate()
		root.add_child(store)
		await process_frame
		store._select_category("guilds")
		store._select_guild_subcategory("rooms")
		store._select_product("guild-room-1-template")
		_check(store.room_preview_button.visible and store._catalog_item("guild-room-1-template").price == 350, "Store shows preview and approved price")
		if "--screenshot" in OS.get_cmdline_user_args():
			store.open_store()
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/tmp/guild-design-store.png")
		store._open_room_preview()
		await process_frame
		var preview_count := 0
		store._open_room_preview()
		var opened := false
		for child: Node in store.get_children():
			if child is Window and child.visible:
				opened = true
				preview_count += 1
		_check(opened and preview_count == 1, "Store opens one shared viewer even after repeated clicks")
		store.close_store()
		await process_frame
		_check(not is_instance_valid(store.room_preview_window), "Closing Store also releases its preview")
		store.queue_free()
	panel.queue_free()
	service.queue_free()
	await process_frame
	print("guild_room_designs_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _capture(path: String) -> void:
	for frame in range(4):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
