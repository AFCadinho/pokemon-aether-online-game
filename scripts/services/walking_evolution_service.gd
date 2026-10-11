extends Node

signal progress_changed(pokemon_id: int)
signal walking_completed(pokemon_id: int)
signal sync_finished(result: Dictionary)

var session_token := ""
var usage_id := ""
var pokemon_id := 0
var total_steps := 0
var synced_steps := 0
var started := false
var syncing := false
var elapsed := 0.0

func reset() -> void:
	session_token = ""
	usage_id = ""
	pokemon_id = 0
	total_steps = 0
	synced_steps = 0
	started = false
	elapsed = 0.0

func _lead() -> Pokemon:
	if PlayerSave.party.is_empty():
		return null
	return PlayerSave.party[0] as Pokemon

func can_count(pokemon: Pokemon) -> bool:
	if pokemon == null or not AuthService.is_authenticated() or GameState.gameplay_reset_in_progress:
		return false
	if pokemon != _lead() or pokemon.evolution_walk_required_steps <= 0 or pokemon.evolution_walk_steps >= pokemon.evolution_walk_required_steps:
		return false
	var world := GameState.get_world()
	if world == null or bool(world.get("is_in_battle")):
		return false
	var player: Node = world.get("player")
	return player != null and not bool(player.get("surf_activity_active")) \
		and not bool(player.get("land_mount_activity_active")) and not bool(player.get("story_path_movement_active"))

func record_steps(count: int) -> void:
	var lead := _lead()
	if count <= 0 or not can_count(lead):
		return
	var previous_usage := usage_id
	_ensure_usage(lead)
	total_steps = mini(total_steps + count, synced_steps + lead.evolution_walk_required_steps - lead.evolution_walk_steps)
	if usage_id != previous_usage and not syncing:
		_sync_usage.call_deferred()

func _ensure_usage(lead: Pokemon) -> void:
	if session_token != AuthService.session_token or pokemon_id != lead.owned_pokemon_id:
		reset()
	if usage_id.is_empty():
		session_token = AuthService.session_token
		pokemon_id = lead.owned_pokemon_id
		usage_id = InventoryService._new_request_id()

func _process(delta: float) -> void:
	elapsed += delta
	if syncing or elapsed < 1.0:
		return
	elapsed = 0.0
	if session_token != "" and session_token != AuthService.session_token:
		reset()
	var lead := _lead()
	if not usage_id.is_empty() and (lead == null or lead.owned_pokemon_id != pokemon_id or lead.evolution_walk_required_steps <= 0):
		reset()
	if can_count(lead):
		_ensure_usage(lead)
		if not started or total_steps > synced_steps:
			_sync_usage()

func flush() -> Dictionary:
	var target := total_steps
	var pending_usage := usage_id
	var rate_retries := 0
	while syncing or synced_steps < target:
		if syncing:
			await sync_finished
			continue
		if usage_id != pending_usage:
			return {"success": true}
		var result := await _sync_usage()
		if not bool(result.get("success", false)):
			var body: Dictionary = result.get("body", {})
			var detail: Variant = body.get("detail", {})
			if detail is Dictionary and str(detail.get("code", "")) == "evolution_walk_rate_limit" and rate_retries < 2:
				rate_retries += 1
				await get_tree().create_timer(0.15).timeout
				continue
			return result
	return {"success": true}

func _send_usage(id: String, mon_id: int, count: int) -> Dictionary:
	return await PlayerPartyStateService.sync_evolution_walking(id, mon_id, count)

func _sync_usage() -> Dictionary:
	if syncing or usage_id.is_empty() or session_token != AuthService.session_token:
		return {"success": false, "error": "The walking session changed."}
	syncing = true
	var sent_usage := usage_id
	var sent_session := session_token
	var sent_pokemon := pokemon_id
	var sent_steps := total_steps if started else 0
	var result := await _send_usage(sent_usage, sent_pokemon, sent_steps)
	if sent_usage == usage_id and sent_session == AuthService.session_token:
		if bool(result.get("success", false)):
			var body: Dictionary = result.get("body", {})
			if str(body.get("usageId", "")) == sent_usage and int(body.get("pokemonId", 0)) == sent_pokemon and int(body.get("totalSteps", -1)) == sent_steps:
				started = true
				synced_steps = sent_steps
				_apply_progress(sent_pokemon, body)
			else:
				result = {"success": false, "error": "Invalid walking progress response."}
		else:
			var detail: Dictionary = (result.get("body", {}) as Dictionary).get("detail", {}) if (result.get("body", {}) as Dictionary).get("detail", {}) is Dictionary else {}
			if int(result.get("status", 0)) == 404 or str(detail.get("code", "")) in ["evolution_walk_stale", "evolution_walk_not_lead", "evolution_walk_not_walking", "evolution_walk_unavailable"]:
				reset()
				result = {"success": true}
			elif str(detail.get("code", "")) == "evolution_walk_not_started":
				started = false
	syncing = false
	sync_finished.emit(result)
	return result

func _apply_progress(mon_id: int, body: Dictionary) -> void:
	for value: Variant in PlayerSave.party:
		var pokemon := value as Pokemon
		if pokemon == null or pokemon.owned_pokemon_id != mon_id:
			continue
		var previous := pokemon.evolution_walk_steps
		pokemon.evolution_walk_steps = maxi(previous, int(body.get("walkSteps", 0)))
		pokemon.evolution_walk_ready_level = int(body.get("walkReadyLevel", 0))
		progress_changed.emit(mon_id)
		if previous < pokemon.evolution_walk_required_steps and pokemon.evolution_walk_steps >= pokemon.evolution_walk_required_steps:
			walking_completed.emit(mon_id)
