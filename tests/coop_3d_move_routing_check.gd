extends "res://tests/trainer_3d_summon_visibility_check.gd"

const Stage := preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

var observed: Array[Node] = []
var completed := false
var attacks: Array = []

func _run() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = ""
	settings.battle_3d_arena = "classic"
	settings._manual_model_catalog_this_session = true
	settings.battle_animations = true
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var service := root.get_node("CoopService")
	service.reset()
	service.activity = {"activityId": "wild_grass:kanto_route_1", "status": "active"}
	var battle: Variant = _battle()
	assert(battle.setup_coop_battle())
	var panel: Node = battle.coop_presenter
	panel.set_process(false)
	var model: Node = battle.animation_router.model_presenter
	for key: String in ["charmander", "pikachu", "squirtle", "bulbasaur"]:
		_seed_attack_model(model, key)
	var snapshot := {"participant": "p3", "positions": [
		{"controller": "p1", "details": "Charmander, L20", "hpPercent": 100},
		{"controller": "p2", "details": "Pikachu, L20", "hpPercent": 100},
		{"controller": "p3", "details": "Squirtle, L20", "hpPercent": 100},
		{"controller": "p4", "details": "Bulbasaur, L20", "hpPercent": 100}],
		"ownTeam": [{"species": "Squirtle", "active": true, "hp": 20, "maxHp": 20}], "events": []}
	panel._latest = snapshot
	panel._apply_positions(snapshot)
	for frame in 8: await process_frame
	assert(model.active)
	assert(panel._native_move_router.get("model_presenter") == model,
		"The actual doubles panel must bind its router to the four-slot 3D presenter")
	for controller: String in ["p1", "p2", "p3", "p4"]:
		assert(model.handles(controller))
		# Explicitly hide the legacy sprite: pair binding must use models alone.
		panel._native_sprite(controller).visible = false
	panel._native_move_router.call("dispose")
	var native: Variant = load("res://tests/fixtures/coop_3d_router_probe.gd").new()
	native.setup(battle.player_sprite_box, battle.enemy_sprite_box, panel._effects.get_parent(), Callable(panel, "_native_animation_allowed"))
	native.model_presenter = model
	native.playback_speed = 8.0
	panel._native_move_router = native
	model.world.child_entered_tree.connect(_observe)
	for slot in 4:
		model.players[slot].animation_started.connect(_record_attack.bind(slot))
	# Crossed opposing slots, allied targets and self-targets retain real IDs.
	for pair: Array in [["p1", "p4"], ["p3", "p2"], ["p2", "p3"], ["p4", "p1"], ["p1", "p3"], ["p4", "p4"]]:
		var bound: Dictionary = native.bind_native_pair(pair[0], pair[1], {}, {})
		assert(bound.actor == pair[0] and bound.target == pair[1], "3D identities cannot collapse into p1/p2 aliases")
		var before := observed.size()
		var attacks_before := attacks.size()
		await panel._animate_event({"kind": "move", "actor": pair[0], "target": pair[1], "move": "Ember"})
		assert(observed.size() > before, "The real doubles event must create native move geometry")
		assert(native.active_audio_nodes.is_empty())
		assert(attacks.size() == attacks_before + 1, "One target starts the model attack once")
		assert(attacks.back() == model.actor_index(pair[0]))
	# The same pair resolves against current 3D actor/bone bounds, not a sprite.
	for actor: String in ["p1", "p2", "p3", "p4"]:
		var target := "p4" if actor != "p4" else "p1"
		var anchors: Dictionary = model._move_anchors(actor, target, "Ember")
		var source_bounds: Dictionary = model._move_bounds(actor)
		assert(anchors.source.distance_to(source_bounds.position) < 3.0)
		assert(anchors.target.distance_to(model._move_bounds(target).position) < 3.0)
		assert(anchors.source.distance_to(anchors.target) > 0.1)
	# Bone-driven mouth anchors must follow animated poses in every doubles slot.
	for slot in 4:
		var old_identity: String = model.identities[slot]
		var old_combatant: Dictionary = model.combatants[slot]
		model.identities[slot] = "charmander"
		model.combatants[slot] = {"species": "charmander", "shiny": false}
		var actor := "p%d" % (slot + 1)
		var target := "p4" if slot != 3 else "p1"
		var anchor: Dictionary = model._move_anchors(actor, target, "Ember")
		assert(anchor.attachment_part == "mouth" and not anchor.attachment_bones.is_empty())
		var rig: Skeleton3D = model.actors[slot].get_node("Rig")
		rig.set_bone_pose_position(0, Vector3(0.3, 1.4, 0))
		var moved: Dictionary = model._move_anchors(actor, target, "Ember")
		assert(anchor.source.distance_to(moved.source) > 0.05, "Each slot samples the current 3D bone pose")
		rig.set_bone_pose_position(0, Vector3(0, 1, 0))
		model.identities[slot] = old_identity
		model.combatants[slot] = old_combatant
	var spread := {"kind": "move", "seq": 10, "actor": "p3", "move": "Ember", "targets": ["p2", "p4"]}
	var before := observed.size()
	await panel._play_native_catalog_move(spread, [{"kind": "-miss", "seq": 11, "actor": "p3", "target": "p4"}])
	assert(observed.size() == before + 2 and native.audible)
	native.audible = false
	assert(await native._start_3d_audio("move", "ember") == null, "Secondary spread targets must stay silent")
	native.audible = true
	await panel._play_native_catalog_move({"kind": "move", "actor": "p3", "target": "p4", "move": "Unmapped Future Move"}, [])
	await panel._play_native_stat_change("p4", 1)
	for frame in 3: await process_frame
	assert(native._sprite_tweens.is_empty(), "Native stat effects cannot start hidden 2D sprite tweens")
	# A loading/replaced model does not permit a sprite fallback in an active 3D stage.
	var identity: String = model.identities[3]
	model.identities[3] = "loading"
	assert(native.bind_native_pair("p1", "p4", {}, {}).is_empty())
	model.identities[3] = identity
	completed = false
	_play_until_cancelled(panel)
	for frame in 120:
		if not model.common_effects.is_empty() or completed: break
		await process_frame
	assert(not completed and not model.common_effects.is_empty())
	native.cancel_render()
	for frame in 120:
		if completed: break
		await process_frame
	assert(completed and native.active_audio_nodes.is_empty())
	model.world.child_entered_tree.disconnect(_observe)
	battle.free()
	service.reset()
	await process_frame
	print("COOP_3D_MOVE_ROUTING_PASS")
	quit(0)

