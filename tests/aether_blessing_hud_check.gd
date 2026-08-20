extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var auth_service := root.get_node_or_null("AuthService")
	_check(auth_service != null, "Aether Blessing HUD check can access AuthService")
	if auth_service == null:
		quit(1)
		return

	var original_user: Dictionary = auth_service.get("current_user").duplicate(true)
	var expires_at := "%sZ" % Time.get_datetime_string_from_unix_time(
		int(Time.get_unix_time_from_system()) + (3 * 86400),
		true
	)
	auth_service.set("current_user", {
		"roles": [{"id": "blessed", "expiresAt": expires_at}],
	})

	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Aether Blessing HUD check loads the overlay")
	if packed == null:
		auth_service.set("current_user", original_user)
		quit(1)
		return

	var overlay := packed.instantiate()
	root.add_child(overlay)
	await process_frame
	overlay.call("set_personal_buffs", [{
		"id": "aether_blessing",
		"label": "AE",
		"name": "Legacy Blessing boost",
	}])

	var badge := overlay.get("player_status_membership_badge") as PanelContainer
	var status_panel := overlay.get("player_status_panel") as PanelContainer
	var active_buffs: Array = overlay.get("active_personal_buffs") as Array
	var shiny_bonus := active_buffs[0] as Dictionary if not active_buffs.is_empty() else {}
	var first_buff_slot := overlay.get_node_or_null(
		"Control/PersonalBuffsPanel/MarginContainer/Row/BuffSlots/BuffSlot1"
	) as Button
	var displayed_name := first_buff_slot.get_node_or_null("Content/NameLabel") as Label
	var displayed_time := first_buff_slot.get_node_or_null("Content/TimeLabel") as Label
	_check(badge != null and badge.visible, "active members see Blessed status in the mini Trainer Card")
	_check(
		badge != null
		and badge.tooltip_text.contains("Aether Blessing")
		and badge.tooltip_text.contains("×1.05"),
		"membership hover details disclose identity, duration, and Shiny benefit"
	)
	_check(
		status_panel != null and bool(status_panel.get_meta("aether_blessing_active", false)),
		"active membership applies the dedicated Trainer Card presentation"
	)
	_check(
		active_buffs.size() == 1
		and str(shiny_bonus.get("id", "")) == "aether_blessing_shiny_bonus",
		"membership exposes only its concrete Shiny effect as a personal boost"
	)
	_check(
		str(shiny_bonus.get("name_key", "")) == "ui.buff.aether_blessing_shiny.name"
		and str(shiny_bonus.get("compactRemaining", "")) != "",
		"5% Shiny communicates its effect immediately and keeps the membership countdown"
	)
	_check(
		displayed_name != null
		and displayed_name.text == str(overlay.call("_localized_buff_name", shiny_bonus))
		and displayed_time != null
		and displayed_time.text != ""
		and first_buff_slot.get_node_or_null("Content/BadgeLabel") == null
		and first_buff_slot.get_node_or_null("Content/Details/DescriptionLabel") == null,
		"expanded boost row shows one clean effect label with its remaining duration"
	)

	auth_service.set("current_user", {
		"roles": [{"id": "blessed", "expiresAt": "2020-01-01T00:00:00Z"}],
	})
	overlay.call("_refresh_personal_buffs_from_entitlements")
	active_buffs = overlay.get("active_personal_buffs") as Array
	_check(
		badge != null and not badge.visible and active_buffs.is_empty(),
		"expired membership disappears from both Trainer Card and personal boosts"
	)

	auth_service.set("current_user", original_user)
	overlay.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
