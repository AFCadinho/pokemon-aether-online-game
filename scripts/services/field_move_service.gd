extends Node

class_name FieldMoveServiceNode

const MoveIdResolverScript := preload("res://scripts/data/move_id_resolver.gd")

signal owned_charms_changed

const DIRECT_FIELD_MOVE_DEFINITIONS := {
	"flash": {
		"name": "Flash",
		"description": "Light the area around you in dark overworld locations.",
	},
	"rain-dance": {
		"name": "Rain Dance",
		"description": "Summon rain on the current weather-enabled overworld map.",
	},
	"snowscape": {
		"name": "Snowscape",
		"description": "Summon snow on the current weather-enabled overworld map.",
	},
	"sunny-day": {
		"name": "Sunny Day",
		"description": "Clear rain or snow on the current weather-enabled overworld map.",
	},
}
const WEATHER_FIELD_MOVES: Array[String] = ["rain-dance", "snowscape", "sunny-day"]
const FIELD_MOVE_REQUIRED_HMS := {
	"cut": "hm-cut",
	"defog": "hm-defog",
	"dive": "hm-dive",
	"flash": "hm-flash",
	"rock-climb": "hm-rock-climb",
	"rock-smash": "hm-rock-smash",
	"strength": "hm-strength",
	"surf": "hm-surf",
	"waterfall": "hm-waterfall",
	"whirlpool": "hm-whirlpool",
}
const KANTO_FIELD_MOVE_BADGES := {
	"flash": "boulder",
	"cut": "cascade",
	"strength": "rainbow",
	"surf": "soul",
}
const WEATHER_ACTION_ENDPOINT := "/world/weather/action"
const DEVELOPER_WEATHER_ENDPOINT := "/world/weather/developer"
const REQUEST_TIMEOUT_SECONDS := 8.0

var owned_charm_moves: Dictionary = {}
var owned_hm_item_ids: Dictionary = {}


func _ready() -> void:
	if not InventoryService.inventory_changed.is_connected(update_owned_charms_from_inventory):
		InventoryService.inventory_changed.connect(update_owned_charms_from_inventory)
	if InventoryService.inventory_loaded:
		update_owned_charms_from_inventory(InventoryService.cached_inventory_items)
	else:
		refresh_owned_charms.call_deferred()


func refresh_owned_charms() -> void:
	if not AuthService.is_authenticated():
		return
	await InventoryService.load_inventory()


func update_owned_charms_from_inventory(items_value: Variant) -> void:
	owned_charm_moves.clear()
	owned_hm_item_ids.clear()
	if not (items_value is Array):
		owned_charms_changed.emit()
		return
	var items: Array = items_value as Array
	for item_value: Variant in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value as Dictionary
		if str(item.get("machineKind", item.get("machine_kind", ""))).strip_edges().to_lower() != "hm":
			continue
		var item_id := str(item.get("itemId", item.get("item_id", ""))).strip_edges().to_lower()
		if item_id != "":
			owned_hm_item_ids[item_id] = true
	for item_value: Variant in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value as Dictionary
		var move_id := _normalize_move_id(str(item.get("fieldMove", item.get("field_move", ""))))
		if move_id != "":
			owned_charm_moves[move_id] = {
				"itemName": str(item.get("name", "Field Move Charm")),
				"requiredHm": str(item.get("requiredHm", item.get("required_hm", ""))).strip_edges().to_lower(),
			}
	owned_charms_changed.emit()

func find_party_pokemon_for_move(move_id: String) -> Pokemon:
	var normalized_move_id := _normalize_move_id(move_id)
	if normalized_move_id == "":
		return null

	for pokemon: Pokemon in PlayerSave.party:
		if pokemon != null and _pokemon_knows_move(pokemon, normalized_move_id):
			return pokemon
	return null


