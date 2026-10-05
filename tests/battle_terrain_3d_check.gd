extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Terrain = preload("res://scripts/battle/battle_ui/terrain_effect_3d.gd")
const Presentation = preload("res://scripts/battle/battle_weather_presentation.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.terrain_effects = true
	SettingsManager.weather_effects = true
	var stage := Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	stage.active = true
	var presentation := Presentation.new()
	presentation.model_presenter = stage
	presentation.terrain_tint = ColorRect.new()
	presentation.grassy_terrain_layer = Control.new()
	presentation.misty_terrain_layer = Control.new()
	presentation.psychic_terrain_layer = Control.new()
	presentation.electric_terrain_layer = Control.new()
	presentation.trick_room_layer = Control.new()
	var legacy := [presentation.terrain_tint, presentation.grassy_terrain_layer, presentation.misty_terrain_layer, presentation.psychic_terrain_layer, presentation.electric_terrain_layer, presentation.trick_room_layer]
	for node in legacy: add_child(node)
	presentation.update_weather("RainDance")
	var weather: Node = stage.weather_effect
	presentation.update_trick_room(true)
	var room: Node = stage.trick_room_effect
	assert(room.key == "trickroom" and room.get_child_count() == 6)
	room.set_process(false)
	room._process(1.0)
	for condition in ["GrassyTerrain", "move: Electric Terrain", "misty_terrain", "Psychic-Terrain"]:
		presentation.update_terrain(condition)
		var effect: Node = stage.terrain_effect
		assert(effect.key == Terrain.normalize(condition))
		assert(stage.trick_room_effect == room and stage.weather_effect == weather, "Changing terrain preserves room and weather clocks")
		assert(legacy.all(func(node): return not node.visible), "No 2D terrain/room overlay on native field")
		assert(effect.particles.multimesh.instance_count <= 90)
		effect.set_process(false)
		effect._process(1.0)
		var elapsed: float = effect.elapsed
		var transform: Transform3D = effect.particles.multimesh.get_instance_transform(0)
		var room_elapsed: float = room.elapsed
		stage.playback_speed = 0
		effect._process(1.0)
		room._process(1.0)
		assert(effect.elapsed == elapsed and room.elapsed == room_elapsed)
		assert(effect.shaders[0].get_shader_parameter("clock") == elapsed)
		assert(room.shaders[0].get_shader_parameter("clock") == room_elapsed, "Shader animations also honor replay pause")
		stage.camera.rotation.y += 1.0
		effect._process(0.0)
		assert(effect.particles.multimesh.get_instance_transform(0).is_equal_approx(transform))
		stage.playback_speed = 2
		effect._process(0.25)
		assert(is_equal_approx(effect.elapsed, elapsed + 0.5))
		stage.playback_speed = 1
		presentation.update_terrain(condition)
		assert(stage.terrain_effect == effect, "Repeated snapshots do not restart terrain")
		presentation.update_terrain("")
		assert(stage.terrain_effect == null and effect.stopped and stage.trick_room_effect == room)
		await get_tree().process_frame
	presentation.update_terrain("GrassyTerrain")
	SettingsManager.weather_effects = false
	presentation.animate(0.0)
	assert(stage.weather_effect == null and is_instance_valid(stage.terrain_effect) and stage.trick_room_effect == room)
	SettingsManager.weather_effects = true
	presentation.animate(0.0)
	weather = stage.weather_effect
	SettingsManager.terrain_effects = false
	presentation.animate(0.0)
	assert(stage.terrain_effect == null and stage.trick_room_effect == null and stage.weather_effect == weather)
	SettingsManager.terrain_effects = true
	presentation.animate(0.0)
	assert(stage.terrain_effect.key == "grassyterrain" and stage.trick_room_effect.key == "trickroom")
	stage._set_active(false)
	presentation.animate(0.0)
	assert(stage.terrain_effect == null and stage.trick_room_effect == null)
	assert(presentation.terrain_tint.visible and presentation.grassy_terrain_layer.visible and presentation.trick_room_layer.visible, "2D fallback restores both remembered field conditions")
	stage._set_active(true)
	presentation.animate(0.0)
	assert(legacy.all(func(node): return not node.visible))
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._sync_field_effects()
	presentation.animate(0.0)
	assert(stage.terrain_effect == null and presentation.grassy_terrain_layer.visible and presentation.trick_room_layer.visible)
	SettingsManager.battle_presentation_mode = "3d"
	stage.set_double_mode(true)
	stage._set_active(true)
	presentation.animate(0.0)
	assert(is_instance_valid(stage.terrain_effect) and is_instance_valid(stage.trick_room_effect))
	presentation.update_trick_room(false)
	assert(stage.trick_room_effect == null and is_instance_valid(stage.terrain_effect), "Room ends independently")
	presentation.update_trick_room(true)
	var terrain: Node = stage.terrain_effect
	room = stage.trick_room_effect
	stage._set_active(false)
	assert(terrain.stopped and room.stopped and not terrain.visible and not room.visible, "Arena release hides and stops both effects synchronously")
	for node in legacy: node.queue_free()
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_TERRAIN_3D_OK terrain=4 trick_room=true weather_coexistence=true pause=true fallback=true settings=true cleanup=true")
	get_tree().quit()
