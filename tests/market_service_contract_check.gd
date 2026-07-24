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
	_check_catalog_response_parsing()
	_check_purchase_response_parsing()
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


func _check_market_selection() -> void:
	var text := _read_text(MARKET_SERVICE_SCRIPT)
	_check_true(text.contains("func load_market(market_id: String) -> Dictionary:"), "market selection entrypoint")
	_check_true(text.contains('"standard", "standard_pokemart":'), "standard market aliases")
	_check_true(text.contains("Unsupported market id:"), "unsupported markets fail explicitly")


func _check_purchase_payload() -> void:
	var payload: Dictionary = service.build_purchase_payload("Poke Ball", 3)
	_check_equal(payload.get("itemId", ""), "poke-ball", "purchase payload item id")
	_check_equal(payload.get("quantity", 0), 3, "purchase payload quantity")

	var minimum_payload: Dictionary = service.build_purchase_payload("potion", 0)
	_check_equal(minimum_payload.get("quantity", 0), 1, "purchase payload minimum quantity")


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
				"items": [
					{
						"itemId": "poke-ball",
						"name": "Poke Ball",
						"category": "poke-balls",
						"shortDesc": "A device for catching Pokemon.",
						"costs": [{"currency": "money", "amount": 200}],
					},
				],
			},
		},
	})

	_check_equal(result.get("success", false), true, "catalog parse success")
	var market: Dictionary = result.get("market", {})
	_check_equal(market.get("id", ""), "standard_pokemart", "catalog market id")
	var items: Array = market.get("items", [])
	_check_equal(items.size(), 1, "catalog item count")
	var first_item: Dictionary = items[0]
	_check_equal(first_item.get("itemId", ""), "poke-ball", "catalog item id")
	_check_equal(((first_item.get("costs", []) as Array)[0] as Dictionary).get("amount", 0), 200, "catalog item price")


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


func _check_error_detail_extraction() -> void:
	_check_equal(
		service._extract_error({"detail": {"message": "Not enough money."}}, 400),
		"Not enough money.",
		"dictionary detail message"
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