func can_use_field_move(move_id: String) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var badge_error := _required_badge_error(normalized_move_id)
	if not badge_error.is_empty():
		return badge_error
	var hm_error := _required_hm_error(normalized_move_id)
	if not hm_error.is_empty():
		return hm_error
	var charm_value: Variant = owned_charm_moves.get(normalized_move_id, {})
	var charm: Dictionary = charm_value as Dictionary if charm_value is Dictionary else {}
	var charm_name := str(charm.get("itemName", ""))
	if charm_name != "":
		return {
			"success": true,
			"source": "charm",
			"itemName": charm_name,
		}
	var pokemon := find_party_pokemon_for_move(move_id)
	if pokemon == null:
		var move_name := ContentLocalization.display_name(
			"moves",
			normalized_move_id,
			_format_move_name(normalized_move_id)
		)
		return {
			"success": false,
			"errorCode": "field_move_not_known",
			"error": LocalizationManager.text(
				"ui.field_move.error.unavailable",
				{"move": move_name}
			),
		}
	return {
		"success": true,
		"source": "pokemon",
		"pokemon": pokemon,
	}


func is_direct_field_move(move_id: String) -> bool:
	return DIRECT_FIELD_MOVE_DEFINITIONS.has(_normalize_move_id(move_id))


func get_direct_field_move_definition(move_id: String) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var definition_value: Variant = DIRECT_FIELD_MOVE_DEFINITIONS.get(normalized_move_id, {})
	return (definition_value as Dictionary).duplicate(true) if definition_value is Dictionary else {}


func can_use_direct_field_move(move_id: String, pokemon_id := 0) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	if not is_direct_field_move(normalized_move_id):
		return {
			"success": false,
			"error": "%s is not a directly usable overworld move." % _format_move_name(normalized_move_id),
		}
	if pokemon_id <= 0:
		return can_use_field_move(normalized_move_id)
	var badge_error := _required_badge_error(normalized_move_id)
	if not badge_error.is_empty():
		return badge_error
	var hm_error := _required_hm_error(normalized_move_id)
	if not hm_error.is_empty():
		return hm_error

	for pokemon: Pokemon in PlayerSave.party:
		if pokemon == null or pokemon.owned_pokemon_id != pokemon_id:
			continue
		if not _pokemon_knows_move(pokemon, normalized_move_id):
			return {
				"success": false,
				"error": "%s no longer knows %s." % [pokemon.species, _format_move_name(normalized_move_id)],
			}
		return {
			"success": true,
			"source": "pokemon",
			"pokemon": pokemon,
		}
	return {
		"success": false,
		"error": "That Pokemon is no longer in your party.",
	}


func use_direct_field_move(move_id: String, pokemon_id := 0) -> Dictionary:
	var normalized_move_id := _normalize_move_id(move_id)
	var availability := can_use_direct_field_move(normalized_move_id, pokemon_id)
	if not bool(availability.get("success", false)):
		return availability
	if normalized_move_id in WEATHER_FIELD_MOVES:
		return await _use_weather_field_move(normalized_move_id, availability)
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("use_direct_field_move"):
		return {"success": false, "error": "The overworld is not ready."}
	var result_value: Variant = world.call("use_direct_field_move", normalized_move_id, availability)
	if not (result_value is Dictionary):
		return {"success": false, "error": "The overworld action returned an invalid result."}
	return result_value as Dictionary


func _use_weather_field_move(move_id: String, availability: Dictionary) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var source := str(availability.get("source", "pokemon"))
	var pokemon_id := 0
	var pokemon: Pokemon = availability.get("pokemon") as Pokemon
	if source == "pokemon" and pokemon != null:
		pokemon_id = pokemon.owned_pokemon_id
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response := await _request_json(
		base_url + WEATHER_ACTION_ENDPOINT,
		JSON.stringify({
			"moveId": move_id,
			"source": source,
			"pokemonId": pokemon_id,
		})
	)
	if not bool(response.get("success", false)):
		return response
	var body_value: Variant = response.get("body", {})
	var body: Dictionary = body_value as Dictionary if body_value is Dictionary else {}
	var weather_value: Variant = body.get("weather", {})
	var weather: Dictionary = weather_value as Dictionary if weather_value is Dictionary else {}
	SfxManager.play_field_move(move_id)
	return {
		"success": true,
		"message": "%s changed the map weather to %s." % [
			_format_move_name(move_id),
			str(weather.get("weather", "clear")).capitalize(),
		],
		"weather": weather,
		"cooldownEndsAt": str(body.get("cooldownEndsAt", "")),
		"playerCooldownEndsAt": str(body.get("playerCooldownEndsAt", body.get("cooldownEndsAt", ""))),
		"mapCooldownEndsAt": str(body.get("mapCooldownEndsAt", "")),
	}


