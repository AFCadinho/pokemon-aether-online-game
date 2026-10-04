extends Node3D
## Short event-owned geometry in the arena. No sprites, model mutations or gameplay.

signal finished
const MOVE_EFFECTS := ["future_sight_impact", "solar_beam_charge", "electro_shot_charge"]

const PROFILES := {
	"stat_up": ["rise", "73b7ff", 0.65], "stat_down": ["fall", "ec638b", 0.65],
	"health_up": ["heal", "45ef95", 0.85], "wish_fulfilled": ["wish", "ffdc72", 0.7],
	"use_item": ["item", "a5e7ff", 0.85], "eat_berry": ["berry", "f3798b", 0.75],
	"shiny_sparkle": ["shiny", "ffe685", 0.7], "protect_block": ["shield", "67d9ff", 0.65],
	"status_paralysis": ["electric", "ffe14f", 0.65],
	"status_poisoned": ["poison", "c07dea", 0.7], "status_badly_poisoned": ["poison", "ae47e5", 0.75],
	"status_burned": ["fire", "ff9a48", 0.7], "status_frozen": ["ice", "9deeff", 0.75],
	"status_sleeping": ["sleep", "9db2f4", 0.8], "status_confused": ["confused", "ffce63", 0.7],
	"grassy_terrain_start": ["terrain", "63e28a", 0.75],
	"z_power": ["power", "ffcb57", 1.35], "mega_evolution": ["power", "d2a4ff", 1.4],
}

var key := ""
var style := ""
var duration := 0.7
var elapsed := 0.0
var done := false
var cancelled := false
var height := 2.0
var radius := 1.0
var valid: Callable
var speed_provider: Callable
var particles: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var shell: MeshInstance3D
var aura: MeshInstance3D
var berry_parts: Array[MeshInstance3D] = []
var front := Vector3(0,0,1)

static func supports(effect: String) -> bool:
	return PROFILES.has(effect)

static func audio_plan(source: Dictionary, effect: String) -> Dictionary:
	if source.is_empty() or not supports(effect):
		return source
	var result := source.duplicate(true)
	var native_duration: float = PROFILES[effect][2]
	var source_duration := maxf(float(source.get("duration_seconds", 0.0)), 0.001)
	var seen := {}
	var cues: Array[Dictionary] = []
	for cue: Dictionary in source.get("cues", []):
		var name := str(cue.event.get("name", ""))
		if seen.has(name):
			continue # Repeated 2D sheet cues must not restart a short shared sample.
		seen[name] = true
		cues.append({"at_seconds": clampf(float(cue.at_seconds) / source_duration, 0.0, 0.75) * native_duration,
			"event": cue.event.duplicate(true)})
	if effect == "eat_berry" and not cues.is_empty():
		cues[0].at_seconds = native_duration * 0.32
	if effect == "mega_evolution" and cues.size() >= 2:
		cues[1].at_seconds = native_duration * 0.55
	result.cues = cues
	result.duration_seconds = native_duration
	result.speed_scale = 1.0
	return result

func start(effect: String, body_height: float, body_radius: float, guard: Callable, speed: Callable) -> void:
	key = effect
	style = str(PROFILES[key][0])
	duration = float(PROFILES[key][2])
	height = clampf(body_height, 0.8, 4.5)
	radius = clampf(body_radius, 0.5, 2.5)
	valid = guard
	speed_provider = speed
	var color := Color(str(PROFILES[key][1]))
	_build(color)
	_update_visuals()

func seconds() -> float:
	return elapsed

func cancel() -> void:
	if done:
		return
	cancelled = true
	_finish()

func _finish() -> void:
	done = true
	set_process(false)
	valid = Callable()
	speed_provider = Callable()
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	if not done:
		done = true
		cancelled = true
		finished.emit()

func _process(delta: float) -> void:
	if done:
		return
	if valid.is_valid() and not bool(valid.call()):
		cancel()
		return
	var speed := maxf(float(speed_provider.call()), 0.0) if speed_provider.is_valid() else 1.0
	elapsed = minf(duration, elapsed + maxf(delta, 0.0) * speed)
	_update_visuals()
	if elapsed >= duration:
		_finish()

