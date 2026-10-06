extends Node

signal charge_changed
signal depleted
signal sync_finished(result: Dictionary)
signal refill_finished

const MAX_STEPS := 10000
const REPEL_ITEMS := ["repel", "super-repel", "max-repel"]

var session_token := ""
var usage_id := ""
var total_steps := 0
var synced_steps := 0
var syncing := false
var refilling := false
var sync_elapsed := 0.0


func apply_initial_state(preferences: Dictionary) -> void:
	if session_token == AuthService.session_token and not usage_id.is_empty():
		GameState.repel_enabled = GameState.repel_enabled and GameState.repel_steps > 0
		charge_changed.emit()
		return
	reset()
	session_token = AuthService.session_token
	usage_id = InventoryService._new_request_id()
	GameState.repel_steps = clampi(int(preferences.get("repelSteps", 0)), 0, MAX_STEPS)
	GameState.repel_enabled = GameState.repel_enabled and GameState.repel_steps > 0
	charge_changed.emit()


func reset() -> void:
	session_token = ""
	usage_id = ""
	total_steps = 0
	synced_steps = 0
	sync_elapsed = 0.0
	GameState.repel_steps = 0
	charge_changed.emit()


func consume_step() -> bool:
	if not GameState.repel_enabled or GameState.repel_steps <= 0 or usage_id.is_empty() or session_token != AuthService.session_token:
		return false
	GameState.repel_steps -= 1
	total_steps += 1
	if GameState.repel_steps == 0:
		GameState.repel_enabled = false
		depleted.emit()
	charge_changed.emit()
	return true


func _process(delta: float) -> void:
	sync_elapsed += delta
	if sync_elapsed < 1.0 or syncing or refilling or total_steps <= synced_steps:
		return
	sync_elapsed = 0.0
	_sync_usage()


func flush(for_refill := false) -> Dictionary:
	while refilling and not for_refill:
		await refill_finished
	var flushing_usage_id := usage_id
	var target := total_steps
	while syncing or synced_steps < target:
		if flushing_usage_id != usage_id:
			return {"success": false, "error": "Session changed."}
		if syncing:
			await sync_finished
			continue
		var result := await _sync_usage()
		if not bool(result.get("success", false)):
			return result
	return {"success": flushing_usage_id == usage_id, "error": "Session changed." if flushing_usage_id != usage_id else ""}


func _sync_usage() -> Dictionary:
	if not AuthService.is_authenticated() or session_token != AuthService.session_token:
		return {"success": false, "error": "Not authenticated."}
	syncing = true
	var sent_id := usage_id
	var sent_steps := total_steps
	var result: Dictionary = await PlayerGameStateService.sync_repel_usage(sent_id, sent_steps)
	if sent_id == usage_id and session_token == AuthService.session_token and bool(result.get("success", false)):
		synced_steps = sent_steps
		GameState.repel_steps = maxi(int(result.get("repelSteps", 0)) - (total_steps - synced_steps), 0)
		if GameState.repel_steps == 0 and GameState.repel_enabled:
			GameState.repel_enabled = false
			depleted.emit()
		charge_changed.emit()
	syncing = false
	sync_finished.emit(result)
	return result


func refill(item_id: String, quantity: int = 1) -> Dictionary:
	if refilling:
		return {"success": false, "error": LocalizationManager.text("ui.repel.busy")}
	refilling = true
	var refill_session := session_token
	var refill_usage_id := usage_id
	var result := await flush(true)
	if refill_session != AuthService.session_token or refill_usage_id != usage_id:
		refilling = false
		refill_finished.emit()
		return {"success": false, "error": "Session changed."}
	if bool(result.get("success", false)):
		result = await InventoryService.use_inventory_item(item_id, quantity)
		if refill_session != AuthService.session_token or refill_usage_id != usage_id:
			result = {"success": false, "error": "Session changed."}
		if bool(result.get("success", false)):
			GameState.repel_steps = maxi(int(result.get("repelSteps", 0)) - (total_steps - synced_steps), 0)
			charge_changed.emit()
	refilling = false
	refill_finished.emit()
	return result
