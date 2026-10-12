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
	menu.name_field.text = "New design"
	await menu._change("save", {})
	_check(service.calls.size() == 1 and service.calls[0].owner == 7 and service.calls[0].payload.expectedRoomRevision == 3, "Save sends room revision and owner")
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
	root.add_child(manager)
	service.state.canEdit = true
	manager.open(service, {"policy": "request", "canManage": true, "requests": []}, "", 7, {"guildId": 7})
	manager._show_page("room_designs")
	await process_frame
	_check(manager.designs_page.visible and not manager.visitor_page.visible, "Manager has a dedicated room design page")
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
	var packed := load("res://scenes/interface/donator_store_popup.tscn") as PackedScene
	_check(packed != null, "Store scene loads")
	if packed != null:
		var store = packed.instantiate()
		root.add_child(store)
		await process_frame
		store._select_category("guilds")
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

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
