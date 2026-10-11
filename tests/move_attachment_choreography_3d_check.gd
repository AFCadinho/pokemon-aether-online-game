extends "res://tests/battle_move_effects_3d_check.gd"
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
var contact_seconds := 0.0
var thread_source := Vector3(1,1,0)

func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	_setup()
	stage.entries.fixture.action_timing.physical_attack_2 = {"frames":60.0,"speed":1.0,"loop":false}
	for player: AnimationPlayer in stage.players:
		var clip := Animation.new()
		clip.length = 1.0
		player.get_animation_library("").add_animation("physical_attack_2", clip)
	for route: Array in [["weedle","Bug Bite","physical_attack_2",0.25,0.45,0],["wurmple","Bug Bite","physical_attack",0.3,0.45,0],["venipede","Bite","physical_attack_2",0.3,0.45,0],["venipede","Bug Bite","physical_attack_2",0.3,0.45,0],["whirlipede","Bite","physical_attack_2",0.3,0.45,0],["whirlipede","Bug Bite","physical_attack_2",0.3,0.45,0],["surskit","Bug Bite","physical_attack",0.3,0.45,0],["masquerain","Bug Bite","physical_attack",0.3,0.45,0],["kricketot","Bug Bite","physical_attack_2",0.55,0.65,0],["kricketune","Bug Bite","physical_attack_2",0.3,0.45,0],["fomantis","Bug Bite","physical_attack_2",0.3,0.45,0],["lurantis","Bug Bite","physical_attack",0.35,0.45,0],["pineco","Bug Bite","physical_attack_2",0.35,0.5,0],["pupitar","Bite","physical_attack_2",0.55,0.66,0],["cascoon","Bug Bite","physical_attack_2",0.25,0.45,0], ["kakuna","Bug Bite","physical_attack_2",0.25,0.45,0], ["silcoon","Bug Bite","physical_attack",.25,.45,0.0], ["spewpa","Bug Bite","physical_attack",.25,.45,0.0], ["beldum","Iron Head","physical_attack",.20,.42,0.0], ["beldum","Tackle","physical_attack",.20,.42,0.0], ["hydrapple","Bug Bite","physical_attack",.20,.42,0.0], ["dodrio","Peck","physical_attack",.30,.45,0.0], ["dodrio","Fury Attack","physical_attack",.30,.45,0.0], ["doduo","Fury Attack","physical_attack",.30,.45,0.0], ["doduo","Peck","physical_attack",.30,.45,0.0], ["snom","Bug Bite","physical_attack",.18,.45,0.0], ["spinarak","Bug Bite","physical_attack",.24,.45,0.0], ["skarmory","Peck","physical_attack",.12,.28,0.0], ["skarmory-mega","Peck","physical_attack",.20,.40,0.0], ["glastrier","Double Kick","physical_attack_2",.12,.45,180.0], ["calyrex-ice","Double Kick","physical_attack",.12,.45,180.0], ["exploud","Low Kick","physical_attack",.05,.22,0.0]]:
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
	for route: Array in [["chandelure-mega","special_attack",.32,.48,.65], ["cubone","special_attack",.14,.22,.30], ["roaring-moon","special_attack",.18,.22,.25], ["slaking","physical_attack_2",.32,.45,.65], ["slugma","special_attack",.28,.44,.72], ["ho-oh","special_attack",.22,.36,.46], ["goodra","special_attack",.28,.42,.56], ["salandit","special_attack",.35,.45,.64], ["volcanion","physical_attack_2",.4,.48,.55], ["walking-wake","special_attack",.3,.45,.6], ["watchog","special_attack",.35,.45,.7], ["zoroark-hisui","physical_attack_2",.2,.28,.32]]:
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
	for route: Array in [["weedle","Poison Sting","physical_attack_2",0.35,0.5],["wurmple","String Shot","special_attack",0.3,0.5],["wurmple","Poison Sting","physical_attack",0.42,0.57],["venipede","Poison Sting","physical_attack_2",0.35,0.5],["venipede","Screech","physical_attack_2",0.35,0.48],["venipede","Sludge Bomb","physical_attack_2",0.35,0.48],["whirlipede","Poison Sting","special_attack",0.35,0.5],["whirlipede","Screech","special_attack",0.35,0.48],["whirlipede","Sludge Bomb","special_attack",0.35,0.48],["surskit","Shadow Ball","special_attack",0.3,0.5],["surskit","Mud Slap","special_attack",0.3,0.5],["surskit","String Shot","special_attack",0.3,0.5],["surskit","Bubble","special_attack",0.3,0.5],["surskit","Bubble Beam","special_attack",0.3,0.5],["surskit","Water Pulse","special_attack",0.3,0.5],["masquerain","Shadow Ball","special_attack",0.3,0.5],["masquerain","Mud Slap","special_attack",0.3,0.5],["masquerain","String Shot","special_attack",0.3,0.5],["masquerain","Bubble","special_attack",0.3,0.5],["masquerain","Bubble Beam","special_attack",0.3,0.5],["masquerain","Water Pulse","special_attack",0.3,0.5],["kricketot","Growl","special_attack",0.35,0.55],["kricketot","String Shot","special_attack",0.35,0.55],["kricketot","Mud Slap","special_attack",0.35,0.55],["kricketune","Growl","special_attack",0.35,0.55],["kricketune","String Shot","special_attack",0.35,0.55],["kricketune","Mud Slap","special_attack",0.35,0.55],["kricketune","Screech","special_attack",0.35,0.55],["morelull","Sludge Bomb","special_attack",0.3,0.5],["spoink","Shadow Ball","special_attack",0.3,0.5],["spoink","Growl","special_attack",0.3,0.5],["seedot","Shadow Ball","special_attack",0.35,0.55],["pineco","String Shot","special_attack",0.3,0.5],["pupitar","Screech","special_attack",0.35,0.55],["pupitar","Mud-Slap","special_attack",0.35,0.55],["cryogonal","Water Pulse","special_attack",0.35,0.55],["glimmet","Sludge Bomb","special_attack",0.4,0.6],["glimmora","Sludge Bomb","special_attack",0.4,0.6],["gimmighoul","Shadow Ball","special_attack",0.42,0.55],["rolycoly","Mud-Slap","physical_attack_2",0.45,0.65],["voltorb","Screech","special_attack",0.35,0.55],["voltorb-hisui","Screech","physical_attack",0.43,0.63],["diglett","Growl","special_attack",0.55,0.75],["diglett","Screech","special_attack",0.55,0.75],["diglett","Sludge Bomb","special_attack",0.55,0.75],["diglett-alola","Growl","special_attack",0.55,0.75],["diglett-alola","Screech","special_attack",0.55,0.75],["diglett-alola","Sludge Bomb","special_attack",0.55,0.75],["dugtrio","Growl","physical_attack",0.4,0.6],["dugtrio","Screech","physical_attack",0.4,0.6],["dugtrio","Sludge Bomb","physical_attack",0.4,0.6],["dugtrio-alola","Growl","physical_attack",0.4,0.6],["dugtrio-alola","Screech","physical_attack",0.4,0.6],["dugtrio-alola","Sludge Bomb","physical_attack",0.4,0.6], ["magnemite","Screech","special_attack",0.3,0.52], ["magnemite","Supersonic","special_attack",0.3,0.52], ["magnezone","Screech","physical_attack",0.3,0.52], ["magnezone","Supersonic","physical_attack",0.3,0.52], ["lampent","Shadow Ball","physical_attack_2",0.4,0.6], ["lampent","Ember","physical_attack_2",0.4,0.6], ["chandelure","Shadow Ball","physical_attack",0.42,0.60], ["chandelure","Ember","physical_attack",0.42,0.60], ["bronzor","Shadow Ball","special_attack",0.35,0.55], ["bronzong","Shadow Ball","special_attack",0.25,0.5], ["cascoon","String Shot","special_attack",0.25,0.45], ["kakuna","String Shot","special_attack",0.25,0.45], ["silcoon","Poison Sting","physical_attack_2",.35,.50], ["honedge","Screech","special_attack",.40,.58], ["doublade","Screech","special_attack",.40,.58], ["aegislash-blade","Screech","special_attack",.40,.58], ["aegislash-shield","Screech","special_attack",.40,.58], ["aegislash-blade","Shadow Ball","special_attack",.40,.58], ["aegislash-shield","Shadow Ball","special_attack",.40,.58], ["silcoon","String Shot","physical_attack",.25,.45], ["spewpa","String Shot","physical_attack",.25,.45], ["sinistea","Shadow Ball","special_attack",.30,.52], ["unown","Hidden Power","special_attack",.30,.52], ["chandelure-mega","Ember","special_attack",.32,.55], ["chandelure-mega","Shadow Ball","special_attack",.32,.55], ["runerigus","Shadow Ball","special_attack",.48,.62], ["starmie-mega","Bubble Beam","special_attack",.32,.55], ["starmie-mega","Water Pulse","special_attack",.32,.55], ["venonat","Sludge Bomb","special_attack",.34,.55], ["venonat","Screech","special_attack",.34,.55], ["venonat","Supersonic","special_attack",.34,.55], ["flabebe","Disarming Voice","physical_attack_2",.25,.45], ["dodrio","Growl","special_attack",.30,.50], ["dodrio","Supersonic","special_attack",.30,.50], ["doduo","Growl","special_attack",.36,.58], ["doduo","Supersonic","special_attack",.36,.58], ["gastly","Shadow Ball","special_attack",.42,.65], ["cubone","Growl","special_attack",.14,.22], ["swanna","Water Gun","special_attack",.30,.45], ["minccino","Growl","physical_attack",.12,.24], ["vikavolt","Flash Cannon","special_attack",.10,.16], ["varoom","Sludge Bomb","physical_attack_2",.12,.40], ["sandslash-alola","Ice Beam","special_attack",.32,.45]]:
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
			if route[0] == "rolycoly":
				assert(is_equal_approx(timing.projectile_arc_height,.05))
				assert(is_equal_approx(effect.projectile_arc_height,.05))
			effect.cancel()
			var doll := Doll.new()
			stage.world.add_child(doll)
			stage.substitute_models[slot] = doll
			assert(not stage.move_timing(route[1],actor).has("contact_yaw_degrees"))
			assert(not stage.move_timing(route[1],actor).has("projectile_arc_height"))
			doll.free()
			stage.substitute_models[slot] = null
	assert(Attachments.choreography_for("vikavolt","hyperbeam","special_attack").is_empty())
	assert(Attachments.choreography_for("varoom","flashcannon","physical_attack_2").is_empty())
	assert(Attachments.action_for("revavroom","sludgebomb",{"physical_attack":{}}).is_empty())
	assert(Attachments.choreography_for("sandslash","icebeam","special_attack").is_empty())
	assert(Attachments.choreography_for("sandslash-alola","blizzard","special_attack").is_empty())
	for route: Array in [["weedle","String Shot","physical_attack_2",0.1,0.18,0.22],["venipede","Solar Beam","physical_attack_2",0.38,0.45,0.52],["whirlipede","Solar Beam","special_attack",0.35,0.48,0.65],["surskit","Water Gun","special_attack",0.3,0.45,0.65],["surskit","Ice Beam","special_attack",0.3,0.45,0.65],["surskit","Solar Beam","special_attack",0.3,0.45,0.65],["surskit","Scald","special_attack",0.3,0.45,0.65],["masquerain","Water Gun","special_attack",0.3,0.45,0.65],["masquerain","Ice Beam","special_attack",0.3,0.45,0.65],["masquerain","Solar Beam","special_attack",0.3,0.45,0.65],["masquerain","Scald","special_attack",0.3,0.45,0.65],["masquerain","Hyper Beam","special_attack",0.3,0.45,0.65],["kricketune","Hyper Beam","special_attack",0.35,0.48,0.65],["cottonee","Solar Beam","special_attack",0.35,0.48,0.65],["cherrim","Hyper Beam","special_attack",0.35,0.48,0.65],["cherrim","Solar Beam","special_attack",0.35,0.48,0.65],["petilil","Solar Beam","special_attack",0.35,0.48,0.65],["lilligant","Hyper Beam","physical_attack_2",0.4,0.5,0.65],["lilligant","Solar Beam","physical_attack_2",0.4,0.5,0.65],["fomantis","Solar Beam","special_attack",0.3,0.45,0.65],["lurantis","Hyper Beam","physical_attack",0.38,0.5,0.65],["lurantis","Solar Beam","physical_attack",0.38,0.5,0.65],["morelull","Solar Beam","special_attack",0.3,0.45,0.65],["spoink","Flash Cannon","special_attack",0.3,0.45,0.65],["seedot","Solar Beam","special_attack",0.35,0.48,0.65],["pineco","Solar Beam","special_attack",0.3,0.45,0.65],["forretress","Flash Cannon","special_attack",0.42,0.46,0.5],["forretress","Hyper Beam","special_attack",0.42,0.46,0.5],["forretress","Solar Beam","special_attack",0.42,0.46,0.5],["forretress","Volt Switch","special_attack",0.42,0.46,0.5],["pupitar","Hyper Beam","special_attack",0.35,0.48,0.65],["carbink","Flash Cannon","special_attack",0.4,0.5,0.65],["carbink","Hyper Beam","special_attack",0.4,0.5,0.65],["cryogonal","Flash Cannon","special_attack",0.35,0.48,0.65],["cryogonal","Hyper Beam","special_attack",0.35,0.48,0.65],["cryogonal","Ice Beam","special_attack",0.35,0.48,0.65],["cryogonal","Solar Beam","special_attack",0.35,0.48,0.65],["glimmora","Flash Cannon","special_attack",0.4,0.5,0.65],["glimmora","Hyper Beam","special_attack",0.4,0.5,0.65],["glimmora","Solar Beam","special_attack",0.4,0.5,0.65],["meltan","Flash Cannon","special_attack",0.32,0.48,0.65],["melmetal","Flash Cannon","special_attack",0.38,0.5,0.65],["melmetal","Hyper Beam","special_attack",0.38,0.5,0.65],["melmetal","Ice Beam","special_attack",0.38,0.5,0.65],["melmetal","Solar Beam","special_attack",0.38,0.5,0.65],["nosepass","Flash Cannon","special_attack",0.3,0.48,0.65],["nosepass","Volt Switch","special_attack",0.3,0.48,0.65],["nacli","Flash Cannon","special_attack",0.35,0.48,0.65],["naclstack","Flash Cannon","special_attack",0.35,0.48,0.65],["naclstack","Hyper Beam","special_attack",0.35,0.48,0.65],["voltorb-hisui","Solar Beam","physical_attack",0.43,0.55,0.65],["diglett-alola","Flash Cannon","special_attack",0.55,0.6,0.66],["dugtrio","Hyper Beam","physical_attack",0.4,0.55,0.7],["dugtrio-alola","Hyper Beam","physical_attack",0.4,0.55,0.7],["dugtrio-alola","Flash Cannon","physical_attack",0.4,0.55,0.7], ["magnemite","Flash Cannon","special_attack",0.3,0.45,0.62], ["magnezone","Flash Cannon","physical_attack",0.3,0.45,0.62], ["magnezone","Hyper Beam","physical_attack",0.3,0.45,0.62], ["lampent","Flamethrower","physical_attack_2",0.4,0.55,0.7], ["lampent","Solar Beam","physical_attack_2",0.4,0.55,0.7], ["chandelure","Flamethrower","physical_attack",0.42,0.52,0.6], ["chandelure","Solar Beam","physical_attack",0.42,0.52,0.6], ["chandelure","Hyper Beam","physical_attack",0.42,0.52,0.6], ["bronzor","Flash Cannon","special_attack",0.35,0.48,0.65], ["bronzor","Solar Beam","special_attack",0.35,0.48,0.65], ["bronzong","Flash Cannon","special_attack",0.25,0.45,0.65], ["bronzong","Solar Beam","special_attack",0.25,0.45,0.65], ["bronzong","Hyper Beam","special_attack",0.25,0.45,0.65], ["honedge","Flash Cannon","special_attack",.40,.52,.65], ["doublade","Flash Cannon","special_attack",.40,.52,.65], ["aegislash-blade","Flash Cannon","special_attack",.40,.52,.65], ["aegislash-shield","Flash Cannon","special_attack",.40,.52,.65], ["aegislash-blade","Hyper Beam","special_attack",.40,.52,.65], ["aegislash-shield","Hyper Beam","special_attack",.40,.52,.65], ["chandelure-mega","Hyper Beam","special_attack",.32,.48,.65], ["chandelure-mega","Solar Beam","special_attack",.32,.48,.65], ["runerigus","Hyper Beam","special_attack",.48,.55,.65], ["wugtrio","Water Gun","special_attack",.32,.45,.62], ["wugtrio","Ice Beam","special_attack",.32,.45,.62], ["wugtrio","Hyper Beam","special_attack",.32,.45,.62], ["magneton","Hyper Beam","special_attack",.32,.48,.65], ["magneton","Flash Cannon","special_attack",.32,.48,.65], ["starmie-mega","Water Gun","special_attack",.32,.48,.65], ["starmie-mega","Ice Beam","special_attack",.32,.48,.65], ["starmie-mega","Hyper Beam","special_attack",.32,.48,.65], ["starmie-mega","Flash Cannon","special_attack",.32,.48,.65], ["starmie-mega","Scald","special_attack",.32,.48,.65], ["mamoswine","Hyper Beam","special_attack",.34,.48,.62], ["mamoswine","Ice Beam","special_attack",.34,.48,.62], ["venonat","Solar Beam","special_attack",.34,.48,.62], ["flabebe","Solar Beam","physical_attack_2",.25,.45,.60], ["hydrapple","Hyper Beam","special_attack",.38,.46,.55], ["hydrapple","Solar Beam","special_attack",.38,.46,.55], ["hydrapple","Dragon Breath","special_attack",.38,.46,.55], ["dodrio","Hyper Beam","special_attack",.30,.50,.70], ["electrode-hisui","Hyper Beam","physical_attack",.28,.42,.60], ["kyurem","Ice Beam","special_attack",.30,.45,.60], ["latios","Ice Beam","special_attack",.38,.50,.65], ["klefki","Flash Cannon","special_attack",.30,.45,.60], ["spiritomb","Hyper Beam","special_attack",.38,.50,.68], ["mareanie","Ice Beam","physical_attack",.60,.65,.72], ["arboliva","Solar Beam","physical_attack_2",.14,.22,.32], ["arboliva","Hyper Beam","physical_attack_2",.14,.22,.32], ["cubone","Water Gun","special_attack",.14,.22,.30], ["stunfisk","Water Gun","physical_attack",.12,.22,.28], ["snivy","Solar Beam","special_attack",.38,.48,.62], ["swinub","Ice Beam","special_attack",.34,.45,.58], ["steelix","Hyper Beam","special_attack",.42,.60,.74], ["stonjourner","Hyper Beam","special_attack",.38,.50,.66], ["mandibuzz","Hyper Beam","special_attack",.42,.60,.74], ["skarmory","Hyper Beam","special_attack",.30,.42,.54], ["skarmory-mega","Hyper Beam","special_attack",.18,.25,.32], ["sandaconda","Hyper Beam","physical_attack_2",.12,.22,.28], ["archaludon","Hyper Beam","special_attack",.18,.24,.29], ["avalugg-hisui","Ice Beam","special_attack",.33,.42,.50], ["grumpig","Hyper Beam","special_attack",.10,.22,.30], ["wyrdeer","Hyper Beam","special_attack",.17,.22,.26], ["houndstone","Hyper Beam","special_attack",.42,.60,.72], ["sudowoodo","Hyper Beam","special_attack",.42,.60,.80], ["cetoddle","Ice Beam","physical_attack",.10,.18,.25], ["lugia","Hyper Beam","special_attack",.27,.40,.53]]:
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
			var new_scale: float = {"wugtrio":.12,"magneton":.14,"starmie-mega":.3,"mamoswine":.18 if route[1] == "Hyper Beam" else .3,"venonat":.12,"flabebe":.05,"hydrapple":.16,"electrode-hisui":.5,"kyurem":.35,"latios":.10,"klefki":.06,"spiritomb":.35,"mareanie":.075}.get(route[0], -1.0)
			if new_scale > 0: assert(is_equal_approx(effect.emission_scale, new_scale))
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
			if route[1] == "String Shot":
				assert(effect.cursor == 0, "Status silk ends without a damaging impact burst")
			else:
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
	# Defaults preserve existing water, ice, cannon and staged-beam durations.
	var Ice = preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd")
	var Beam = preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd")
	var Water = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
	var Cannon = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
	for script in [Ice, Beam, Water, Cannon]:
		var effect: Node3D = script.new()
		stage.world.add_child(effect)
		contact_seconds = 0.0
		effect.start("Ice Beam" if script == Ice else "Water Gun" if script == Water else "Flash Cannon" if script == Cannon else "Hyper Beam", {"frames":60.0,"impact_frame":27.0}, {}, func(): return contact_seconds, func(): return {"source":Vector3.ZERO,"target":Vector3(4,0,0),"radius":.5}, func(): return true)
		effect.set_process(false)
		assert(is_equal_approx(effect.water_emission_end if script == Water else effect.emission_end,.63 if script == Water else .618 if script == Ice else -1.0))
		if script == Water:
			assert(is_equal_approx(effect.emission_scale, 1.0))
			assert(is_zero_approx(effect.water_stream_arc_height))
		if script == Cannon:
			contact_seconds = effect.impact + effect.duration * .22 * .64
			effect._process(0)
			assert(effect.cursor > 0, "Default cannon keeps its legacy fade window")
			contact_seconds = effect.impact + effect.duration * .22 * .66
			effect._process(0)
			assert(effect.cursor == 0)
		effect.cancel()

	await _check_recent_routes()
	_check_stream_scaling()
	_check_orb_scaling()
	_check_staged_projectile_scaling("Hidden Power")
	_check_staged_projectile_scaling("Mud-Slap")
	_check_projectile_arc()
	_check_string_source()
	_check_sting_scaling()
	_check_ember_scaling()
	_check_silk_window()
	_check_two_sting_sources()
	_check_water_globe_scaling()
	_check_sludge_arc()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("MOVE_ATTACHMENT_CHOREOGRAPHY_OK routes=338 slots=4 shiny=true cancellation=true substitute=true emission_end=true")
	get_tree().quit()

