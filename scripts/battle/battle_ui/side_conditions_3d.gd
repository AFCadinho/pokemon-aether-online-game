extends Node3D
## Persistent side-owned geometry. Snapshots reconcile effects without restarting them.
const COLORS := {"stealthrock": Color("9b8064"), "spikes": Color("becbd6"),
	"toxicspikes": Color("b861df"), "stickyweb": Color("f1e9cd"),
	"reflect": Color("efadbd"), "lightscreen": Color("ffe6a3"), "auroraveil": Color("91e5e2")}
const SCREEN_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
uniform float clock = 0.0;
void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float frame = 1.0 - smoothstep(0.015, 0.04, min(edge.x, edge.y));
	float wave = 0.5 + 0.5 * sin(UV.y * 18.0 - clock * 1.2);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 0.15;
	ALPHA = 0.07 + wave * 0.045 + frame * 0.35;
}"""
var effects := {}
var elapsed := 0.0
var speed_provider: Callable
var radius := 2.4

static func snapshot(values: Array) -> Dictionary:
	var result := {}
	for value in values:
		if not value is Dictionary: continue
		var key := str(value.get("effectId", value.get("effect", ""))).strip_edges().to_lower()
		if ":" in key: key = key.get_slice(":", 1).strip_edges()
		key = key.replace(" ", "").replace("_", "").replace("-", "")
		if key == "stickywebs": key = "stickyweb"
		if not COLORS.has(key): continue
		var limit := 3 if key == "spikes" else (2 if key == "toxicspikes" else 1)
		result[key] = clampi(int(value.get("layers", 1)), 1, limit)
	return result

func configure(origin: Vector3, facing: Vector3, double: bool, clock: Callable) -> void:
	set_meta("battle_field_visual", true)
	position = origin
	rotation.y = atan2(facing.x, facing.z)
	speed_provider = clock
	var next_radius := 3.5 if double else 2.4
	if radius != next_radius:
		clear()
		radius = next_radius

func reconcile(values: Dictionary) -> void:
	for key in effects.keys():
		if not values.has(key) or effects[key].layers != values[key]:
			var node: Node3D = effects[key].node
			node.hide()
			node.queue_free()
			effects.erase(key)
	for key in values:
		if effects.has(key): continue
		var node := Node3D.new()
		node.name = key
		add_child(node)
		effects[key] = {"node": node, "layers": values[key]}
		_build(node, key, values[key])

func _material(color: Color, metal := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55 if metal else 0.85
	material.metallic = 0.45 if metal else 0.0
	return material

func _mesh(parent: Node3D, shape: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = point
	parent.add_child(node)
	return node

func _strand(parent: Node3D, start: Vector3, end: Vector3, material: Material) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = 0.012
	shape.bottom_radius = 0.012
	shape.height = start.distance_to(end)
	shape.radial_segments = 4
	var node := _mesh(parent, shape, (start + end) * 0.5, material)
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build(parent: Node3D, key: String, layers: int) -> void:
	var material := _material(COLORS[key], key == "spikes")
	match key:
		"stealthrock":
			for index in 7:
				var angle := TAU * index / 7.0
				var shape := SphereMesh.new()
				shape.radius = 0.22 + (index % 3) * 0.045
				shape.height = shape.radius * 2.5
				shape.radial_segments = 5
				shape.rings = 2
				var rock := _mesh(parent, shape, Vector3(cos(angle) * radius, 0.6 + (index % 3) * 0.3, sin(angle) * radius), material)
				rock.rotation = Vector3(index * 0.6, angle, index * 0.4)
				rock.scale = Vector3(0.85, 1.0, 1.2)
				rock.set_meta("rest_height", rock.position.y)
		"spikes", "toxicspikes":
			for layer in layers:
				for index in 6:
					var angle := TAU * (index + layer * 0.35) / 6.0 + (0.3 if key == "toxicspikes" else 0.0)
					var ring := radius * (0.65 + layer * 0.13)
					var shape := CylinderMesh.new()
					shape.top_radius = 0.0
					shape.bottom_radius = 0.14 if key == "spikes" else 0.19
					shape.height = 0.36 if key == "spikes" else 0.27
					shape.radial_segments = 4 if key == "spikes" else 3
					var point := Vector3(cos(angle) * ring, shape.height * 0.5 + 0.015, sin(angle) * ring)
					var spike := _mesh(parent, shape, point, material)
					spike.rotation.y = angle
		"stickyweb":
			var web_y := 0.025
			for index in 12:
				var angle := TAU * index / 12.0
				_strand(parent, Vector3(0, web_y, 0), Vector3(cos(angle) * radius, web_y, sin(angle) * radius), material)
			for ring in range(1, 5):
				for index in 12:
					var a := TAU * index / 12.0
					var b := TAU * (index + 1) / 12.0
					var r := radius * ring / 4.0
					_strand(parent, Vector3(cos(a) * r, web_y, sin(a) * r), Vector3(cos(b) * r, web_y, sin(b) * r), material)
		"reflect", "lightscreen", "auroraveil":
			var shader := Shader.new()
			shader.code = SCREEN_SHADER
			var screen := ShaderMaterial.new()
			screen.shader = shader
			screen.set_shader_parameter("tint", COLORS[key])
			var shape := QuadMesh.new()
			shape.size = Vector2(radius * 1.9, 2.7)
			var offset := ["reflect", "lightscreen", "auroraveil"].find(key) * 0.16
			var panel := _mesh(parent, shape, Vector3(0, 1.4, radius * 0.85 + offset), screen)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	var speed := maxf(float(speed_provider.call()), 0.0) if speed_provider.is_valid() else 1.0
	elapsed += maxf(delta, 0.0) * speed
	for key in effects:
		var node: Node3D = effects[key].node
		for index in node.get_child_count():
			var mesh := node.get_child(index) as MeshInstance3D
			if key == "stealthrock":
				mesh.position.y = float(mesh.get_meta("rest_height")) + sin(elapsed * 1.2 + index) * 0.08
			elif mesh.material_override is ShaderMaterial:
				mesh.material_override.set_shader_parameter("clock", elapsed)

func clear() -> void:
	for effect in effects.values():
		effect.node.hide()
		effect.node.queue_free()
	effects.clear()

func cancel() -> void:
	hide()
	set_process(false)
	clear()
	queue_free()
