extends Node

const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Effect = preload("res://scripts/battle/battle_ui/common_battle_effect_3d.gd")
const Catalog = preload("res://scripts/battle/animations/battle_audio_catalog.gd")
const Effects2D = preload("res://data/battle_effect_animations.json")

class Router extends BattleAnimationRouter:
	var audio_history: Array = []
	var effect_history: Array[String] = []
	func play_effect_animation(key: String, target: String = "", reveal: Callable = Callable()) -> void:
		effect_history.append(key)
		await super.play_effect_animation(key, target, reveal)
	func _get_effect_animation_config(_key: String) -> Dictionary:
		assert(false, "Native common effects must not request legacy visuals")
		return {}
	func _get_move_animation_config(_key: String) -> Dictionary:
		assert(false, "Native common effects must not request move visuals")
		return {}
	func _start_3d_audio(kind: String, key: String, plan: Dictionary = {}, begin_immediately := true) -> Node:
		assert(kind == "effect")
		var audio := await super._start_3d_audio(kind, key, plan, begin_immediately)
		if is_instance_valid(audio):
			audio_history.append(audio)
		return audio

class SilentCatalog extends Catalog:
	func get_plan(_kind: String, _key: String) -> Dictionary:
		return {}

class LegacyRouter extends BattleAnimationRouter:
	var requested: Array[String] = []
	func _get_effect_animation_config(key: String) -> Dictionary:
		requested.append(key)
		return {}

class ActionPanel extends CurrentActionPanel:
	func set_message(_message: String) -> void:
		pass

var stage: Node
var router: Router
var complete := false
var hp: Array = []

func _ready() -> void:
	_run.call_deferred()

func _setup_stage() -> void:
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	stage.double_mode = true
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	stage.visual_bounds.pikachu = {"idle": {"min": [-0.5,0,-0.5], "size": [1,2,1]}}
	for index in 4:
		var actor := Node3D.new()
		stage.world.add_child(actor)
		actor.position = Vector3(index * 3,0,index % 2 * -3)
		stage.actors[index] = actor
		stage.identities[index] = "pikachu"
		stage.combatants[index] = {"species": "pikachu", "shiny": false}
		stage.lifecycle[index] = "idle"
		stage.actor_shown[index] = true

func _effect(key: String, target := "p1") -> void:
	await router.play_effect_animation(key, target)
	complete = true

func _started() -> Node:
	while stage.common_effects.is_empty() and not complete:
		await get_tree().process_frame
	assert(not stage.common_effects.is_empty(), "Native visual must start even when optional audio is absent")
	return stage.common_effects[0]

func _drain_frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func _inventory() -> void:
	var catalog := Catalog.new()
	for key: String in Effects2D.data.effects:
		assert(Effect.supports(key) or key in Effect.MOVE_EFFECTS, "Unclassified 2D effect: " + key)
	for key: String in Effect.PROFILES:
		assert(Effects2D.data.effects.has(key))
	for alias: String in Effects2D.data.aliases:
		assert(catalog.resolve_key("effect", alias) == Effects2D.data.aliases[alias])
	var source: Dictionary = catalog.get_plan("effect", "generic_heal")
	var before := source.duplicate(true)
	var native: Dictionary = Effect.audio_plan(source, "health_up")
	assert(source == before and native.duration_seconds == 0.85 and native.speed_scale == 1.0)
	var names := {}
	for cue: Dictionary in native.cues:
		assert(not names.has(cue.event.name) and cue.at_seconds <= 0.85)
		names[cue.event.name] = true
	assert(Effect.audio_plan({}, "health_up").is_empty())

