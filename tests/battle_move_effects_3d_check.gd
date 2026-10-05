extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const Timing = preload("res://scripts/battle/battle_3d_move_timing.gd")
const Catalog = preload("res://scripts/battle/animations/battle_audio_catalog.gd")
class SilentCatalog extends Catalog:
	func get_plan(_kind: String, _key: String) -> Dictionary: return {}
class Doll extends Node3D:
	var idle_scale := 0.8
class Router extends BattleAnimationRouter:
	var loaded: Array[String] = []
	func _get_move_animation_config(_key: String) -> Dictionary:
		assert(false,"Native moves must never load 2D visual configs")
		return {}
	func _get_cached_sound_stream(path: String) -> AudioStream:
		loaded.append(path)
		return super._get_cached_sound_stream(path)
var stage: Node
var router: Router
var complete := false
var misses := 0
func _ready() -> void: _run.call_deferred()
func _setup() -> void:
	SettingsManager.battle_animations = true
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	stage.double_mode = true
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	stage.visual_bounds.fixture = {"idle":{"min":[-0.5,0,-0.5],"size":[1,2,1]}}
	stage.entries.fixture = {"action_timing":{}}
	for action in ["idle","physical_attack","special_attack","damage"]:
		stage.entries.fixture.action_timing[action] = {"frames":60.0,"speed":1.0,"loop": action == "idle"}
	for index in 4:
		var actor := Node3D.new()
		stage.world.add_child(actor)
		actor.position = Vector3(index*3,0,index%2*3)
		var player := AnimationPlayer.new()
		actor.add_child(player)
		var library := AnimationLibrary.new()
		for action in stage.entries.fixture.action_timing:
			var clip := Animation.new()
			clip.length = 1.0
			var track := clip.add_track(Animation.TYPE_VALUE)
			clip.track_set_path(track, NodePath(".:rotation:y"))
			clip.track_insert_key(track,0.0,0.0)
			clip.track_insert_key(track,1.0,0.1)
			library.add_animation(action,clip)
		player.add_animation_library("",library)
		stage.actors[index] = actor
		stage.players[index] = player
		stage.identities[index] = "fixture"
		stage.combatants[index] = {"species":"fixture","shiny":false}
		stage.actor_shown[index] = true
		stage.lifecycle[index] = "idle"
		stage.current_actions[index] = "idle"
	router = Router.new()
	router.model_presenter = stage
	router.animation_parent = stage
func _route(move: String, options: Dictionary = {}) -> void:
	await router.play_move_animation(move,"p1","p2",options)
	complete = true
