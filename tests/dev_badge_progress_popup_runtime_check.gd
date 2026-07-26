extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(root.get_node_or_null("BadgeProgressionService") != null, "badge progression service autoload is available")
	var player_save := root.get_node_or_null("PlayerSave")
	_check(player_save != null, "PlayerSave autoload is available")
	if player_save == null:
		quit(1)
		return
	player_save.call("apply_gym_badge_state", {
		"badges": [
			{"region": "kanto", "badgeId": "boulder", "earned": true},
			{"region": "kanto", "badgeId": "cascade", "earned": true},
			{"region": "kanto", "badgeId": "thunder", "earned": true},
			{"region": "kanto", "badgeId": "rainbow", "earned": false},
		],
	})
	_check(int(player_save.call("gym_badge_count")) == 3, "PlayerSave counts earned server badges")
	_check(bool(player_save.call("has_gym_badge", "kanto", "cascade")), "PlayerSave resolves earned badge ownership")
	_check(not bool(player_save.call("has_gym_badge", "kanto", "rainbow")), "PlayerSave keeps locked badges locked")

	var packed := load("res://scenes/interface/dev_badge_progress_popup.tscn") as PackedScene
	_check(packed != null, "developer badge popup loads at runtime")
	if packed == null:
		quit(1)
		return

	var popup := packed.instantiate() as DevBadgeProgressPopup
	root.add_child(popup)
	await process_frame
	popup.set_badge_state({
		"badges": [
			{"region": "kanto", "badgeId": "boulder", "earned": true},
			{"region": "kanto", "badgeId": "cascade", "earned": true},
			{"region": "kanto", "badgeId": "thunder", "earned": true},
		],
	})
	await process_frame

	var minimum_size := popup.get_combined_minimum_size()
	_check(
		minimum_size.x <= DevBadgeProgressPopup.POPUP_SIZE.x
		and minimum_size.y <= DevBadgeProgressPopup.POPUP_SIZE.y,
		"developer badge controls fit inside the popup (minimum %s)" % minimum_size
	)
	_check(popup.badge_buttons.size() == 8, "developer popup renders all eight Kanto badges")
	var boulder_button := popup.find_child("BoulderBadgeButton", true, false) as Button
	var earth_button := popup.find_child("EarthBadgeButton", true, false) as Button
	_check(boulder_button != null and boulder_button.tooltip_text.contains("Earned"), "earned badge is visibly marked")
	_check(earth_button != null and earth_button.tooltip_text.contains("Locked"), "unearned badge is visibly locked")
	_check(popup.find_child("GrantFirstThreeButton", true, false) != null, "first-three bulk developer action exists")
	_check(popup.find_child("GrantAllButton", true, false) != null, "grant-all developer action exists")
	_check(popup.find_child("ClearAllButton", true, false) != null, "clear-all developer action exists")

	popup.visible = true
	popup.close()
	await process_frame
	_check(not popup.visible, "developer badge popup closes cleanly")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
