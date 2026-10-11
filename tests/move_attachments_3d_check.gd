extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
class Doll extends Node3D:
	var idle_scale := 0.8
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const SourceEffect = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const LegacyEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
var seconds := 0.0
func _ready() -> void: _run.call_deferred()
func _rig(world: Node3D, names: Array) -> Node3D:
	var actor := Node3D.new()
	world.add_child(actor)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Rig"
	actor.add_child(skeleton)
	for name_value: String in names: skeleton.add_bone(name_value)
	return actor
func _run() -> void:
	get_tree().create_timer(15).timeout.connect(func(): get_tree().quit(1))
	var world := Node3D.new()
	add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(5, -2, 3))
	_check_weighted_attachments(world)
	var actor := _rig(world, ["head", "left_feeler_b_02", "right_feeler_b_02"])
	actor.transform = Transform3D(Basis(Vector3.UP, 0.9).scaled(Vector3(2, 3, 2)), Vector3(-4, 1, 2))
	var skeleton: Skeleton3D = actor.get_node("Rig")
	skeleton.position = Vector3(0.2, 0.3, 0.4)
	skeleton.set_bone_pose_position(0, Vector3(0, 1, 0))
	var mouth: Dictionary = Attachments.sample(actor, "charmander", "ember", world)
	var expected: Vector3 = actor.transform * skeleton.transform * (Vector3(0, 1, 0) + Vector3(0.05, 0, 0.195))
	assert(mouth.sources[0].is_equal_approx(expected))
	skeleton.set_bone_pose_position(0, Vector3(0.2, 1.5, -0.1))
	var rotation_value := Quaternion(Vector3.RIGHT, 0.65)
	skeleton.set_bone_pose_rotation(0, rotation_value)
	mouth = Attachments.sample(actor, "charmander@shiny", "ember", world)
	expected = actor.transform * skeleton.transform * (Vector3(0.2, 1.5, -0.1) + rotation_value * Vector3(0.05, 0, 0.195))
	assert(mouth.sources[0].is_equal_approx(expected), "Cached bindings must sample fresh bone poses")
	skeleton.set_bone_pose_position(1, Vector3(-0.5, 1, 0))
	skeleton.set_bone_pose_position(2, Vector3(0.5, 1, 0))
	var cannons: Dictionary = Attachments.sample(actor, "blastoise", "watergun", world)
	assert(cannons.sources.size() == 2 and cannons.part == "cannons")
	assert(cannons.sources[0].distance_to(cannons.sources[1]) > 0.9)
	assert(Attachments.sample(actor, "blastoise-mega", "watergun", world).is_empty())
	assert(Attachments.sample(actor, "unknown", "watergun", world).is_empty())
	assert(Attachments.part_for("charmander", "bite") == "mouth")
	assert(Attachments.part_for("charmander", "scratch") == "hand")
	assert(Attachments.part_for("pikachu", "tackle") == "body")
	assert(Attachments.part_for("pikachu@shiny", "thundershock") == "electric_body")
	for identity: String in ["zapdos", "zapdos@shiny", "zapdos-galar", "zapdos-galar@shiny"]:
		assert(Attachments.part_for(identity, "peck") == "beak_tip")
		assert(Attachments.part_for(identity, "hyperbeam") == "mouth")
		assert(Attachments.definitions_for(identity, "beak_tip").size() == 1)
		assert(Attachments.definitions_for(identity, "beak_tip")[0][0].bone == "head")
	for identity: String in ["zygarde-mega", "zygarde-mega@shiny"]:
		assert(Attachments.part_for(identity, "hyperbeam") == "cannon")
		assert(Attachments.definitions_for(identity, "cannon")[0][0].bone == "feeler_a_02")
		assert(Attachments.part_for(identity, "bite") == "mouth")
	assert(Attachments.part_for("zygarde-50", "hyperbeam") == "mouth")
	for species: String in ["regice", "regieleki", "regigigas", "regirock", "registeel", "staryu", "starmie"]:
		for identity: String in [species, species + "@shiny"]:
			var part := "gem" if species.begins_with("star") else "face"
			var move := "watergun" if part == "gem" else "hyperbeam"
			assert(Attachments.part_for(identity, move) == part)
			assert(Attachments.definitions_for(identity, part).size() == 1)
			assert(Attachments.definitions_for(identity, "mouth").is_empty())
			assert(Attachments.part_for(identity, "tackle") == "body")
	for identity: String in ["staryu", "staryu@shiny", "starmie", "starmie@shiny"]:
		for move: String in ["watergun", "bubblebeam", "icebeam", "flashcannon", "scald", "waterpulse"]:
			assert(Attachments.part_for(identity, move) == "gem")
	assert(Attachments.part_for("starmie", "hyperbeam") == "gem")
	assert(Attachments.part_for("starmie-mega", "watergun") == "mouth")
	for species: String in ["grimer", "grimer-alola", "goodra", "gengar", "crobat", "bunnelby"]:
		for identity: String in [species, species + "@shiny"]:
			var emitters := Attachments.definitions_for(identity, "mouth")
			assert(emitters.size() == 1)
			assert(emitters[0].size() > 1 if species != "crobat" else emitters[0][0].bone == "head")
			assert(Attachments.part_for(identity, "sludgebomb") == "mouth")
	assert(Attachments.definitions_for("grimer", "mouth") != Attachments.definitions_for("grimer-alola", "mouth"))
	assert(Attachments.definitions_for("goodra", "mouth") != Attachments.definitions_for("goodra-hisui", "mouth"))
	assert(Attachments.definitions_for("gengar", "mouth") != Attachments.definitions_for("gengar-mega", "mouth"))

	for species: String in ["cetoddle", "drizzile", "crabominable", "lugia", "ho-oh", "houndstone", "minccino", "grumpig", "slaking", "sudowoodo", "wyrdeer", "slugma", "archaludon", "avalugg-hisui", "glalie-mega", "roaring-moon"]:
		for identity: String in [species, species + "@shiny"]:
			var emitters := Attachments.definitions_for(identity, "mouth")
			assert(emitters.size() == 1 and emitters[0].size() > 1)
			assert(Attachments.part_for(identity, "icebeam") == "mouth")

	for identity: String in ["ariados", "ariados@shiny"]:
		assert(Attachments.definitions_for(identity, "mouth")[0][0].bone == "head")
		assert(Attachments.part_for(identity, "hyperbeam") == "mouth")

	for identity: String in ["zweilous", "zweilous@shiny"]:
		var heads := Attachments.definitions_for(identity, "mouth")
		assert(heads.size() == 2)
		assert(heads[0][0].bone == "right_head" and heads[1][0].bone == "left_head")
	for move: String in ["bugbite", "peck", "lick"]:
		assert(Attachments.part_for("charmander", move) == "mouth")
	for move: String in ["doublekick", "highjumpkick", "lowkick", "pyroball"]:
		assert(Attachments.part_for("cinderace", move) == "foot")
	assert(Attachments.part_for("snivy@shiny", "vinewhip") == "vines")
	assert(Attachments.definitions_for("snivy", "vines").size() == 2)
	assert(Attachments.action_for("snivy@shiny", "vinewhip", {"physical_attack_2": {}}) == "physical_attack_2")
	assert(Attachments.action_for("snivy", "vinewhip", {"physical_attack": {}}).is_empty())
	assert(Attachments.action_for("snivy", "tackle", {"physical_attack_2": {}}).is_empty())
	for species: String in ["scovillain", "scovillain@shiny"]:
		for move: String in ["bite", "flamethrower"]:
			assert(Attachments.part_for(species, move) == "mouth_red")
			assert(Attachments.action_for(species, move, {"physical_attack": {}, "special_attack": {}}) == "physical_attack")
		for move: String in ["hyperbeam", "solarbeam"]:
			assert(Attachments.part_for(species, move) == "mouth")
			assert(Attachments.action_for(species, move, {"physical_attack": {}, "special_attack": {}}) == "special_attack")
		assert(Attachments.definitions_for(species, "mouth").size() == 1)
		assert(Attachments.definitions_for(species, "mouth_red").size() == 1)
	assert(Attachments.action_for("scovillain-mega", "flamethrower", {"physical_attack": {}, "special_attack": {}}).is_empty(), "Alternate forms must not inherit incompatible native action routes")
	for route: Array in [["decidueye", "lowkick", "physical_attack_2"], ["glastrier", "doublekick", "physical_attack_2"], ["calyrex-ice", "doublekick", "physical_attack"], ["calyrex-shadow", "doublekick", "physical_attack"], ["exploud", "lowkick", "physical_attack"]]:
		for identity: String in [route[0], route[0] + "@shiny"]:
			assert(Attachments.part_for(identity, route[1]) == "foot")
			assert(Attachments.action_for(identity, route[1], {"physical_attack": {}, "physical_attack_2": {}}) == route[2])
			assert(Attachments.definitions_for(identity, "foot").size() == 1)
	assert(Attachments.action_for("decidueye-hisui", "lowkick", {"physical_attack": {}, "physical_attack_2": {}}).is_empty(), "Hisuian form must not inherit Decidueye's kick clip")
	var electric_actor := _rig(world, ["spine_02"])
	var electric_rig: Skeleton3D = electric_actor.get_node("Rig")
	electric_rig.set_bone_pose_position(0, Vector3(0, 0.8, 0))
	var discharge := Attachments.sample(electric_actor, "pikachu@shiny", "thundershock", world)
	assert(discharge.sources[0].is_equal_approx(Vector3(0,0.8,0)))
	electric_rig.set_bone_pose_position(0, Vector3(0, 1.2, 0))
	assert(Attachments.sample(electric_actor, "pikachu", "thundershock", world).sources[0].is_equal_approx(Vector3(0,1.2,0)))
	assert(Attachments.sample(electric_actor, "pikachu", "tackle", world).is_empty(), "Approved Tackle keeps its body fallback")
	electric_actor.free()
	var incomplete := _rig(world, ["left_feeler_b_02"])
	assert(Attachments.sample(incomplete, "blastoise", "watergun", world).is_empty())
	actor.free()
	actor = _rig(world, ["head"])
	assert(Attachments.sample(actor, "charmander", "ember", world).sources[0].is_equal_approx(Vector3(0.05, 0, 0.195)), "Replacement models must not inherit old bindings")
	var stage := Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	stage.world = world
	stage.identities[0] = "snivy"
	stage.entries.snivy = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Vine Whip", "p1") == "physical_attack_2")
	stage.entries.erase("snivy")
	stage.identities[0] = "scovillain"
	stage.entries.scovillain = {"action_timing": {"physical_attack": {}, "special_attack": {}}}
	assert(stage.attack_action_for("Flamethrower", "p1") == "physical_attack")
	assert(stage.attack_action_for("Solar Beam", "p1") == "special_attack")
	stage.entries.erase("scovillain")
	stage.identities[0] = "decidueye"
	stage.entries.decidueye = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Low Kick", "p1") == "physical_attack_2")
	stage.entries.erase("decidueye")
	stage.identities[0] = "glastrier"
	stage.entries.glastrier = {"action_timing": {"physical_attack": {}, "physical_attack_2": {}}}
	assert(stage.attack_action_for("Double Kick", "p1") == "physical_attack_2")
	stage.entries.erase("glastrier")
	for i in 2:
		stage.actors[i] = _rig(world, ["head"])
		stage.actors[i].position.x = -2 if i == 0 else 2
		stage.identities[i] = "charmander"
		stage.combatants[i] = {"species": "charmander", "shiny": false}
		stage.actor_shown[i] = true
		stage.lifecycle[i] = "idle"
	stage.visual_bounds.charmander = {"idle": {"min": [-0.5,0,-0.5], "size": [1,2,1]}}
	var actual: Dictionary = stage._move_anchors("p1", "p2", "Ember")
	assert(actual.attachment_part == "mouth")
	assert(stage._move_anchors("p2", "p1", "Ember").attachment_part == "mouth")
	# Charmeleon previously used static idle bounds above its animated mouth.
	# Exercise the battle-stage route on both sides, including the shiny rig.
	for index in 2:
		stage.identities[index] = "charmeleon" if index == 0 else "charmeleon@shiny"
		stage.combatants[index] = {"species": "charmeleon", "shiny": index == 1}
		var rig: Skeleton3D = stage.actors[index].get_node("Rig")
		var ident := "p%d" % (index + 1)
		var target := "p%d" % (2 - index)
		stage.actors[index].rotation.y = 0.7 if index == 0 else -0.7
		stage.actors[index].scale = Vector3.ONE * 1.6
		for head_y in [0.8, 1.2]:
			rig.set_bone_pose_position(0, Vector3(0, head_y, 0))
			rig.set_bone_pose_rotation(0, Quaternion(Vector3.RIGHT, head_y))
			var flame: Dictionary = stage._move_anchors(ident, target, "Flamethrower")
			var lip := Vector3(-0.015, 0, 0.235)
			var expected_lip := world.to_local(rig.to_global(rig.get_bone_global_pose(0) * lip))
			assert(flame.attachment_part == "mouth" and flame.attachment_bones == ["head"])
			assert(flame.source.is_equal_approx(expected_lip), "Flamethrower must follow Charmeleon's animated mouth")
		stage.identities[index] = "charmander"
		stage.combatants[index] = {"species": "charmander", "shiny": false}
		stage.actors[index].rotation.y = 0
		stage.actors[index].scale = Vector3.ONE
		rig.reset_bone_pose(0)
	# The whole Moonblast orb must clear the attacker's silhouette on either
	# side, including rotated/scaled models; the moon keeps its own body anchor.
	var orb_radius: float = Stage.BatchFourMoveEffect.MOONBLAST_ORB_RADIUS * LegacyEffect.PRESENTATION_SCALES.moonblast
	for index in 2:
		for yaw in [0.0,PI/4]:
			for size in [0.75,2.0]:
				stage.actors[index].rotation.y = yaw
				stage.actors[index].scale = Vector3.ONE * size
				var charge: Dictionary = stage._move_anchors("p%d" % (index+1),"p%d" % (2-index),"Moonblast")
				var bounds: AABB = stage.actors[index].transform * AABB(Vector3(-0.5,0,-0.5),Vector3(1,2,1))
				var forward: Vector3 = charge.target-charge.source
				forward.y = 0
				forward = forward.normalized()
				for corner in 8:
					assert(charge.source.dot(forward)-orb_radius > bounds.get_endpoint(corner).dot(forward))
				assert(charge.moon_source.dot(forward)<charge.source.dot(forward))
		stage.actors[index].rotation.y = 0
		stage.actors[index].scale = Vector3.ONE
	var doll := Doll.new()
	world.add_child(doll)
	doll.position = Vector3(-3,0,1)
	stage.substitute_models[0] = doll
	assert(stage._move_anchors("p1", "p2", "Ember").attachment_part == "bounds", "Visible Substitute must own the emitter")
	stage.identities[0] = "charmeleon"
	stage.combatants[0].species = "charmeleon"
	assert(stage._move_anchors("p1", "p2", "Flamethrower").attachment_part == "bounds")
	stage.identities[0] = "charmander"
	stage.combatants[0].species = "charmander"
	var doll_charge: Dictionary = stage._move_anchors("p1","p2","Moonblast")
	assert(doll_charge.source.distance_to(doll.position)>orb_radius+doll.idle_scale*0.6)
	doll.hide()
	assert(stage._move_anchors("p1", "p2", "Ember").attachment_part == "mouth")
	stage.world = null # This fixture owns world separately from the stage.
	stage.free()
	# Both renderers emit two beams but keep one target splash and one effect clock.
	for script in [SourceEffect, LegacyEffect]:
		for outcome in ["hit", "miss", "block"]:
			seconds = 0
			var effect: Node3D = script.new()
			world.add_child(effect)
			var points := {"source": Vector3(-2,1,0), "sources": [Vector3(-2,1,-0.5), Vector3(-2,1,0.5)], "target": Vector3(2,1,0), "radius": 0.8}
			effect.start("watergun", {"frames": 60, "impact_frame": 27}, {"show_impact": outcome == "hit", "result": "miss" if outcome == "miss" else ""}, func(): return seconds, func(): return points, func(): return true)
			effect.set_process(false)
			seconds = 0.48
			effect._process(0)
			assert(effect.emission_sources.size() == 2 and effect.cursor < 90)
			if script == SourceEffect:
				var muzzle_count := 0
				var splash_count := 0
				for i in effect.cursor:
					if i >= effect.sprite_keys.size(): continue
					if effect.sprite_keys[i] == "water_muzzle": muzzle_count += 1
					if effect.sprite_keys[i] == "water_splash": splash_count += 1
				assert(muzzle_count == 2 and splash_count == (1 if outcome == "hit" else 0))
			effect.cancel()
			await get_tree().process_frame
			await get_tree().process_frame
	var lash_counts := []
	for count in [1, 2]:
		seconds = 0
		var lash := Stage.StagedMoveEffect.new()
		world.add_child(lash)
		var sources := [Vector3(-2,1,-0.5)]
		if count == 2: sources.append(Vector3(-2,1,0.5))
		var points := {"source": sources[0], "sources": sources, "target": Vector3(2,1,0), "radius": 0.8}
		lash.start("vinewhip", {"frames": 60, "launch_frame": 10, "impact_frame": 40}, {}, func(): return seconds, func(): return points, func(): return true)
		lash.set_process(false)
		seconds = 0.62
		lash._process(0)
		lash_counts.append(lash.cursor)
		lash.cancel()
		await get_tree().process_frame
	assert(lash_counts[1] - lash_counts[0] == 12, "Each vine tip must create its own twelve-segment lash")
	var lash_widths := []
	for part in ["hand", "vines"]:
		seconds = 0
		var lash := Stage.StagedMoveEffect.new()
		world.add_child(lash)
		var points := {"source": Vector3(-2,1,0), "sources": [Vector3(-2,1,0)], "target": Vector3(2,1,0), "radius": 0.8, "attachment_part": part}
		lash.start("vinewhip", {"frames": 60, "launch_frame": 10, "impact_frame": 40}, {}, func(): return seconds, func(): return points, func(): return true)
		lash.set_process(false)
		seconds = 0.62
		lash._process(0)
		var widths := []
		for i in lash.cursor:
			if lash.pieces[i].mesh == lash.tube and lash.pieces[i].material_override == lash.edge:
				widths.append(lash.pieces[i].basis.x.length())
		# Eight approach trails precede the twelve vine segments.
		assert(widths.size() == 20)
		lash_widths.append(widths[8])
		lash.cancel()
		await get_tree().process_frame
	assert(is_equal_approx(lash_widths[1] / lash_widths[0], .008 / .045), "Native vine tips must retain their narrower extension width")
	print("MOVE_ATTACHMENTS_3D_OK transforms=true moving_bones=true forms=true lifecycle=true paired_beams=true paired_vines=true single_impact=true")
	get_tree().quit()

