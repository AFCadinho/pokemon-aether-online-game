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
	for route: Array in [["skarmory","Peck","physical_attack",.12,.28,0.0], ["skarmory-mega","Peck","physical_attack",.20,.40,0.0], ["glastrier","Double Kick","physical_attack_2",.12,.45,180.0], ["calyrex-ice","Double Kick","physical_attack",.12,.45,180.0], ["exploud","Low Kick","physical_attack",.05,.22,0.0]]:
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
	for route: Array in [["cubone","special_attack",.14,.22,.30], ["roaring-moon","special_attack",.18,.22,.25], ["slaking","physical_attack_2",.32,.45,.65], ["slugma","special_attack",.28,.44,.72], ["ho-oh","special_attack",.22,.36,.46], ["goodra","special_attack",.28,.42,.56], ["salandit","special_attack",.35,.45,.64], ["volcanion","physical_attack_2",.4,.48,.55], ["walking-wake","special_attack",.3,.45,.6], ["watchog","special_attack",.35,.45,.7], ["zoroark-hisui","physical_attack_2",.2,.28,.32]]:
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
	assert(Attachments.choreography_for("goodra-hisui","flamethrower","special_attack").is_empty())
	assert(Attachments.choreography_for("goodra","watergun","special_attack").is_empty())
	assert(Attachments.choreography_for("salazzle","flamethrower","special_attack").is_empty())
	assert(Attachments.choreography_for("volcanion","flamethrower","special_attack").is_empty())
	assert(Attachments.choreography_for("volcanion","watergun","physical_attack_2").is_empty())
	assert(Attachments.action_for("volcanion","watergun",{"physical_attack_2":{}}).is_empty())
	assert(Attachments.action_for("volcanion","flamethrower",{"special_attack":{}}).is_empty())
	assert(Attachments.choreography_for("zoroark","flamethrower","physical_attack_2").is_empty())
	for identity: String in ["walking-wake", "watchog", "zoroark-hisui"]:
		assert(Attachments.choreography_for(identity,"hyperbeam","special_attack").is_empty())
	for route: Array in [["cubone","Growl","special_attack",.14,.22], ["swanna","Water Gun","special_attack",.30,.45], ["minccino","Growl","physical_attack",.12,.24], ["vikavolt","Flash Cannon","special_attack",.10,.16], ["varoom","Sludge Bomb","physical_attack_2",.12,.40], ["sandslash-alola","Ice Beam","special_attack",.32,.45]]:
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
	for route: Array in [["arboliva","Solar Beam","physical_attack_2",.14,.22,.32], ["arboliva","Hyper Beam","physical_attack_2",.14,.22,.32], ["cubone","Water Gun","special_attack",.14,.22,.30], ["stunfisk","Water Gun","physical_attack",.12,.22,.28], ["snivy","Solar Beam","special_attack",.38,.48,.62], ["swinub","Ice Beam","special_attack",.34,.45,.58], ["steelix","Hyper Beam","special_attack",.42,.60,.74], ["stonjourner","Hyper Beam","special_attack",.38,.50,.66], ["mandibuzz","Hyper Beam","special_attack",.42,.60,.74], ["skarmory","Hyper Beam","special_attack",.30,.42,.54], ["skarmory-mega","Hyper Beam","special_attack",.18,.25,.32], ["sandaconda","Hyper Beam","physical_attack_2",.12,.22,.28], ["archaludon","Hyper Beam","special_attack",.18,.24,.29], ["avalugg-hisui","Ice Beam","special_attack",.33,.42,.50], ["grumpig","Hyper Beam","special_attack",.10,.22,.30], ["wyrdeer","Hyper Beam","special_attack",.17,.22,.26], ["houndstone","Hyper Beam","special_attack",.42,.60,.72], ["sudowoodo","Hyper Beam","special_attack",.42,.60,.80], ["cetoddle","Ice Beam","physical_attack",.10,.18,.25], ["lugia","Hyper Beam","special_attack",.27,.40,.53]]:
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
			assert(is_equal_approx(timing.emission_end_frame / timing.frames,route[5]))
			var effect: Node = stage.create_move_effect(route[1],actor,"p%d" % ((slot^1)+1),{})
			effect.set_process(false)
			assert(is_equal_approx(effect.water_emission_end if route[1] == "Water Gun" else effect.emission_end,timing.emission_end_frame/60.0))
			effect.clock = func(): return contact_seconds
			if route[0] == "cubone":
				assert(is_equal_approx(effect.emission_scale, .25))
			elif route[0] == "arboliva":
				assert(is_equal_approx(effect.emission_scale, .3))
			elif route[0] == "stunfisk":
				assert(is_equal_approx(effect.emission_scale, .2))
				assert(is_equal_approx(effect.water_stream_arc_height, 1.0))
				var source := Vector3(2,1,3)
				var target := Vector3(-2,.5,-3)
				assert(effect._water_stream_point(source,target,0).is_equal_approx(source))
				assert(effect._water_stream_point(source,target,1).is_equal_approx(target))
				assert(effect._water_stream_point(source,target,.5).is_equal_approx(source.lerp(target,.5)+Vector3.UP))
			contact_seconds = effect.impact
			effect._process(0)
			assert(effect.cursor > 0, "Beam must be visible during its open-mouth window")
			contact_seconds = (effect.water_emission_end if route[1] == "Water Gun" else effect.emission_end) + 0.001
			effect._process(0)
			assert(effect.cursor == 0, "Beam and source particles must finish before the mouth closes")
			for piece: MeshInstance3D in effect.pieces:
				assert(not piece.visible)
			effect.hit = true
			effect._process(0)
			assert(effect.cursor > 0, "Confirmed target impact continues after mouth emission ends")
			effect.cancel()
			var doll := Doll.new()
			stage.world.add_child(doll)
			stage.substitute_models[slot] = doll
			assert(not stage.move_timing(route[1],actor).has("emission_end_frame"))
			assert(not stage.move_timing(route[1],actor).has("emission_scale"))
			assert(not stage.move_timing(route[1],actor).has("water_stream_arc_height"))
			doll.free()
			stage.substitute_models[slot] = null
	assert(Attachments.action_for("cetoddle","waterpulse",{"physical_attack":{}}).is_empty())
	assert(Attachments.choreography_for("cetitan","icebeam","physical_attack").is_empty())
	assert(Attachments.choreography_for("lugia","icebeam","special_attack").is_empty())
	assert(Attachments.choreography_for("ho-oh","hyperbeam","special_attack").is_empty())
	assert(Attachments.action_for("stunfisk-galar","watergun",{"physical_attack":{}}).is_empty())
	assert(Attachments.choreography_for("stunfisk","waterpulse","physical_attack").is_empty())
	# Defaults preserve existing water, ice and staged-beam durations.
	var Ice = preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd")
	var Beam = preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd")
	var Water = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
	for script in [Ice, Beam, Water]:
		var effect: Node3D = script.new()
		stage.world.add_child(effect)
		contact_seconds = 0.0
		effect.start("Ice Beam" if script == Ice else "Water Gun" if script == Water else "Hyper Beam", {"frames":60.0,"impact_frame":27.0}, {}, func(): return contact_seconds, func(): return {"source":Vector3.ZERO,"target":Vector3(4,0,0),"radius":.5}, func(): return true)
		effect.set_process(false)
		assert(is_equal_approx(effect.water_emission_end if script == Water else effect.emission_end,.63 if script == Water else .618 if script == Ice else -1.0))
		if script == Water:
			assert(is_equal_approx(effect.emission_scale, 1.0))
			assert(is_zero_approx(effect.water_stream_arc_height))
		effect.cancel()

	_check_stream_scaling()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_ATTACHMENT_CHOREOGRAPHY_OK routes=42 slots=4 shiny=true cancellation=true substitute=true emission_end=true")
	get_tree().quit()

