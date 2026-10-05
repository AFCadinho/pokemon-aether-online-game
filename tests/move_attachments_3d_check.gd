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
	var doll := Doll.new()
	world.add_child(doll)
	doll.position = Vector3(-3,0,1)
	stage.substitute_models[0] = doll
	assert(stage._move_anchors("p1", "p2", "Ember").attachment_part == "bounds", "Visible Substitute must own the emitter")
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
	print("MOVE_ATTACHMENTS_3D_OK transforms=true moving_bones=true forms=true lifecycle=true paired_beams=true single_impact=true")
	get_tree().quit()
