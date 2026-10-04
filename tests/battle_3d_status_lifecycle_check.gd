extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Overlay = preload("res://scripts/battle/animations/status_condition_overlay.gd")
const Box = preload("res://scenes/battle/sprite_box.tscn")
const Common = preload("res://scripts/battle/battle_ui/common_battle_effect_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
var stage: Node
var router: BattleAnimationRouter
var done := false
var reveals := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SettingsManager.battle_animations = true
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.double_mode = true
	stage.active = true
	stage.viewport = SubViewport.new()
	stage.viewport.size = Vector2i(640,480)
	stage.add_child(stage.viewport)
	stage.world = Node3D.new()
	stage.viewport.add_child(stage.world)
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.camera.position = Vector3(4,4,8)
	stage.camera.look_at(Vector3.ZERO)
	for index in 4:
		var box := Box.instantiate()
		add_child(box)
		box.set_model_sprites_hidden(true)
		stage.boxes.append(box)
		var actor := MeshInstance3D.new()
		actor.mesh = SphereMesh.new()
		actor.material_override = StandardMaterial3D.new()
		actor.material_overlay = StandardMaterial3D.new()
		stage.world.add_child(actor)
		stage.actors[index] = actor
		stage.identities[index] = "pikachu"
		stage.combatants[index] = {"species":"pikachu","shiny":false}
		stage.lifecycle[index] = "idle"
		stage.visual_bounds.pikachu = {"idle":{"min":[-0.5,0,-0.5],"size":[1,2,1]}}
	router = BattleAnimationRouter.new()
	router.model_presenter = stage
	router.animation_parent = stage
	await _status()
	await _substitute()
	await _mega()
	_audio()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	for child in get_children(): child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_3D_STATUS_LIFECYCLE_OK status=6 slots=4 substitute=true mega=true item_audio=true")
	get_tree().quit()

func _status() -> void:
	for index in 4:
		var box: Node = stage.boxes[index]
		var overlay := Overlay.new()
		box.get_single_sprite_slot().add_child(overlay)
		var original: Material = stage.actors[index].material_overlay
		for condition in ["psn","tox","brn","par","frz","slp"]:
			overlay.set_condition(condition)
			overlay._update_sprite_tint()
			assert(box.single_sprite.self_modulate.a == 0.0, "Status must never reveal the hidden 2D sprite")
			stage.set_status_condition(index,condition)
			var effect: Node = stage.status_effects[index]
			assert(is_instance_valid(effect) and effect.actor == stage.actors[index])
			effect._process(8.0)
			assert(not effect.done and stage.actors[index].material_overlay != original)
			var elapsed: float = effect.cycle
			stage.playback_speed = 0
			effect._process(1.0)
			assert(effect.cycle == elapsed)
			stage.playback_speed = 1
			stage.set_coop_target_highlight("p%d" % (index+1))
			stage.set_status_condition(index,"")
			stage.set_coop_target_highlight("")
			assert(stage.actors[index].material_overlay == original, "Cure restores both status and target overlay ownership")
			await get_tree().process_frame
		overlay.set_condition("psn")
		box.set_model_sprites_hidden(false)
		overlay._update_sprite_tint()
		assert(box.single_sprite.self_modulate.a == 1.0 and box.single_sprite.self_modulate != Color.WHITE)
		box.set_model_sprites_hidden(true)
		overlay._update_sprite_tint()
		assert(box.single_sprite.self_modulate.a == 0.0)
		overlay.queue_free()
	stage.set_status_condition(0,"brn")
	stage.actor_shown[0] = false
	stage._sync_status_effects()
	assert(stage.status_effects[0] == null)
	stage.actor_shown[0] = true
	stage._sync_status_effects()
	assert(is_instance_valid(stage.status_effects[0]))
	stage._set_active(false)
	assert(stage.status_effects.all(func(effect): return effect == null))
	stage._set_active(true)
	stage.set_status_condition(0,"")

func _substitute() -> void:
	for index in 4:
		var ident := "p%d" % (index+1)
		await router.set_substitute_active(ident,true)
		var doll: Node = stage.substitute_models[index]
		assert(stage.active and is_instance_valid(doll) and doll.visible and not stage.actors[index].visible)
		assert(not stage.boxes[index].substitute_sprite.visible and stage.boxes[index].single_sprite.self_modulate.a == 0.0)
		var heal: Node = stage.create_common_effect("health_up",ident)
		assert(is_instance_valid(heal), "Common effects can target a visible Substitute")
		heal.cancel()
		assert(await router.reveal_pokemon_from_substitute_for_move(ident))
		assert(stage.actors[index].visible and not doll.visible)
		await router.restore_substitute_after_move(ident)
		assert(doll.visible and not stage.actors[index].visible)
		await router.play_substitute_damage_tween(ident)
		assert(doll.hit_left == 0.0)
		router.clear_substitute_for_ident(ident)
		assert(stage.active and stage.actors[index].visible and stage.substitute_models[index] == null)
	await router.set_substitute_active("p1",true)
	stage._set_active(false)
	assert(stage.substitute_models.all(func(doll): return doll == null))
	stage._set_active(true)
	router.clear_substitute_for_ident("p1")

func _play_mega(reveal: Callable) -> void:
	await router.play_effect_animation("mega_evolution","p1",reveal)
	done = true

func _mega() -> void:
	for shiny in [false,true]:
		var key := Registry.key("garchomp-mega-z",shiny)
		assert(Registry.supports(key))
		stage.catalog_entries[key] = {}
		stage.packed[key] = PackedScene.new()
		stage.placements[key] = {"calibrated":true}
		assert(await stage.prepare_mega_form("p1","Garchomp-Mega-Z",shiny))
		assert(stage.staged_mega_species[0] == key)
		done = false
		_play_mega(func():
			reveals += 1
			assert(stage.common_effects.size() == 1)
			var effect: Node = stage.common_effects[0]
			assert(effect.elapsed >= effect.duration * 0.55 and effect.elapsed < effect.duration)
			# Simulate the announced form replacing the original actor at reveal.
			stage.identities[0] = key
			stage.combatants[0] = {"species":"garchomp-mega-z","shiny":shiny}
		)
		while not done: await get_tree().process_frame
		assert(stage.active and stage.identities[0] == key)
		stage.identities[0] = "pikachu"
		stage.combatants[0] = {"species":"pikachu","shiny":false}
		router.cancel_render()
		await get_tree().process_frame
	assert(reveals == 2)
	done = false
	_play_mega(func(): reveals += 1)
	while stage.common_effects.is_empty() and not done: await get_tree().process_frame
	router.cancel_render()
	while not done: await get_tree().process_frame
	assert(reveals == 2, "Cancellation before the reveal beat must not transform a stale actor")
	assert(not Registry.supports("moltres-galar"), "Missing form must never substitute ordinary Moltres art")

func _audio() -> void:
	var item: Node = stage.create_common_effect("use_item","p1")
	item.set_process(false)
	item._process(item.duration*0.2)
	var first_y: float = item.particles[0].position.y
	item._process(item.duration*0.4)
	assert(item.particles[0].position.y > first_y, "Item particles rise from the feet")
	item.cancel()
	for key in ["use_item","eat_berry"]:
		var plan: Dictionary = Common.audio_plan(router.audio_catalog.get_plan("effect",key),key)
		assert(plan.cues.size() == 1)
		var cue: Dictionary = plan.cues[0]
		var path: String = plan.sound_paths[cue.event.name]
		assert(ResourceLoader.load(path) is AudioStream)
		if key == "eat_berry":
			assert(path.ends_with("PRSFX- Bite.wav") and is_equal_approx(cue.at_seconds,plan.duration_seconds*0.32))
		else:
			assert(path.ends_with("UseItem.ogg") and cue.at_seconds == 0.0)
