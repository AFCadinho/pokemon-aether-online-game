extends SceneTree

const TradeServiceScript := preload("res://scripts/services/trade_service.gd")

var failed := false
var service: Node


func _init() -> void:
	service = TradeServiceScript.new()
	_check_capability_normalization()
	_check_capability_defaults()
	_check_snapshot_parsing()
	_check_invitation_contract()
	await _check_capabilities_require_authentication()

	service.free()
	quit(1 if failed else 0)


func _check_capability_normalization() -> void:
	var capabilities: Dictionary = service.normalize_capabilities({
		"enabled": true,
		"canCreate": true,
		"rolloutMode": "alpha",
		"userAccess": true,
		"maxPokemonPerSide": 5,
		"allowHeldItems": false,
		"requiresSameMap": true,
		"inviteExpiresInSeconds": 45,
		"reconnectGraceSeconds": 60,
	})

	_check_equal(capabilities.get("enabled", false), true, "enabled capability")
	_check_equal(capabilities.get("rolloutMode", ""), "alpha", "rollout mode capability")
	_check_equal(capabilities.get("userAccess", false), true, "user rollout access capability")
	_check_equal(capabilities.get("maxPokemonPerSide", 0), 5, "max Pokemon capability")
	_check_equal(capabilities.get("inviteExpiresInSeconds", 0), 45, "invite expiry capability")
	_check_equal(capabilities.get("reconnectGraceSeconds", 0), 60, "reconnect grace capability")


func _check_capability_defaults() -> void:
	var capabilities: Dictionary = service.normalize_capabilities({
		"maxPokemonPerSide": 999,
		"inviteExpiresInSeconds": 0,
		"reconnectGraceSeconds": -1,
	})

	_check_equal(capabilities.get("enabled", true), false, "disabled default")
	_check_equal(capabilities.get("maxPokemonPerSide", 0), 5, "max Pokemon clamp")
	_check_equal(capabilities.get("allowHeldItems", true), false, "held item default")
	_check_equal(capabilities.get("requiresSameMap", false), true, "same map default")
	_check_equal(capabilities.get("inviteExpiresInSeconds", 0), 1, "invite expiry minimum")
	_check_equal(capabilities.get("reconnectGraceSeconds", 0), 1, "reconnect grace minimum")


func _check_snapshot_parsing() -> void:
	var snapshot: Dictionary = service.normalize_trade_snapshot({"tradeId": "trade-1", "status": "active", "revision": 3, "lastEventSeq": 4, "participants": [{"userId": 1}], "offers":[{"userId":1,"pokemon":[{"pokemonId":7}]}]})
	_check_equal(snapshot.get("tradeId", ""), "trade-1", "trade snapshot id")
	_check_equal(snapshot.get("revision", 0), 3, "trade snapshot revision")
	_check_equal(snapshot.get("offers", []).size(), 1, "trade offers parsed")
	var events: Dictionary = service.normalize_trade_events({"tradeId": "trade-1", "revision": 3, "lastEventSeq": 4, "afterSeq": 2, "limit": 500, "events": [{"eventSeq": 3}]})
	_check_equal(events.get("limit", 0), 100, "trade event limit clamp")
	_check_equal(events.get("events", []).size(), 1, "trade event parsing")


func _check_invitation_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/services/trade_service.gd")
	_check_equal(source.contains("func create_invitation"), true, "create invitation command")
	_check_equal(source.contains("func accept_invitation"), true, "accept invitation command")
	_check_equal(source.contains("func decline_invitation"), true, "decline invitation command")
	_check_equal(source.contains("func cancel_invitation"), true, "cancel invitation command")
	_check_equal(source.contains("expectedRevision"), true, "revision precondition payload")
	_check_equal(source.contains("targetUsername"), true, "target username payload")
	_check_equal(source.contains("func replace_offer"), true, "complete offer replacement command")
	_check_equal(source.contains("pokemonIds"), true, "offer Pokemon ids payload")
	_check_equal(source.contains("func set_readiness"), true, "readiness command")
	_check_equal(source.contains("/%s/readiness"), true, "readiness endpoint")
	_check_equal(source.contains("func leave_trade"), true, "active and locked abandonment command")
	_check_equal(source.contains("func confirm_trade"), true, "locked review confirmation command")
	_check_equal(source.contains("lockedSnapshotHash"), true, "confirmation submits locked review hash")
	_check_equal(source.contains("func load_trade_history"), true, "participant trade history API")
	_check_equal(source.contains("func load_trade_receipt"), true, "participant trade receipt API")


func _check_capabilities_require_authentication() -> void:
	var result: Dictionary = await service.load_capabilities()
	_check_equal(result.get("success", true), false, "capability auth success")
	_check_equal(result.get("error", ""), "Not authenticated.", "capability auth error")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
