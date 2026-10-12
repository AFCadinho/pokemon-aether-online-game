@tool
extends GateNPC

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
signal admission_choice_resolved(accepted: bool)

var admission_in_flight := false
var pending_admission_state: Dictionary = {}


func _start_manual_interaction(body: Node2D) -> void:
	await super._start_manual_interaction(body)
	_apply_pending_admission()


func on_route_gate_blocked(player: Node2D) -> void:
	await super.on_route_gate_blocked(player)
	player.set("route_gate_interaction_in_progress", false)
	_apply_pending_admission()


func present_world_transition_denied(_access: Dictionary, player: Node2D) -> void:
	await on_route_gate_blocked(player)


func _apply_pending_admission() -> void:
	if pending_admission_state.is_empty():
		return
	var state := pending_admission_state
	pending_admission_state = {}
	# The ordinary NPC/guard wrapper must release its input lock before this
	# map change removes the attendant. World owns the remaining teleport lock.
	GameState.get_world().call_deferred("apply_authorized_teleport_state", state)


func is_gate_open() -> bool:
	# Every new visit needs consent and a server-side payment.
	return false


func _sync_guard_presence() -> void:
	_set_guard_present(true)


func show_gate_dialogue() -> void:
	if admission_in_flight:
		return
	admission_in_flight = true
	await _offer_admission()
	if is_instance_valid(self):
		admission_in_flight = false


func _offer_admission() -> void:
	var checked := await _refresh_transition_access(true)
	if not bool(checked.get("success", false)):
		await GameErrorDialogService.show_response(checked)
		return
	if str(transition_access.get("reasonCode", "")) != "ENTRY_FEE_REQUIRED":
		await _show_transition_denied_dialogue(transition_access)
		return
	var fee := int(transition_access.get("entryFee", 0))
	if fee <= 0:
		await GameErrorDialogService.show_report_to_staff_message()
		return
	if not await _confirm_admission(fee):
		return
	var world: Node = GameState.get_world()
	if world == null or not world.has_method("begin_authorized_teleport"):
		await GameErrorDialogService.show_report_to_staff_message()
		return
	var begin_result: Dictionary = await world.call("begin_authorized_teleport", true)
	if not bool(begin_result.get("success", false)):
		await GameErrorDialogService.show_response(begin_result)
		return
	var transition_service := get_node("/root/WorldTransitionService")
	var response: Dictionary = await transition_service.call("enter_transition", guarded_transition_id, "up", true)
	if not bool(response.get("success", false)):
		world.call("cancel_authorized_teleport")
		await GameErrorDialogService.show_response(response)
		return
	if not bool(response.get("allowed", false)):
		world.call("cancel_authorized_teleport")
		await _show_transition_denied_dialogue(response.get("access", {}))
		return
	pending_admission_state = response.get("state", {})
	if pending_admission_state.is_empty():
		world.call("cancel_authorized_teleport")
		await GameErrorDialogService.show_report_to_staff_message()


func _confirm_admission(fee: int) -> bool:
	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	dialog.configure(
		display_name,
		LocalizationManager.text("npc.museum.admission_prompt", {"fee": fee}),
		LocalizationManager.text("npc.museum.admission_pay", {"fee": fee}),
		LocalizationManager.text("npc.museum.admission_cancel")
	)
	dialog.confirmed.connect(func(): admission_choice_resolved.emit(true), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): admission_choice_resolved.emit(false), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(540, 260))
	var accepted: bool = await admission_choice_resolved
	layer.queue_free()
	return accepted
