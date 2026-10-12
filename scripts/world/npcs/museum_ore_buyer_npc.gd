@tool
extends "res://scripts/world/npcs/dialogue_npc.gd"

signal ore_sale_choice_resolved(accepted: bool)

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
const ICONS := preload("res://scripts/services/item_icon_resolver.gd")
var sale_in_flight := false
var pending_quote_id := ""
var pending_request_id := ""


func interact_with_player(_player: Node2D) -> void:
	if sale_in_flight:
		return
	sale_in_flight = true
	await _offer_sale()
	if is_instance_valid(self):
		sale_in_flight = false


func _ore_service() -> Node:
	return get_node("/root/MuseumOreService")


func _offer_sale() -> void:
	var synced := await _sync_position()
	if not bool(synced.get("success", false)):
		await GameErrorDialogService.show_response(synced)
		return
	# A lost response retries the already-confirmed transaction with its original
	# receipt ID, so newly acquired ores cannot be sold by an accidental replay.
	if not pending_request_id.is_empty():
		await _complete_sale()
		return
	var response: Dictionary = await _ore_service().get_quote()
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response)
		return
	var quote: Dictionary = response.get("body", {})
	if (quote.get("items", []) as Array).is_empty():
		await InventoryService.load_inventory()
		var wallet: Dictionary = await PlayerWalletService.load_wallet()
		if bool(wallet.get("success", false)):
			PlayerWalletService.apply_wallet_result(wallet)
		await show_dialogue([_text("empty")])
		return
	if not await _confirm_sale(quote):
		return
	pending_quote_id = str(quote.get("quoteId", ""))
	pending_request_id = "%s-%s-%s" % [Time.get_ticks_usec(), randi(), randi()]
	await _complete_sale()


func _complete_sale() -> void:
	var response: Dictionary = await _ore_service().sell_all(pending_quote_id, pending_request_id)
	if not bool(response.get("success", false)):
		if BackendErrorLocalizationService.error_code(response) in [
			"museum_ore_quote_changed", "item_reserved_for_trade", "item_reserved_for_loan", "reward_wallet_limit"
		]:
			pending_request_id = ""
			pending_quote_id = ""
		await GameErrorDialogService.show_response(response)
		return
	pending_request_id = ""
	pending_quote_id = ""
	var sale: Dictionary = response.get("body", {})
	if bool(sale.get("sold", false)):
		SfxManager.play("npc_shop_purchase")
		await show_dialogue([_text("sold", {"money": _money(int(sale.get("totalMoney", 0)))})])
	else:
		await show_dialogue([_text("empty")])


func _confirm_sale(quote: Dictionary) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	dialog.configure(display_name, _text("confirm", {"money": _money(int(quote.get("totalMoney", 0)))}),
		_text("sell_all"), LocalizationManager.text("common.cancel"))
	for item: Dictionary in quote.get("items", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = ICONS.load_icon(str(item.itemId))
		row.add_child(icon)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		label.text = "%s ×%d" % [ItemLocalization.display_name(str(item.itemId), str(item.get("name", item.itemId))), int(item.quantity)]
		row.add_child(label)
		var price := Label.new()
		price.add_theme_font_size_override("font_size", 13)
		price.text = _money(int(item.totalMoney)) + " ₽"
		row.add_child(price)
		dialog.add_custom_control(row)
	dialog.confirmed.connect(func(): ore_sale_choice_resolved.emit(true), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): ore_sale_choice_resolved.emit(false), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(560, 260 + 40 * (quote.get("items", []) as Array).size()))
	var accepted: bool = await ore_sale_choice_resolved
	layer.queue_free()
	return accepted


func _text(key: String, values: Dictionary = {}) -> String:
	return LocalizationManager.text("npc.museum.ore_buyer." + key, values)


func _sync_position() -> Dictionary:
	var world: Node = GameState.get_world()
	if world == null or not world.has_method("sync_player_position_for_world_action"):
		return {"success": false, "error": "The player position is not ready."}
	return await world.call("sync_player_position_for_world_action")


func _money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted
