extends SceneTree

const ROUTE_22_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_22.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(ROUTE_22_SCENE)
	var lock_start := source.find('[node name="VictoryRoadPostLock"')
	var lock_end := source.find("\n[node ", lock_start + 1) if lock_start >= 0 else -1
	var lock_block := source.substr(lock_start, lock_end - lock_start) if lock_start >= 0 and lock_end > lock_start else ""

	_check(
		source.contains("res://scenes/world/interactables/locked_door_interactable.tscn"),
		"Route 22 uses the shared locked-door interactable"
	)
	_check(lock_start >= 0, "Route 22 has a Victory Road Post lock")
	_check(
		lock_block.contains('position = Vector2(352, 304)')
		and lock_block.contains('blocked_tile_offset = Vector2i(-1, 0)')
		and lock_block.contains('blocked_tile_footprint = Vector2i(3, 1)'),
		"Victory Road lock covers the complete three-tile entrance"
	)
	_check(
		lock_block.contains("The Victory Road checkpoint is closed for now."),
		"Victory Road lock explains why the checkpoint is closed"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		printerr("FAIL %s" % label)