func _check_weighted_attachments(world: Node3D) -> void:
	var upper := {"bone": "upper", "offset": [0, 0, 0.2], "weight": 1.0}
	var lower := {"bone": "lower", "offset": [0, 0, 0.2], "weight": 3.0}
	var calibrated_profiles: Dictionary = Attachments.CALIBRATED.data.profiles
	calibrated_profiles["__weighted_test"] = {
		"parts": {"mouth": [[upper, lower]]},
		"actions": {"physical_attack_2": {"mouth": [[upper]]}},
	}
	var actor := _rig(world, ["upper", "lower"])
	actor.transform = Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3(2, 3, 2)), Vector3(1, 2, 3))
	var rig: Skeleton3D = actor.get_node("Rig")
	rig.set_bone_pose_position(0, Vector3(0, 2, 0))
	rig.set_bone_pose_position(1, Vector3(0, 1, 0))
	var result := Attachments.sample(actor, "__weighted_test@shiny", "ember", world)
	assert(result.sources.size() == 1, "Blended lips must emit one projectile")
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 1.25, 0.2)))
	rig.set_bone_pose_position(1, Vector3(0, 0, 0))
	result = Attachments.sample(actor, "__weighted_test", "ember", world)
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 0.5, 0.2)), "Jaw movement must update cached blended attachments")
	result = Attachments.sample(actor, "__weighted_test", "ember", world, "physical_attack_2")
	assert(result.sources[0].is_equal_approx(actor.transform * Vector3(0, 2, 0.2)), "Action overrides must have distinct cache entries")
	var partial := _rig(world, ["upper"])
	assert(Attachments.sample(partial, "__weighted_test", "ember", world).is_empty())
	assert(not Attachments.sample(partial, "__weighted_test", "ember", world, "physical_attack_2").is_empty())
	assert(Attachments._bind(actor, [[{"bone": "upper", "offset": [0, 0], "weight": 1}]]).is_empty())
	assert(Attachments._bind(actor, [[{"bone": "upper", "offset": [0, 0, 0], "weight": 0}]]).is_empty())
	var open_mesh := MeshInstance3D.new()
	open_mesh.name = "OpenMouth"
	actor.add_child(open_mesh)
	var closed_mesh := MeshInstance3D.new()
	closed_mesh.name = "ClosedMouth"
	actor.add_child(closed_mesh)
	var open_point := upper.duplicate()
	open_point["visible_mesh"] = "OpenMouth"
	var closed_point := lower.duplicate()
	closed_point["visible_mesh"] = "ClosedMouth"
	calibrated_profiles["__visibility_test"] = {"parts":{"mouth":[[open_point], [closed_point]]}}
	closed_mesh.hide()
	var open_result := Attachments.sample(actor, "__visibility_test", "ember", world)
	assert(open_result.sources.size() == 1)
	assert(open_result.sources[0].is_equal_approx(actor.transform * Vector3(0, 2, .2)))
	open_mesh.hide()
	closed_mesh.show()
	var closed_result := Attachments.sample(actor, "__visibility_test", "ember", world)
	assert(closed_result.sources.size() == 1)
	assert(closed_result.sources[0].is_equal_approx(actor.transform * Vector3(0, 0, .2)), "Cached bindings must follow mouth-mesh switches")
	closed_mesh.hide()
	assert(Attachments.sample(actor, "__visibility_test", "ember", world).is_empty())
	open_mesh.free()
	assert(Attachments.sample(actor, "__visibility_test", "ember", world).is_empty(), "Freed visibility predicates invalidate the attachment")
	assert(Attachments._bind(actor, [[open_point]]).is_empty(), "Missing visibility mesh invalidates the attachment")
	calibrated_profiles.erase("__visibility_test")
	actor.free()
	partial.free()
	calibrated_profiles.erase("__weighted_test")