func _geometry() -> void:
	var glyphs := Effect.new()
	var down_vertices: PackedVector3Array = glyphs._icon("down_arrow").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in glyphs._icon("arrow").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(Vector3(vertex.x,-vertex.y,vertex.z) in down_vertices, "Stat-down must invert the glyph itself; billboards discard negative scale")
	glyphs.free()
	for key: String in Effect.PROFILES:
		var effect: Node = stage.create_common_effect(key, "p3")
		assert(is_instance_valid(effect) and effect.get_child_count() > 0 and effect.get_child_count() <= 20, key)
		if key != "grassy_terrain_start":
			assert(effect.height == 2.0 and is_equal_approx(effect.radius, 0.55))
		else:
			assert(effect.rings.size() == 3)
		effect.set_process(false)
		effect._process(effect.duration * 0.4)
		for mesh: MeshInstance3D in effect.get_children():
			assert(mesh.mesh.get_surface_count() > 0 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(mesh.material_override is StandardMaterial3D or mesh.material_override is ShaderMaterial)
			if mesh.material_override is StandardMaterial3D and mesh.material_override.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
				assert(mesh.material_override.billboard_keep_scale, "Pictograms must retain their species-relative size")
		assert(stage.actors[2].position == Vector3(6,0,0), "Visuals cannot move their actor")
		effect.cancel()
		await _drain_frames()
		assert(stage.common_effects.is_empty())
	assert(stage.create_common_effect("health_up", "missing") == null)
	assert(stage.create_common_effect("unknown_move_phase", "p1") == null)
	stage.actor_shown[0] = false
	assert(stage.create_common_effect("health_up", "p1") == null)
	stage.actor_shown[0] = true
	# Bounds are in model units; the actor's calibrated transform must be applied.
	stage.actors[0].scale = Vector3.ONE * 1.5
	stage.actors[0].rotation.y = PI * 0.5
	var scaled: Node = stage.create_common_effect("health_up", "p1")
	assert(is_equal_approx(scaled.height, 3.0) and is_equal_approx(scaled.radius, 0.825))
	scaled.cancel()
	stage.actors[0].scale = Vector3.ONE
	stage.actors[0].rotation = Vector3.ZERO
	await _drain_frames()

func _routing() -> void:
	router.playback_speed = 4
	for key: String in Effect.PROFILES:
		complete = false
		_effect(key, "p4")
		var effect: Node = await _started()
		assert(effect.key == key)
		var audio: Node = router.audio_history[-1]
		assert(audio.plan.duration_seconds == effect.duration and audio.clock.is_valid())
		var result := {}
		effect.finished.connect(func():
			result.done = effect.done
			result.cancelled = effect.cancelled
			result.audio_done = audio.done
			result.draining = audio.draining or bool(audio.plan.get("bounded_to_action",false))
			result.detached = not audio.clock.is_valid()
			result.dispatched = audio.cursor == audio.plan.cues.size()
		)
		while not complete:
			await get_tree().process_frame
		assert(result.done and not result.cancelled and result.audio_done and result.draining and result.detached and result.dispatched)
		if is_instance_valid(audio):
			for name: String in audio.players:
				for cue: Dictionary in audio.plan.cues:
					if cue.event.name == name:
						assert(is_equal_approx(audio.players[name].pitch_scale, float(cue.event.get("pitch",100)) / 100.0))
		router.cancel_render()
		await _drain_frames()
	# Move phases now use the same native lifecycle as the other common effects.
	var count := router.audio_history.size()
	assert(stage.common_effects.is_empty())
	SettingsManager.battle_animations = false
	await router.play_effect_animation("health_up", "p1")
	assert(router.audio_history.size() == count and stage.common_effects.is_empty())
	SettingsManager.battle_animations = true
	complete = false
	_effect("leftovers_recovery")
	var heal: Node = await _started()
	assert(heal.key == "health_up")
	while not complete:
		await get_tree().process_frame
	# Natural tails retain cancellable ownership, then release themselves.
	while not router.active_audio_nodes.is_empty():
		await get_tree().process_frame
	await _drain_frames()
	assert(stage.common_effects.is_empty())

func _pause_cancel() -> void:
	router.playback_speed = 1
	complete = false
	_effect("stat_up")
	var effect: Node = await _started()
	router.playback_speed = 0
	var elapsed: float = effect.elapsed
	await get_tree().create_timer(0.1).timeout
	assert(not complete and effect.elapsed == elapsed)
	for audio: Node in router.active_audio_nodes:
		for player: AudioStreamPlayer in audio.players.values():
			assert(player.stream_paused)
	router.cancel_render()
	while not complete:
		await get_tree().process_frame
	await _drain_frames()
	assert(router.active_audio_nodes.is_empty() and stage.common_effects.is_empty())
	router.playback_speed = 1
	complete = false
	_effect("status_confused", "p2")
	await _started()
	stage.actors[1].visible = false
	while not complete:
		await get_tree().process_frame
	await _drain_frames()
	assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty())
	stage.actors[1].visible = true
	complete = false
	_effect("status_sleeping", "p2")
	await _started()
	var old_actor: Node3D = stage.actors[1]
	var replacement := Node3D.new()
	stage.world.add_child(replacement)
	replacement.transform = old_actor.transform
	stage.actors[1] = replacement
	old_actor.queue_free()
	while not complete:
		await get_tree().process_frame
	await _drain_frames()
	assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty())
	# Scene deactivation must release the waiter, including pooled worlds.
	complete = false
	_effect("health_up")
	await _started()
	stage._set_active(false)
	while not complete:
		await get_tree().process_frame
	await _drain_frames()
	assert(stage.common_effects.is_empty() and router.active_audio_nodes.is_empty())
	stage.active = true

