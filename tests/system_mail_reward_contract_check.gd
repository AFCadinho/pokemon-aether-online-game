extends SceneTree

var failures := 0


func _init() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/services/mail_service.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")

	_check(
		service_source.count('"wallet": _dictionary_from_value(_dictionary_from_value(body.get("wallet", {})).get("wallet", {}))') >= 2,
		"Mail claim responses expose the authoritative wallet state"
	)
	_check(
		overlay_source.count('PlayerWalletService.apply_wallet_result({"success": true, "wallet": wallet_value})') >= 3,
		"Mail claims apply wallet changes immediately"
	)
	_check(
		overlay_source.contains('"currency":')
		and overlay_source.contains("mail_attachment_list.add_child(_create_mail_attachment_row("),
		"Mail renders currency attachments"
	)
	_check(
		overlay_source.contains('in ["system", "admin"]'),
		"System mail cannot be replied to"
	)

	if failures == 0:
		print("System mail reward contract checks passed.")
		quit(0)
	else:
		push_error("%d system mail reward contract check(s) failed." % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
