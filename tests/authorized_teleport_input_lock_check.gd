extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	_expect(
		world_source.contains(
			'const AUTHORIZED_TELEPORT_INPUT_LOCK_OWNER := &"authorized_teleport"'
		)
		and world_source.count(
			"GameState.acquire_overworld_input_lock(AUTHORIZED_TELEPORT_INPUT_LOCK_OWNER)"
		) == 3
		and world_source.count(
			"GameState.release_overworld_input_lock(AUTHORIZED_TELEPORT_INPUT_LOCK_OWNER)"
		) == 3,
		"Authorized teleports own their movement lock until completion"
	)
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
