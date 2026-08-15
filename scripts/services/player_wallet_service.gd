extends Node

class_name PlayerWalletServiceNode

const PLAYER_WALLET_ENDPOINT := "/game/wallet"
const DEV_ADD_MONEY_ENDPOINT := "/game/dev/wallet/money"
const DEV_ADD_GEMS_ENDPOINT := "/game/dev/wallet/gems"
const DEV_ADD_AETHERITE_ENDPOINT := "/game/dev/wallet/aetherite"
const DEV_ADD_BATTLE_POINTS_ENDPOINT := "/game/dev/wallet/battle-points"
const WILD_BATTLE_REWARD_ENDPOINT := "/game/wallet/rewards/wild-battle"
const TRAINER_BATTLE_REWARD_ENDPOINT := "/game/wallet/rewards/trainer-battle"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_wallet() -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + PLAYER_WALLET_ENDPOINT,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	return _wallet_result_from_response(response)


func dev_add_money(amount: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if amount <= 0:
		return {
			"success": false,
			"error": "Amount must be positive.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_ADD_MONEY_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"amount": amount,
		})
	)
	return _wallet_result_from_response(response)


func dev_add_gems(amount: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if amount <= 0:
		return {
			"success": false,
			"error": "Amount must be positive.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_ADD_GEMS_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"amount": amount,
		})
	)
	return _wallet_result_from_response(response)


func dev_add_aetherite(amount: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if amount <= 0:
		return {
			"success": false,
			"error": "Amount must be positive.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_ADD_AETHERITE_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"amount": amount,
		})
	)
	return _wallet_result_from_response(response)


func dev_add_battle_points(amount: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if amount <= 0:
		return {
			"success": false,
			"error": "Amount must be positive.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + DEV_ADD_BATTLE_POINTS_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"amount": amount,
		})
	)
	return _wallet_result_from_response(response)


func award_wild_battle_money(battle_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if battle_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing battle id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + WILD_BATTLE_REWARD_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"battleId": battle_id,
		})
	)
	return _reward_claim_result_from_response(response)


func award_trainer_battle_rewards(battle_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if battle_id.strip_edges() == "":
		return {
			"success": false,
			"error": "Missing battle id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + TRAINER_BATTLE_REWARD_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify({
			"battleId": battle_id,
		})
	)
	return _reward_claim_result_from_response(response)


func apply_wallet_result(result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return

	var wallet: Dictionary = _dictionary_from_value(result.get("wallet", {}))
	PlayerSave.money = max(int(wallet.get("money", PlayerSave.money)), 0)
	PlayerSave.gems = max(int(wallet.get("gems", PlayerSave.gems)), 0)
	PlayerSave.aetherite = max(int(wallet.get("aetherite", PlayerSave.aetherite)), 0)
	PlayerSave.battle_points = max(int(wallet.get("battle_points", PlayerSave.battle_points)), 0)
	var party: Array = _array_from_value(result.get("party", []))
	if not party.is_empty():
		PlayerSave.replace_party_from_state(party)
	var badges: Dictionary = _dictionary_from_value(result.get("badges", {}))
	if not badges.is_empty():
		PlayerSave.apply_gym_badge_state(badges)
	var level_cap: Dictionary = _dictionary_from_value(result.get("pokemonLevelCap", {}))
	if not level_cap.is_empty():
		GameState.apply_pokemon_level_cap_state(level_cap)


func _wallet_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
	}


func _reward_claim_result_from_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var party: Dictionary = _dictionary_from_value(body.get("party", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"reward": _dictionary_from_value(body.get("reward", {})),
		"inventory": _dictionary_from_value(body.get("inventory", {})),
		"party": _array_from_value(party.get("party", [])),
		"pokemonLevelCap": _dictionary_from_value(party.get("pokemonLevelCap", {})),
		"badges": _dictionary_from_value(body.get("badges", {})),
		"gymBadgeAward": _dictionary_from_value(body.get("gymBadgeAward", {})),
		"trainerProgress": _dictionary_from_value(body.get("trainerProgress", {})),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _request_result_message(result: int) -> String:
	return BackendErrorLocalizationService.transport_message(result)