func _check_stream_scaling() -> void:
	# The five stream presenters scale source geometry without moving endpoints
	# or shrinking the independent target impact.
	for route: Array in [
		[preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd"), "Water Gun"],
		[preload("res://scripts/battle/battle_ui/ice_beam_move_effect_3d.gd"), "Ice Beam"],
		[preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd"), "Flamethrower"],
		[preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd"), "Hyper Beam"],
		[preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd"), "Flash Cannon"]]:
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

func _check_orb_scaling() -> void:
	var Orb = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
	for move: String in ["Shadow Ball", "Sludge Bomb", "Focus Blast", "Moonblast"]:
		var captures := []
		for scale_value: float in [-1.0, 1.0, .25]:
			var effect: Node3D = Orb.new()
			stage.world.add_child(effect)
			var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
			if scale_value > 0: timing.emission_scale = scale_value
			contact_seconds = 0.0
			effect.start(move, timing, {"show_impact":true}, func(): return contact_seconds, func(): return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5}, func(): return true)
			effect.set_process(false)
			var phases := []
			for seconds: float in [.1,.3,.5]:
				contact_seconds = seconds
				effect._process(0)
				var transforms: Array[Transform3D] = []
				var orb_index := -1
				for index in effect.cursor:
					transforms.append(effect.pieces[index].transform)
					if orb_index < 0 and effect.pieces[index].mesh == effect.sphere: orb_index = index
				assert(not transforms.is_empty())
				if seconds < .45: assert(orb_index >= 0)
				phases.append({"pieces":transforms,"orb_index":orb_index})
			captures.append(phases)
			effect.cancel()
		for phase in 3:
			var baseline: Array = captures[0][phase].pieces
			var explicit_default: Array = captures[1][phase].pieces
			var smaller: Array = captures[2][phase].pieces
			assert(baseline.size() == explicit_default.size())
			for index in baseline.size():
				assert(baseline[index].is_equal_approx(explicit_default[index]), "Default orb geometry is preserved")
			if phase == 2:
				assert(baseline.size() == smaller.size())
				for index in baseline.size(): assert(baseline[index].is_equal_approx(smaller[index]), "Orb target impacts retain their position and size")
			else:
				var index: int = captures[0][phase].orb_index
				var small_index: int = captures[2][phase].orb_index
				assert(baseline[index].origin.is_equal_approx(smaller[small_index].origin), "Orb charge and flight centers are unchanged")
				for axis in 3: assert(is_equal_approx(smaller[small_index].basis[axis].length(),baseline[index].basis[axis].length()*.25))

func _check_staged_projectile_scaling(move_name: String) -> void:
	var captures := []
	for scale_value: float in [-1.0, 1.0, .25]:
		var effect := preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd").new()
		stage.world.add_child(effect)
		var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
		if scale_value > 0: timing.emission_scale = scale_value
		contact_seconds = 0.0
		effect.start(move_name, timing, {"show_impact":true}, func(): return contact_seconds, func(): return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5}, func(): return true)
		effect.set_process(false)
		var phases := []
		for seconds: float in [.1,.3,.75]:
			contact_seconds = seconds
			effect._process(0)
			var transforms: Array[Transform3D] = []
			for index in effect.cursor: transforms.append(effect.pieces[index].transform)
			assert(not transforms.is_empty())
			phases.append(transforms)
		captures.append(phases)
		effect.cancel()
	for phase in 3:
		var baseline: Array = captures[0][phase]
		var explicit_default: Array = captures[1][phase]
		var smaller: Array = captures[2][phase]
		assert(baseline.size() == explicit_default.size() and baseline.size() == smaller.size())
		for index in baseline.size():
			assert(baseline[index].is_equal_approx(explicit_default[index]), "Default staged projectile geometry is preserved")
			assert(baseline[index].origin.is_equal_approx(smaller[index].origin), "Projectile positions stay unchanged")
			if phase == 2:
				assert(baseline[index].is_equal_approx(smaller[index]), "Faded projectile and independent impact keep their geometry")
			else:
				for axis in 3: assert(is_equal_approx(smaller[index].basis[axis].length(), baseline[index].basis[axis].length()*.25))

func _check_string_source() -> void:
	var captures := []
	for move_name: String in ["String Shot", "Thunder Wave"]:
		for scale_value: float in [-1.0, 1.0, .25]:
			var effect := preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd").new()
			stage.world.add_child(effect)
			var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":36.0}
			if scale_value > 0: timing.emission_scale = scale_value
			contact_seconds = .3
			thread_source = Vector3(1,1,0)
			effect.start(move_name,timing,{},func():return contact_seconds,func():return {"source":thread_source,"sources":[thread_source],"target":Vector3(4,1,0),"radius":.5},func():return true)
			effect.set_process(false)
			effect._process(0)
			var before: Array[Transform3D] = []
			for index in effect.cursor: before.append(effect.pieces[index].transform)
			assert(before.size() == 30)
			if move_name == "String Shot": captures.append(before)
			thread_source = Vector3(1.2,1.5,.3)
			effect._process(0)
			assert(effect.aim.is_equal_approx(Vector3(4,1,0)))
			if move_name == "String Shot":
				for strand in 3:
					var line: Transform3D = effect.pieces[strand*10].transform
					var start := line*Vector3(0,-.5,0)
					assert(start.distance_to(thread_source) < .009, "Every silk strand follows the moving source")
			else:
				for index in effect.cursor: assert(effect.pieces[index].transform.is_equal_approx(before[index]), "Paralysis arcs retain their captured origin")
			effect.cancel()
	for index in 30:
		assert(captures[0][index].is_equal_approx(captures[1][index]), "Default silk geometry is preserved")
		assert(captures[0][index].origin.is_equal_approx(captures[2][index].origin), "Silk width scaling preserves path centers")
		assert(is_equal_approx(captures[2][index].basis.x.length(), captures[0][index].basis.x.length()*.25))

func _check_sting_scaling() -> void:
	var captures := []
	for scale_value: float in [-1.0, 1.0, .2]:
		var effect := preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd").new()
		stage.world.add_child(effect)
		var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
		if scale_value > 0: timing.emission_scale = scale_value
		contact_seconds = 0.0
		effect.start("Poison Sting",timing,{"show_impact":true},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
		effect.set_process(false)
		var phases := []
		for seconds: float in [.2,.3,.5]:
			contact_seconds = seconds
			effect._process(0)
			var transforms: Array[Transform3D] = []
			for index in effect.cursor: transforms.append(effect.pieces[index].transform)
			assert(not transforms.is_empty())
			phases.append(transforms)
		captures.append(phases)
		effect.cancel()
	for phase in 3:
		assert(captures[0][phase].size() == captures[1][phase].size())
		assert(captures[0][phase].size() == captures[2][phase].size())
		for index in captures[0][phase].size():
			var baseline: Transform3D = captures[0][phase][index]
			var smaller: Transform3D = captures[2][phase][index]
			assert(baseline.is_equal_approx(captures[1][phase][index]), "Default dart geometry is unchanged")
			assert(baseline.origin.is_equal_approx(smaller.origin), "Darts and trails retain their path centres")
			if phase == 2:
				assert(baseline.is_equal_approx(smaller), "Poison Sting target impact retains its size")
			else:
				for axis in 3: assert(is_equal_approx(smaller.basis[axis].length(),baseline.basis[axis].length()*.2))

func _check_ember_scaling() -> void:
	var captures := []
	for scale_value: float in [-1.0, 1.0, .2]:
		var effect := preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd").new()
		stage.world.add_child(effect)
		var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
		if scale_value > 0: timing.emission_scale = scale_value
		contact_seconds = 0.0
		effect.start("Ember",timing,{"show_impact":true},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
		effect.set_process(false)
		var phases := []
		for seconds: float in [.2,.3,.5]:
			contact_seconds = seconds
			effect._process(0)
			var transforms: Array[Transform3D] = []
			for index in effect.cursor: transforms.append(effect.pieces[index].transform)
			assert(not transforms.is_empty())
			phases.append(transforms)
		captures.append(phases)
		effect.cancel()
	for phase in 3:
		assert(captures[0][phase].size() == captures[1][phase].size())
		assert(captures[0][phase].size() == captures[2][phase].size())
		for index in captures[0][phase].size():
			var baseline: Transform3D = captures[0][phase][index]
			var smaller: Transform3D = captures[2][phase][index]
			assert(baseline.is_equal_approx(captures[1][phase][index]), "Default ember geometry is unchanged")
			assert(baseline.origin.is_equal_approx(smaller.origin), "Embers and trails retain their path centres")
			if phase == 2:
				assert(baseline.is_equal_approx(smaller), "Ember target impact retains its size")
			else:
				for axis in 3: assert(is_equal_approx(smaller.basis[axis].length(),baseline.basis[axis].length()*.2))

func _check_projectile_arc() -> void:
	var captures := []
	for height: float in [-1,1.8,.05,0]:
		var effect := preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd").new()
		stage.world.add_child(effect)
		var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
		if height >= 0: timing.projectile_arc_height = height
		contact_seconds = 0
		effect.start("Mud-Slap",timing,{"show_impact":true},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
		effect.set_process(false)
		assert(is_zero_approx(effect._projectile_arc_offset(0)))
		assert(is_zero_approx(effect._projectile_arc_offset(1)))
		assert(is_equal_approx(effect._projectile_arc_offset(.5),height if height >= 0 else 1.8))
		var phases := []
		for seconds: float in [.1,.325,.75]:
			contact_seconds = seconds
			effect._process(0)
			var transforms: Array[Transform3D] = []
			for index in effect.cursor: transforms.append(effect.pieces[index].transform)
			assert(not transforms.is_empty())
			phases.append(transforms)
		captures.append(phases)
		effect.cancel()
	for phase in 3:
		assert(captures[0][phase].size() == captures[1][phase].size())
		for index in captures[0][phase].size():
			var baseline: Transform3D = captures[0][phase][index]
			assert(baseline.is_equal_approx(captures[1][phase][index]),"Default projectile arc is preserved")
			for variant in [2,3]:
				var adjusted: Transform3D = captures[variant][phase][index]
				assert(baseline.basis.is_equal_approx(adjusted.basis),"Arc adjustment does not resize geometry")
				assert(is_equal_approx(baseline.origin.x,adjusted.origin.x) and is_equal_approx(baseline.origin.z,adjusted.origin.z))
				if phase != 1: assert(baseline.is_equal_approx(adjusted),"Charge and target impact are independent of arc height")
	assert(is_equal_approx(captures[2][1][0].origin.y-captures[3][1][0].origin.y,.05))

func _check_silk_window() -> void:
	for move: String in ["String Shot", "Thunder Wave"]:
		var captures := []
		for use_window in [false,true]:
			var effect := preload("res://scripts/battle/battle_ui/staged_move_effect_3d.gd").new()
			stage.world.add_child(effect)
			var timing := {"frames":60.0,"launch_frame":6.0,"impact_frame":12.0}
			if use_window: timing.emission_end_frame=18.0
			contact_seconds=0
			effect.start(move,timing,{},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
			effect.set_process(false)
			contact_seconds=.2;effect._process(0)
			assert(effect.cursor==30)
			contact_seconds=.31;effect._process(0)
			captures.append(effect.cursor)
			if use_window and move=="String Shot":
				for piece: MeshInstance3D in effect.pieces: assert(not piece.visible)
			effect.cancel()
		assert(captures[0]==30)
		assert(captures[1]==(0 if move=="String Shot" else 30),"Silk end time must not truncate paralysis arcs")

func _check_two_sting_sources() -> void:
	var effect := preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd").new()
	stage.world.add_child(effect)
	var sources: Array[Vector3]=[Vector3(1,1,-.4),Vector3(1,1,.4)]
	var original: Array[Vector3] = []
	var target := Vector3(4,1,0)
	contact_seconds=0
	effect.start("Poison Sting",{"frames":60.0,"launch_frame":12.0,"impact_frame":27.0},{},func():return contact_seconds,func():return {"source":sources[0],"sources":sources,"target":target,"radius":.5},func():return true)
	effect.set_process(false)
	for i in 5:
		sources[0]+=Vector3(0,.1,0);sources[1]+=Vector3(0,.1,0)
		contact_seconds=.2+i*.045*.25+.000001
		effect._process(0)
		original.append(sources[i%2])
		assert(effect.dart_launch_sources==original,"Each delayed dart captures its own spike's current pose")
	sources[0]+=Vector3(0,1,0);sources[1]+=Vector3(0,1,0)
	contact_seconds=.3;effect._process(0)
	assert(effect.dart_launch_sources==original,"Later head motion cannot drag launched darts")
	var travel: float=(.3-effect.launch)/(effect.impact-effect.launch)
	assert(effect.cursor==10,"Five darts and trails are shared between two spikes")
	for i in 5:
		var t := (travel-i*.045)/(1-i*.045)
		var source: Vector3=original[i]
		var forward := (target-source).normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var vertical := side.cross(forward).normalized()
		var a := i*TAU/5
		var point := source.lerp(target,t)+(side*cos(a)+vertical*sin(a))*sin(t*PI)*.18
		assert(effect.pieces[i*2].position.is_equal_approx(point))
	effect.cancel()

func _check_water_globe_scaling() -> void:
	for move: String in ["Bubble","Bubble Beam","Water Pulse"]:
		var captures := []
		for scale_value: float in [-1,1,.12]:
			var effect: Node3D=(preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd") if move=="Water Pulse" else preload("res://scripts/battle/battle_ui/bubble_move_effect_3d.gd")).new()
			stage.world.add_child(effect)
			var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
			if scale_value>0:timing.emission_scale=scale_value
			contact_seconds=0
			effect.start(move,timing,{"show_impact":true},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
			effect.set_process(false)
			var phases := []
			for seconds: float in [.2,.3,.55]:
				contact_seconds=seconds;effect._process(0)
				var transforms: Array[Transform3D]=[]
				for index in effect.cursor:
					# The late frame contains target sprites and no active bubble jet.
					if seconds==.55 and move!="Water Pulse" and effect.pieces[index].mesh==effect.sphere:continue
					transforms.append(effect.pieces[index].transform)
				assert(not transforms.is_empty())
				phases.append(transforms)
			captures.append(phases);effect.cancel()
		for phase in 3:
			assert(captures[0][phase].size()==captures[1][phase].size())
			assert(captures[0][phase].size()==captures[2][phase].size())
			for index in captures[0][phase].size():
				var base: Transform3D=captures[0][phase][index]
				var small: Transform3D=captures[2][phase][index]
				assert(base.is_equal_approx(captures[1][phase][index]),"Default water globes retain their geometry")
				if phase==2:assert(base.is_equal_approx(small),"Water target impact retains its size")
				else:
					if move!="Water Pulse" or index%4==0:assert(base.origin.is_equal_approx(small.origin),"Bubble/ring path centres must not shift")
					for axis in 3:assert(is_equal_approx(small.basis[axis].length(),base.basis[axis].length()*.12))

func _check_sludge_arc() -> void:
	var captures := []
	for height: float in [-1,.6,.05,0]:
		var effect := preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd").new()
		stage.world.add_child(effect)
		var timing := {"frames":60.0,"launch_frame":12.0,"impact_frame":27.0}
		if height>=0:timing.projectile_arc_height=height
		contact_seconds=0
		effect.start("Sludge Bomb",timing,{"show_impact":true},func():return contact_seconds,func():return {"source":Vector3(1,1,0),"target":Vector3(4,1,0),"radius":.5},func():return true)
		effect.set_process(false)
		var phases := []
		for seconds: float in [.1,.2,.325,.5]:
			contact_seconds=seconds;effect._process(0)
			var transforms: Array[Transform3D]=[]
			for index in effect.cursor:transforms.append(effect.pieces[index].transform)
			assert(not transforms.is_empty());phases.append(transforms)
		captures.append(phases);effect.cancel()
	for phase in 4:
		for index in captures[0][phase].size():
			var base: Transform3D=captures[0][phase][index]
			assert(base.is_equal_approx(captures[1][phase][index]),"Default sludge arc remains .6")
			for variant in [2,3]:
				var adjusted: Transform3D=captures[variant][phase][index]
				assert(base.basis.is_equal_approx(adjusted.basis))
				assert(is_equal_approx(base.origin.x,adjusted.origin.x) and is_equal_approx(base.origin.z,adjusted.origin.z))
				if phase!=2:assert(base.is_equal_approx(adjusted),"Charge, launch and impact stay fixed")
	assert(is_equal_approx(captures[2][2][0].origin.y-captures[3][2][0].origin.y,.05))

func _check_recent_routes() -> void:
	# Explicit expected values for the individually reviewed origins and native action windows.
	var routes: Array = [{"species":"dustox","move":"Hyper Beam","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.12},{"species":"dustox","move":"Solar Beam","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.12},{"species":"dustox","move":"Shadow Ball","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.5,"emission_scale":0.1},{"species":"dustox","move":"String Shot","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.5,"emission_scale":0.2},{"species":"dustox","move":"Bug Bite","part":"mouth","action":"physical_attack","launch_fraction":0.3,"impact_fraction":0.45,"contact_yaw_degrees":0},{"species":"dustox","move":"Sludge Bomb","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.5,"emission_scale":0.1,"projectile_arc_height":0.1},{"species":"dustox","move":"Poison Sting","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.5,"emission_scale":0.12},{"species":"frosmoth","move":"Hyper Beam","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_end_fraction":0.65,"emission_scale":0.08},{"species":"frosmoth","move":"Ice Beam","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_end_fraction":0.65,"emission_scale":0.08},{"species":"frosmoth","move":"Bug Bite","part":"face","action":"physical_attack","launch_fraction":0.35,"impact_fraction":0.5,"contact_yaw_degrees":0},{"species":"cutiefly","move":"Bug Bite","part":"proboscis_tip","action":"physical_attack","launch_fraction":0.35,"impact_fraction":0.5,"contact_yaw_degrees":0},{"species":"iron-moth","move":"Flamethrower","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"iron-moth","move":"Solar Beam","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"iron-moth","move":"Hyper Beam","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"iron-moth","move":"Flash Cannon","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"iron-moth","move":"Ember","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.12},{"species":"iron-moth","move":"Screech","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45},{"species":"larvesta","move":"Flamethrower","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_end_fraction":0.6,"emission_scale":0.1},{"species":"larvesta","move":"Solar Beam","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_end_fraction":0.6,"emission_scale":0.1},{"species":"larvesta","move":"Ember","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.12},{"species":"larvesta","move":"Screech","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5},{"species":"larvesta","move":"String Shot","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_end_fraction":0.6,"emission_scale":0.2},{"species":"larvesta","move":"Bug Bite","part":"face","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"contact_yaw_degrees":0},{"species":"volcarona","move":"Flamethrower","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"volcarona","move":"Solar Beam","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"volcarona","move":"Hyper Beam","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_end_fraction":0.65,"emission_scale":0.1},{"species":"volcarona","move":"Ember","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.12},{"species":"volcarona","move":"Screech","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45},{"species":"volcarona","move":"String Shot","part":"face","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.2},{"species":"volcarona","move":"Bug Bite","part":"face","action":"physical_attack","launch_fraction":0.3,"impact_fraction":0.45,"contact_yaw_degrees":0},{"species":"mothim","move":"Hyper Beam","part":"mouth","action":"physical_attack","launch_fraction":0.14,"impact_fraction":0.24,"emission_scale":0.08,"emission_end_fraction":0.34},{"species":"mothim","move":"Solar Beam","part":"mouth","action":"physical_attack","launch_fraction":0.14,"impact_fraction":0.24,"emission_scale":0.08,"emission_end_fraction":0.34},{"species":"mothim","move":"Shadow Ball","part":"mouth","action":"physical_attack","launch_fraction":0.18,"impact_fraction":0.35,"emission_scale":0.08},{"species":"mothim","move":"String Shot","part":"mouth","action":"physical_attack","launch_fraction":0.14,"impact_fraction":0.3,"emission_scale":0.15,"emission_end_fraction":0.36},{"species":"mothim","move":"Bug Bite","part":"mouth","action":"physical_attack","launch_fraction":0.5,"impact_fraction":0.65,"contact_yaw_degrees":0},{"species":"mothim","move":"Mud Slap","part":"mouth","action":"physical_attack","launch_fraction":0.18,"impact_fraction":0.35,"emission_scale":0.08,"projectile_arc_height":0.05},{"species":"flabebe","move":"Moonblast","part":"flower_tip","action":"physical_attack_2","launch_fraction":0.25,"impact_fraction":0.45,"emission_scale":0.05},{"species":"clamperl","move":"Ice Beam","part":"mouth","action":"special_attack","launch_fraction":0.42,"impact_fraction":0.52,"emission_scale":0.08,"emission_end_fraction":0.68},{"species":"clamperl","move":"Scald","part":"mouth","action":"special_attack","launch_fraction":0.42,"impact_fraction":0.52,"emission_scale":0.08,"emission_end_fraction":0.68},{"species":"clamperl","move":"Water Gun","part":"mouth","action":"special_attack","launch_fraction":0.42,"impact_fraction":0.52,"emission_scale":0.08,"emission_end_fraction":0.68},{"species":"clamperl","move":"Water Pulse","part":"mouth","action":"special_attack","launch_fraction":0.42,"impact_fraction":0.55,"emission_scale":0.12},{"species":"clamperl","move":"Supersonic","part":"mouth","action":"special_attack","launch_fraction":0.42,"impact_fraction":0.55,"emission_scale":0.08},{"species":"clauncher","move":"Ice Beam","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"emission_end_fraction":0.65},{"species":"clauncher","move":"Scald","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"emission_end_fraction":0.65},{"species":"clauncher","move":"Water Gun","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"emission_end_fraction":0.65},{"species":"clauncher","move":"Flash Cannon","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"emission_end_fraction":0.65},{"species":"clauncher","move":"Bubble","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.12},{"species":"clauncher","move":"Bubble Beam","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.12},{"species":"clauncher","move":"Water Pulse","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.12},{"species":"clauncher","move":"Sludge Bomb","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"projectile_arc_height":0.1},{"species":"clauncher","move":"Mud Slap","part":"cannon","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.45,"emission_scale":0.1,"projectile_arc_height":0.1},{"species":"clawitzer","move":"Ice Beam","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.2,"emission_end_fraction":0.7},{"species":"clawitzer","move":"Scald","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.2,"emission_end_fraction":0.7},{"species":"clawitzer","move":"Water Gun","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.2,"emission_end_fraction":0.7},{"species":"clawitzer","move":"Flash Cannon","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.2,"emission_end_fraction":0.7},{"species":"clawitzer","move":"Hyper Beam","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.12,"emission_end_fraction":0.7},{"species":"clawitzer","move":"Bubble","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2},{"species":"clawitzer","move":"Bubble Beam","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2},{"species":"clawitzer","move":"Water Pulse","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2},{"species":"clawitzer","move":"Shadow Ball","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2},{"species":"clawitzer","move":"Sludge Bomb","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2,"projectile_arc_height":0.1},{"species":"clawitzer","move":"Mud Slap","part":"cannon","action":"special_attack","launch_fraction":0.4,"impact_fraction":0.55,"emission_scale":0.2,"projectile_arc_height":0.1},{"species":"genesect","move":"Flamethrower","part":"cannon","action":"physical_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.12,"emission_end_fraction":0.56},{"species":"genesect","move":"Flash Cannon","part":"cannon","action":"physical_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.12,"emission_end_fraction":0.56},{"species":"genesect","move":"Hyper Beam","part":"cannon","action":"physical_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.06,"emission_end_fraction":0.56},{"species":"genesect","move":"Ice Beam","part":"cannon","action":"physical_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.12,"emission_end_fraction":0.56},{"species":"genesect","move":"Solar Beam","part":"cannon","action":"physical_attack","launch_fraction":0.4,"impact_fraction":0.5,"emission_scale":0.06,"emission_end_fraction":0.56},{"species":"revavroom","move":"Flash Cannon","part":"mouth","action":"physical_attack_2","launch_fraction":0.12,"impact_fraction":0.2,"emission_scale":0.15,"emission_end_fraction":0.27},{"species":"revavroom","move":"Hyper Beam","part":"mouth","action":"physical_attack_2","launch_fraction":0.12,"impact_fraction":0.2,"emission_scale":0.15,"emission_end_fraction":0.27},{"species":"revavroom","move":"Screech","part":"mouth","action":"physical_attack_2","launch_fraction":0.12,"impact_fraction":0.2,"emission_scale":0.2},{"species":"revavroom","move":"Sludge Bomb","part":"mouth","action":"physical_attack_2","launch_fraction":0.12,"impact_fraction":0.2,"emission_scale":0.15,"projectile_arc_height":0.1},{"species":"regidrago","move":"Hyper Beam","part":"face","action":"special_attack","launch_fraction":0.35,"impact_fraction":0.5,"emission_scale":0.25,"emission_end_fraction":0.68},{"species":"regidrago","move":"Dragon Breath","part":"face","action":"special_attack","launch_fraction":0.35,"impact_fraction":0.5,"emission_scale":0.25,"emission_end_fraction":0.68},{"species":"genesect","move":"Screech","part":"mouth","action":"special_attack","launch_fraction":0.3,"impact_fraction":0.5,"emission_scale":0.1},{"species":"genesect","move":"Bug Bite","part":"mouth","action":"physical_attack","launch_fraction":0.35,"impact_fraction":0.45,"contact_yaw_degrees":0},{"species":"revavroom","move":"Lick","part":"tongue_tip","action":"physical_attack_2","launch_fraction":0.1,"impact_fraction":0.2,"contact_yaw_degrees":0,"emission_end_fraction":0.27}]
	for route: Dictionary in routes:
		for slot in 4:
			var identity: String = route.species + ("@shiny" if slot % 2 else "")
			var actor := "p%d" % (slot+1)
			stage.identities[slot] = identity
			stage.combatants[slot] = {"species":route.species,"shiny":bool(slot % 2)}
			stage.entries[identity] = stage.entries.fixture.duplicate(true)
			stage.visual_bounds[identity] = stage.visual_bounds.fixture.duplicate(true)
			stage.start_move_action(actor,route.move)
			stage.players[slot].pause()
			assert(stage.current_actions[slot] == route.action)
			var timing: Dictionary = stage.move_timing(route.move,actor)
			assert(is_equal_approx(timing.launch_frame / timing.frames,route.launch_fraction))
			assert(is_equal_approx(timing.impact_frame / timing.frames,route.impact_fraction))
			var effect: Node = stage.create_move_effect(route.move,actor,"p%d" % ((slot^1)+1),{})
			effect.set_process(false)
			for key: String in ["emission_scale","projectile_arc_height"]:
				if route.has(key):
					assert(is_equal_approx(timing[key],route[key]))
					assert(is_equal_approx(effect.get(key),route[key]))
			if route.has("contact_yaw_degrees"):
				assert(is_equal_approx(timing.contact_yaw_degrees,route.contact_yaw_degrees))
			if route.has("emission_end_fraction"):
				assert(is_equal_approx(timing.emission_end_frame / timing.frames,route.emission_end_fraction))
				var end_property := "water_emission_end" if route.move == "Water Gun" else "emission_end"
				assert(is_equal_approx(effect.get(end_property),timing.emission_end_frame/60.0))
				effect.clock = func(): return contact_seconds
				contact_seconds=timing.emission_end_frame/60.0+.001
				effect._process(0)
				if route.move != "Lick":
					assert(effect.cursor==0,"Source emission ends inside the selected window")
			effect.cancel()
			var doll := Doll.new()
			stage.world.add_child(doll)
			stage.substitute_models[slot] = doll
			var substitute_timing: Dictionary = stage.move_timing(route.move,actor)
			for key: String in ["emission_scale","projectile_arc_height","contact_yaw_degrees","emission_end_frame"]:
				assert(not substitute_timing.has(key))
			doll.free()
			stage.substitute_models[slot] = null
			await get_tree().process_frame
