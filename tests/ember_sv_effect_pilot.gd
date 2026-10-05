extends Node3D
## Preview-only reconstruction with extracted SV textures/colors.
## Travel, sizes, emission and atlas playback are authored here, not decoded SV simulation.
var original: Node3D
var source_dir := ""
var manifest: Dictionary
var sprites: Array[MeshInstance3D] = []
var materials := {}
var cursor := 0
var shader := Shader.new()

func configure(base: Node3D, folder: String, data: Dictionary) -> void:
	original = base
	source_dir = folder
	manifest = data
	set_meta("battle_field_visual", true)
	process_priority = 10
	original.visible = false
	original.tree_exiting.connect(queue_free, CONNECT_ONE_SHOT)
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float frames = 1.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
void fragment() {
	vec2 uv = vec2((UV.x + floor(frame_index)) / frames, UV.y);
	float mask = texture(source_mask, uv).r;
	ALBEDO = tint;
	ALPHA = mask * opacity;
}
"""

func _material(part: String, emitter_name: String) -> ShaderMaterial:
	var key := part + "/" + emitter_name
	if materials.has(key): return materials[key]
	for emitter: Dictionary in manifest.parts[part].emitters:
		if emitter.name != emitter_name: continue
		var path := source_dir.path_join(part).path_join(str(emitter.textures[0]) + ".png")
		var img := Image.load_from_file(path)
		if img == null or img.is_empty(): return null
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("source_mask", ImageTexture.create_from_image(img))
		var values: Array = emitter.color_curves[0] if int(emitter.color_key_counts[0]) > 0 else emitter.colors
		mat.set_shader_parameter("tint", Vector3(float(values[0]), float(values[1]), float(values[2])))
		# These inspected flame atlases contain one horizontal row of square cells.
		mat.set_shader_parameter("frames", float(img.get_width()) / float(img.get_height()))
		materials[key] = mat
		return mat
	return null

func _sprite(point: Vector3, size: float, part: String, emitter_name: String, phase: float, alpha: float, rotation_value := 0.0) -> void:
	if size < 0.001 or alpha < 0.001: return
	var template := _material(part, emitter_name)
	if template == null: return
	if cursor == sprites.size():
		var node := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		node.mesh = quad
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		sprites.append(node)
	var node := sprites[cursor]
	cursor += 1
	if not node.has_meta("template") or node.get_meta("template") != template:
		node.material_override = template.duplicate()
		node.set_meta("template", template)
	var mat := node.material_override as ShaderMaterial
	var frames: float = template.get_shader_parameter("frames")
	mat.set_shader_parameter("frame_index", minf(floor(clampf(phase, 0, 0.999) * frames), frames - 1.0))
	mat.set_shader_parameter("opacity", alpha)
	var camera: Camera3D = original.view_camera
	var facing := global_basis.inverse() * camera.global_basis
	node.transform = Transform3D(facing * Basis(Vector3.FORWARD, rotation_value) * Basis.from_scale(Vector3.ONE * size), point)
	node.visible = true

func _process(_delta: float) -> void:
	if not is_instance_valid(original) or original.done:
		queue_free()
		return
	var positions: Dictionary = original.anchors.call()
	var start: Vector3 = positions.source
	var target: Vector3 = positions.target
	var camera: Camera3D = original.view_camera
	var right := global_basis.inverse() * camera.global_basis.x
	if original.miss: target += right * (clampf(float(positions.radius), 0.35, 1.4) + 1.4) + Vector3.UP * 0.4
	var elapsed: float = original.elapsed
	var flight_time: float = maxf(original.impact - original.launch, 0.01)
	var travel: float = (elapsed - original.launch) / flight_time
	var after: float = (elapsed - original.impact) / maxf(original.duration * 0.3, 0.01)
	cursor = 0
	if travel >= 0 and travel < 0.7:
		_sprite(start, 0.75, "ew0052_fire_muzzle", "fire", travel / 0.7, 1.0 - travel / 0.7)
	if travel >= 0 and after < 0.15:
		for i in 3:
			var phase := clampf(travel - i * 0.06, 0, 1)
			var point := start.lerp(target, phase) + Vector3.UP * sin(phase * PI) * 0.25
			point += right * (i - 1) * sin(phase * PI) * 0.11
			_sprite(point, 0.52, "ew0052_bullet", "fire_core", 0, 0.9, elapsed * 3 + i)
			for tail in 5:
				var p := clampf(phase - tail * 0.032, 0, 1)
				var behind := start.lerp(target, p) + Vector3.UP * sin(p * PI) * 0.25
				_sprite(behind, 0.4, "ew0052_bullet", "fire_last", float(tail) / 5.0, 0.7, float(i + tail))
	if original.hit and after >= 0 and after < 1:
		_sprite(target, 1.15, "ew0052_hit", "fire", after, 1.0 - after * 0.5)
		for i in 7:
			var angle := float(i) * TAU / 7.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2)) * after * 0.65
			_sprite(target + offset, 0.6, "ew0052_hit", "fire2", after, 0.8 * (1.0 - after), angle)
	for i in range(cursor, sprites.size()): sprites[i].visible = false
