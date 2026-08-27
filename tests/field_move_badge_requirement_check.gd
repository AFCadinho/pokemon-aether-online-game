extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var player_save := root.get_node_or_null("PlayerSave")
	var field_move_service := root.get_node_or_null("FieldMoveService")
	_check(player_save != null, "PlayerSave autoload is available")
	_check(field_move_service != null, "FieldMoveService autoload is available")
	if player_save == null or field_move_service == null:
		quit(1)
		return
	var original_badges: Array = player_save.get("earned_gym_badges").duplicate()
	var original_charms: Dictionary = field_move_service.get("owned_charm_moves").duplicate(true)
	player_save.get("earned_gym_badges").clear()
	field_move_service.set("owned_charm_moves", {
		"flash": "Flash Charm",
		"cut": "Cut Charm",
		"strength": "Strength Charm",
		"surf": "Surf Charm",
		"rock-smash": "Rock Smash Charm",
		"waterfall": "Waterfall Charm",
	})

	_check_required_badge(field_move_service, player_save, "flash", "boulder")
	_check_required_badge(field_move_service, player_save, "cut", "cascade")
	_check_required_badge(field_move_service, player_save, "strength", "rainbow")
	_check_required_badge(field_move_service, player_save, "surf", "soul")
	_check(
		bool(field_move_service.call("can_use_field_move", "rock-smash").get("success", false)),
		"Rock Smash remains outside the Gen I Kanto badge gates"
	)
	_check(
		bool(field_move_service.call("can_use_field_move", "waterfall").get("success", false)),
		"Waterfall remains outside the Gen I Kanto badge gates"
	)

	player_save.get("earned_gym_badges").assign(original_badges)
	field_move_service.set("owned_charm_moves", original_charms)
	quit(1 if failed else 0)


func _check_required_badge(field_move_service: Node, player_save: Node, move_id: String, badge_id: String) -> void:
	var blocked: Dictionary = field_move_service.call("can_use_field_move", move_id)
	_check(not bool(blocked.get("success", false)), "%s is blocked without its badge" % move_id)
	_check(str(blocked.get("errorCode", "")) == "field_move_badge_required", "%s returns a stable badge error" % move_id)
	_check(str(blocked.get("requiredBadge", "")) == badge_id, "%s requires the official Kanto badge" % move_id)

	player_save.get("earned_gym_badges").append("kanto:%s" % badge_id)
	var allowed: Dictionary = field_move_service.call("can_use_field_move", move_id)
	_check(bool(allowed.get("success", false)), "%s becomes usable after earning its badge" % move_id)
	player_save.get("earned_gym_badges").erase("kanto:%s" % badge_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	failed = true
	push_error("FAIL: %s" % message)
