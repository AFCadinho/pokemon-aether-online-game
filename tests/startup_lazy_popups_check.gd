extends SceneTree

const WINDOWS := [
	["trainer_card_popup", "_show_trainer_card", "_hide_trainer_card"],
	["donator_store_popup", "_on_donator_store_button_pressed", "_hide_donator_store_popup"],
	["market_popup", "open_market", "_hide_market_popup"],
	["aether_exchange_popup", "_on_aether_exchange_button_pressed", "_hide_aether_exchange"],
	["aether_atelier_popup", "open_aether_atelier", "_hide_aether_atelier"],
	["bank_popup", "open_bank", "_hide_bank"],
	["move_mentor_popup", "open_move_mentor", "_hide_move_mentor"],
	["move_deleter_popup", "open_move_deleter", "_hide_move_deleter"],
	["shiny_tracker_popup", "_show_shiny_tracker", "_hide_shiny_tracker"],
]

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/interface/ui_overlay.tscn") as PackedScene
	var overlay := packed.instantiate()
	root.add_child(overlay)
	for entry: Array in WINDOWS:
		_expect(overlay.get(entry[0]) == null, "%s is absent after actual HUD startup" % entry[0])
	var inventory: Node = root.get_node("InventoryService")
	_expect(inventory.mount_box_opened.is_connected(Callable(overlay, "_on_mount_box_inventory_updated")), "mount box notifications work before the tracker is first opened")
	var locale: Node = root.get_node("LocalizationManager")
	var original_locale: String = locale.current_locale
	locale.set_locale("nl")
	for entry: Array in WINDOWS:
		if entry[1] == "open_market":
			overlay.call(entry[1], {"items": []})
		else:
			await overlay.call(entry[1])
		var popup: Control = overlay.get(entry[0])
		_expect(popup != null and popup.visible, "%s opens through its real player action" % entry[0])
		if popup == null:
			continue
		if entry[0] == "trainer_card_popup":
			var tabs: TabContainer = overlay.get("trainer_card_tabs")
			_expect(tabs.get_tab_title(0) == "Overzicht", "a card constructed after a locale change uses the current locale")
		overlay.call(entry[2])
		_expect(not popup.visible, "%s closes normally" % entry[0])
		var child_count := overlay.get_node("Control").get_child_count()
		if entry[1] == "open_market":
			overlay.call(entry[1], {"items": []})
		else:
			await overlay.call(entry[1])
		_expect(overlay.get(entry[0]) == popup and overlay.get_node("Control").get_child_count() == child_count, "%s reopens without duplicate windows or signals" % entry[0])
		overlay.call(entry[2])
	locale.set_locale(original_locale)
	overlay.free()
	await process_frame
	print("startup_lazy_popups_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
	else:
		print("PASS: ", message)
