extends SceneTree

var failures := 0


func _init() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/services/gift_code_service.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")

	_check(service_source.contains('const REDEEM_ENDPOINT := "/game/gift-codes/redeem"'), "Gift code service uses the authoritative redeem endpoint")
	_check(service_source.contains('"requestId": normalized_request_id'), "Gift code requests are idempotent")
	_check(service_source.contains("PlayerSave.replace_party_from_state(party)"), "Gift code response applies Party state")
	_check(service_source.contains("PlayerSave.gems"), "Gift code response applies Wallet state")
	_check(project_source.contains('GiftCodeService="*res://scripts/services/gift_code_service.gd"'), "Gift code service is registered")
	_check(overlay_source.contains("GiftCodeService.redeem(code)"), "Trainer Card submits through the gift code service")
	_check(overlay_source.contains("bag_inventory_items = _normalize_bag_inventory_items"), "Redeemed Bag rewards refresh immediately")
	_check(overlay_source.contains("add_system_message"), "Successful redemption produces a System message")
	_check(
		overlay_source.contains("_show_gift_code_reward_notifications")
		and overlay_source.contains("add_currency_reward_notification("),
		"Redeemed items and currency use reward cards"
	)

	if failures == 0:
		print("Gift code service contract checks passed.")
		quit(0)
	else:
		push_error("%d gift code service contract check(s) failed." % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
