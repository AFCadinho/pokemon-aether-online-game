extends SceneTree

const MarketServiceScript := preload("res://scripts/services/market_service.gd")
const MARKET_SERVICE_SCRIPT := "res://scripts/services/market_service.gd"
const PROJECT_CONFIG := "res://project.godot"

var failed := false
var service: Node


func _init() -> void:
	service = MarketServiceScript.new()

	_check_service_is_autoloaded()
	_check_endpoints()
	_check_market_selection()
	_check_purchase_payload()
	_check_sale_payload()
	_check_catalog_response_parsing()
	_check_purchase_response_parsing()
	_check_sale_response_parsing()
	_check_error_detail_extraction()

	service.free()
	quit(1 if failed else 0)


func _check_service_is_autoloaded() -> void:
	var project_text := _read_text(PROJECT_CONFIG)
	_check_true(project_text.contains("MarketService=\"*res://scripts/services/market_service.gd\""), "MarketService is autoloaded")


func _check_endpoints() -> void:
	var text := _read_text(MARKET_SERVICE_SCRIPT)
	_check_true(text.contains("STANDARD_MARKET_ENDPOINT := \"/game/markets/standard\""), "catalog endpoint")
	_check_true(text.contains("STANDARD_MARKET_PURCHASE_ENDPOINT := \"/game/markets/standard/purchase\""), "purchase endpoint")
	_check_true(text.contains("STANDARD_MARKET_SALE_ENDPOINT := \"/game/markets/standard/sell\""), "sale endpoint")
	_check_true(text.contains("MARKET_ENDPOINT_TEMPLATE := \"/game/markets/%s\""), "named catalog endpoint")
	_check_true(text.contains("MARKET_PURCHASE_ENDPOINT_TEMPLATE := \"/game/markets/%s/purchase\""), "named purchase endpoint")


func _check_market_selection() -> void:
	var text := _read_text(MARKET_SERVICE_SCRIPT)
	_check_true(text.contains("func load_market(market_id: String) -> Dictionary:"), "market selection entrypoint")
	_check_true(text.contains('"standard", "standard_pokemart":'), "standard market aliases")
	_check_true(text.contains("return await _load_named_market(normalized_market_id)"), "named NPC markets load through the generic endpoint")
	_check_true(text.contains("func purchase_item(market_id: String, item_id: String"), "named NPC markets use a generic purchase entrypoint")


func _check_purchase_payload() -> void:
	var payload: Dictionary = service.build_purchase_payload("Poke Ball", 3)
	_check_equal(payload.get("itemId", ""), "poke-ball", "purchase payload item id")
	_check_equal(payload.get("quantity", 0), 3, "purchase payload quantity")

	var minimum_payload: Dictionary = service.build_purchase_payload("potion", 0)
	_check_equal(minimum_payload.get("quantity", 0), 1, "purchase payload minimum quantity")


func _check_sale_payload() -> void:
	var payload: Dictionary = service.build_sale_payload("Poke Ball", 2)
	_check_equal(payload.get("itemId", ""), "poke-ball", "sale payload item id")
	_check_equal(payload.get("quantity", 0), 2, "sale payload quantity")


func _check_catalog_response_parsing() -> void:
	var result: Dictionary = service.parse_market_catalog_response({
		"success": true,
		"body": {
			"market": {
				"id": "standard_pokemart",
				"name": "Standard Pokemart",
				"type": "pokemart",
				"locationId": "standard_pokemart",
				"locationName": "Pokemarts",
				"badgeCount": 5,
				"nextUnlockBadge": 6,
				"items": [
					{
						"itemId": "poke-ball",
						"name": "Poke Ball",
						"category": "poke-balls",
						"shortDesc": "A device for catching Pokemon.",
						"sellPrice": 100,
						"requiredBadges": 0,
						"available": true,
						"costs": [{
							"currency": "money",
							"amount": 190,
							"baseAmount": 200,
							"membershipDiscountPercent": 5,
						}],
					},
				],
			},
		},
	})

	_check_equal(result.get("success", false), true, "catalog parse success")
	var market: Dictionary = result.get("market", {})
	_check_equal(market.get("id", ""), "standard_pokemart", "catalog market id")
	_check_equal(market.get("badgeCount", -1), 5, "catalog badge count")
	_check_equal(market.get("nextUnlockBadge", -1), 6, "catalog next unlock badge")
	var items: Array = market.get("items", [])
	_check_equal(items.size(), 1, "catalog item count")
	var first_item: Dictionary = items[0]
	_check_equal(first_item.get("itemId", ""), "poke-ball", "catalog item id")
	_check_equal(first_item.get("sellPrice", 0), 100, "catalog item sale price")
	_check_equal(first_item.get("requiredBadges", -1), 0, "catalog item badge requirement")
	_check_equal(first_item.get("available", false), true, "catalog item availability")
	var first_cost := (first_item.get("costs", []) as Array)[0] as Dictionary
	_check_equal(first_cost.get("amount", 0), 190, "catalog item discounted price")
	_check_equal(first_cost.get("baseAmount", 0), 200, "catalog item base price")
	_check_equal(first_cost.get("membershipDiscountPercent", 0), 5, "catalog membership discount")


func _check_purchase_response_parsing() -> void:
	var result: Dictionary = service.parse_purchase_response({
		"success": true,
		"body": {
			"wallet": {"money": 600},
			"inventory": {"items": [{"itemId": "poke-ball", "quantity": 2}]},
			"purchase": {
				"marketId": "standard_pokemart",
				"itemId": "poke-ball",
				"quantity": 2,
				"unitPrice": 200,
				"totalPrice": 400,
			},
		},
	})

	_check_equal(result.get("success", false), true, "purchase parse success")
	_check_equal((result.get("wallet", {}) as Dictionary).get("money", 0), 600, "purchase wallet money")
	_check_equal((result.get("inventory", []) as Array).size(), 1, "purchase inventory size")
	_check_equal((result.get("purchase", {}) as Dictionary).get("totalPrice", 0), 400, "purchase total")


func _check_sale_response_parsing() -> void:
	var result: Dictionary = service.parse_sale_response({
		"success": true,
		"body": {
			"wallet": {"money": 800},
			"inventory": {"items": [{"itemId": "poke-ball", "quantity": 1}]},
			"sale": {
				"marketId": "standard_pokemart",
				"itemId": "poke-ball",
				"quantity": 2,
				"unitPrice": 100,
				"totalPrice": 200,
			},
		},
	})

	_check_equal(result.get("success", false), true, "sale parse success")
	_check_equal((result.get("wallet", {}) as Dictionary).get("money", 0), 800, "sale wallet money")
	_check_equal((result.get("inventory", []) as Array).size(), 1, "sale inventory size")
	_check_equal((result.get("sale", {}) as Dictionary).get("totalPrice", 0), 200, "sale total")


func _check_error_detail_extraction() -> void:
	_check_equal(
		service._extract_error({"detail": {"code": "not_enough_money", "message": "Private detail."}}, 400),
		"You do not have enough money.",
		"coded errors use the safe localized message"
	)


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		return

	failed = true
	push_error("FAIL %s" % message)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
