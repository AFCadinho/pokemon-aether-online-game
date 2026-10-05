extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
var stage: Node
var cues: Array[String] = []
var complete := false
var result := false

func _ready() -> void:
	_run.call_deferred()

func _start_capture(caught: bool, shakes := 3) -> void:
	complete = false
	result = await stage.capture("p2", "great-ball", shakes, caught)
	complete = true

func _run() -> void:
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	stage.double_mode = true
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	for index in 4:
		var actor := MeshInstance3D.new()
		actor.mesh = SphereMesh.new()
		stage.world.add_child(actor)
		actor.position = stage._position(index)
		stage.actors[index] = actor
		stage.identities[index] = "pikachu"
		stage.combatants[index] = {"species":"pikachu", "shiny":false}
		stage.lifecycle[index] = "idle"
		stage.actor_shown[index] = true
	stage.ball_cue.connect(func(_ident: String, key: String): cues.append(key))
	stage.playback_speed = 12.0
	for ident in ["p1","p2","p3","p4"]:
		var index: int = stage.actor_index(ident)
		stage.set_actor_shown(index,false)
		cues.clear()
		assert(await stage.send_out(ident,"poke-ball","",true))
		assert(cues == ["summon_throw","summon_release","cry"])
		assert(stage.actor_shown[index] and stage.lifecycle[index] == "idle")
		assert(await stage.recall(ident,"poke-ball"))
		assert(not stage.actor_shown[index] and stage.lifecycle[index] == "hidden")
		assert(stage.actor_scale[index] == 1.0 and stage.actor_transition_offsets[index] == Vector3.ZERO)
		assert(stage.ball_effects[index] == null)
		stage.set_actor_shown(index,true)
	for caught in [false,true]:
		for shakes in [0,1,3]:
			cues.clear()
			stage.set_actor_shown(1,true)
			assert(await stage.capture("p2","ultra-ball",shakes,caught))
			assert(cues[0] == "capture_throw" and cues[1] == "capture_absorb")
			assert(cues.count("capture_shake") == shakes)
			assert(cues[-1] == ("capture_success" if caught else "capture_break"))
			assert(stage.actor_shown[1] == not caught)
			assert(stage.actors[1].visible == not caught)
			assert(stage.actor_scale[1] == 1.0 and stage.actor_transition_offsets[1] == Vector3.ZERO)
			assert(stage.actor_shown[0], "Capture must only affect its target")
	# Exercise the co-op host's target routing without any 2D capture player.
	var coop := preload("res://scripts/battle/coop_battle_panel.gd").new()
	coop._native_mode = true
	coop.embedded_hosts = {"model_presenter": stage}
	coop._capture_target_controller = "p4"
	await coop._play_native_capture_preview("poke-ball", {"caught":true, "shakeCount":1})
	assert(not stage.actor_shown[3] and stage.actor_shown[0])
	stage.set_actor_shown(3,true)
	coop.free()
	stage.set_actor_shown(1,true)
	stage.playback_speed = 0.0
	cues.clear()
	_start_capture(false)
	var effect: Node3D = stage.ball_effects[1]
	var point: Vector3 = effect.ball.position
	for i in 6: await get_tree().process_frame
	assert(not complete and effect.ball.position == point and cues == ["capture_throw"])
	stage.playback_speed = 4.0
	while stage.actor_shown[1]: await get_tree().process_frame
	stage.cancel_actions()
	while not complete: await get_tree().process_frame
	assert(not result and stage.actor_shown[1] and stage.actor_scale[1] == 1.0)
	assert(stage.actor_transition_offsets[1] == Vector3.ZERO and stage.ball_effects[1] == null)
	assert("capture_success" not in cues and "capture_break" not in cues)
	# A new combatant invalidates an old capture, even while the ball is paused.
	stage.playback_speed = 0.0
	_start_capture(true)
	stage.set_combatant(1,"pikachu",false,true)
	while not complete: await get_tree().process_frame
	assert(not result and stage.actor_shown[1] and stage.lifecycle[1] == "idle")
	_start_capture(true)
	stage._set_active(false)
	while not complete: await get_tree().process_frame
	assert(not result and stage.actor_shown[1] and stage.ball_effects[1] == null)
	assert(stage.actor_transition_offsets[1] == Vector3.ZERO)
	assert(not await stage.capture("missing","poke-ball",3,true))
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Let non-blocking shared audio tails release before the headless runner exits.
	await get_tree().create_timer(1.0).timeout
	print("BATTLE_BALL_EFFECTS_3D_OK summon=4 recall=4 capture=6 pause=true cancel=true replacement=true deactivation=true coop=true")
	get_tree().quit.call_deferred()
