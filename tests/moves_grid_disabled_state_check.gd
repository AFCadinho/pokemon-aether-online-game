extends SceneTree

var failed := false

func _init() -> void:
	_run_check.call_deferred()


func _run_check() -> void:
	var moves_grid := MovesGrid.new()
	var available_move := Button.new()
	var unavailable_move := Button.new()
	unavailable_move.disabled = true
	moves_grid.add_child(available_move)
	moves_grid.add_child(unavailable_move)
	root.add_child(moves_grid)

	var hovered_moves: Array[Dictionary] = []
	var unhovered_count := [0]
	moves_grid.move_hovered.connect(func(move_data: Dictionary, _slot_rect: Rect2) -> void:
		hovered_moves.append(move_data)
	)
	moves_grid.move_unhovered.connect(func() -> void:
		unhovered_count[0] += 1
	)

	moves_grid.set_input_disabled(true)
	_check(moves_grid.input_disabled, "moves grid records its locked waiting state")
	_check(available_move.disabled, "available move is not clickable while waiting")
	_check(unavailable_move.disabled, "unavailable move stays disabled while waiting")
	_check_equal(
		moves_grid.self_modulate,
		MovesGrid.INPUT_DISABLED_MODULATE,
		"waiting moves are visibly dimmed"
	)
	_check_equal(unhovered_count[0], 1, "locking clears any active move hover presentation")

	moves_grid._on_slot_hovered({"name": "Substitute"}, Rect2())
	_check_equal(hovered_moves.size(), 0, "locked moves cannot reopen hover presentation")

	moves_grid.set_input_disabled(false)
	_check(not moves_grid.input_disabled, "moves grid unlocks for the next decision")
	_check(not available_move.disabled, "previously available move becomes clickable again")
	_check(unavailable_move.disabled, "move-specific disabled state survives the waiting lock")
	_check_equal(
		moves_grid.self_modulate,
		MovesGrid.INPUT_ENABLED_MODULATE,
		"next decision restores full move brightness"
	)

	moves_grid._on_slot_hovered({"name": "Substitute"}, Rect2())
	_check_equal(hovered_moves.size(), 1, "unlocked moves can show hover presentation again")

	if failed:
		quit(1)
		return

	print("PASS moves_grid_disabled_state_check")
	quit(0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s: expected %s got %s" % [label, str(expected), str(actual)])
