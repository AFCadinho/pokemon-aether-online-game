@tool
extends DialogueNPC

const TOPIC_MENU := preload("res://scripts/ui/mentor_topic_menu.gd")
const Mounts := preload("res://scripts/services/mount_service.gd")
const GRID_MENU := preload("res://scripts/ui/mount_collector_grid.gd")
const OFFERS_PER_PAGE := GRID_MENU.OFFERS_PER_PAGE

var exchange_in_progress := false


func interact_with_player(_player: Node2D) -> void:
	if exchange_in_progress:
		return
	exchange_in_progress = true
	await _run_collector()
	exchange_in_progress = false


func _run_collector() -> void:
	await show_dialogue([LocalizationManager.text("ui.mount_collector.intro")], display_name)
	var page := 0
	while is_inside_tree():
		var service := get_node_or_null("/root/InventoryService")
		var response: Dictionary = await service.call("load_mount_collector")
		if not bool(response.get("success", false)):
			await GameErrorDialogService.show_response(response)
			return
		var catalog: Dictionary = response.get("catalog", {})
		var offers: Array = catalog.get("offers", [])
		var credit := int(catalog.get("voucherCredit", 100))
		if offers.is_empty():
			await show_dialogue([LocalizationManager.text("ui.mount_collector.empty")], display_name)
			return
		page = mini(page, (offers.size() - 1) / OFFERS_PER_PAGE)
		var choice := await _choose_offer(offers, page, credit)
		if choice.is_empty():
			return
		if choice == "next":
			page += 1
			continue
		if choice == "previous":
			page -= 1
			continue
		var offer: Dictionary = {}
		for value: Dictionary in offers:
			if str(value.get("itemId", "")) == choice:
				offer = value
				break
		if offer.is_empty() or not await _confirm_exchange(offer, credit):
			continue
		var result: Dictionary = await service.call("exchange_shiny_mount", choice)
		if not bool(result.get("success", false)):
			await GameErrorDialogService.show_response(result)
			return
		var exchange: Dictionary = result.get("exchange", {})
		var normal_name := _normal_name(offer)
		await show_dialogue([LocalizationManager.text("ui.mount_collector.received", {
			"mount": normal_name, "credit": int(exchange.get("voucherCredit", credit))
		})], display_name)
		get_tree().call_group("ui_overlay", "add_item_reward_notification", str(exchange.get("rewardItemId", "")), 1)
		get_tree().call_group("ui_overlay", "add_system_message", LocalizationManager.text("ui.mount_collector.received", {
			"mount": normal_name, "credit": int(exchange.get("voucherCredit", credit))
		}))
		SfxManager.play("item_received")


func _offer_name(offer: Dictionary) -> String:
	return Mounts.get_mount_display_name(str(offer.get("shinyMountId", "")))


func _normal_name(offer: Dictionary) -> String:
	return Mounts.get_mount_display_name(str(offer.get("normalMountId", "")))


func _choose_offer(offers: Array, page: int, credit: int) -> String:
	var menu := GRID_MENU.new()
	add_child(menu)
	var choice: String = await menu.choose_mount(offers, page, credit)
	menu.queue_free()
	return choice


func _confirmation_text(offer: Dictionary, credit: int) -> String:
	var text: String = LocalizationManager.text("ui.mount_collector.confirm", {
		"shiny": _offer_name(offer), "normal": _normal_name(offer), "credit": credit
	})
	text += "\n\n" + LocalizationManager.text("ui.mount_collector.binding_bound" if bool(offer.get("accountBound", false)) else "ui.mount_collector.binding_tradeable")
	if bool(offer.get("normalAlreadyOwned", false)):
		text += "\n\n" + LocalizationManager.text("ui.mount_collector.duplicate")
	return text


func _confirm_exchange(offer: Dictionary, credit: int) -> bool:
	var menu := TOPIC_MENU.new()
	add_child(menu)
	var choice: String = await menu.choose_topic(
		LocalizationManager.text("ui.mount_collector.title"), _confirmation_text(offer, credit),
		[{"id": "confirm", "label": LocalizationManager.text("ui.mount_collector.trade")}],
		"", LocalizationManager.text("ui.mount_collector.back"), 1, true
	)
	menu.queue_free()
	return choice == "confirm"
