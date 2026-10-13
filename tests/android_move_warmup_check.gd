extends "res://tests/battle_move_effects_3d_check.gd"
const Warmup = preload("res://scripts/battle/battle_ui/android_move_warmup.gd")
var cancellation_done := false

func _prepare_then_finish() -> void:
	await stage.android_move_warmup.prepare(stage, Effect.KEYS)
	cancellation_done = true

func _run() -> void:
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	stage.camera = camera
	camera.position = Vector3(5, 6, 14)
	camera.look_at(Vector3(0, 1, 0))
	var original_camera: Transform3D = camera.transform
	var actions: Array = stage.current_actions.duplicate()
	var lifecycles: Array = stage.lifecycle.duplicate()
	var positions: Array = stage.actors.map(func(actor): return actor.transform)
	assert(Warmup.allows(true, true, true))
	for flags in [[false, true, true], [true, false, true], [true, true, false]]:
		assert(not Warmup.allows(flags[0], flags[1], flags[2]))
	assert(Warmup.selected_moves([{"id": "flamethrower"}, {"name": "Thunderbolt"}, "FLAMETHROWER", "unknown"]) == ["flamethrower", "thunderbolt", "tackle"])
	assert(Warmup.selected_moves(Effect.KEYS).size() == Warmup.LIMIT)
	var metrics: Dictionary = await stage.android_move_warmup.prepare(stage)
	assert(metrics.effects == 3, "Bounded representative effects instantiated")
	assert(stage.android_move_warmup.retained.size() == 3)
	for effect in stage.android_move_warmup.retained.values():
		assert(not effect.visible and not effect.is_processing() and effect.pieces.size() > 0)
	assert(stage.common_effects.is_empty() and stage.move_camera.effect == null)
	assert(stage.current_actions == actions and stage.lifecycle == lifecycles)
	assert(stage.actors.map(func(actor): return actor.transform) == positions)
	assert(camera.transform == original_camera)
	var reused: Dictionary = await stage.android_move_warmup.prepare(stage)
	assert(reused.effects == 0 and reused.reused == 3, "Existing preparations do not run again")
	stage.android_move_warmup.clear()
	await get_tree().process_frame
	assert(stage.android_move_warmup.retained.is_empty())
	assert(stage.world.get_child_count() == 5, "All temporary VFX nodes released")
	_prepare_then_finish()
	await get_tree().process_frame
	stage.cancel_preparation()
	for frame in 3: await get_tree().process_frame
	assert(cancellation_done and not stage.android_move_warmup.busy and stage.android_move_warmup.retained.is_empty(), "Cancel during preparation releases everything")
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ANDROID_MOVE_WARMUP_PASS hidden=true bounded=true no_actions=true no_camera=true reuse=true cleanup=true")
	get_tree().quit()
