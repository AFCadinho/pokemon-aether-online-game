extends Node
## Generic two-pass response for offline-validated source-material endpoints.
## Textures live in the threaded-loaded PackedScene, never in a global cache.

const RESPONSE = preload("res://scripts/battle/battle_ui/material_response.gdshader")
const IRRADIANCE = preload("res://scripts/battle/battle_ui/material_irradiance.gdshader")
const META := "pokeaether_material_response"
var stage: Control
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var source_world_id := 0
var source_ids := [0, 0]
var copies: Array = [null, null]
var pairs: Array = [[], []]
var sync_count := 0

static func apply_neutral_lighting(target: Node3D) -> void:
	for child in target.get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_color = Color.WHITE
			child.environment.ambient_light_energy = 0.14
	# Locked review baseline. Material work must not tune these lights.
	for spec in [[Vector3(-45, -30, 0), 1.15], [Vector3(-25, 45, 0), 0.25], [Vector3(-35, 150, 0), 0.45]]:
		var light := DirectionalLight3D.new()
		target.add_child(light)
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_angular_distance = 0.0
		light.shadow_blur = 2.0
		light.shadow_enabled = spec[1] == 1.15
		light.directional_shadow_max_distance = 25
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL

static func valid_material(original: Material) -> bool:
	if not original is StandardMaterial3D:
		return false
	var data: Variant = original.get_meta(META, {})
	return data is Dictionary and data.get("schema", 0) == 1 and data.get("endpoint_0") is Texture2D and data.get("endpoint_1") is Texture2D and data.get("specular") is float and is_finite(data.specular) and data.specular >= 0.0 and data.specular <= 1.0

static func supported_actor(node: Node) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			if not valid_material(node.get_active_material(surface)):
				return false
	for child in node.get_children():
		if not supported_actor(child):
			return false
	return true

func _ready() -> void:
	process_priority = 100 # After presenter pose/visibility, before render.
	RenderingServer.frame_pre_draw.connect(_sync)

func _material(original: StandardMaterial3D, light_pass: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = IRRADIANCE if light_pass else RESPONSE
	material.set_shader_parameter("normal_tex", original.normal_texture)
	material.set_shader_parameter("normal_strength", original.normal_scale if original.normal_enabled else 0.0)
	if not light_pass:
		var data: Dictionary = original.get_meta(META)
		material.set_shader_parameter("light_map", viewport.get_texture())
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("roughness_tex", original.roughness_texture)
		material.set_shader_parameter("roughness_value", original.roughness)
		material.set_shader_parameter("has_roughness", original.roughness_texture != null)
		var channels := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0.333333, 0.333333, 0.333333, 0)]
		material.set_shader_parameter("roughness_selector", channels[original.roughness_texture_channel])
		material.set_shader_parameter("specular_value", data.specular)
		material.set_shader_parameter("endpoint_0", data.endpoint_0)
		material.set_shader_parameter("endpoint_1", data.endpoint_1)
	return material

func _pair(source: Node, copy: Node, list: Array) -> void:
	list.append([source, copy])
	if copy is AnimationPlayer:
		copy.active = false
	if source is MeshInstance3D and source.mesh != null:
		for surface in source.mesh.get_surface_count():
			var original: StandardMaterial3D = source.get_active_material(surface)
			copy.set_surface_override_material(surface, _material(original, true))
			source.set_surface_override_material(surface, _material(original, false))
	for index in source.get_child_count():
		_pair(source.get_child(index), copy.get_child(index), list)

func _drop() -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()
	viewport = null
	world = null
	camera = null
	source_world_id = 0
	source_ids = [0, 0]
	copies = [null, null]
	pairs = [[], []]

func _build() -> void:
	source_world_id = stage.world.get_instance_id()
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = stage.viewport.msaa_3d
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	for child in stage.world.get_children():
		if child == stage.camera or child in stage.actors:
			continue
		if stage.has_method("build_response_arena") and child == stage.arena_root:
			continue
		var copy: Node = child.duplicate()
		if copy is WorldEnvironment:
			copy.environment = copy.environment.duplicate()
			copy.environment.ssr_enabled = false
			copy.environment.glow_enabled = false
		world.add_child(copy)
		if copy is MeshInstance3D:
			copy.material_override = StandardMaterial3D.new()
			copy.material_override.albedo_color = Color(0.8, 0.8, 0.8)
			copy.material_override.metallic_specular = 0.0
	camera = Camera3D.new()
	world.add_child(camera)
	if stage.has_method("build_response_arena"):
		var arena: Node3D = stage.build_response_arena(world,camera)
		if arena != null:
			world.add_child(arena)
		for child in world.get_children():
			if child is WorldEnvironment:
				child.environment.ssr_enabled = false
				child.environment.glow_enabled = false

func _process(_delta: float) -> void:
	if not is_instance_valid(stage.world):
		_drop()
		return
	if source_world_id != 0 and source_world_id != stage.world.get_instance_id():
		_drop()
	for index in 2:
		var source: Node = stage.actors[index]
		var id := source.get_instance_id() if is_instance_valid(source) else 0
		if id == source_ids[index]:
			continue
		if is_instance_valid(copies[index]):
			copies[index].queue_free()
		copies[index] = null
		pairs[index] = []
		source_ids[index] = id
		if id == 0 or source.get_meta(META, 0) != 1 or not supported_actor(source):
			continue # Legacy prepared catalogs retain their standard materials.
		if viewport == null:
			_build()
		copies[index] = stage.packed[stage.identities[index]].instantiate()
		world.add_child(copies[index])
		_pair(source, copies[index], pairs[index])
	if viewport != null:
		viewport.size = stage.viewport.size
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if stage.active else SubViewport.UPDATE_DISABLED

func _sync() -> void:
	if not is_instance_valid(viewport) or not is_instance_valid(stage.camera):
		return
	camera.transform = stage.camera.transform
	camera.projection = stage.camera.projection
	camera.fov = stage.camera.fov
	camera.size = stage.camera.size
	camera.near = stage.camera.near
	camera.far = stage.camera.far
	for list in pairs:
		for pair in list:
			var source: Node = pair[0]
			var copy: Node = pair[1]
			if not is_instance_valid(source) or not is_instance_valid(copy):
				continue
			if source is Node3D:
				copy.transform = source.transform
				copy.visible = source.visible
			if source is Skeleton3D:
				for bone in source.get_bone_count():
					copy.set_bone_pose(bone, source.get_bone_pose(bone))
				copy.force_update_all_bone_transforms()
			if source is MeshInstance3D:
				for shape in source.get_blend_shape_count():
					copy.set_blend_shape_value(shape, source.get_blend_shape_value(shape))
	sync_count += 1

func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_sync)
	_drop()
