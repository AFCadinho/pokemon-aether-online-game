extends "res://scripts/world/map_metadata.gd"


const PORTAL_REFRESH_SECONDS := 5.0
const AETHER_CONFIRMATION_DIALOG_SCENE: PackedScene = preload("res://scenes/interface/aether_confirmation_dialog.tscn")

var portal_refresh_in_flight := false


func _ready() -> void:
	add_to_group("aether_clash_war_controller")
	super._ready()
	var timer := Timer.new()
	timer.name = "AetherClashPortalRefreshTimer"
	timer.wait_time = PORTAL_REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh_portals)
	add_child(timer)
	_refresh_portals.call_deferred()


func request_portal_entry(
	mode_id: String,
	_player: Node2D,
	portal: Node
) -> Dictionary:
	if mode_id != "guild_duel":
		return {
			"success": false,
			"error": _text("world.aether_clash.portal.battle_royale_unavailable"),
		}
	var guild_service := get_node_or_null("/root/GuildService")
	if guild_service == null or not guild_service.has_method("load_aether_clash_portal_sessions"):
		return {"success": false, "error": _text("world.aether_clash.portal.unavailable")}
	var sessions_result: Dictionary = await guild_service.call("load_aether_clash_portal_sessions")
	if not bool(sessions_result.get("success", false)):
		return sessions_result
	var sessions := _dictionary_array(sessions_result.get("sessions", []))
	if sessions.is_empty():
		if portal != null and portal.has_method("configure_mode_available"):
			portal.call("configure_mode_available", false)
		return {
			"success": false,
			"error": _text("world.aether_clash.portal.inactive"),
		}
	var selected := sessions[0] if sessions.size() == 1 else await _select_session(sessions)
	if selected.is_empty():
		return {"success": true, "cancelled": true}
	var challenge := selected.get("session", {}) as Dictionary
	var challenge_id := str(challenge.get("id", "")).strip_edges()
	if challenge_id.is_empty():
		return {"success": false, "error": _text("world.aether_clash.portal.unavailable")}

	var world := get_tree().get_first_node_in_group("world")
	if (
		world == null
		or not world.has_method("begin_authorized_teleport")
		or not world.has_method("apply_authorized_teleport_state")
		or not world.has_method("save_current_player_state_now")
	):
		return {"success": false, "error": _text("world.aether_clash.portal.unavailable")}
	var save_result: Dictionary = await world.call("save_current_player_state_now")
	if not bool(save_result.get("success", false)):
		return save_result
	var begin_result: Dictionary = await world.call("begin_authorized_teleport", true, true)
	if not bool(begin_result.get("success", false)):
		return begin_result
	var enter_result: Dictionary = await guild_service.call("enter_aether_clash_portal", challenge_id)
	if not bool(enter_result.get("success", false)):
		if world.has_method("cancel_authorized_teleport_effect"):
			world.call("cancel_authorized_teleport_effect")
		else:
			world.call("cancel_authorized_teleport")
		return enter_result
	if world.has_method("play_authorized_teleport_departure_effect"):
		await world.call("play_authorized_teleport_departure_effect")
	var apply_result: Dictionary = await world.call(
		"apply_authorized_teleport_state",
		enter_result.get("state", {})
	)
	if not bool(apply_result.get("success", false)):
		return apply_result
	return {
		"success": true,
		"role": str(enter_result.get("role", "spectator")),
		"session": enter_result.get("session", {}),
	}


func _refresh_portals() -> void:
	if portal_refresh_in_flight:
		return
	portal_refresh_in_flight = true
	var guild_service := get_node_or_null("/root/GuildService")
	var result: Dictionary = {}
	if guild_service != null and guild_service.has_method("load_aether_clash_portal_sessions"):
		result = await guild_service.call("load_aether_clash_portal_sessions")
	portal_refresh_in_flight = false
	var has_guild_duel := (
		bool(result.get("success", false))
		and not _dictionary_array(result.get("sessions", [])).is_empty()
	)
	var guild_portal := get_node_or_null("Entities/Interactables/GuildDuelPortal")
	if guild_portal != null and guild_portal.has_method("configure_mode_available"):
		guild_portal.call("configure_mode_available", has_guild_duel)
	var royale_portal := get_node_or_null("Entities/Interactables/BattleRoyalePortal")
	if royale_portal != null and royale_portal.has_method("configure_mode_available"):
		royale_portal.call("configure_mode_available", false)


func _select_session(sessions: Array[Dictionary]) -> Dictionary:
	var dialog := AETHER_CONFIRMATION_DIALOG_SCENE.instantiate() as AetherConfirmationDialog
	dialog.name = "AetherClashPortalSessionDialog"
	get_tree().current_scene.add_child(dialog)
	dialog.configure(
		_text("world.aether_clash.portal.choose_title"),
		_text("world.aether_clash.portal.choose_hint"),
		_text("world.aether_clash.portal.enter"),
		_text("common.cancel")
	)
	var choices := OptionButton.new()
	choices.name = "AetherClashPortalSessionSelect"
	choices.custom_minimum_size = Vector2(0, 42)
	for item: Dictionary in sessions:
		var challenge := item.get("session", {}) as Dictionary
		var challenger := challenge.get("challengerGuild", {}) as Dictionary
		var challenged := challenge.get("challengedGuild", {}) as Dictionary
		var role := str(item.get("role", "spectator"))
		choices.add_item("%s vs %s · %s" % [
			str(challenger.get("name", "Guild")),
			str(challenged.get("name", "Guild")),
			_text("world.aether_clash.portal.role.%s" % role),
		])
	dialog.style_option_button(choices)
	dialog.add_custom_control(choices)
	var resolution := {"finished": false, "confirmed": false}
	dialog.confirmed.connect(func() -> void:
		resolution["confirmed"] = true
		resolution["finished"] = true
	)
	dialog.canceled.connect(func() -> void: resolution["finished"] = true)
	dialog.popup_centered(Vector2i(580, 320))
	await dialog.visibility_changed
	while not bool(resolution["finished"]):
		await get_tree().process_frame
	var selected: Dictionary = {}
	if bool(resolution["confirmed"]) and choices.selected >= 0:
		selected = sessions[choices.selected].duplicate(true)
	dialog.queue_free()
	return selected


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _text(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key))
	return key
