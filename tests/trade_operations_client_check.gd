extends SceneTree

var failed := false


func _init() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/services/trade_service.gd")
	var realtime_source := FileAccess.get_file_as_string("res://scripts/services/trade_realtime_service.gd")
	var social_source := FileAccess.get_file_as_string("res://scripts/ui/friendlist_popup.gd")
	_check(service_source.contains("func load_trade_history"), "history service method")
	_check(service_source.contains("func load_trade_receipt"), "receipt service method")
	_check(service_source.contains("source.get(\"canCreate\", false)"), "account-specific rollout capability")
	_check(realtime_source.contains('call("load_capabilities", true)'), "capability refresh during reconnect recovery")
	_check(social_source.contains('label": "Trades"'), "trade history social tab")
	_check(social_source.contains("func _load_trade_receipt"), "participant receipt action")
	_check(not social_source.contains("/admin/api/trades"), "normal client excludes admin audit API")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("Missing Phase 12 client contract: %s" % label)
