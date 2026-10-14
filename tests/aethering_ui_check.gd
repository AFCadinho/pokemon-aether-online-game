extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)

func _entry(id: int, groups: Array, location: String, values: Dictionary, allowed := true) -> Dictionary:
	return {"pokemonId": id, "pokemon": {"speciesId": "eevee", "species": "eevee", "nickname": "Example " + str(id), "ivs": values}, "location": {"type": location, "partySlot": id - 1, "boxIndex": 1}, "eggGroups": groups, "recipientAllowed": true, "donorAllowed": allowed, "donorBlockedReason": null, "shiny": false}

func _run() -> void:
	var popup = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	root.add_child(popup)
	await process_frame
	_check(popup != null, "Aethering popup compiles and builds")
	if popup == null:
		quit(1)
		return
	var original := _entry(1, ["ground", "fairy"], "party", {"hp": 31, "atk": 31, "def": 15, "spa": 0, "spd": 31, "spe": 22})
	var good := _entry(2, ["ground"], "party", {"hp": 31, "atk": 12, "def": 31, "spa": 0, "spd": 31, "spe": 12})
	var bad := _entry(3, ["water2"], "party", {})
	var protected := _entry(4, ["ground"], "party", {}, false)
	protected["donorBlockedReason"] = "aethering_donor_held_item"
	var boxed := _entry(5, ["ground"], "box", good["pokemon"]["ivs"])
	popup.candidates = [bad, good, original, protected, boxed]
	popup.recipient = original
	popup.resources_ready = true
	root.get_node("PlayerSave").set("money", 100000)
	popup._render()
	_check(popup.compatible(original, good), "Both Recipient Egg Groups count")
	_check(not popup.compatible(original, bad), "Incompatible groups blocked")
	_check(popup.compatible({"eggGroups": ["ditto"]}, {"eggGroups": ["ditto"]}), "Ditto matches Ditto")
	_check(not popup.compatible({"eggGroups": ["ditto"]}, good), "Ditto has no breeding exception")
	popup._open_picker(true)
	if popup.picker_rows.is_empty():
		quit(1)
		return
	_check(popup.picker_rows.all(func(entry: Dictionary): return entry.is_empty() or entry["location"]["type"] == "party"), "PC candidates never appear in picker")
	_check(popup.picker_rows.size() == 6 and popup.picker_buttons.size() == 6, "Picker shows all six Party slots")
	_check(popup.picker.top_level and popup.picker.get_parent() == popup, "Picker opens outside the scrolling comparison")
	_check(popup.picker_rows[0]["pokemonId"] == 1 and popup.picker_rows[1]["pokemonId"] == 2, "Party order is retained regardless of input order")
	_check(popup.picker_buttons[0].disabled and not popup.picker_buttons[1].disabled, "Recipient cannot be chosen as its own Donor")
	_check(popup.picker_buttons[2].disabled and popup.picker_buttons[3].disabled, "Incompatible and held-item Donors are disabled")
	_check(popup.picker_buttons[4].disabled and popup.picker_buttons[5].disabled, "Empty Party slots are visible and disabled")
	var replacement := good.duplicate(true)
	replacement["pokemonId"] = 99
	popup.picker_rows[1] = replacement
	popup.picker_buttons[1].pressed.emit()
	_check(popup.donor.is_empty(), "Old slot button cannot select a replacement Pokémon")
	popup.picker_rows[1] = good
	popup.picker_buttons[1].pressed.emit()
	_check(popup.donor["pokemonId"] == 2, "Party Donor selection")
	_check(not popup.picker.visible, "Selection closes the modal picker")
	popup._open_picker(true)
	popup._close_picker()
	_check(popup.donor["pokemonId"] == 2, "Cancel preserves the current selection")
	popup._open_picker(false)
	for index in range(popup.picker_rows.size()):
		if popup.picker_rows[index].get("pokemonId") == 2:
			popup._pick(index)
			break
	_check(popup.recipient["pokemonId"] == 2 and popup.recipient["location"]["type"] == "party", "Party Recipient selection")
	popup._open_picker(false)
	for index in range(popup.picker_rows.size()):
		if popup.picker_rows[index].get("pokemonId") == 1:
			popup._pick(index)
			break
	_check(popup.recipient["pokemonId"] == 1 and popup.donor.is_empty(), "Party Recipient selection invalidates Donor")
	for role in [false, true]:
		popup.choosing_donor = role
		popup.picker_rows = [boxed]
		popup._pick(0)
		_check(popup.recipient["pokemonId"] == 1 and popup.donor.is_empty(), "PC selection callback rejected for role " + str(role))
	popup.candidates = [original]
	popup._render()
	_check(popup.preview_button.disabled, "One Party Pokémon cannot preview")
	popup.candidates = [original, good]
	popup.donor = good
	popup._lock_changed(2, false)
	_check(popup.donor_options.is_item_disabled(2), "Same-stat Donor lock disabled")
	popup._lock_changed(2, true)
	_check(popup.donor_lock == null, "Duplicate lock callback cannot change selection")
	popup._lock_changed(5, true)
	_check(popup.recipient_lock == "atk" and popup.donor_lock == "spd", "Two independent locks selected")
	popup.wing_availability = {"muscle-wing": 0, "clever-wing": 0}
	popup.stat_preview = {"stats": {"atk": {"mode": "recipient_lock", "guaranteedIV": 31}, "spd": {"mode": "donor_lock", "guaranteedIV": 31}, "spe": {"mode": "reroll", "guaranteedIV": null}, "spa": {"mode": "equal", "guaranteedIV": 0}}}
	popup.stat_preview["stats"]["hp"] = {"mode": "reroll", "guaranteedIV": null, "recipientIV": 30, "donorIV": 7}
	popup._render()
	_check(popup.confirm_button.disabled and popup.confirm_button.tooltip_text.contains("Muscle Wing") and popup.confirm_button.tooltip_text.contains("Clever Wing"), "Missing Wings explain why confirm is disabled")
	_check((popup.grid.get_child(11) as Label).text.begins_with("31"), "Server-provided protected value visible without executable preview")
	_check((popup.grid.get_child(27) as Label).text.begins_with("?"), "Unknown reroll displayed as question mark")
	_check((popup.grid.get_child(19) as Label).text.begins_with("0"), "Guaranteed zero IV remains visible")
	_check((popup.grid.get_child(5) as Label).text == "30" and (popup.grid.get_child(6) as Label).text == "7", "Authoritative preview sources override stale candidate IVs")
	_check(popup.recipient_options.has_theme_stylebox_override("normal") and popup.recipient_options.get_popup().has_theme_stylebox_override("panel"), "Dropdown button and popup share custom styling")
	popup.wing_availability = {"muscle-wing": 1, "clever-wing": 1}
	popup._render()
	_check(popup.confirm_button.disabled, "Advisory comparison without preview ID cannot enable confirmation")
	popup.plan = {"previewId": "11111111-1111-4111-8111-111111111111", "shinyDonor": true, "requiredWings": [{"itemId": "muscle-wing", "quantity": 1}, {"itemId": "clever-wing", "quantity": 1}], "stats": {"hp": {"mode": "equal", "guaranteedIV": 31}, "atk": {"mode": "recipient_lock", "guaranteedIV": 31}, "spd": {"mode": "donor_lock", "guaranteedIV": 31}, "spe": {"mode": "reroll", "guaranteedIV": null}}}
	popup._render()
	_check(not popup.confirm_button.disabled, "Valid preview plus Wings and money enables confirmation")
	root.get_node("PlayerSave").set("money", 9999)
	popup._render()
	_check(popup.confirm_button.disabled, "Insufficient money blocks confirmation clearly")
	root.get_node("PlayerSave").set("money", 100000)
	popup.wing_availability["clever-wing"] = 0
	popup._render()
	_check(popup.confirm_button.disabled and popup.confirm_button.tooltip_text.contains("Clever Wing"), "One of two required Wings missing blocks confirmation")
	popup._without_wings()
	_check(popup.recipient_lock == null and popup.donor_lock == null and popup.plan.is_empty(), "Without Wings clears both locks and invalidates the old preview")
	popup.wing_availability.clear()
	for wing in popup.WINGS:
		popup.wing_availability[wing] = 0
	popup.plan = {"previewId": "11111111-1111-4111-8111-111111111111", "requiredWings": [], "stats": {"hp": {"mode": "equal", "guaranteedIV": 31}, "atk": {"mode": "reroll", "guaranteedIV": null}}}
	popup._render()
	_check(not popup.confirm_button.disabled and not popup.no_wings_button.visible, "Zero Wings still permits confirmation when no locks are selected")
	popup.recipient_lock = "atk"
	popup.donor_lock = "spd"
	popup.plan = {"previewId": "11111111-1111-4111-8111-111111111111", "shinyDonor": true, "requiredWings": [{"itemId": "muscle-wing", "quantity": 1}, {"itemId": "clever-wing", "quantity": 1}], "stats": {"atk": {"mode": "recipient_lock", "guaranteedIV": 31}, "spd": {"mode": "donor_lock", "guaranteedIV": 31}}}
	popup.wing_availability["muscle-wing"] = 1
	popup.wing_availability["clever-wing"] = 1
	popup._render()
	popup._ask_confirm()
	await process_frame
	var dialog: AetherConfirmationDialog
	for child: Node in popup.get_children():
		if child is AetherConfirmationDialog:
			dialog = child
	_check(dialog != null and dialog.option_checkbox.visible and dialog.confirm_button.disabled, "Shiny Donor requires additional acknowledgement")
	dialog.option_checkbox.button_pressed = true
	_check(not dialog.confirm_button.disabled, "Shiny acknowledgement enables explicit confirmation")
	dialog.canceled.emit()
	await process_frame
	popup.last_result = {"ivs": {"hp": 31, "atk": 31, "def": 18, "spa": 0, "spd": 31, "spe": 9}}
	popup.result_before = original["pokemon"]["ivs"]
	popup._render_result()
	_check((popup.result_grid.get_child(15) as Label).text.contains("+3") and (popup.result_grid.get_child(27) as Label).text.contains("-13"), "Actual IV gains and losses shown")
	for locale in ["en", "nl", "pt_BR"]:
		root.get_node("LocalizationManager").call("set_locale", locale)
		_check(not popup.help_label.text.begins_with("ui."), "Localized instructions " + locale)
		_check(not popup._reason(protected, true).begins_with("ui."), "Localized protection reasons " + locale)
	root.get_node("LocalizationManager").call("set_locale", "en")
	var auth := root.get_node("AuthService")
	auth.set("current_user", {"id": 12345})
	var service := root.get_node("AetheringService")
	service.call("clear_pending")
	_check(service.call("begin_confirmation", popup.plan, {"recipient": original, "donor": good}), "Retry receipt stored before transport")
	var first_id: String = service.get("pending")["requestId"]
	_check(not service.call("begin_confirmation", popup.plan, {}), "Unresolved request cannot be replaced")
	service.call("restore_pending")
	_check(service.get("pending")["requestId"] == first_id, "Retry retains UUID after restoration")
	auth.set("current_user", {"id": 99999})
	_check(service.call("restore_pending").is_empty(), "Retry receipts scoped to player account")
	auth.set("current_user", {"id": 12345})
	service.call("restore_pending")
	service.call("clear_pending")
	var source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(not source.contains('"health-wing": {"stat"'), "Wing removed from normal EV item UI")
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	for item_id in ["health-wing", "muscle-wing", "resist-wing", "genius-wing", "clever-wing", "swift-wing"]:
		_check(not overlay.call("_is_pokemon_usable_item_id", item_id), "No direct Pokémon use for " + item_id)
		_check(not overlay.call("_bag_item_can_use_from_bag", {"id": item_id, "category": "medicine"}), "No direct Bag use for " + item_id)
	overlay.set("root_control", overlay.get_node("Control"))
	overlay.call("open_market", {"id": "daycare_wing_merchant", "name": "Wing Merchant", "items": [{"itemId": "health-wing", "category": "medicine", "costs": [{"currency": "money", "amount": 10000, "baseAmount": 10000, "membershipDiscountPercent": 0}]}]})
	_check(overlay.get("market_selected_item").get("price") == 10000, "Merchant UI uses exact server price")
	for locale in ["en", "nl", "pt_BR"]:
		root.get_node("LocalizationManager").call("set_locale", locale)
		overlay.call("_apply_market_context_copy")
		_check(overlay.get("market_title_label").text == root.get_node("LocalizationManager").call("text", "ui.aethering.merchant"), "Localized merchant title " + locale)
	root.get_node("LocalizationManager").call("set_locale", "en")
	overlay.free()
	var daycare: PackedScene = load("res://scenes/overworld/kanto/routes/route5/daycare.tscn")
	_check(daycare != null, "Daycare scene loads with both NPCs")
	var instance := daycare.instantiate()
	_check(instance.get_node("Entities/NPCs/AetherResearcher").get("npc_definition_id") == "kanto_route_5_aethering_researcher", "Aethering NPC wired")
	_check(instance.get_node("Entities/NPCs/WingMerchant").get("market_id") == "daycare_wing_merchant", "Merchant uses existing shop NPC")
	instance.free()
	popup.free()
	print("AETHERING UI failures: ", failures)
	quit(1 if failures else 0)