func _material(color: Color, billboard := false, alpha := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color * 0.12
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	return material

func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _polygon(points: Array[Vector2]) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(PackedVector2Array(points)):
		var point := points[index]
		tool.add_vertex(Vector3(point.x, point.y, 0.0))
	return tool.commit()

func _icon(kind: String) -> ArrayMesh:
	if kind == "sparkle":
		return _polygon([Vector2(0,0.5),Vector2(0.1,0.1),Vector2(0.5,0),Vector2(0.1,-0.1),Vector2(0,-0.5),Vector2(-0.1,-0.1),Vector2(-0.5,0),Vector2(-0.1,0.1)])
	if kind in ["arrow", "down_arrow"]:
		var points: Array[Vector2] = [Vector2(-0.5,-0.1),Vector2(0,0.4),Vector2(0.5,-0.1),Vector2(0.5,-0.4),Vector2(0,-0.05),Vector2(-0.5,-0.4)]
		if kind == "down_arrow":
			for index in points.size(): points[index].y *= -1.0
		return _polygon(points)
	if kind == "bolt":
		return _polygon([Vector2(-0.1,0.6),Vector2(-0.38,-0.06),Vector2(-0.03,-0.02),Vector2(-0.15,-0.6),Vector2(0.38,0.16),Vector2(0.03,0.12)])
	if kind == "sleep":
		return _polygon([Vector2(-0.4,0.4),Vector2(0.4,0.4),Vector2(0.4,0.22),Vector2(-0.1,-0.23),Vector2(0.4,-0.23),Vector2(0.4,-0.4),Vector2(-0.4,-0.4),Vector2(-0.4,-0.22),Vector2(0.1,0.23),Vector2(-0.4,0.23)])
	if kind == "cross":
		return _polygon([Vector2(-0.12,0.4),Vector2(0.12,0.4),Vector2(0.12,0.12),Vector2(0.4,0.12),Vector2(0.4,-0.12),Vector2(0.12,-0.12),Vector2(0.12,-0.4),Vector2(-0.12,-0.4),Vector2(-0.12,-0.12),Vector2(-0.4,-0.12),Vector2(-0.4,0.12),Vector2(-0.12,0.12)])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 10:
		tool.add_vertex(Vector3.ZERO)
		for step in [index, index + 1]:
			var angle := float(step) * TAU / 10.0 + PI / 2.0
			var extent := 0.5 if step % 2 == 0 else 0.22
			tool.add_vertex(Vector3(cos(angle),sin(angle),0) * extent)
	return tool.commit()

func _build(color: Color) -> void:
	var particle_mesh: Mesh
	var icon := ""
	match style:
		"rise": icon = "arrow"
		"fall": icon = "down_arrow"
		"heal": icon = "cross"
		"electric": icon = "bolt"
		"sleep": icon = "sleep"
		"wish", "confused": icon = "star"
		"shiny", "power", "item": icon = "sparkle"
	if not icon.is_empty():
		particle_mesh = _icon(icon)
	elif style == "ice":
		var prism := PrismMesh.new()
		prism.size = Vector3(0.23,0.7,0.23)
		particle_mesh = prism
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		sphere.radial_segments = 12
		sphere.rings = 6
		particle_mesh = sphere
	var count := 8
	if style in ["rise", "fall", "electric", "ice"]: count = 6
	if style == "sleep": count = 3
	if style == "confused": count = 5
	if style == "wish": count = 6
	if style == "terrain": count = 0
	if style == "shield": count = 6
	if style == "item": count = 12
	if style == "power": count = 16
	if style == "berry": count = 6
	var material := _material(color, not icon.is_empty())
	for index in count:
		particles.append(_mesh(particle_mesh, material))
	if style in ["rise", "fall", "heal", "item", "power", "shield", "terrain"]:
		for index in (3 if style in ["shield", "terrain"] else 2):
			var torus := TorusMesh.new()
			torus.inner_radius = radius * 0.96
			torus.outer_radius = radius
			torus.rings = 32
			torus.ring_segments = 6
			rings.append(_mesh(torus, _material(color, false, 0.6)))
	if style == "berry":
		for index in 3:
			var fruit := SphereMesh.new()
			fruit.radius = 0.13
			fruit.height = 0.26
			fruit.radial_segments = 16
			fruit.rings = 8
			berry_parts.append(_mesh(fruit,_material(Color("ec617f"))))
		var leaf := PrismMesh.new()
		leaf.size = Vector3(0.13,0.23,0.04)
		berry_parts.append(_mesh(leaf,_material(Color("60d577"))))
	if style == "power":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius * 0.75
		cylinder.bottom_radius = radius * 1.25
		cylinder.height = height * 1.25
		cylinder.radial_segments = 48
		cylinder.cap_top = false
		cylinder.cap_bottom = false
		var material_aura := ShaderMaterial.new()
		material_aura.shader = preload("res://scripts/battle/battle_ui/power_aura_3d.gdshader")
		material_aura.set_shader_parameter("flame_color",color)
		aura = _mesh(cylinder,material_aura)
		aura.position.y = height * 0.6
	if style == "shield":
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		shell = _mesh(sphere, _material(color, false, 0.12))
		shell.position.y = height * 0.5
		shell.scale = Vector3(radius * 1.15,height * 0.6,radius * 1.15)

func _update_visuals() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var envelope := minf(progress / 0.12, (1.0 - progress) / 0.22)
	envelope = clampf(envelope, 0.0, 1.0)
	for index in particles.size():
		var node := particles[index]
		var offset := float(index) / maxf(particles.size(), 1)
		var angle := offset * TAU + progress * 1.5
		var phase := fmod(progress * 0.9 + offset * 0.65, 1.0)
		var spread := radius * 0.9
		var y := height * (0.12 + phase * 0.8)
		var size := clampf(height * 0.15, 0.16, 0.4)
		match style:
			"rise": y = height * (0.05 + progress * 0.85 + offset * 0.1)
			"fall": y = height * (0.95 - progress * 0.85 - offset * 0.1)
			"heal": spread *= 0.75
			"poison": size = 0.65 + phase; y = height * (0.1 + phase * 0.7)
			"fire": size = 0.8 + 0.4 * sin(progress * 22.0 + index); y = height * (0.15 + phase * 0.65)
			"ice": size = 0.9; y = height * (0.2 + offset * 0.65); angle = offset * TAU
			"electric": y = height * (0.25 + offset * 0.55); size *= 1.1; spread *= 0.75
			"sleep": y = height * (0.85 + offset * 0.5 + progress * 0.3); spread *= 0.35; size *= 1.0 + offset
			"confused": y = height * 1.1 + sin(angle * 2.0) * 0.1; angle += progress * TAU; spread *= 0.7; size *= 0.65
			"wish": y = height * (1.45 - progress * 0.9 + offset * 0.15); spread *= 1.0 - progress * 0.65; size *= 0.75
			"shiny": y = height * (0.2 + offset * 0.8); spread *= 0.4 + progress * 1.1
			"item": y = height * (0.02 + progress * 1.1 - offset * 0.28); spread *= 0.65; size *= 0.65 + 0.35 * sin(index * 2.0)
			"power": y = height * (0.05 + phase * 1.2); spread *= 1.4 - progress * 0.65; size *= 0.8 + progress
			"berry": y = height * 0.65 - maxf(0.0,progress - 0.32) * height * 0.4; spread *= maxf(0.0,progress - 0.32) * 0.6; size = 0.5 * (1.0 - progress)
			"shield": y = height * (0.2 + offset * 0.6); spread *= 1.1; size *= 0.5
		node.position = Vector3(cos(angle) * spread, y, sin(angle) * spread)
		if style == "berry": node.position += front * radius * 0.9
		node.scale = Vector3.ONE * maxf(size, 0.01)
		if style == "fire": node.scale.y *= 2.0
		if style == "ice": node.rotation = Vector3(0.12 * sin(index),angle,0.2 * cos(index))
		node.visible = envelope > 0.01 and (style != "berry" or progress >= 0.32) and (style != "item" or y > 0.0)
		node.transparency = 1.0 - envelope * (0.65 + 0.35 * sin(phase * PI))
	for index in berry_parts.size():
		var part := berry_parts[index]
		part.position = front * radius * 0.9 + Vector3((index % 2 - 0.5) * 0.12, height * 0.55 + (0.18 if index == 3 else float(index) * 0.04), 0.0)
		var shrink := 1.0 - smoothstep(0.32,0.68,progress)
		part.scale = Vector3.ONE * shrink * clampf(height * 0.65,0.8,1.6)
		part.visible = envelope > 0.01 and shrink > 0.01
		part.transparency = 1.0 - envelope
	if is_instance_valid(aura):
		aura.material_override.set_shader_parameter("effect_time",elapsed)
		aura.material_override.set_shader_parameter("strength",envelope * smoothstep(0.0,0.35,progress))
		aura.scale = Vector3.ONE * (0.75 + progress * 0.45)
	for index in rings.size():
		var ring := rings[index]
		var scale_factor := 0.75 + progress * 0.55 + index * 0.12
		ring.position.y = 0.04 + index * height * 0.1
		if style == "shield":
			ring.position.y = height * (0.2 + index * 0.3)
			scale_factor = 1.1 - 0.08 * sin(progress * PI)
		if style == "power": scale_factor = 0.8 + maxf(0.0,progress - 0.5) * 3.5 + index * 0.18
		if style == "terrain": scale_factor = 1.0 + progress * 3.0 + index * 0.7
		if style == "fall": scale_factor = 1.3 - progress * 0.45
		ring.scale = Vector3.ONE * scale_factor
		ring.visible = envelope > 0.01
		ring.transparency = 1.0 - envelope * 0.7
	if is_instance_valid(shell):
		shell.visible = envelope > 0.01
		shell.transparency = 1.0 - envelope * 0.8
