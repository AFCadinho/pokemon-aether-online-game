@tool
extends "res://scripts/world/interactables/world_interactable.gd"

## A permanent, player-specific encounter; each map actor needs its own server ID.
@export var encounter_id := ""
@export var encounter_area_id := ""
@export var flute_sound: AudioStream

var completed := false
var status_loading := false
var status: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()
	add_to_group("static_encounters")
	refresh_status.call_deferred()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and not completed:
		super._process(delta)


func _get_map_origin() -> Vector2:
	# Tool previews and placement checks can inspect an actor before tree entry.
	if not is_inside_tree():
		return Vector2.ZERO
	return super._get_map_origin()


func blocks_world_position(world_position: Vector2) -> bool:
	return not completed and super.blocks_world_position(world_position)


func apply_status(next_status: Dictionary) -> bool:
	if str(next_status.get("encounterId", "")) != encounter_id:
		return false
	status = next_status.duplicate(true)
	completed = bool(status.get("completed", false))
	visible = not completed
	return true


func refresh_status() -> Dictionary:
	while status_loading:
		await get_tree().process_frame
	status_loading = true
	await GatewayApiConfig.wait_for_metadata_request_frame()
	var request := HTTPRequest.new()
	add_child(request)
	var response: Dictionary = await BattleApiClient.send_get_request(
		request, "/game/static-encounters/" + encounter_id.uri_encode()
	)
	request.queue_free()
	status_loading = false
	if bool(response.get("success", false)):
		var value: Variant = response.get("encounter", {})
		if value is Dictionary and apply_status(value as Dictionary):
			return response
	if not bool(response.get("success", false)):
		return response
	return {"success": false, "error": "Encounter status unavailable."}


func _start_manual_interaction(_body: Node2D) -> void:
	is_interacting = true
	_lock_overworld_input()
	var response := await refresh_status()
	var awaken := false
	if not bool(response.get("success", false)):
		await GameErrorDialogService.show_response(response)
	elif not completed:
		if not bool(status.get("canAwaken", false)):
			await show_dialogue([LocalizationManager.text("static_encounter.snorlax_sleeping")])
		else:
			if flute_sound != null:
				SfxManager.play("poke_flute_awaken")
				await get_tree().create_timer(flute_sound.get_length()).timeout
			await show_dialogue([
				LocalizationManager.text("static_encounter.played_flute"),
				LocalizationManager.text("static_encounter.snorlax_awoke"),
			])
			awaken = true
	_unlock_overworld_input()
	if awaken:
		var world := get_tree().get_first_node_in_group("world")
		if world != null:
			await world.start_triggered_wild_battle_for_area(encounter_area_id, "static", "", true, encounter_id)
	is_interacting = false
