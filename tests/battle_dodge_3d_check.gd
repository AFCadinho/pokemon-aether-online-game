extends "res://tests/battle_move_effects_3d_check.gd"
var commands := 0
var command_pending := false
var command_wait := 0.06
func _command() -> void:
	commands += 1
	command_pending = true
	assert(stage.common_effects.is_empty(), "Dodge command must precede the move effect")
	assert(stage.move_command_holds[0])
	assert(stage.dodge_offsets[1] == Vector3.ZERO)
	var before: float = stage.players[0].current_animation_position
	var generation: int = router.render_generation
	await get_tree().create_timer(command_wait).timeout
	if generation == router.render_generation:
		assert(is_equal_approx(before, stage.players[0].current_animation_position), "Attacker clock is held while the trainer speaks")
	command_pending = false
func _run() -> void:
	get_tree().create_timer(25).timeout.connect(func(): get_tree().quit(1))
	_setup()
	router.audio_catalog = SilentCatalog.new()
	for slot in 4:
		var target_index := (slot + 1) % 4
		var actor := "p%d" % (slot + 1)
		var target := "p%d" % (target_index + 1)
		var initial: Vector3 = stage.actors[target_index].position
		stage.start_move_action(actor, "Water Gun")
		stage.start_move_dodge(actor, target, "Water Gun")
		var effect: Node = stage.create_move_effect("Water Gun", actor, target, {"result": "miss", "show_impact": true})
		effect.set_process(false)
		var aim: Dictionary = effect.anchors.call()
		stage.players[slot].seek(0.45, true)
		stage.players[slot].speed_scale = 0
		stage._update_move_dodges()
		effect._process(0)
		assert(stage.dodge_offsets[target_index].length() > 0.7)
		assert(stage.actors[target_index].position.is_equal_approx(initial + stage.dodge_offsets[target_index]))
		assert(effect.anchors.call().target == aim.target, "Miss aim must not follow the dodging target")
		assert(not effect.hit and effect.cursor > 0)
		var paused: Vector3 = stage.dodge_offsets[target_index]
		await get_tree().create_timer(0.04).timeout
		stage._update_move_dodges()
		assert(stage.dodge_offsets[target_index] == paused)
		stage.players[slot].seek(0.99, true)
		stage._update_move_dodges()
		assert(stage.dodge_offsets[target_index].length() < 0.01, "Return completes with the attack")
		stage.players[slot].seek(1.0, true)
		stage._update_move_dodges()
		assert(stage.move_dodges[target_index].is_empty())
		assert(stage.actors[target_index].position.is_equal_approx(initial))
		router.cancel_render()
		await get_tree().process_frame
	# A visible Substitute moves instead of leaving a stationary decoy behind.
	var doll := Doll.new()
	stage.world.add_child(doll)
	doll.position = stage.actors[1].position
	stage.substitute_models[1] = doll
	stage.actors[1].hide()
	var doll_origin := doll.position
	stage.start_move_action("p1", "Ember")
	stage.start_move_dodge("p1", "p2", "Ember")
	stage.players[0].seek(0.45, true)
	stage._update_move_dodges()
	assert(doll.position.distance_to(doll_origin) > 0.7)
	stage._clear_move_dodge(1)
	assert(doll.position.is_equal_approx(doll_origin))
	stage.substitute_models[1] = null
	doll.free()
	stage.actors[1].show()
	# Target replacement clears the old displacement without moving the new model.
	stage.start_move_action("p1", "Ember")
	stage.start_move_dodge("p1", "p2", "Ember")
	stage.players[0].seek(0.45, true)
	stage._update_move_dodges()
	stage._clear_move_dodge(1) # Same reset used before runtime actor replacement.
	var previous: Node3D = stage.actors[1]
	stage.actors[1] = Node3D.new()
	stage.world.add_child(stage.actors[1])
	stage._update_move_dodges()
	assert(stage.actors[1].position == Vector3.ZERO)
	stage.actors[1].free()
	stage.actors[1] = previous
	router.cancel_render()
	await get_tree().process_frame
	# Production routing: one command before flight, including model-only moves.
	for move in ["Ember", "Surf"]:
		await router.play_move_animation(move, "p1", "p2", {"result": "miss", "on_dodge_started": _command})
		assert(stage.move_dodges[1].is_empty() and stage.dodge_offsets[1] == Vector3.ZERO)
	assert(commands == 2)
	for outcome in ["", "immune", "fail", "blocked"]:
		await router.play_move_animation("Tackle", "p1", "p2", {"result": outcome, "on_dodge_started": _command})
		assert(commands == 2 and stage.move_dodges[1].is_empty(), "Only true misses dodge")
	# Cancellation while the trainer is still speaking must not start stale motion.
	router.audio_catalog = Catalog.new()
	command_wait = 0.15
	complete = false
	_route("Ember", {"result": "miss", "on_dodge_started": _command})
	while not command_pending: await get_tree().process_frame
	router.cancel_render()
	while not complete: await get_tree().process_frame
	assert(commands == 3 and stage.common_effects.is_empty())
	assert(stage.move_dodges[1].is_empty() and not stage.move_command_holds[0])
	# Immediate restore on cancellation/deactivation, even if the animation is paused.
	for shutdown in [false, true]:
		stage.start_move_action("p1", "Ember")
		stage.start_move_dodge("p1", "p2", "Ember")
		var origin: Vector3 = stage.actors[1].position
		stage.players[0].seek(0.45, true)
		stage._update_move_dodges()
		assert(stage.dodge_offsets[1].length() > 0.7)
		if shutdown: stage._set_active(false)
		else: router.cancel_render()
		assert(stage.actors[1].position.is_equal_approx(origin) and stage.dodge_offsets[1] == Vector3.ZERO)
		stage.active = true
	router.cancel_render()
	stage.queue_free()
	await get_tree().process_frame
	print("BATTLE_DODGE_3D_OK slots=4 fixed_aim=true pause=true substitute=true command_order=true model_only=true cancellation=true")
	get_tree().quit()
