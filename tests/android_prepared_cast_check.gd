extends "res://tests/battle_move_effects_3d_check.gd"
const Warmup = preload("res://scripts/battle/battle_ui/android_move_warmup.gd")
const MOVES := ["Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor", "Tackle"]
var preparation_done := false

func _snapshot(effect: Node) -> Array:
	var result := []
	for piece: MeshInstance3D in effect.pieces:
		if not piece.visible: continue
		var material: Material = piece.material_override
		var values := {}
		if material is ShaderMaterial:
			for property: Dictionary in material.get_property_list():
				if str(property.name).begins_with("shader_parameter/"):
					values[property.name] = material.get(property.name)
		elif material is StandardMaterial3D:
			values.albedo = material.albedo_color
		result.append([piece.transform, piece.mesh.get_aabb(), values])
	return result

func _prepare_then_finish() -> void:
	await stage.android_move_warmup.prepare(stage, MOVES, "hidden")
	preparation_done = true

func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	_setup()
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.camera.position = Vector3(5, 6, 14)
	stage.camera.look_at(Vector3(0, 1, 0))
	var outcomes := [{"show_impact": true}, {"result": "miss", "show_impact": true}, {"show_impact": false}]
	var comparisons := 0
	for options in outcomes:
		for player in stage.players: player.stop()
		var original_camera: Transform3D = stage.camera.transform
		var before_actions: Array = stage.current_actions.duplicate()
		var before_positions: Array = stage.actors.map(func(actor): return actor.transform)
		var metrics: Dictionary = await stage.android_move_warmup.prepare(stage, MOVES, "hidden")
		assert(metrics.effects == 5 and metrics.complete_keys.size() == 5 and not metrics.bounded)
		assert(stage.current_actions == before_actions and stage.actors.map(func(actor): return actor.transform) == before_positions)
		assert(stage.camera.transform == original_camera and stage.common_effects.is_empty())
		for move in MOVES:
			var key := Effect.move_key(move)
			var prepared: Node = stage.android_move_warmup.retained[key]
			assert(not prepared.visible and not prepared.is_processing() and prepared.elapsed == 0.0)
			assert(not prepared.clock.is_valid() and not prepared.anchors.is_valid() and not prepared.valid.is_valid())
			var id: int = prepared.get_instance_id()
			# Use the opposite side and changed raised coordinates after preparation.
			stage.actors[0].position += Vector3(.3, .6, -.2)
			stage.actors[1].position += Vector3(-.4, .3, .5)
			stage.start_move_action("p2", move)
			var cast: Node = stage.create_move_effect(move, "p2", "p1", options)
			cast.set_process(false)
			assert(cast.get_instance_id() == id and not stage.android_move_warmup.retained.has(key))
			assert(stage.android_move_warmup.take(key) == null, "A prepared node must be consumed only once")
			assert(cast.visible and cast.elapsed < cast.duration * .1 and not cast.done)
			var reference: Node = stage.new_move_effect(move)
			stage.world.add_child(reference)
			reference.view_camera = stage.camera
			var clock := {"seconds": 0.0}
			var points: Callable = cast.anchors
			reference.start(move, stage.move_timing(move, "p2"), options, func(): return clock.seconds, points, func(): return true)
			reference.set_process(false)
			# A new model clock, options and anchors must replace the preparation's.
			for fraction in [.05, .3, .46, .55, .64, .72, .85, .94]:
				clock.seconds = cast.duration * fraction
				stage.players[1].seek(clock.seconds, true)
				cast._process(0.0)
				reference._process(0.0)
				assert(_snapshot(cast) == _snapshot(reference), "%s outcome=%s sample=%f diverged after preparation" % [move, options, fraction])
				comparisons += 1
			var held: WeakRef = weakref(cast)
			if options == outcomes[0]:
				stage.players[1].seek(cast.duration, true)
				cast._process(0.0)
				assert(cast.done and not cast.cancelled)
			else:
				cast.cancel()
			reference.cancel()
			await get_tree().process_frame
			assert(held.get_ref() == null and stage.common_effects.is_empty())
		assert(stage.android_move_warmup.retained.is_empty())
	# Deactivation and cancellation during an await must release unused preparations.
	await stage.android_move_warmup.prepare(stage, MOVES, "hidden")
	var unused: WeakRef = weakref(stage.android_move_warmup.retained.flamethrower)
	stage._set_active(false)
	await get_tree().process_frame
	assert(stage.android_move_warmup.retained.is_empty() and unused.get_ref() == null)
	stage.active = true
	_prepare_then_finish()
	await get_tree().process_frame
	stage.cancel_preparation()
	for frame in 3: await get_tree().process_frame
	assert(preparation_done and not stage.android_move_warmup.busy and stage.android_move_warmup.retained.is_empty())
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("ANDROID_PREPARED_CAST_OK moves=5 outcomes=3 samples=%d same_instance=true fresh_parity=true clock_anchors_reset=true single_use=true cleanup=true" % comparisons)
	get_tree().quit()
