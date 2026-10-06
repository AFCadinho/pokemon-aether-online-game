extends SceneTree

# Exercise the real item-use method; stub only the HTTP transport. Earlier
# cosmetic tests bypassed this response conversion and missed JSON null.

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Keep unrelated login pollers offline while the transport fixture is active.
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	# A conversion script error aborts its coroutine; fail instead of hanging.
	create_timer(5.0).timeout.connect(func() -> void:
		push_error("Item-use response check did not finish")
		quit(1)
	)
	var auth := root.get_node("AuthService")
	var gateway := root.get_node("GatewayApiConfig")
	var state := root.get_node("GameState")
	var previous_user: Dictionary = auth.current_user
	var previous_token: String = auth.session_token
	var previous_url: String = gateway.cached_url
	var previous_steps: int = state.repel_steps
	auth.current_user = {"id": 1}
	auth.session_token = "inventory-response-test"
	gateway.cached_url = "http://127.0.0.1:1"
	state.repel_steps = 175
	var inventory = load("res://tests/support/inventory_use_response_transport.gd").new()
	root.add_child(inventory)
	var components := {"thor-shirt": ["top", "Thor_Shirt"], "thor-trousers": ["bottom", "Thor_Trousers"], "thor-shoes": ["shoes", "Thor_Shoes"], "thor-hammer": ["cape", "Thor_Hammer"]}
	var granted: Array = []
	for item_id: String in components:
		granted.append({"itemId": item_id, "quantity": 1})
	inventory.response_body = {"itemId": "thor-outfit", "useAction": "open_item_bundle", "durationDays": 0, "creditAmount": 0, "repelSteps": null, "addedRepelSteps": 0, "wallet": null, "user": null, "guild": null, "mountBox": null, "grantedItems": granted, "inventory": {"items": granted}, "appearanceInventory": {"slotLimit": 8, "slotCounts": {}, "unlocks": []}}
	var result: Dictionary = await inventory.use_inventory_item("thor-outfit")
	_check(result.get("success", false), "Thor box accepts explicit null repelSteps")
	# JSON numbers are floats in Godot, including each quantity in the arrays.
	var expected_granted: Array = JSON.parse_string(JSON.stringify(granted))
	_check(result.get("grantedItems") == expected_granted and result.get("inventory") == expected_granted, "box returns all four granted parts to the Bag")
	_check(result.get("repelSteps") == 0 and state.repel_steps == 175, "non-Repel response defaults safely without clearing active Repel")
	for item_id: String in components:
		var unlocks := [{"slot": components[item_id][0], "appearanceId": components[item_id][1], "sourceItemId": item_id}]
		inventory.response_body["itemId"] = item_id
		inventory.response_body["useAction"] = "unlock_appearance"
		inventory.response_body["grantedItems"] = []
		inventory.response_body["appearanceInventory"] = {"slotLimit": 8, "slotCounts": {components[item_id][0]: 1}, "unlocks": unlocks}
		result = await inventory.use_inventory_item(item_id)
		_check(result.get("success", false) and result.get("appearanceUnlocks") == unlocks, item_id + " completes its wardrobe response")
		_check(result.get("appearanceSlotLimit") == 8 and result.get("appearanceSlotCounts").get(components[item_id][0]) == 1, item_id + " preserves slot information")
	inventory.response_body.erase("repelSteps")
	result = await inventory.use_inventory_item("thor-hammer")
	_check(result.get("repelSteps") == 0, "omitted repelSteps retains the existing zero fallback")
	for steps: int in [0, 100, 250, 10000]:
		inventory.response_body["itemId"] = "repel"
		inventory.response_body["useAction"] = "add_repel_steps"
		inventory.response_body["repelSteps"] = steps
		inventory.response_body["addedRepelSteps"] = 100
		result = await inventory.use_inventory_item("repel")
		_check(result.get("repelSteps") == steps and result.get("addedRepelSteps") == 100, "numeric Repel response preserved: %d" % steps)
	_check(inventory.request_count == 10, "each use sends exactly one request")
	inventory.response_body["usedRepelItems"] = 11
	inventory.response_body["addedRepelSteps"] = 2750
	inventory.response_body["repelSteps"] = 2750
	inventory.fail_next = true
	result = await inventory.use_inventory_item("max-repel", 11)
	_check(not result.get("success", false), "ambiguous batch request stays pending")
	result = await inventory.use_inventory_item("max-repel", 1)
	_check(result.get("usedRepelItems") == 11 and result.get("addedRepelSteps") == 2750, "batch response preserves consumed item count and full added charge")
	var initial: Dictionary = inventory.requests[10]
	var retry: Dictionary = inventory.requests[11]
	_check(JSON.parse_string(initial.body).quantity == 11 and initial.body == retry.body and initial.headers == retry.headers, "retry preserves original quantity and idempotency key even when the selected amount changes")
	await inventory.use_inventory_item("max-repel", 2)
	var next: Dictionary = inventory.requests[12]
	_check(JSON.parse_string(next.body).quantity == 2 and next.headers != retry.headers, "confirmed batch frees the next request to use a new amount")
	auth.current_user = previous_user
	auth.session_token = previous_token
	gateway.cached_url = previous_url
	state.repel_steps = previous_steps
	inventory.free()
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)