func set_developer_world_weather(weather: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var normalized_weather := weather.strip_edges().to_lower()
	if normalized_weather == "":
		normalized_weather = "default"
	if normalized_weather not in ["default", "clear", "rain", "snow"]:
		return {"success": false, "error": "Unsupported overworld weather."}
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response := await _request_json(
		base_url + DEVELOPER_WEATHER_ENDPOINT,
		JSON.stringify({"weather": normalized_weather})
	)
	if not bool(response.get("success", false)):
		return response
	var body_value: Variant = response.get("body", {})
	var body: Dictionary = body_value as Dictionary if body_value is Dictionary else {}
	var weather_value: Variant = body.get("weather", {})
	var weather_state: Dictionary = weather_value as Dictionary if weather_value is Dictionary else {}
	return {
		"success": true,
		"weather": weather_state,
	}


func _request_json(url: String, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error: Error = request.request(url, GatewayApiConfig.get_json_headers(), HTTPClient.METHOD_POST, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": BackendErrorLocalizationService.message({"code": "service_unavailable"}),
			"diagnosticError": error_string(error),
		}
	var result: Array = await request.request_completed
	request.queue_free()
	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": BackendErrorLocalizationService.transport_message(request_result),
		}
	var parsed_body: Variant = JSON.parse_string(response_text)
	var parsed_dictionary: Dictionary = parsed_body as Dictionary if parsed_body is Dictionary else {}
	if response_code < 200 or response_code >= 300:
		return BackendErrorLocalizationService.decorate({
			"success": false,
			"status": response_code,
			"body": parsed_dictionary,
		})
	return {"success": true, "status": response_code, "body": parsed_dictionary}


func _pokemon_knows_move(pokemon: Pokemon, move_id: String) -> bool:
	for move_value: Variant in pokemon.moves:
		if MoveIdResolverScript.value_matches(move_value, move_id):
			return true
	return false


func _normalize_move_id(value: String) -> String:
	return MoveIdResolverScript.normalize(value)


func _format_move_name(move_id: String) -> String:
	return _normalize_move_id(move_id).replace("-", " ").capitalize()


func _format_hm_name(item_id: String) -> String:
	var move_name := item_id.strip_edges().to_lower().trim_prefix("hm-").replace("-", " ").capitalize()
	return "HM %s" % move_name


func _required_hm_error(move_id: String) -> Dictionary:
	var required_hm_item_id := str(FIELD_MOVE_REQUIRED_HMS.get(move_id, ""))
	if required_hm_item_id.is_empty() or owned_hm_item_ids.has(required_hm_item_id):
		return {}
	return {
		"success": false,
		"errorCode": "field_move_hm_required",
		"error": LocalizationManager.text(
			"ui.field_move.error.hm_required",
			{"hm": _format_hm_name(required_hm_item_id)}
		),
		"requiredHm": required_hm_item_id,
	}


func _required_badge_error(move_id: String) -> Dictionary:
	var badge_id := str(KANTO_FIELD_MOVE_BADGES.get(move_id, ""))
	if badge_id.is_empty() or PlayerSave.has_gym_badge("kanto", badge_id):
		return {}
	var badge_name := LocalizationManager.text("ui.gym_badge.%s" % badge_id)
	return {
		"success": false,
		"errorCode": "field_move_badge_required",
		"error": LocalizationManager.text(
			"ui.field_move.error.badge_required",
			{"badge": badge_name}
		),
		"requiredBadge": badge_id,
		"requiredBadgeRegion": "kanto",
	}
