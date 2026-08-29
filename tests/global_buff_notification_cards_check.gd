extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const NOTIFICATION_STACK_SCRIPT_PATH := "res://scripts/ui/reward_notification_stack.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_script := load(OVERLAY_SCRIPT_PATH) as Script
	var stack_script := load(NOTIFICATION_STACK_SCRIPT_PATH) as Script
	_check(overlay_script != null and stack_script != null, "global buff notification scripts load")
	if overlay_script == null or stack_script == null:
		quit(1)
		return
	var overlay: Node = overlay_script.new()
	var stack := stack_script.new() as VBoxContainer
	overlay.set("global_buffs_panel", PanelContainer.new())
	overlay.set("global_buff_slots", HBoxContainer.new())
	stack.set("auto_expire", false)
	overlay.set("reward_notification_stack", stack)
	overlay.set("global_buffs_data", [
		{
			"id": "global_exp",
			"name_key": "ui.buff.global_exp.name",
			"state": "funding",
			"current": 0,
			"goal": 100000,
		},
		{
			"id": "global_heal",
			"name_key": "ui.buff.global_heal.name",
			"state": "available",
			"cooldownUntil": "",
		},
	])

	overlay.call("_apply_global_boost_state", {
		"current": 0,
		"goal": 100000,
		"active": true,
		"activeUntil": _future_timestamp(1800),
	}, "global_exp", false)
	_check(stack.get_child_count() == 0, "an active global boost at login does not show a stale card")
	overlay.call("_apply_global_boost_state", {
		"current": 10000,
		"goal": 100000,
		"active": false,
		"activeUntil": "",
	}, "global_exp", true)
	_check(stack.get_child_count() == 0, "ordinary global boost contributions do not show cards")

	var boost_expiry := _future_timestamp(3600)
	var active_boost := {
		"current": 0,
		"goal": 100000,
		"active": true,
		"activeUntil": boost_expiry,
	}
	overlay.call("_apply_global_boost_state", active_boost, "global_exp", true)
	_check(stack.get_child_count() == 1, "a newly activated global boost shows one card")
	var boost_card := stack.get_child(0) as PanelContainer
	_check(_label_text(boost_card, "RewardSubtitle") != "", "global boost cards show their activation status")
	_check(_detail_text(boost_card) == "1h", "global boost cards show a compact duration")
	_check(
		is_equal_approx(float(boost_card.get_meta("display_seconds", 0.0)), 6.0),
		"global boost cards stay visible for six seconds"
	)
	overlay.call("_apply_global_boost_state", active_boost, "global_exp", true)
	_check(stack.get_child_count() == 1, "the same global boost activation is deduplicated")

	var game_state := root.get_node_or_null("GameState")
	_check(game_state != null, "global buff notification checks can access GameState")
	var original_requests_enabled := bool(game_state.get("global_heal_requests_enabled"))
	game_state.set("global_heal_requests_enabled", false)
	var heal_message := {
		"eventId": "heal-notification-test",
		"displayName": "Nurse Joy",
		"expiresAt": _future_timestamp(300),
		"cooldownUntil": _future_timestamp(3600),
	}
	overlay.call("_receive_global_heal_request", heal_message, true)
	_check(stack.get_child_count() == 2, "Global Heal shows a card even when heal prompts are disabled")
	var heal_card := stack.get_child(0) as PanelContainer
	_check(
		_label_text(heal_card, "RewardSubtitle").contains("Nurse Joy"),
		"Global Heal cards identify the activating Trainer"
	)
	_check(
		is_equal_approx(float(heal_card.get_meta("display_seconds", 0.0)), 6.0),
		"Global Heal cards stay visible for six seconds"
	)
	overlay.call("_receive_global_heal_request", heal_message, true)
	_check(stack.get_child_count() == 2, "the same Global Heal event is deduplicated")
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	var sfx_source := FileAccess.get_file_as_string("res://scripts/services/sfx_manager.gd")
	_check(
		overlay_source.count('SfxManager.play("global_buff_activated")') == 1
			and overlay_source.contains("GLOBAL_BUFF_NOTIFICATION_SOUND_BATCH_SECONDS"),
		"global buff activations batch one sound call"
	)
	_check(
		sfx_source.contains('"global_buff_activated"')
			and sfx_source.contains('"path": "res://assets/audio/sfx/battle/capture_success.ogg"')
			and load("res://assets/audio/sfx/battle/capture_success.ogg") is AudioStream,
		"the subtle global buff sound is registered and importable"
	)
	game_state.set("global_heal_requests_enabled", original_requests_enabled)

	stack.free()
	(overlay.get("global_buffs_panel") as PanelContainer).free()
	(overlay.get("global_buff_slots") as HBoxContainer).free()
	overlay.free()
	quit(1 if failed else 0)


func _future_timestamp(seconds: int) -> String:
	return "%sZ" % Time.get_datetime_string_from_unix_time(
		int(Time.get_unix_time_from_system()) + seconds,
		true
	)


func _detail_text(card: PanelContainer) -> String:
	var detail := card.find_child("RewardDetail", true, false) as Label if card != null else null
	return detail.text if detail != null else ""


func _label_text(card: PanelContainer, node_name: String) -> String:
	var label := card.find_child(node_name, true, false) as Label if card != null else null
	return label.text if label != null else ""


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
