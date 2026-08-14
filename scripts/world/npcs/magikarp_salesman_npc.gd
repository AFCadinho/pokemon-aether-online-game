@tool
extends DialogueNPC

class_name MagikarpSalesmanNPC

signal purchase_confirmation_resolved(accepted: bool)

const ConfirmationScene := preload("res://scenes/interface/aether_confirmation_dialog.tscn")

@export var sale_id := "kanto_route_3_magikarp"
@export var success_dialogue_id := ""
@export var already_purchased_dialogue_id := ""
@export var insufficient_funds_dialogue_id := ""

var _interaction_active := false


func interact_with_player(_player: Node2D) -> void:
	if _interaction_active:
		return
	_interaction_active = true
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message(_get_dialogue_box())
		_interaction_active = false
		return

	var sale: Dictionary = await NpcPokemonSaleService.get_sale(sale_id)
	if not bool(sale.get("success", false)):
		await GameErrorDialogService.show_response(sale, "backend.error.npc_pokemon_sale")
		_interaction_active = false
		return
	if bool(sale.get("alreadyPurchased", false)):
		# Also reconciles the client after a purchase whose response was lost.
		await PlayerPartyStateService.refresh_party()
		await show_dialogue(await _resolve_lines(
			already_purchased_dialogue_id,
			["One exceptional Magikarp per customer. You already bought mine."]
		))
		_interaction_active = false
		return

	await show_dialogue()
	if not await _confirm_purchase(int(sale.get("price", 5000)), int(sale.get("level", 5))):
		_interaction_active = false
		return

	var result: Dictionary = await NpcPokemonSaleService.purchase(sale_id)
	if not bool(result.get("success", false)):
		if _error_code(result) == "npc_pokemon_purchase_insufficient_funds":
			await show_dialogue(await _resolve_lines(
				insufficient_funds_dialogue_id,
				["This premium Magikarp costs ₽5,000. Come back when your wallet is ready."]
			))
		else:
			await GameErrorDialogService.show_response(result, "backend.error.npc_pokemon_sale")
		_interaction_active = false
		return

	if bool(result.get("purchased", false)):
		await show_dialogue(await _resolve_lines(
			success_dialogue_id,
			["A brilliant investment! Treat Magikarp well and one day it may surprise you."]
		))
		get_tree().call_group(
			"ui_overlay",
			"add_system_message",
			LocalizationManager.text("ui.magikarp_sale.received")
		)
		SfxManager.play("item_received")
	else:
		await show_dialogue(await _resolve_lines(
			already_purchased_dialogue_id,
			["One exceptional Magikarp per customer. You already bought mine."]
		))
	_interaction_active = false


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)
	var metadata_sale_id := str(metadata.get("saleId", metadata.get("sale_id", ""))).strip_edges()
	if not metadata_sale_id.is_empty():
		sale_id = metadata_sale_id
	success_dialogue_id = _metadata_id(metadata, "successDialogueId", success_dialogue_id)
	already_purchased_dialogue_id = _metadata_id(
		metadata,
		"alreadyPurchasedDialogueId",
		already_purchased_dialogue_id
	)
	insufficient_funds_dialogue_id = _metadata_id(
		metadata,
		"insufficientFundsDialogueId",
		insufficient_funds_dialogue_id
	)


func _confirm_purchase(price: int, level: int) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var confirmation := ConfirmationScene.instantiate() as AetherConfirmationDialog
	layer.add_child(confirmation)
	confirmation.configure(
		LocalizationManager.text("ui.magikarp_sale.title"),
		LocalizationManager.text(
			"ui.magikarp_sale.confirm",
			{"level": level, "price": _format_money(price)}
		),
		LocalizationManager.text("ui.magikarp_sale.buy"),
		LocalizationManager.text("common.cancel")
	)
	confirmation.confirmed.connect(_resolve_confirmation.bind(true), CONNECT_ONE_SHOT)
	confirmation.canceled.connect(_resolve_confirmation.bind(false), CONNECT_ONE_SHOT)
	confirmation.popup_centered(Vector2i(540, 230))
	var accepted: bool = await purchase_confirmation_resolved
	layer.queue_free()
	return accepted


func _resolve_confirmation(accepted: bool) -> void:
	purchase_confirmation_resolved.emit(accepted)


func _metadata_id(metadata: Dictionary, key: String, current: String) -> String:
	var value := str(metadata.get(key, "")).strip_edges()
	return current if value.is_empty() else value


func _resolve_lines(dialogue_id: String, fallback: Array) -> Array[String]:
	return await NpcDialogueService.resolve_lines(dialogue_id, fallback, "MagikarpSalesmanNPC")


func _error_code(result: Dictionary) -> String:
	var body: Variant = result.get("body", {})
	if body is Dictionary:
		var detail: Variant = (body as Dictionary).get("detail", {})
		if detail is Dictionary:
			return str((detail as Dictionary).get("code", ""))
	return ""


func _format_money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = ",%s%s" % [digits.right(3), formatted]
		digits = digits.left(digits.length() - 3)
	return digits + formatted