func _miss() -> void: misses += 1
func _run() -> void:
	_setup()
	var catalog := Catalog.new()
	for move: String in Effect.KEYS:
		var timing: Dictionary = stage.move_timing(move,"p1")
		var source := catalog.get_plan("move",Effect.audio_source_key(move))
		var copy := source.duplicate(true)
		var plan := Effect.audio_plan(source,timing)
		assert(source == copy and plan.cues.size() == (2 if move in ["thunderbolt","razorleaf"] or Effect.IMPACT_SOUNDS.has(move) else 1) and plan.sound_paths == source.sound_paths)
		var expected: float = timing.impact_frame/60.0 if move in ["tackle","scratch","bite"] else timing.impact_frame/60.0-0.28
		assert(is_equal_approx(plan.cues[0].at_seconds,expected))
		if move in ["thunderbolt","razorleaf"] or Effect.IMPACT_SOUNDS.has(move): assert(is_equal_approx(plan.cues[1].at_seconds,timing.impact_frame/60.0))
		for slot in 4:
			var actor := "p%d" % (slot+1)
			var target := "p%d" % ((slot+1)%4+1)
			stage.start_move_action(actor,move)
			var effect: Node = stage.create_move_effect(move,actor,target,{"show_impact":true})
			assert(is_instance_valid(effect))
			if move == "ember": assert(effect.get_script() == Stage.SourceMoveEffect, "Approved Ember must use packaged source textures")
			if move in ["tackle", "scratch", "bite", "quickattack"]: assert(effect.get_script() == Stage.ContactMoveEffect)
			if move == "thundershock": assert(effect.get_script() == Stage.ElectricMoveEffect)
			if move == "thunderbolt": assert(effect.get_script() == Stage.ThunderboltMoveEffect)
			if move in Stage.BatchFourMoveEffect.MOVE_KEYS: assert(effect.get_script() == Stage.BatchFourMoveEffect)
			if move == "icebeam": assert(effect.get_script() == Stage.IceBeamMoveEffect)
			if move == "razorleaf": assert(effect.get_script() == Stage.LeafMoveEffect)
			if move == "flamethrower": assert(effect.get_script() == Stage.FireStreamMoveEffect)
			if move in ["bubble","bubblebeam"]: assert(effect.get_script() == Stage.BubbleMoveEffect)
			if move == "watergun": assert(effect.get_script() == Stage.SourceMoveEffect, "Approved Water Gun must use packaged source textures")
			effect.set_process(false)
			stage.players[slot].seek(effect.impact+0.04,true)
			effect._process(0)
			assert(effect.pieces.size() > 0 and effect.pieces.size() < 90, "%s slot=%d count=%d elapsed=%f impact=%f" % [move,slot,effect.pieces.size(),effect.elapsed,effect.impact])
			assert(effect.hit and effect.has_meta("battle_field_visual"))
			var anchors: Dictionary = effect.anchors.call()
			assert(anchors.source.distance_to(anchors.target)>0.1)
			effect.cancel()
			await get_tree().process_frame
			assert(stage.common_effects.is_empty())
	# A visible Substitute supplies both the anchor and the lifecycle guard.
	var doll := Doll.new()
	stage.world.add_child(doll)
	doll.position = Vector3(4,0,2)
	stage.substitute_models[1] = doll
	stage.actors[1].visible = false
	stage.start_move_action("p1","Water Gun")
	var substitute_effect: Node = stage.create_move_effect("Water Gun","p1","p2",{"show_impact":true})
	assert(is_instance_valid(substitute_effect))
	assert(is_equal_approx(stage._move_bounds("p2").height,0.96))
	assert(stage._move_bounds("p2").position == doll.position)
	doll.visible = false
	substitute_effect._process(0)
	assert(substitute_effect.cancelled)
	stage.substitute_models[1] = null
	doll.queue_free()
	stage.actors[1].visible = true
	await get_tree().process_frame
	# Stage deactivation synchronously cancels owned move geometry.
	stage.start_move_action("p1","Ember")
	var shutdown_effect: Node = stage.create_move_effect("Ember","p1","p2",{"show_impact":true})
	stage._set_active(false)
	assert(shutdown_effect.cancelled and stage.common_effects.is_empty())
	stage.active = true
	await get_tree().process_frame
	assert(stage.create_move_effect("Unknown","p1","p2",{}) == null)
	assert(stage.create_move_effect("Ember","p1","missing",{}) == null)
	# Outcome evidence comes only from the ordered events, including Substitute hits.
	var move_event := {"type":"move","actor":"p1","target":"p2"}
	assert(Timing.has_target_hit([move_event,{"type":"damage","target":"p2"}],0))
	assert(Timing.has_target_hit([move_event,{"type":"pokemonEffect","target":"p2","effect":"move: Substitute","state":"activate"}],0))
	for outcome in ["miss","immune","fail"]:
		assert(not Timing.has_target_hit([move_event,{"type":outcome,"target":"p2"}],0))
	assert(not Timing.has_target_hit([move_event,{"type":"damage","target":"p2","source":"brn"}],0))
	assert(not Timing.has_target_hit([move_event,{"type":"move"},{"type":"damage","target":"p2"}],0))
	# Route owns VFX/audio through the impact/recovery split.
	await router.play_move_animation("Water Gun","p1","p2",{"stop_at_impact":true,"show_impact":true})
	assert(router.has_3d_impact_damage("p2") and not stage.common_effects.is_empty())
	assert(not router.loaded.is_empty() and router.active_audio_nodes.size()==1)
	await router.finish_3d_impact_damage("p2")
	await get_tree().process_frame
	assert(stage.common_effects.is_empty() and not router.has_3d_impact_damage())
	for audio: Node in router.active_audio_nodes: assert(audio.draining)
	router.cancel_render()
	await get_tree().process_frame
	# Miss calls Dodge before motion; cancellation releases the waiter without repeating it.
	complete = false
	_route("Scratch",{"result":"miss","on_dodge_started":_miss,"show_impact":true})
	while stage.common_effects.is_empty() and not complete: await get_tree().process_frame
	assert(not complete and not stage.common_effects[0].hit)
	router.cancel_render()
	while not complete: await get_tree().process_frame
	assert(misses==1 and router.active_audio_nodes.is_empty())
	await get_tree().process_frame
	# Missing optional audio must not prevent native geometry.
	router.audio_catalog = SilentCatalog.new()
	complete = false
	_route("Ember",{"show_impact":true})
	while stage.common_effects.is_empty() and not complete: await get_tree().process_frame
	assert(not complete and router.active_audio_nodes.is_empty())
	var effect: Node = stage.common_effects[0]
	effect.set_process(false)
	var previous: Node3D = stage.actors[1]
	stage.actors[1] = Node3D.new()
	stage.world.add_child(stage.actors[1])
	effect._process(0)
	assert(effect.cancelled,"Replacing a target must cancel stale effects")
	stage.actors[1].free()
	stage.actors[1] = previous
	router.cancel_render()
	while not complete: await get_tree().process_frame
	await get_tree().process_frame
	stage.actor_shown[1] = false
	assert(stage.create_move_effect("Bite","p1","p2",{}) == null)
	stage.actor_shown[1] = true
	SettingsManager.battle_animations = false
	await router.play_move_animation("Ember","p1","p2")
	assert(stage.common_effects.is_empty())
	SettingsManager.battle_animations = true
	await router.play_move_animation("Bite","p1","p2",{"result":"miss","on_dodge_started":_miss})
	assert(misses==2)
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_MOVE_EFFECTS_3D_OK moves=",Effect.KEYS.size()," slots=4 audio=true impact=true outcomes=true replacement=true cancellation=true optional_audio=true")
	get_tree().quit()
