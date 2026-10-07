@tool
extends "res://scripts/world/npcs/gate_npc.gd"

signal purchase_confirmation_resolved(accepted: bool)

const ConfirmationScene := preload("res://scenes/interface/aether_confirmation_dialog.tscn")

@export var entry_direction := Vector2.RIGHT
## Garden bounds relative to the fixed passage anchor.
@export var garden_bounds := Rect2()

var guild_service: Node
var _interaction_active := false
var _access_check_active := false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if guild_service == null:
		guild_service = _root_service("GuildService")
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(_check_garden_membership)
	add_child(timer)
	if guild_service.has_signal("membership_changed"):
		guild_service.connect("membership_changed", _on_guild_context_changed)


func is_gate_open() -> bool:
	# Every crossing gets fresh membership authorization; the registrar stays
	# visible beside the passage instead of disappearing for established guilds.
	return false


func interact_with_player(_player: Node2D) -> void:
	if _interaction_active:
		return
	_interaction_active = true
	await _registration_dialogue()
	_interaction_active = false


func _registration_dialogue() -> void:
	var metadata: Dictionary = await _load_gate_metadata()
	if not bool(metadata.get("success", false)):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var result: Dictionary = await guild_service.call("load_base_registrar", npc_id)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result)
		return
	var state: Dictionary = result.get("registrar", {})
	if not bool(state.get("canPurchase", false)):
		await show_dialogue([_registration_message(state)])
		return
	if not await _confirm_purchase(state):
		return
	var world := get_tree().get_first_node_in_group("world")
	if world != null:
		var saved: Dictionary = await world.call("sync_player_position_for_world_action")
		if not bool(saved.get("success", false)):
			await GameErrorDialogService.show_response(saved)
			return
	var purchase: Dictionary = await guild_service.call("purchase_base", npc_id)
	if not bool(purchase.get("success", false)):
		await GameErrorDialogService.show_response(purchase)
		return
	var purchased_state: Dictionary = purchase.get("registrar", {})
	await show_dialogue([LocalizationManager.text("ui.guild_base.purchased", {
		"town": str(purchased_state.get("townName", "")),
	})])
	if bool(purchase.get("purchased", false)):
		SfxManager.play("npc_shop_purchase")


func on_route_gate_blocked(player: Node2D) -> void:
	if _interaction_active:
		return
	_interaction_active = true
	var lock_id := StringName("guild-garden-%d" % get_instance_id())
	GameState.acquire_overworld_input_lock(lock_id)
	await _cross_garden_gate(player)
	GameState.release_overworld_input_lock(lock_id)
	_interaction_active = false


func _cross_garden_gate(player: Node2D) -> void:
	if not _is_current_map():
		return
	var current_map: Node = GameState.current_map
	var anchor := get_node(guard_blocking_anchor_path) as Node2D
	if (player.global_position - anchor.global_position).dot(entry_direction) > 0.0:
		# Leaving is always possible, including after being removed from a guild.
		_teleport_across_gate(player, false)
		return
	var result: Dictionary = await guild_service.call("load_base_registrar", npc_id)
	if GameState.current_map != current_map or not is_instance_valid(player):
		return
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result)
		return
	var state: Dictionary = result.get("registrar", {})
	if bool(state.get("canEnterGarden", false)):
		_teleport_across_gate(player, true)
		return
	await _load_gate_metadata()
	_face_body(player)
	if player.has_method("face_world_position"):
		player.call("face_world_position", get_feet_position())
	await show_dialogue([_registration_message(state, true)])


func _teleport_across_gate(player: Node2D, entering: bool) -> void:
	var anchor := get_node(guard_blocking_anchor_path) as Node2D
	var facing := entry_direction if entering else -entry_direction
	player.call("teleport_within_current_map", anchor.global_position + facing * 32.0, facing)


