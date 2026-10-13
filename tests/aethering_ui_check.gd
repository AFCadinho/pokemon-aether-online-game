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
	return {"pokemonId": id, "pokemon": {"speciesId": "eevee", "species": "eevee", "nickname": "Example " + str(id), "ivs": values}, "location": {"type": location, "boxIndex": 1}, "eggGroups": groups, "recipientAllowed": true, "donorAllowed": allowed, "donorBlockedReason": null, "shiny": false}

func _run() -> void:
	var popup = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	root.add_child(popup)
	await process_frame
	_check(popup != null, "Aethering popup compiles and builds")
	if popup == null:
		quit(1)
		return
	var original := _entry(1, ["ground", "fairy"], "party", {"hp": 31, "atk": 31, "def": 15, "spa": 0, "spd": 31, "spe": 22})
	var good := _entry(2, ["ground"], "box", {"hp": 31, "atk": 12, "def": 31, "spa": 0, "spd": 31, "spe": 12})
	var bad := _entry(3, ["water2"], "party", {})
	var protected := _entry(4, ["ground"], "box", {}, false)
	protected["donorBlockedReason"] = "aethering_donor_held_item"
	popup.candidates = [bad, good, original, protected]
	popup.recipient = original
	popup.resources_ready = true
	popup._render()
	_check(popup.compatible(original, good), "Both Recipient Egg Groups count")
	_check(not popup.compatible(original, bad), "Incompatible groups blocked")
	_check(popup.compatible({"eggGroups": ["ditto"]}, {"eggGroups": ["ditto"]}), "Ditto matches Ditto")
	_check(not popup.compatible({"eggGroups": ["ditto"]}, good), "Ditto has no breeding exception")
	popup._open_picker(true)
	if popup.picker_rows.is_empty():
		quit(1)
		return
	_check(popup.picker_rows[0]["pokemonId"] == 2, "Compatible donors sorted before unavailable candidates")
	popup._pick(0)
	_check(popup.donor["pokemonId"] == 2, "PC Donor selection")
	popup._open_picker(false)
	for index in range(popup.picker_rows.size()):
		if popup.picker_rows[index]["pokemonId"] == 2:
			popup._pick(index)
			break
	_check(popup.recipient["pokemonId"] == 2 and popup.recipient["location"]["type"] == "box", "PC Recipient selection")
	popup._open_picker(false)
	for index in range(popup.picker_rows.size()):
		if popup.picker_rows[index]["pokemonId"] == 1:
			popup._pick(index)
			break
	_check(popup.recipient["pokemonId"] == 1 and popup.donor.is_empty(), "Party Recipient selection invalidates Donor")
	popup.donor = good
	popup._lock_changed(2, false)
	_check(popup.donor_options.is_item_disabled(2), "Same-stat Donor lock disabled")
	popup._lock_changed(2, true)
	_check(popup.donor_lock == null, "Duplicate lock callback cannot change selection")
	popup._lock_changed(5, true)
	_check(popup.recipient_lock == "atk" and popup.donor_lock == "spd", "Two independent locks selected")
	popup.plan = {"previewId": "11111111-1111-4111-8111-111111111111", "shinyDonor": true, "requiredWings": [{"itemId": "muscle-wing", "quantity": 1}, {"itemId": "clever-wing", "quantity": 1}], "stats": {"hp": {"mode": "equal", "guaranteedIV": 31}, "atk": {"mode": "recipient_lock", "guaranteedIV": 31}, "spd": {"mode": "donor_lock", "guaranteedIV": 31}, "spe": {"mode": "reroll", "guaranteedIV": null}}}
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
	_check(popup.results.text.contains("(+3)") and popup.results.text.contains("(-13)"), "Actual IV gains and losses shown")
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