func _check_stream_scaling() -> void:
	# The four stream presenters scale source geometry without moving endpoints
	# or shrinking the independent target impact.
	for route: Array in [
		[preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd"), "Water Gun"],
		[preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd"), "Ice Beam"],
		[preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd"), "Flamethrower"],
		[preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd"), "Hyper Beam"]]:
		var source_transforms: Array[Transform3D] = []
		var target_transforms: Array[Transform3D] = []
		for scale_value: float in [1.0, .25]:
			var effect: Node3D = route[0].new()
			stage.world.add_child(effect)
			contact_seconds = .45
			effect.start(route[1], {"frames":60.0,"launch_frame":10.0,"impact_frame":27.0,"emission_end_frame":36.0,"emission_scale":scale_value}, {}, func(): return contact_seconds, func(): return {"source":Vector3.ZERO,"target":Vector3(4,0,0),"radius":.5}, func(): return true)
			effect.set_process(false)
			assert(effect.cursor > 0)
			source_transforms.append(effect.pieces[0].transform)
			contact_seconds = .65
			effect.hit = true
			effect._process(0)
			assert(effect.cursor > 0)
			target_transforms.append(effect.pieces[0].transform)
			effect.cancel()
		assert(source_transforms[0].origin.is_equal_approx(source_transforms[1].origin), "Stream endpoints must not be scaled toward the world origin")
		assert(is_equal_approx(source_transforms[1].basis.x.length(),source_transforms[0].basis.x.length()*.25))
		assert(is_equal_approx(source_transforms[1].basis.z.length(),source_transforms[0].basis.z.length()*.25))
		assert(target_transforms[0].is_equal_approx(target_transforms[1]), "Target impact retains its original position and size")
