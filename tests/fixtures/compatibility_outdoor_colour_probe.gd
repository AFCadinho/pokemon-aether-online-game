extends RefCounted
## Offline prototype for matte outdoor surfaces. Never called by the game.
const LIGHT_CODE := """uniform vec3 poke_sun_direction;
uniform vec3 poke_ambient;
uniform float poke_ambient_occlusion = 1.0;
uniform vec3 poke_fill_direction_0;
uniform vec3 poke_fill_direction_1;
uniform vec3 poke_fill_direction_2;
uniform vec3 poke_fill_colour_0;
uniform vec3 poke_fill_colour_1;
uniform vec3 poke_fill_colour_2;
vec3 poke_to_srgb(vec3 x) {
 x = max(x, vec3(0.0));
 return mix(x * 12.92, 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), x));
}
vec3 poke_to_linear(vec3 x) {
 return mix(x / 12.92, pow((x + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), x));
}
void light() {
 vec3 contribution = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
 vec3 sun_direction = normalize((VIEW_MATRIX * vec4(poke_sun_direction, 0.0)).xyz);
 if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, sun_direction) > 0.9999) {
  vec3 base = poke_ambient * poke_ambient_occlusion;
  base += max(dot(NORMAL, normalize((VIEW_MATRIX * vec4(poke_fill_direction_0, 0.0)).xyz)), 0.0) * poke_fill_colour_0;
  base += max(dot(NORMAL, normalize((VIEW_MATRIX * vec4(poke_fill_direction_1, 0.0)).xyz)), 0.0) * poke_fill_colour_1;
  base += max(dot(NORMAL, normalize((VIEW_MATRIX * vec4(poke_fill_direction_2, 0.0)).xyz)), 0.0) * poke_fill_colour_2;
  vec3 delta = max(poke_to_srgb((base + contribution) * ALBEDO) - poke_to_srgb(base * ALBEDO), vec3(0.0));
  DIFFUSE_LIGHT += poke_to_linear(delta) / max(ALBEDO, vec3(0.00001));
 } else {
  DIFFUSE_LIGHT += contribution;
 }
}
"""
const GROUND_CONVERSION := "tint = mix(tint / 12.92, pow((tint + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), tint));"
var materials: Array[ShaderMaterial] = []
var replaced_surfaces := 0
var skipped_surfaces := 0
var error := ""

func apply(arena: Node3D, lighting: Node) -> bool:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		error = "Prototype requires Compatibility"
		return false
	if lighting._lights.size() != 4 or not lighting._lights[0].shadow_enabled:
		error = "Prototype requires one shadowed sun and three unshadowed fill lights"
		return false
	for index in range(1, 4):
		if lighting._lights[index].shadow_enabled:
			error = "Multiple shadowed lights are outside the prototype"
			return false
	var copies: Dictionary = {}
	var shaders: Dictionary = {}
	var nodes: Array[Node] = [arena]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is MultiMeshInstance3D:
			var next := _material(node.material_override, copies, shaders)
			if next != null:
				node.material_override = next
		elif node is MeshInstance3D and node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var next := _material(node.get_active_material(surface), copies, shaders)
				if next != null:
					node.set_surface_override_material(surface, next)
	refresh(lighting)
	return not materials.is_empty()

func _material(original: Material, copies: Dictionary, shaders: Dictionary) -> ShaderMaterial:
	if not original is ShaderMaterial or original.shader == null:
		skipped_surfaces += 1
		return null
	var code: String = original.shader.code
	# Do not replace specular/metallic materials, custom light processors or water.
	if not "SPECULAR = 0.0;" in code or "void light(" in code or "unshaded" in code:
		skipped_surfaces += 1
		return null
	var key := original.get_instance_id()
	replaced_surfaces += 1
	if copies.has(key):
		return copies[key]
	var material := original.duplicate() as ShaderMaterial
	var shader_key: int = original.shader.get_instance_id()
	if not shaders.has(shader_key):
		var shader := Shader.new()
		shader.code = code.replace(GROUND_CONVERSION, "") + LIGHT_CODE
		shaders[shader_key] = shader
	material.shader = shaders[shader_key]
	var ao: Variant = original.get_shader_parameter("ambient_occlusion")
	material.set_shader_parameter("poke_ambient_occlusion", float(ao) if ao != null else 1.0)
	copies[key] = material
	materials.append(material)
	return material

func refresh(lighting: Node) -> void:
	var ambient: Color = lighting._environment.ambient_light_color.srgb_to_linear() * lighting._environment.ambient_light_energy
	for material in materials:
		material.set_shader_parameter("poke_sun_direction", lighting._lights[0].global_basis.z.normalized())
		material.set_shader_parameter("poke_ambient", Vector3(ambient.r, ambient.g, ambient.b))
		for index in 3:
			var lamp: DirectionalLight3D = lighting._lights[index + 1]
			var colour := lamp.light_color.srgb_to_linear() * lamp.light_energy
			material.set_shader_parameter("poke_fill_direction_%d" % index, lamp.global_basis.z.normalized())
			material.set_shader_parameter("poke_fill_colour_%d" % index, Vector3(colour.r, colour.g, colour.b))
