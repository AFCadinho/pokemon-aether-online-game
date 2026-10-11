extends "res://tests/battle_move_effects_3d_check.gd"
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
var contact_seconds := 0.0

func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	_setup()
	stage.entries.fixture.action_timing.physical_attack_2 = {"frames":60.0,"speed":1.0,"loop":false}
	for player: AnimationPlayer in stage.players:
		var clip := Animation.new()
		clip.length = 1.0
		player.get_animation_library("").add_animation("physical_attack_2", clip)
	for route: Array in [["glastrier","Double Kick","physical_attack_2",.12,.45,180.0], ["calyrex-ice","Double Kick","physical_attack",.12,.45,180.0], ["exploud","Low Kick","physical_attack",.05,.22,0.0]]:
		for slot in 4:
			var identity: String = route[0] + ("@shiny" if slot % 2 else "")
			var actor := "p%d" % (slot+1)
			var target := "p%d" % ((slot^1)+1)
			stage.identities[slot] = identity
			stage.combatants[slot] = {"species":route[0],"shiny":bool(slot % 2)}
			stage.entries[identity] = stage.entries.fixture.duplicate(true)
			stage.visual_bounds[identity] = stage.visual_bounds.fixture.duplicate(true)
			stage.start_move_action(actor,route[1])
			stage.players[slot].pause()
			assert(stage.current_actions[slot] == route[2])
			var key: String = Effect.move_key(route[1])
			assert(Attachments.choreography_for(identity,key,"special_attack").is_empty())
			var timing: Dictionary = stage.move_timing(route[1],actor)
			assert(is_equal_approx(timing.launch_frame,60*route[3]))
			assert(is_equal_approx(timing.impact_frame,60*route[4]))
			assert(is_equal_approx(timing.contact_yaw_degrees,route[5]))
			var home: Transform3D = stage.actors[slot].transform
			var effect: Node = stage.create_move_effect(route[1],actor,target,{"show_impact":true})
			effect.set_process(false)
			stage.move_contacts[slot].clock = func(): return contact_seconds
			contact_seconds = float(route[4])
			stage._update_move_contacts()
			assert(is_equal_approx(stage.contact_yaws[slot],stage.move_contacts[slot].yaw))
			assert(stage.actors[slot].transform.is_finite())
			effect.cancel()
			assert(stage.move_contacts[slot].is_empty())
			assert(stage.actors[slot].transform.is_equal_approx(home), "Cancel restores position and facing")
			var doll := Doll.new()
			stage.world.add_child(doll)
			doll.position = stage.actors[slot].position
			stage.substitute_models[slot] = doll
			var substitute_timing: Dictionary = stage.move_timing(route[1],actor)
			assert(not substitute_timing.has("contact_yaw_degrees"), "Substitute does not inherit anatomical choreography")
			doll.free()
			stage.substitute_models[slot] = null
			await get_tree().process_frame
	assert(Attachments.choreography_for("decidueye-hisui","lowkick","physical_attack_2").is_empty())
	assert(Attachments.choreography_for("glastrier","tackle","physical_attack_2").is_empty())
	for route: Array in [["salandit","special_attack",.35,.45,.64], ["volcanion","physical_attack_2",.4,.48,.55], ["walking-wake","special_attack",.3,.45,.6], ["watchog","special_attack",.35,.45,.7], ["zoroark-hisui","physical_attack_2",.2,.28,.32]]:
		for slot in 4:
			var identity := str(route[0]) + ("@shiny" if slot % 2 else "")
			var actor := "p%d" % (slot+1)
			stage.identities[slot] = identity
			stage.combatants[slot] = {"species":route[0],"shiny":bool(slot % 2)}
			stage.entries[identity] = stage.entries.fixture.duplicate(true)
			stage.visual_bounds[identity] = stage.visual_bounds.fixture.duplicate(true)
			stage.start_move_action(actor,"Flamethrower")
			stage.players[slot].pause()
			assert(stage.current_actions[slot] == route[1])
			var timing: Dictionary = stage.move_timing("Flamethrower",actor)
			assert(is_equal_approx(timing.launch_frame / timing.frames,route[2]))
			assert(is_equal_approx(timing.impact_frame / timing.frames,route[3]))
			assert(is_equal_approx(timing.emission_end_frame / timing.frames,route[4]))
			var effect: Node = stage.create_move_effect("Flamethrower",actor,"p%d" % ((slot^1)+1),{})
			effect.set_process(false)
			assert(is_equal_approx(effect.emission_end,timing.emission_end_frame/60.0))
			effect.cancel()
			var doll := Doll.new()
			stage.world.add_child(doll)
			stage.substitute_models[slot] = doll
			assert(not stage.move_timing("Flamethrower",actor).has("emission_end_frame"))
			doll.free()
			stage.substitute_models[slot] = null
	assert(Attachments.choreography_for("salandit","flamethrower","physical_attack").is_empty())
	assert(Attachments.choreography_for("salandit","ember","special_attack").is_empty())
	assert(Attachments.choreography_for("salazzle","flamethrower","special_attack").is_empty())
	assert(Attachments.choreography_for("volcanion","flamethrower","special_attack").is_empty())
	assert(Attachments.choreography_for("volcanion","watergun","physical_attack_2").is_empty())
	assert(Attachments.action_for("volcanion","watergun",{"physical_attack_2":{}}).is_empty())
	assert(Attachments.action_for("volcanion","flamethrower",{"special_attack":{}}).is_empty())
	assert(Attachments.choreography_for("zoroark","flamethrower","physical_attack_2").is_empty())
	for identity: String in ["walking-wake", "watchog", "zoroark-hisui"]:
		assert(Attachments.choreography_for(identity,"hyperbeam","special_attack").is_empty())
	for route: Array in [["vikavolt","Flash Cannon","special_attack",.10,.16], ["varoom","Sludge Bomb","physical_attack_2",.12,.40], ["sandslash-alola","Ice Beam","special_attack",.32,.45]]:
		for slot in 4:
			var identity := str(route[0]) + ("@shiny" if slot % 2 else "")
			var actor := "p%d" % (slot+1)
			stage.identities[slot] = identity
			stage.combatants[slot] = {"species":route[0],"shiny":bool(slot % 2)}
			stage.entries[identity] = stage.entries.fixture.duplicate(true)
			stage.visual_bounds[identity] = stage.visual_bounds.fixture.duplicate(true)
			stage.start_move_action(actor,route[1])
			stage.players[slot].pause()
			assert(stage.current_actions[slot] == route[2])
			var timing: Dictionary = stage.move_timing(route[1],actor)
			assert(is_equal_approx(timing.launch_frame / timing.frames,route[3]))
			assert(is_equal_approx(timing.impact_frame / timing.frames,route[4]))
			var effect: Node = stage.create_move_effect(route[1],actor,"p%d" % ((slot^1)+1),{})
			effect.set_process(false)
			assert(is_equal_approx(effect.launch,timing.launch_frame/60.0))
			assert(is_equal_approx(effect.impact,timing.impact_frame/60.0))
			effect.cancel()
			var doll := Doll.new()
			stage.world.add_child(doll)
			stage.substitute_models[slot] = doll
			assert(not stage.move_timing(route[1],actor).has("contact_yaw_degrees"))
			doll.free()
			stage.substitute_models[slot] = null
	assert(Attachments.choreography_for("vikavolt","hyperbeam","special_attack").is_empty())
	assert(Attachments.choreography_for("varoom","flashcannon","physical_attack_2").is_empty())
	assert(Attachments.action_for("revavroom","sludgebomb",{"physical_attack_2":{}}).is_empty())
	assert(Attachments.choreography_for("sandslash","icebeam","special_attack").is_empty())
	assert(Attachments.choreography_for("sandslash-alola","blizzard","special_attack").is_empty())
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_ATTACHMENT_CHOREOGRAPHY_OK routes=11 slots=4 shiny=true cancellation=true substitute=true emission_end=true")
	get_tree().quit()
