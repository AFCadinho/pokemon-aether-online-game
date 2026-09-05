extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"
const BATTLE_PATH := "res://scripts/battle/battle.gd"
const API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"

var failed := false


func _init() -> void:
	var world := FileAccess.get_file_as_string(WORLD_PATH)
	var battle := FileAccess.get_file_as_string(BATTLE_PATH)
	var api := FileAccess.get_file_as_string(API_PATH)
	var resume_position := world.find("var wild_resume := await _resume_saved_wild_battle(saved_state)")
	var idle_position := world.find('await _save_player_activity_state("idle")', resume_position)

	_expect(api.contains('send_get_request(request_node, "/battle/wild/resume")'),
		"The client requests the authenticated wild resume endpoint")
	_expect(resume_position >= 0 and idle_position > resume_position,
		"Login attempts wild battle recovery before clearing activity")
	_expect(world.contains('get("retryable", false)'),
		"Transient resume failures preserve the server activity binding")
	_expect(world.contains("for attempt in range(3):")
		and world.contains("create_timer(0.35).timeout"),
		"Login retries a temporarily unavailable battle snapshot")
	_expect(world.contains("wild_battle_resume_pending = true")
		and world.contains("if is_in_battle or wild_battle_resume_pending:"),
		"A temporarily unreachable battle cannot be replaced by another battle")
	_expect(world.contains('active_battle_kind = "wild"')
		and world.contains("battle_instance.resume_wild_battle_from_response("),
		"A valid snapshot remounts the existing wild battle")
	_expect(battle.contains("func resume_wild_battle_from_response(")
		and battle.contains("without replaying encounter or\n\t# move animations"),
		"Wild resume restores the snapshot without replaying old animations")
	_expect(battle.contains("await _finish_if_battle_ended({}, true)"),
		"A terminal snapshot immediately enters normal battle settlement")
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
