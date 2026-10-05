extends Node3D
## Arena-space weather with a bounded mesh budget and the battle replay clock.
## Camera-local atmosphere never changes pooled arena or day/night resources.
const PROFILES := {
	"rain": [420, Color("9dc8e2"), Color("71879f"), 0.0035],
	"sun": [12, Color("ffe7a2"), Color("f3dca1"), 0.0015],
	"sandstorm": [240, Color("d6b376"), Color("b89b70"), 0.0075],
	"snow": [180, Color("e5f6ff"), Color("b7d1de"), 0.003],
	"hail": [220, Color("c7e9fa"), Color("9db6c9"), 0.004],
	"primordialsea": [620, Color("91b8d8"), Color("526d8b"), 0.007],
	"desolateland": [18, Color("ffd17e"), Color("e5ad70"), 0.004],
	"deltastream": [192, Color("d7f4e9"), Color("acc9c3"), 0.002],
}
const SHAFT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color;
uniform float opacity = 0.1;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 2.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	ALBEDO = color.rgb;
	ALPHA = edge * ends * opacity;
}
"""
var key := ""
var elapsed := 0.0
var speed_provider: Callable
var field: MultiMeshInstance3D
var material: Material
var camera: Camera3D
var original_camera_environment: Environment
var source_environment: Environment
var atmosphere: Environment
var stopped := false

static func normalize(raw: String) -> String:
	var normalized := raw.strip_edges().to_lower()
	if ":" in normalized: normalized = normalized.get_slice(":", 1).strip_edges()
	normalized = normalized.replace(" ", "").replace("_", "").replace("-", "")
	match normalized:
		"raindance": return "rain"
		"sunnyday", "harshsun": return "sun"
		"snowscape": return "snow"
	return normalized if PROFILES.has(normalized) else ""

func start(weather: String, arena_world: Node3D, view: Camera3D, origin: Vector3, clock: Callable) -> void:
	key = normalize(weather)
	speed_provider = clock
	position = origin
	camera = view
	# Do not duplicate these visible particles into the Pokémon irradiance pass.
	set_meta("battle_weather_visual", true)
	original_camera_environment = camera.environment
	source_environment = original_camera_environment
	if source_environment == null:
		for child in arena_world.get_children():
			if child is WorldEnvironment:
				source_environment = child.environment
				break
	if source_environment != null:
		atmosphere = source_environment.duplicate()
		camera.environment = atmosphere
	_build()
	_process(0.0)

func _build() -> void:
	field = MultiMeshInstance3D.new()
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	var shape: Mesh
	if key in ["sun", "desolateland"]:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.6, 15.0)
		shape = quad
		var shader := Shader.new()
		shader.code = SHAFT_SHADER
		var shafts := ShaderMaterial.new()
		shafts.shader = shader
		shafts.set_shader_parameter("color", PROFILES[key][1])
		material = shafts
	else:
		if key in ["snow", "hail", "sandstorm"]:
			var sphere := SphereMesh.new()
			sphere.radius = 0.028 if key == "snow" else (0.014 if key == "sandstorm" else 0.035)
			sphere.height = sphere.radius * 2.0
			sphere.radial_segments = 6
			sphere.rings = 3
			shape = sphere
		else:
			var streak := BoxMesh.new()
			streak.size = Vector3(0.018, 0.48, 0.018) if key != "deltastream" else Vector3(0.022, 0.022, 1.0)
			shape = streak
		var surface := StandardMaterial3D.new()
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		surface.vertex_color_use_as_albedo = true
		surface.albedo_color = PROFILES[key][1]
		material = surface
	shape.material = material
	instances.mesh = shape
	instances.instance_count = PROFILES[key][0]
	field.multimesh = instances
	field.custom_aabb = AABB(Vector3(-20, -1, -20), Vector3(40, 22, 40))
	add_child(field)

func _process(delta: float) -> void:
	if stopped or not is_instance_valid(camera): return
	var speed := maxf(float(speed_provider.call()), 0.0) if speed_provider.is_valid() else 1.0
	elapsed += maxf(delta, 0.0) * speed
	var fade := clampf(elapsed / 0.45, 0.0, 1.0)
	if atmosphere != null:
		# Follow live world-clock lighting while owning only camera-local haze.
		atmosphere.ambient_light_color = source_environment.ambient_light_color
		atmosphere.ambient_light_energy = source_environment.ambient_light_energy
		atmosphere.background_color = source_environment.background_color
		atmosphere.fog_enabled = true
		atmosphere.fog_light_color = source_environment.fog_light_color.lerp(PROFILES[key][2], fade)
		atmosphere.fog_density = lerpf(source_environment.fog_density if source_environment.fog_enabled else 0.0, PROFILES[key][3], fade)
		atmosphere.fog_sky_affect = 0.3 * fade
	if material is ShaderMaterial:
		material.set_shader_parameter("opacity", fade * (0.075 if key == "sun" else 0.13) * (0.92 + 0.08 * sin(elapsed * 1.2)))
	for i in field.multimesh.instance_count:
		var seed_x := fposmod(i * 0.61803399, 1.0)
		var seed_z := fposmod(i * 0.41421356, 1.0)
		var phase := fposmod(i * 0.73205081, 1.0)
		var point := Vector3((seed_x - 0.5) * 30.0, 0, (seed_z - 0.5) * 30.0)
		var basis := Basis.IDENTITY
		var alpha := 0.55 * fade
		match key:
			"rain", "primordialsea":
				point.y = fposmod(phase * 14.0 - elapsed * (17.0 if key == "primordialsea" else 13.0), 14.0)
				point.x += point.y * 0.12
				basis = Basis(Vector3.FORWARD, -0.12)
				alpha *= smoothstep(0.0, 0.45, point.y)
			"snow":
				point.y = fposmod(phase * 12.0 - elapsed * (0.85 + seed_x * 0.55), 12.0)
				point.x += sin(elapsed * 0.7 + i) * 0.6
				point.z += cos(elapsed * 0.5 + i) * 0.45
				alpha = 0.8 * fade * smoothstep(0.0, 0.3, point.y)
			"hail":
				var drop := fposmod(phase + elapsed * 0.65, 1.0)
				point.y = (1.0 - drop / 0.84) * 12.0 if drop < 0.84 else sin((drop - 0.84) / 0.16 * PI) * 0.3
				point.x += drop * 0.6
				alpha = 0.85 * fade
			"sandstorm":
				point.x = fposmod(point.x + elapsed * (5.0 + phase * 2.0) + 15.0, 30.0) - 15.0
				point.y = 0.2 + phase * 5.0 + sin(elapsed * 1.4 + i) * 0.15
				point.z += sin(elapsed * 1.1 + i) * 0.65
				basis = Basis.IDENTITY.scaled(Vector3(1.8, 0.7, 0.7))
			"sun", "desolateland":
				point.y = 7.5
				basis = Basis(Vector3.UP, i * 2.4) * Basis(Vector3.FORWARD, 0.24)
			"deltastream":
				var strand := i / 12
				var segment := i % 12
				var progress := fposmod(elapsed * 0.18 + strand * 0.173, 1.0)
				var first := _wind_point(strand, segment, progress)
				var next := _wind_point(strand, segment + 1, progress)
				point = (first + next) * 0.5
				basis = Basis.looking_at((next - first).normalized()).scaled(Vector3(1, 1, first.distance_to(next)))
				alpha = fade * sin(progress * PI) * sin((segment + 1) / 13.0 * PI) * 0.38
		# Hide near-camera grains/streaks before perspective can turn them into large blobs.
		alpha *= smoothstep(2.0, 5.0, camera.global_position.distance_to(to_global(point)))
		field.multimesh.set_instance_transform(i, Transform3D(basis, point))
		field.multimesh.set_instance_color(i, Color(1, 1, 1, alpha))

func _wind_point(strand: int, segment: int, progress: float) -> Vector3:
	var t := segment / 12.0
	return Vector3(progress * 36.0 - 18.0 + t * 3.0,
		0.6 + fposmod(strand * 0.618, 1.0) * 5.5 + sin(t * PI + elapsed * 1.2 + strand) * 0.45,
		fposmod(strand * 0.414, 1.0) * 24.0 - 12.0 + cos(t * PI + elapsed * 0.8 + strand) * 0.65)

func cancel() -> void:
	stopped = true
	set_process(false)
	if is_instance_valid(camera) and camera.environment == atmosphere:
		camera.environment = original_camera_environment
	visible = false
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(camera) and camera.environment == atmosphere:
		camera.environment = original_camera_environment
