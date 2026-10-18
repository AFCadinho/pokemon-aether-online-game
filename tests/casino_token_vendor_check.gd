extends SceneTree
var failed := false

class FakeCounterService extends Node:
	var casino_pending_purchase: Dictionary = {}
	var wallet := {"money": 10000, "casino_tokens": 0}
	var purchases: Array[int] = []
	var fail_load := false
	func load_casino_tokens() -> Dictionary:
		if fail_load:
			return {"success": false, "error": "Fixture unavailable"}
		return {"success": true, "wallet": wallet.duplicate(), "unitPrice": 100, "offers": [
			{"tokenAmount": 10, "moneyCost": 1000}, {"tokenAmount": 50, "moneyCost": 5000},
			{"tokenAmount": 100, "moneyCost": 10000}, {"tokenAmount": 500, "moneyCost": 50000}]}
	func purchase_casino_tokens(amount: int) -> Dictionary:
		purchases.append(amount)
		await get_tree().process_frame
		wallet.money -= amount * 100
		wallet.casino_tokens += amount
		casino_pending_purchase.clear()
		return {"success": true, "wallet": wallet.duplicate(), "purchase": {"tokenAmount": amount, "moneyCost": amount * 100}}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var wallet_script: Script = load("res://scripts/services/player_wallet_service.gd")
	var wallet_service: Node = wallet_script.new()
	root.add_child(wallet_service)
	var save := root.get_node("PlayerSave")
	var previous_money: int = save.money
	var previous_tokens: int = save.casino_tokens
	var request := {"tokenAmount": 50, "requestId": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}
	wallet_service.casino_pending_purchase = request.duplicate()
	var result: Dictionary = wallet_service._finish_casino_purchase({"success": false, "status": 0})
	_check(result.get("retryRequired", false) and wallet_service.casino_pending_purchase == request, "Transport failure retains the original purchase id")
	result = wallet_service._finish_casino_purchase({"success": true, "status": 200, "body": {}})
	_check(result.get("retryRequired", false) and wallet_service.casino_pending_purchase == request, "Malformed successful response cannot cause a second charge")
	result = wallet_service._finish_casino_purchase({"success": false, "status": 403})
	_check(result.get("retryRequired", false) and wallet_service.casino_pending_purchase == request, "An upstream rejection does not discard an uncertain purchase")
	result = wallet_service._finish_casino_purchase({"success": false, "status": 503})
	_check(result.get("retryRequired", false) and wallet_service.casino_pending_purchase == request, "Server failure retains uncertain purchase")
	result = wallet_service._finish_casino_purchase({"success": true, "body": {"wallet": {"money": 1, "casino_tokens": 999}, "purchase": {"tokenAmount": 50, "requestId": "different-request"}}})
	_check(result.get("retryRequired", false) and save.money == previous_money and save.casino_tokens == previous_tokens, "An unrelated receipt cannot alter the wallet")
	result = wallet_service._finish_casino_purchase({"success": true, "body": {"wallet": {"money": 5000, "casino_tokens": 50}, "purchase": request.duplicate()}})
	_check(result.success and wallet_service.casino_pending_purchase.is_empty(), "Matching receipt resolves pending purchase")
	_check(save.money == 5000 and save.casino_tokens == 50, "Only authoritative wallet updates are applied")
	wallet_service.casino_pending_purchase = request.duplicate()
	wallet_service._finish_casino_purchase({"success": false, "status": 400, "error": "Not enough money", "body": {"detail": {"code": "not_enough_money"}}})
	_check(wallet_service.casino_pending_purchase.is_empty(), "Definitive rejection allows choosing a different bundle")
	save.money = previous_money
	save.casino_tokens = previous_tokens
	wallet_service.queue_free()

	var counter_script: Script = load("res://scripts/ui/casino_token_counter.gd")
	var counter: CanvasLayer = counter_script.new()
	var fake := FakeCounterService.new()
	root.add_child(fake)
	counter.service = fake
	root.add_child(counter)
	await process_frame
	_check(counter.choice.item_count == 4 and not counter.dialog.confirm_button.disabled, "All four fixed-price bundles are available")
	counter.choice.select(3)
	counter.choice.item_selected.emit(3)
	_check(counter.dialog.confirm_button.disabled, "Unaffordable bundles cannot be purchased")
	counter.choice.select(1)
	counter.choice.item_selected.emit(1)
	var closes := [0]
	counter.finished.connect(func(): closes[0] += 1)
	counter.dialog.confirm_button.pressed.emit()
	_check(counter.busy and counter.dialog.confirm_button.disabled and counter.dialog.visible, "Purchase cannot be double-clicked and remains visible")
	counter._cancel()
	_check(closes[0] == 0, "Escape cannot abandon a purchase in progress")
	for frame in range(3):
		await process_frame
	_check(fake.purchases == [50] and counter.wallet.money == 5000 and counter.wallet.casino_tokens == 50, "Selected bundle is purchased and balances refresh")
	fake.casino_pending_purchase = {"tokenAmount": 100, "requestId": "fixture"}
	await counter._load_catalog()
	_check(counter.choice.disabled and counter.choice.selected == 2 and not counter.dialog.confirm_button.disabled, "Reopening an uncertain purchase preserves its selected bundle for retry")
	counter._cancel()
	_check(closes[0] == 1, "Closing completes the NPC interaction")
	counter.queue_free()
	var unavailable: CanvasLayer = counter_script.new()
	fake.fail_load = true
	unavailable.service = fake
	root.add_child(unavailable)
	await process_frame
	_check(unavailable.dialog.confirm_button.disabled and not unavailable.dialog.cancel_button.disabled, "A failed catalog load cannot purchase and can be closed")
	unavailable.queue_free()
	fake.queue_free()

	var scene: Node2D = load("res://scenes/overworld/kanto/towns/celadon_city/game_corner.tscn").instantiate()
	var iris: Node2D = scene.get_node("Entities/NPCs/HostIris")
	_check(iris.get_script().resource_path == "res://scripts/world/npcs/casino_token_vendor.gd" and iris.position == Vector2(432, 176), "Iris uses token vendor behavior at the server-authorized counter")
	_check(iris.manual_interaction_reach_tiles == 3 and iris.get_node("InteractionArea").position == Vector2(0, 64), "Counter interaction reaches the customer side")
	var vendor_source := FileAccess.get_file_as_string(iris.get_script().resource_path)
	_check(vendor_source.find("save_current_player_state_now") < vendor_source.find("COUNTER.new()"), "Counter saves the player's position before opening")
	scene.free()
	await process_frame
	print("CASINO_TOKEN_VENDOR ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
