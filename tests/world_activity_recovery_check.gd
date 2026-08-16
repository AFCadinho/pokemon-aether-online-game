extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var setup_start := world_source.find("func _setup_initial_world_state()")
	var setup_end := world_source.find("\nfunc ", setup_start + 1)
	var setup_source := world_source.substr(setup_start, setup_end - setup_start)
	var teleport_recovery := setup_source.find(
		'if bool(saved_state.get("teleportAcknowledgementRequired", false))'
	)
	var idle_recovery := setup_source.find('await _save_player_activity_state("idle")')
	var presence_connect := setup_source.find(
		"WorldPresenceService.connect_presence.call_deferred()"
	)

	_expect(setup_start >= 0 and setup_end > setup_start, "World setup function is available")
	_expect(
		idle_recovery > teleport_recovery,
		"A fresh overworld clears stale activity after pending teleport recovery"
	)
	_expect(
		presence_connect > idle_recovery,
		"Presence starts only after the server accepts the recovered idle state"
	)
	_expect(
		world_source.contains(
			"func _save_player_activity_state(activity_state: String, activity_context: Dictionary = {})"
		)
		and world_source.contains(
			"await PlayerGameStateService.save_player_activity_state(activity_state, activity_context)"
		),
		"Overworld activity recovery uses the authenticated player activity endpoint"
	)

	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
