extends SceneTree
const Outdoor = preload("res://scripts/battle/arenas/shared/outdoor_lighting.gd")
const Neutral = preload("res://scripts/battle/battle_ui/material_response.gd")
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for id in ["forest", "sea", "route_1", "route_1_water", "route_22", "route_22_water"]:
		assert(Arenas.uses_outdoor_lighting(id))
		assert(Arenas.definition(id).lighting == "outdoor")
	for id in ["classic", "cave", "stadium"]:
		assert(not Arenas.uses_outdoor_lighting(id))
		assert(Arenas.definition(id).lighting != "outdoor")
	var passes: Array[Node3D] = []
	var clock := root.get_node("WorldTimeService")
	for index in 2:
		var world := Node3D.new()
		root.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		world.add_child(environment)
		Neutral.apply_neutral_lighting(world)
		var arena := Node3D.new()
		world.add_child(arena)
		var controller := Outdoor.new()
		controller.name = "OutdoorLighting"
		arena.add_child(controller)
		passes.append(world)
	for hour in [0, 5, 6, 8, 12, 19, 21, 23]:
		clock.set_debug_time(hour)
		for frame in 2:
			await process_frame
		var a: Environment = passes[0].get_child(0).environment
		var b: Environment = passes[1].get_child(0).environment
		assert(a != b and a.sky != b.sky)
		assert(a.background_mode == Environment.BG_SKY)
		assert(a.reflected_light_source == Environment.REFLECTION_SOURCE_BG)
		assert(a.sky.sky_material.sky_top_color == b.sky.sky_material.sky_top_color)
		assert(a.ambient_light_energy >= 0.3)
		assert(passes[0].get_child(1).light_energy >= 0.4799)
		assert(passes[0].get_child(1).light_energy == passes[1].get_child(1).light_energy)
	var controller: Node = passes[0].get_child(4).get_node("OutdoorLighting")
	for hour in [5.0, 6.0, 8.0, 17.5, 19.0, 20.5, 24.0]:
		controller.apply_seconds(hour * 3600.0 - 0.01)
		var before: Color = passes[0].get_child(0).environment.sky.sky_material.sky_horizon_color
		controller.apply_seconds(hour * 3600.0 + 0.01)
		var after: Color = passes[0].get_child(0).environment.sky.sky_material.sky_horizon_color
		assert(absf(before.r - after.r) < 0.001)
	clock.clear_debug_time()
	for world in passes:
		world.free()
	print("OUTDOOR_LIGHTING_OK clock, paired passes, readability floors, continuous transitions")
	quit()
