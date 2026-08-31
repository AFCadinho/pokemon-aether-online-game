extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_save := root.get_node_or_null("PlayerSave")
	var localization_manager := root.get_node_or_null("LocalizationManager")
	_check(player_save != null, "PlayerSave autoload is available")
	_check(localization_manager != null, "LocalizationManager autoload is available")
	if player_save == null or localization_manager == null:
		quit(1)
		return
	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "en")

	var overlay_script := load(OVERLAY_SCRIPT_PATH) as GDScript
	_check(overlay_script != null, "Trainer Card overlay script loads")
	if overlay_script == null:
		quit(1)
		return
	var overlay := overlay_script.new() as CanvasLayer
	var overview := overlay.call("_create_trainer_card_stats_tab") as Control
	overlay.call("_apply_own_trainer_card_pvp", {
		"gamesPlayed": 12,
		"wins": 8,
		"losses": 4,
		"winRate": 66.7,
	})
	_check(
		_trainer_card_value(overview, "pvp_games") == "12"
		and _trainer_card_value(overview, "pvp_wins") == "8"
		and _trainer_card_value(overview, "pvp_losses") == "4"
		and _trainer_card_value(overview, "pvp_win_rate") == "66.7%",
		"local Trainer Card overview preserves real PvP games, wins and losses"
	)
	var boulder := {
		"id": "boulder",
		"name": "Boulder Badge",
		"texture": "res://assets/gym_badges/kanto_badges/Boulder_Badge.png",
	}
	player_save.call("apply_gym_badge_state", {"badges": []})
	var local_slot := overlay.call("_create_trainer_card_badge_slot", boulder) as PanelContainer
	_check(local_slot != null and local_slot.tooltip_text.contains("Locked"), "local Trainer Card starts an unearned badge locked")
	_check(_find_label(overview, "0 / 8") != null, "local Trainer Card overview starts with the current badge total")

	player_save.call("apply_gym_badge_state", {
		"badges": [{"region": "kanto", "badgeId": "boulder", "earned": true}],
	})
	overlay.call("_refresh_trainer_card_gym_badges")
	_check(local_slot != null and local_slot.tooltip_text.contains("Earned"), "local Trainer Card refreshes an earned badge")
	_check(_find_label(overview, "1 / 8") != null, "local Trainer Card overview refreshes its badge total")

	var public_panel := overlay.call("_create_public_trainer_gym_badges_panel", {
		"badges": {
			"badges": [
				{"region": "kanto", "badgeId": "boulder", "earned": true},
				{"region": "kanto", "badgeId": "cascade", "earned": false},
			],
		},
	}) as Control
	_check(_find_label(public_panel, "GYM BADGES · 1/8") != null, "public Trainer Card reports the correct earned badge count")
	_check(_find_tooltip(public_panel, "Boulder Badge · Earned") != null, "public Trainer Card shows another trainer's earned badge")
	_check(_find_tooltip(public_panel, "Cascade Badge · Locked") != null, "public Trainer Card keeps another trainer's unearned badge locked")

	if local_slot != null:
		local_slot.free()
	if overview != null:
		overview.free()
	if public_panel != null:
		public_panel.free()
	overlay.free()
	player_save.call("apply_gym_badge_state", {"badges": []})
	localization_manager.call("set_locale", original_locale)
	quit(1 if failed else 0)


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child: Node in node.get_children():
		var result := _find_label(child, text)
		if result != null:
			return result
	return null


func _find_tooltip(node: Node, text: String) -> Control:
	if node is Control and (node as Control).tooltip_text == text:
		return node as Control
	for child: Node in node.get_children():
		var result := _find_tooltip(child, text)
		if result != null:
			return result
	return null


func _trainer_card_value(overview: Control, field_id: String) -> String:
	if overview == null:
		return ""
	var label := overview.find_child(
		"TrainerCardValue_%s" % field_id,
		true,
		false
	) as Label
	return label.text if label != null else ""


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
