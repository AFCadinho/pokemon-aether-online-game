extends SceneTree

var failed := false


func _init() -> void:
	var reset_service := _source("res://scripts/services/player_gameplay_reset_service.gd")
	var game_state := _source("res://scripts/core/game_state.gd")
	var player_data := _source("res://scripts/data/player_data.gd")
	var world := _source("res://scripts/world/world.gd")
	var overlay := _source("res://scripts/ui/ui_overlay.gd")
	var starter := _source("res://scripts/world/kanto/towns/pallet_town/oak.gd")
	var party_service := _source("res://scripts/services/player_party_state_service.gd")

	_expect(reset_service.contains('const RESET_ENDPOINT := "/game/dev/new-game-reset"'), "reset uses the protected developer endpoint")
	_expect(reset_service.contains('"confirmation": "RESET"'), "reset sends the destructive confirmation token")
	_expect(reset_service.contains("pending_request_id"), "reset retains an idempotency key for safe retries")
	_expect(game_state.contains("var gameplay_reset_in_progress := false"), "global state exposes an autosave reset barrier")
	_expect(player_data.contains("func reset_gameplay_progress() -> void:"), "local player progress has an explicit reset operation")
	_expect(world.contains("func prepare_for_gameplay_reset() -> Dictionary:"), "world drains in-flight saves before reset")
	_expect(world.contains("GameState.gameplay_reset_in_progress"), "world persistence honors the reset barrier")
	_expect(
		world.contains("await _persist_initial_player_position_during_reset(initial_spawn_name)"),
		"reset startup persists its initial world position before releasing the reset barrier"
	)
	_expect(
		world.contains("func _is_player_position_save_blocked_by_teleport(allow_gameplay_reset := false)"),
		"only an explicitly authorized initial reset save may bypass the reset barrier"
	)
	var initial_world_setup := world.find("await _setup_initial_world_state()")
	var reset_unlock := world.find("GameState.finish_gameplay_reset()")
	_expect(
		initial_world_setup >= 0 and reset_unlock > initial_world_setup,
		"the reset remains input-locked until its initial position save has completed"
	)
	_expect(overlay.contains('"Reset / New Game"'), "Developer Tools exposes Reset / New Game")
	_expect(overlay.contains("await PlayerGameplayResetService.reset_gameplay()"), "Developer Tools awaits the server transaction")
	_expect(overlay.contains("change_scene_to_file(LOADING_SCENE_PATH)"), "successful reset reloads authoritative state")
	_expect(party_service.contains('"/game/starter"'), "starter claim uses the durable server endpoint")
	_expect(party_service.contains('"/game/starter/options"'), "starter choices come from the authoritative server catalog")
	_expect(party_service.contains('"speciesId": normalized_species_id'), "starter claim sends only the selected species identity")
	_expect(starter.contains("PlayerPartyStateService.claim_starter"), "Professor Oak uses the durable starter claim")
	_expect(starter.contains("StarterChoiceDialog.new()"), "Professor Oak opens the starter catalog selection UI")

	quit(1 if failed else 0)


func _source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "can read %s" % path)
		return ""
	return file.get_as_text()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
