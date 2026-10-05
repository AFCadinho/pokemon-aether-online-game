extends Node3D
## Independent arena-space terrain / Trick Room; no camera or arena-material ownership.
const COLORS := {
	"grassyterrain": Color("80d46e"), "electricterrain": Color("ffe785"),
	"mistyterrain": Color("efb6e8"), "psychicterrain": Color("ce88ed"),
	"trickroom": Color("ad95ed"),
}
const FLOOR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform int kind = 0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float radius = length(p);
	float edge = 1.0 - smoothstep(0.65, 1.0, radius);
	float wave = 0.5 + 0.5 * sin(p.x * 10.0 + sin(p.y * 12.0 + clock * 0.6) + clock * 0.7);
	float strength = 0.06 + wave * 0.07;
	if (kind == 1) strength = 0.055 + wave * 0.045;
	if (kind == 2) strength = 0.09 + wave * 0.09;
	if (kind == 3) {
		float rings = pow(0.5 + 0.5 * sin(radius * 48.0 - clock * 1.6), 14.0);
		strength = 0.025 + rings * 0.2;
	}
	ALBEDO = tint.rgb;
	ALPHA = edge * strength * opacity;
}
"""
const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform float clock = 0.0;
uniform float opacity = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float edge = pow(max(0.0, 1.0 - dot(p, p)), 2.0);
	float wisps = 0.55 + 0.25 * sin(UV.x * 14.0 + clock * 0.6 + sin(UV.y * 11.0 - clock * 0.3));
	ALBEDO = tint.rgb;
	ALPHA = edge * wisps * opacity * 0.18;
}
"""
const ROOM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform float clock = 0.0;
uniform float opacity = 0.0;
uniform vec2 cells = vec2(8.0, 4.0);
void fragment() {
	vec2 grid = abs(fract(UV * cells - 0.5) - 0.5) / max(fwidth(UV * cells), vec2(0.0001));
	float lines = 1.0 - clamp(min(grid.x, grid.y), 0.0, 1.0);
	vec2 border = min(UV, vec2(1.0) - UV);
	float frame = 1.0 - smoothstep(0.003, 0.009, min(border.x, border.y));
	float pulse = 0.85 + 0.15 * sin(clock * 0.8 + UV.x * 5.0 + UV.y * 3.0);
	ALBEDO = tint.rgb;
	ALPHA = (0.012 + lines * 0.13 + frame * 0.2) * pulse * opacity;
}
"""
var key := ""
var elapsed := 0.0
var stopped := false
var speed_provider: Callable
var particles: MultiMeshInstance3D
var shaders: Array[ShaderMaterial] = []

static func normalize(raw: String) -> String:
	var cleaned := raw.strip_edges().to_lower()
	if ":" in cleaned: cleaned = cleaned.get_slice(":", 1).strip_edges()
	cleaned = cleaned.replace(" ", "").replace("_", "").replace("-", "")
	return cleaned if COLORS.has(cleaned) and cleaned != "trickroom" else ""

func start(effect: String, origin: Vector3, clock: Callable) -> void:
	key = effect
	position = origin + Vector3(0, 0.035, 0)
	speed_provider = clock
	set_meta("battle_field_visual", true)
	if key == "trickroom":
		_build_room()
	else:
		var floor_material := _shader(FLOOR_SHADER)
		floor_material.set_shader_parameter("kind", ["grassyterrain", "electricterrain", "mistyterrain", "psychicterrain"].find(key))
		_plane(Vector2(17, 17), Vector3.ZERO, Vector3(-PI / 2, 0, 0), floor_material)
		_build_particles()
	_process(0.0)

func _shader(source: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = source
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", COLORS[key])
	shaders.append(material)
	return material

func _plane(size: Vector2, point: Vector3, angles: Vector3, material: Material) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.position = point
	node.rotation = angles
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_room() -> void:
	var walls := _shader(ROOM_SHADER)
	walls.set_shader_parameter("cells", Vector2(8, 3))
	var floor_material := _shader(ROOM_SHADER)
	floor_material.set_shader_parameter("cells", Vector2(8, 8))
	_plane(Vector2(16, 16), Vector3.ZERO, Vector3(-PI / 2, 0, 0), floor_material)
	_plane(Vector2(16, 16), Vector3(0, 6, 0), Vector3(PI / 2, 0, 0), floor_material)
	for side in [-1, 1]:
		_plane(Vector2(16, 6), Vector3(0, 3, side * 8), Vector3.ZERO, walls)
		_plane(Vector2(16, 6), Vector3(side * 8, 3, 0), Vector3(0, PI / 2, 0), walls)

func _leaf_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, -0.16), Vector3(-0.065, 0, 0), Vector3(0, 0.025, 0.18), Vector3(0.065, 0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_particles() -> void:
	particles = MultiMeshInstance3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var shape: Mesh
	var count := 64
	match key:
		"grassyterrain": shape = _leaf_mesh()
		"mistyterrain":
			var mist := QuadMesh.new()
			mist.size = Vector2(4.0, 3.0)
			shape = mist
			shape.material = _shader(MIST_SHADER)
			count = 20
		"psychicterrain":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.18
			ring.outer_radius = 0.2
			ring.rings = 24
			ring.ring_segments = 6
			shape = ring
			count = 16
		"electricterrain":
			var streak := BoxMesh.new()
			streak.size = Vector3(0.032, 0.02, 1.0)
			shape = streak
			count = 90
	if shape.surface_get_material(0) == null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.vertex_color_use_as_albedo = true
		material.albedo_color = COLORS[key]
		shape.surface_set_material(0, material)
	instances.mesh = shape
	instances.instance_count = count
	particles.multimesh = instances
	particles.custom_aabb = AABB(Vector3(-10, -0.1, -10), Vector3(20, 3, 20))
	add_child(particles)

func _process(delta: float) -> void:
	if stopped: return
	var speed := maxf(float(speed_provider.call()), 0.0) if speed_provider.is_valid() else 1.0
	elapsed += maxf(delta, 0.0) * speed
	var fade := clampf(elapsed / 0.5, 0.0, 1.0)
	for material in shaders:
		material.set_shader_parameter("clock", elapsed)
		material.set_shader_parameter("opacity", fade)
	if particles == null: return
	for i in particles.multimesh.instance_count:
		var phase := fposmod(elapsed * 0.22 + i * 0.618034, 1.0)
		var angle := i * 2.39996
		var radius := sqrt(fposmod(i * 0.414214, 1.0)) * 7.0
		var point := Vector3(cos(angle) * radius, 0.12, sin(angle) * radius)
		var basis := Basis.IDENTITY
		var alpha := sin(phase * PI) * fade
		match key:
			"grassyterrain":
				point.y += sin(phase * PI) * 0.65
				point.x += sin(elapsed * 0.9 + i) * 0.22
				basis = Basis.from_euler(Vector3(sin(elapsed + i) * 0.4, angle + elapsed * 0.4, phase * 0.5))
			"mistyterrain":
				point.y = 0.12 + fposmod(i * 0.173, 1.0) * 0.28
				point.x += sin(elapsed * 0.3 + i) * 0.6
				point.z += cos(elapsed * 0.2 + i) * 0.5
				basis = Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, -PI / 2)
			"psychicterrain":
				point.y += phase * 0.8
				basis = Basis.IDENTITY.scaled(Vector3.ONE * (0.7 + phase * 1.4))
				alpha *= 0.5
			"electricterrain":
				var arc := i / 5
				var segment := i % 5
				var pulse := fposmod(elapsed + arc * 0.197, 3.2)
				var start := _arc_point(arc, segment)
				var end := _arc_point(arc, segment + 1)
				point = (start + end) * 0.5
				basis = Basis.looking_at((end - start).normalized()).scaled(Vector3(1, 1, start.distance_to(end)))
				alpha = sin(clampf(pulse / 0.55, 0.0, 1.0) * PI) * fade * 0.85 if pulse < 0.55 else 0.0
		particles.multimesh.set_instance_transform(i, Transform3D(basis, point))
		particles.multimesh.set_instance_color(i, Color(1, 1, 1, alpha))

func _arc_point(arc: int, segment: int) -> Vector3:
	var angle := arc * 2.39996
	var radius := 0.8 + sqrt(fposmod(arc * 0.414214, 1.0)) * 4.5
	var origin := Vector3(cos(angle) * radius, 0.08, sin(angle) * radius)
	var along := Vector3(cos(angle + 0.6), 0, sin(angle + 0.6))
	var across := Vector3(-along.z, 0, along.x)
	return origin + along * (segment - 2.5) * 0.3 + across * sin(segment * 2.7 + arc) * 0.13

func cancel() -> void:
	stopped = true
	set_process(false)
	visible = false
	queue_free()
