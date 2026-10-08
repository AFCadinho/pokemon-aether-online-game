extends SceneTree
const Colour = preload("res://scripts/battle/arenas/shared/compatibility_outdoor_colour.gd")
const Outdoor = preload("res://scripts/battle/arenas/shared/outdoor_lighting.gd")
const Neutral = preload("res://scripts/battle/battle_ui/material_response.gd")
const Exposure = preload("res://scripts/battle/battle_ui/android_actor_exposure.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := MeshInstance3D.new()
	actor.mesh = BoxMesh.new()
	var source := StandardMaterial3D.new()
	source.albedo_color = Color(0.6,0.4,0.2,0.75)
	source.albedo_texture = GradientTexture2D.new()
	source.emission_enabled = true
	source.emission = Color(0.1,0.2,0.3)
	source.set_meta(Neutral.META,{"schema":1,"endpoint_0":source.albedo_texture})
	actor.mesh.material = source
	assert(Exposure.apply(actor) == 1)
	var exposed: StandardMaterial3D = actor.get_active_material(0)
	assert(exposed != source and exposed.albedo_texture == source.albedo_texture)
	assert(is_equal_approx(exposed.albedo_color.r,source.albedo_color.r*Exposure.GAIN))
	assert(exposed.albedo_color.a == source.albedo_color.a and exposed.emission == source.emission)
	assert(exposed.get_meta(Neutral.META) == source.get_meta(Neutral.META))
	assert(source.albedo_color == Color(0.6,0.4,0.2,0.75) and Exposure.apply(actor) == 0)
	actor.free()
	assert(Colour.enabled_for_platform(true, false, true, false, false, "gl_compatibility"))
	assert(Colour.enabled_for_platform(true, false, false, true, true, "gl_compatibility"))
	for flags in [[false,false,true,false,false,"gl_compatibility"], [true,true,true,false,false,"gl_compatibility"], [true,false,false,true,false,"gl_compatibility"], [true,false,true,false,false,"mobile"], [true,false,false,false,true,"gl_compatibility"]]:
		assert(not Colour.enabled_for_platform(flags[0],flags[1],flags[2],flags[3],flags[4],flags[5]))
	var original := ShaderMaterial.new()
	original.shader = Colour.Ground
	var texture := GradientTexture2D.new()
	original.set_shader_parameter("ground_albedo", texture)
	var shared_mesh := BoxMesh.new()
	shared_mesh.material = original
	var worlds: Array[Node3D] = []
	var controllers: Array[Node] = []
	for pass_index in 2:
		var world := Node3D.new()
		root.add_child(world)
		worlds.append(world)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		world.add_child(env)
		Neutral.apply_neutral_lighting(world)
		var arena := Node3D.new()
		var sky_light := DirectionalLight3D.new()
		arena.add_child(sky_light)
		var surface := MeshInstance3D.new()
		surface.mesh = shared_mesh
		arena.add_child(surface)
		var instanced := MultiMeshInstance3D.new()
		instanced.multimesh = MultiMesh.new()
		instanced.multimesh.mesh = shared_mesh
		instanced.material_override = original
		arena.add_child(instanced)
		var custom := MeshInstance3D.new()
		custom.mesh = BoxMesh.new()
		var custom_material := ShaderMaterial.new()
		custom_material.shader = Shader.new()
		custom_material.shader.code = "shader_type spatial; void fragment() { ALBEDO=vec3(1.0); SPECULAR = 0.0; }"
		custom.material_override = custom_material
		arena.add_child(custom)
		var controller := Outdoor.new()
		controller.compatibility_colour_enabled = true
		arena.add_child(controller)
		world.add_child(arena)
		controllers.append(controller)
		controller.set_process(false)
		assert(controller.colour_correction != null)
		assert(controller.colour_correction.materials.size() == 1)
		assert(controller.colour_correction.replaced_surfaces == 2)
		assert(custom.material_override == custom_material)
		var corrected: ShaderMaterial = surface.get_active_material(0)
		assert(corrected != original and corrected == instanced.material_override)
		assert(corrected.get_shader_parameter("ground_albedo") == texture)
		assert(original.shader == Colour.Ground and shared_mesh.material == original)
		assert(Colour.GROUND_CONVERSION in original.shader.code and not Colour.GROUND_CONVERSION in corrected.shader.code)
		var update_count: int = controller.colour_correction.uniform_updates
		controller.apply_seconds(43200.0)
		controller.apply_seconds(43200.5)
		var day: Vector3 = corrected.get_shader_parameter("poke_ambient")
		update_count = controller.colour_correction.uniform_updates
		controller.apply_seconds(43201.0)
		assert(controller.colour_correction.uniform_updates == update_count)
		controller.process_mode = Node.PROCESS_MODE_DISABLED
		controller.process_mode = Node.PROCESS_MODE_INHERIT
		controller.apply_seconds(75600.0)
		assert(corrected.get_shader_parameter("poke_ambient") != day)
		assert(controller.colour_correction.uniform_updates > update_count)
		var unsupported := Colour.new()
		controller._lights[1].shadow_enabled = true
		assert(not unsupported.apply(arena,controller._environment,controller._lights))
		controller._lights[1].shadow_enabled = false
	assert(controllers[0].colour_correction.materials[0] != controllers[1].colour_correction.materials[0])
	var depth_arena := Node3D.new()
	var depth_surface := MeshInstance3D.new()
	depth_surface.mesh = shared_mesh
	depth_arena.add_child(depth_surface)
	var depth_colour := Colour.new()
	depth_colour.irradiance_only = true
	assert(depth_colour.apply(depth_arena,controllers[0]._environment,controllers[0]._lights))
	assert("render_mode unshaded;" in depth_surface.get_active_material(0).shader.code)
	assert(not "void light()" in depth_surface.get_active_material(0).shader.code)
	assert(depth_surface.get_active_material(0).get_shader_parameter("ground_albedo") == texture)
	assert(depth_surface.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert(depth_colour.uniform_updates == 0)
	depth_arena.free()
	var clock := root.get_node("WorldTimeService")
	clock.set_debug_time(19.0)
	for controller in controllers:
		controller.set_process(true)
	await process_frame
	await process_frame
	assert(controllers[0].colour_correction.materials[0].get_shader_parameter("poke_ambient") == controllers[1].colour_correction.materials[0].get_shader_parameter("poke_ambient"))
	clock.clear_debug_time()
	for world in worlds:
		world.queue_free()
	await process_frame
	await process_frame
	print("COMPATIBILITY_OUTDOOR_COLOUR_OK platform guard, shared art isolation, unknown shader rejection, clock, paired passes and teardown")
	quit()