func _registration_message(state: Dictionary, entering := false) -> String:
	if bool(state.get("canEnterGarden", false)):
		return LocalizationManager.text("ui.guild_base.welcome", {"town": str(state.get("townName", ""))})
	if state.get("guildId") == null:
		return LocalizationManager.text("ui.guild_base.no_guild")
	if state.get("baseTownId") != null:
		return LocalizationManager.text("ui.guild_base.other_town", {"town": str(state.get("baseTownName", ""))})
	if entering:
		return LocalizationManager.text("ui.guild_base.garden_requires_base", {"town": str(state.get("townName", ""))})
	var params := {
		"level": int(state.get("requiredLevel", 10)),
		"current_level": int(state.get("guildLevel", 0)),
		"price": _format_money(int(state.get("price", 1000000))),
		"balance": _format_money(int(state.get("bankBalance", 0))),
	}
	if not bool(state.get("isLeader", false)):
		return LocalizationManager.text("ui.guild_base.leader_required", params)
	if int(state.get("guildLevel", 0)) < int(state.get("requiredLevel", 10)):
		return LocalizationManager.text("ui.guild_base.level_required", params)
	return LocalizationManager.text("ui.guild_base.funds_required", params)


func _confirm_purchase(state: Dictionary) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var confirmation := ConfirmationScene.instantiate() as AetherConfirmationDialog
	layer.add_child(confirmation)
	confirmation.configure(
		LocalizationManager.text("ui.guild_base.title"),
		LocalizationManager.text("ui.guild_base.confirm", {
			"town": str(state.get("townName", "")),
			"level": int(state.get("requiredLevel", 10)),
			"current_level": int(state.get("guildLevel", 0)),
			"price": _format_money(int(state.get("price", 0))),
			"balance": _format_money(int(state.get("bankBalance", 0))),
		}),
		LocalizationManager.text("ui.guild_base.buy"),
		LocalizationManager.text("common.cancel")
	)
	confirmation.confirmed.connect(_resolve_confirmation.bind(true), CONNECT_ONE_SHOT)
	confirmation.canceled.connect(_resolve_confirmation.bind(false), CONNECT_ONE_SHOT)
	confirmation.popup_centered(Vector2i(560, 310))
	var accepted: bool = await purchase_confirmation_resolved
	layer.queue_free()
	return accepted


func _resolve_confirmation(accepted: bool) -> void:
	purchase_confirmation_resolved.emit(accepted)


func _on_guild_context_changed(_membership: Dictionary) -> void:
	_check_garden_membership.call_deferred()


func _check_garden_membership() -> void:
	if not _is_current_map() or _access_check_active or _interaction_active or GameState.is_overworld_input_locked():
		return
	var current_map: Node = GameState.current_map
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not _is_in_garden(player.global_position):
		return
	_access_check_active = true
	var result: Dictionary = await guild_service.call("load_base_registrar", npc_id)
	_access_check_active = false
	if GameState.current_map != current_map or not is_instance_valid(player) or GameState.is_overworld_input_locked() or not _is_in_garden(player.global_position):
		return
	if bool(result.get("success", false)) and not bool((result.get("registrar", {}) as Dictionary).get("canEnterGarden", false)):
		_teleport_across_gate(player, false)
		get_tree().call_group("ui_overlay", "add_system_message", LocalizationManager.text("ui.guild_base.access_lost"))


func _is_current_map() -> bool:
	return is_instance_valid(GameState.current_map) and GameState.current_map.is_ancestor_of(self)


func _is_in_garden(world_position: Vector2) -> bool:
	var anchor := get_node(guard_blocking_anchor_path) as Node2D
	return garden_bounds.has_point(world_position - anchor.global_position)


func _format_money(amount: int) -> String:
	var digits := str(maxi(amount, 0))
	var formatted := ""
	while digits.length() > 3:
		formatted = ",%s%s" % [digits.right(3), formatted]
		digits = digits.left(digits.length() - 3)
	return digits + formatted