func _record_attack(action: StringName, slot: int) -> void:
	if str(action).contains("attack"):
		attacks.append(slot)

func _observe(node: Node) -> void:
	if node.get_script() == Stage.SourceMoveEffect:
		observed.append(node)

func _play_until_cancelled(panel: Node) -> void:
	await panel._play_native_catalog_move({"kind": "move", "actor": "p3", "target": "p4", "move": "Ember"}, [])
	completed = true

func _seed_attack_model(stage: Node, key: String) -> void:
	var actor := MeshInstance3D.new()
	actor.mesh = CapsuleMesh.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Rig"
	actor.add_child(skeleton)
	skeleton.owner = actor
	skeleton.add_bone("head")
	skeleton.set_bone_pose_position(0, Vector3(0, 1, 0))
	var player := AnimationPlayer.new()
	actor.add_child(player)
	player.owner = actor
	var library := AnimationLibrary.new()
	var timing := {}
	for action: String in ["idle", "physical_attack", "special_attack", "damage"]:
		var clip := Animation.new()
		clip.length = 0.4
		clip.loop_mode = Animation.LOOP_LINEAR if action == "idle" else Animation.LOOP_NONE
		library.add_animation(action, clip)
		timing[action] = {"frames": 24.0, "speed": 1.0, "loop": action == "idle"}
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK)
	actor.free()
	stage.packed[key] = packed
	stage.entries[key] = {"action_timing": timing}
	stage.placements[key] = {"scale": 1.0, "yaw_degrees": 0.0, "lift": 0.5, "hover_height": 0.0, "calibrated": false}