func _optional_audio() -> void:
	var original: RefCounted = router.audio_catalog
	router.audio_catalog = SilentCatalog.new()
	router.playback_speed = 4
	complete = false
	_effect("health_up")
	await _started()
	while not complete:
		await get_tree().process_frame
	assert(router.active_audio_nodes.is_empty())
	router.audio_catalog = original
	await _drain_frames()

func _hp_update(_ident: String, _event: Dictionary, previous: bool) -> void:
	hp.append([previous, stage.common_effects.size()])

func _renderer() -> void:
	var panel := ActionPanel.new()
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	var label := Label.new()
	label.name = "CurrentActionLabel"
	margin.add_child(label)
	panel.add_child(margin)
	add_child(panel)
	var renderer := BattleEventRenderer.new()
	renderer.setup(null,null,panel,router,BattleMessageTiming.new(),stage,_hp_update)
	await renderer.render_event({"type":"heal"}, {"heal_target_ident":"p1", "effect_animation_key":"generic_heal", "effect_animation_target_ident":"p1"}, true)
	assert(hp == [[true,0],[false,1]], "HP update follows the same awaited heal effect boundary")
	# 2D stat and heal shapes are never invoked by an active 3D scene.
	await renderer.render_event({"type":"statChange"}, {"stat_change_target_ident":"p3", "stat_change_amount":1, "effect_animation_key":"stat_up", "effect_animation_target_ident":"p3"}, true)
	await renderer.render_event({"type":"status"}, {"effect_animation_key":"status_paralysis", "effect_animation_target_ident":"p2"}, true)
	router.effect_history.clear()
	await renderer.render_event({"type":"status", "status":"frz"}, {"effect_animation_key":"status_frozen", "effect_animation_target_ident":"p2"}, true)
	assert(router.effect_history.is_empty(), "Acquiring native Freeze uses only the persistent tint")
	await renderer.render_event({"type":"cant", "reason":"frz"}, {"effect_animation_key":"status_frozen", "effect_animation_target_ident":"p2"}, true)
	assert(router.effect_history == ["status_frozen"], "A Freeze-blocked action retains its ice burst")
	var legacy := LegacyRouter.new()
	renderer.animation_router = legacy
	await renderer.render_event({"type":"status", "status":"frz"}, {"effect_animation_key":"status_frozen", "effect_animation_target_ident":"p2"}, true)
	assert(legacy.requested == ["status_frozen"], "2D still requests its original Freeze activation effect")
	renderer.animation_router = router
	router.cancel_render()
	panel.queue_free()
	await _drain_frames()

func _run() -> void:
	_inventory()
	SettingsManager.battle_animations = true
	_setup_stage()
	router = Router.new()
	router.model_presenter = stage
	router.animation_parent = stage
	await _geometry()
	await _routing()
	await _pause_cancel()
	await _optional_audio()
	await _renderer()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await _drain_frames()
	print("BATTLE_COMMON_EFFECTS_3D_OK profiles=", Effect.PROFILES.size(), " catalog=", Effects2D.data.effects.size())
	get_tree().quit()
