extends RefCounted
## Instance-local correction for the reviewed matte forest art under Android GLES.
## Other renderers, water, specular props and Pokémon keep their authored lighting.
const LightCode = preload("res://scripts/battle/arenas/shared/compatibility_outdoor_light.gdshaderinc")
const Ground = preload("res://scripts/battle/arenas/shared/grassland_ground.gdshader")
const CityGround = preload("res://scripts/battle/arenas/shared/city_ground.gdshader")
const ART_SHADERS := {
	"7f8b9478ab94740e6e5f3c39416514833fc4fb0bae43837b5df64d2b85ce85b7": "grass",
	"774283d73287f0c988231ba98dd004ca7f2723001c65940f75b8041701de2397": "flowers",
	"70436801417e9c1e1054b9bd64ded3f2e8238043e6c95c6526e699d437914150": "bush leaves",
	"bd2cc216ab59b62145ff5dee5739ea0bc318b4020a1f85bdc8b791454728de97": "tree leaves",
}
const GROUND_CONVERSION := "tint = mix(tint / 12.92, pow((tint + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), tint));"
var materials: Array[ShaderMaterial] = []
var replaced_surfaces := 0
var skipped_surfaces := 0
var uniform_updates := 0
var irradiance_only := false
var _last_light_state: Array = []

static func enabled_for_platform(android: bool, web: bool, experimental: bool, pilot: bool, debug: bool, renderer: String) -> bool:
	return android and not web and (experimental or (pilot and debug)) and renderer == "gl_compatibility"

static func supported() -> bool:
	return enabled_for_platform(OS.has_feature("android"), OS.has_feature("web"), OS.has_feature("android_3d_experimental"), OS.has_feature("android_3d_pilot"), OS.is_debug_build(), RenderingServer.get_current_rendering_method())

func _supported_lights(lights: Array[DirectionalLight3D]) -> bool:
	if lights.size() != 4 or not lights[0].shadow_enabled:
		return false
	for index in range(1, 4):
		if lights[index].shadow_enabled:
			return false
	return true

func apply(arena: Node3D, environment: Environment, lights: Array[DirectionalLight3D]) -> bool:
	if not materials.is_empty() or not _supported_lights(lights) or environment == null:
		return false
	var copies: Dictionary = {}
	var shaders: Dictionary = {}
	var nodes: Array[Node] = [arena]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is GeometryInstance3D and node.material_override != null:
			var next := _material(node.material_override, copies, shaders)
			if next != null:
				node.material_override = next
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var next := _material(node.get_active_material(surface), copies, shaders)
				if next != null:
					node.set_surface_override_material(surface, next)
	refresh(environment, lights)
	return not materials.is_empty()

func _material(original: Material, copies: Dictionary, shaders: Dictionary) -> ShaderMaterial:
	if not original is ShaderMaterial or original.shader == null or original.next_pass != null:
		skipped_surfaces += 1
		return null
	var shader_key: int = original.shader.get_instance_id()
	if not shaders.has(shader_key):
		var code: String = original.shader.code
		# Exact reviewed programs only: a future/custom shader is left untouched.
		if not ART_SHADERS.has(code.sha256_text()) and code != Ground.code and code != CityGround.code:
			skipped_surfaces += 1
			return null
		var shader := Shader.new()
		code = code.replace(GROUND_CONVERSION, "")
		# View-space light directions are constant across a primitive. Transform
		# them per vertex instead of doing four matrices/normalizations per pixel.
		if irradiance_only:
			# Scenery in this offscreen pass provides occlusion and casts shadows.
			# Its colour is never used by visible Pokémon pixels. Keep its geometry,
			# alpha cutouts and wind, without evaluating outdoor colour a second time.
			shader.code = code.replace("render_mode ", "render_mode unshaded, ") if "render_mode " in code else code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
		else:
			var first_function := code.find("void ")
			code = code.insert(first_function, LightCode.code)
			var vertex_setup := "\n poke_sun_view = (VIEW_MATRIX * vec4(poke_sun_direction, 0.0)).xyz;"
			for index in 3:
				vertex_setup += "\n poke_fill_view_%d = (VIEW_MATRIX * vec4(poke_fill_direction_%d, 0.0)).xyz;" % [index, index]
			shader.code = code.replace("void vertex() {", "void vertex() {" + vertex_setup)
		shaders[shader_key] = shader
	var key := original.get_instance_id()
	replaced_surfaces += 1
	if copies.has(key):
		return copies[key]
	var material := original.duplicate() as ShaderMaterial
	material.shader = shaders[shader_key]
	var ao: Variant = original.get_shader_parameter("ambient_occlusion")
	material.set_shader_parameter("poke_ambient_occlusion", float(ao) if ao != null else 1.0)
	copies[key] = material
	materials.append(material)
	return material

func refresh(environment: Environment, lights: Array[DirectionalLight3D]) -> void:
	if irradiance_only or materials.is_empty() or not _supported_lights(lights):
		return
	var ambient := environment.ambient_light_color.srgb_to_linear() * environment.ambient_light_energy
	var state: Array = [lights[0].global_basis.z.normalized(), Vector3(ambient.r, ambient.g, ambient.b)]
	for index in 3:
		var lamp := lights[index + 1]
		var colour := lamp.light_color.srgb_to_linear() * lamp.light_energy
		state.append(lamp.global_basis.z.normalized())
		state.append(Vector3(colour.r, colour.g, colour.b))
	if state == _last_light_state:
		return
	_last_light_state = state
	uniform_updates += 1
	for material in materials:
		material.set_shader_parameter("poke_sun_direction", state[0])
		material.set_shader_parameter("poke_ambient", state[1])
		for index in 3:
			material.set_shader_parameter("poke_fill_direction_%d" % index, state[2 + index * 2])
			material.set_shader_parameter("poke_fill_colour_%d" % index, state[3 + index * 2])
