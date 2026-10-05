extends Node3D
## World-space ball choreography. All movement and cues share the battle clock.
signal cue(key: String)
var cancelled := false
var speed_provider: Callable
var actor_update: Callable
var ball: Node3D
var opening_player: AnimationPlayer
var glow: MeshInstance3D
var beam: MeshInstance3D
var sparks: Array[MeshInstance3D] = []
var origin := Vector3.ZERO
var target := Vector3.ZERO
var floor_point := Vector3.ZERO
var actor_origin := Vector3.ZERO

func build(start: Vector3, center: Vector3, ground: Vector3, item: String, speed: Callable, update: Callable) -> void:
	origin = start
	actor_origin = ground
	target = center
	floor_point = ground + Vector3.UP * 0.18
	speed_provider = speed
	actor_update = update
	ball = Node3D.new()
	add_child(ball)
	var model := preload("res://assets/models/battle/pokeball/openable_pokeball.fbx").instantiate() as Node3D
	ball.add_child(model)
	# Source FBX uses centimetres: normalize its closed diameter to 0.36 world units.
	model.scale = Vector3.ONE * (0.36 / 0.020433)
	for child in model.find_children("*", "", true, false):
		if child is Camera3D:
			child.queue_free()
		elif child is AnimationPlayer:
			opening_player = child
		elif child is MeshInstance3D:
			# Keep materials local to the instance; show the shell interior when open.
			for surface in child.mesh.get_surface_count():
				var material: StandardMaterial3D = child.mesh.surface_get_material(surface)
				if material != null:
					var shell := material.duplicate() as StandardMaterial3D
					if material.resource_name == "red": shell.albedo_color = _ball_color(item)
					shell.roughness = 0.3
					shell.cull_mode = BaseMaterial3D.CULL_DISABLED
					child.set_surface_override_material(surface, shell)
	opening_player.play("Take 001")
	opening_player.pause()
	_open(0.0)
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	orb.radial_segments = 16
	orb.rings = 8
	glow = _mesh(orb, _material(Color("b9f3ff"), true), self)
	glow.visible = false
	var ray := CylinderMesh.new()
	ray.top_radius = 0.025
	ray.bottom_radius = 0.075
	ray.height = 1.0
	ray.radial_segments = 12
	beam = _mesh(ray, _material(Color("ff7196"), true), self)
	beam.visible = false
	for i in 12:
		var spark := _mesh(orb, _material(Color("d9f9ff"), true), self)
		spark.scale = Vector3.ONE * 0.045
		spark.visible = false
		sparks.append(spark)

func _ball_color(item: String) -> Color:
	# One reviewed shape, palette variants until dedicated ball-type assets are supplied.
	var colors := {"great-ball":"327dd6", "ultra-ball":"292a30", "master-ball":"9a4ecd",
		"premier-ball":"f4f4ed", "cherish-ball":"c82938", "luxury-ball":"24242b",
		"nest-ball":"4c9859", "net-ball":"31858e", "dive-ball":"65b9e5", "repeat-ball":"d86828",
		"timer-ball":"eeeeeb", "safari-ball":"73904e", "quick-ball":"efc444", "dusk-ball":"40804e",
		"heal-ball":"f2a7c9", "beast-ball":"237ebd", "gs-ball":"cdb752", "fast-ball":"e87737",
		"lure-ball":"3f82a1", "level-ball":"333035", "heavy-ball":"555d6e", "love-ball":"ed8cae",
		"friend-ball":"74b94c", "moon-ball":"343b47", "park-ball":"d6ba42", "sport-ball":"d76c31",
		"dream-ball":"cd77b2"}
	return Color(colors.get(item.to_lower().replace("_","-").replace(" ","-"), "e63b45"))

func _open(amount: float) -> void:
	# The supplied clip reaches its open pose at 0.375 s and then closes again.
	# Sample only its opening section, in either direction, under the battle clock.
	opening_player.seek(clampf(amount,0.0,1.0)*0.375,true)

func _material(color: Color, light := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.35
	if light:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.8
	return mat

func _mesh(shape: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _step(duration: float, update: Callable) -> bool:
	var elapsed := 0.0
	update.call(0.0)
	while not cancelled and is_inside_tree() and elapsed < duration:
		await get_tree().process_frame
		if cancelled or not is_inside_tree(): return false
		elapsed += get_process_delta_time() * maxf(float(speed_provider.call()), 0.0)
		update.call(clampf(elapsed / duration, 0.0, 1.0))
	return not cancelled and is_inside_tree()

func _actor(amount: float, displacement := Vector3.ZERO) -> void:
	if not cancelled and actor_update.is_valid(): actor_update.call(amount, displacement)

func _burst(center: Vector3, progress: float, pink := false) -> void:
	glow.visible = progress < 0.96
	glow.position = center
	glow.scale = Vector3.ONE * maxf(0.01, sin(progress * PI) * 0.95)
	glow.material_override.albedo_color = Color(1.0,0.45,0.64,1.0-progress) if pink else Color(0.7,0.95,1.0,1.0-progress)
	for i in sparks.size():
		var angle := TAU * i / sparks.size()
		var direction := Vector3(cos(angle), 0.35 + 0.35 * sin(i * 2.3), sin(angle)).normalized()
		var spark := sparks[i]
		spark.visible = progress < 0.96
		spark.position = center + direction * progress * 1.1
		spark.scale = Vector3.ONE * maxf(0.002,0.06 * (1.0-progress))

func _ray(from: Vector3, to: Vector3, amount: float) -> void:
	beam.visible = amount > 0.0
	var delta := to - from
	if delta.length() < 0.001: return
	beam.position = (from+to)*0.5
	var axis := delta.normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.01: right = axis.cross(Vector3.RIGHT).normalized()
	beam.basis = Basis(right,axis,right.cross(axis)).scaled(Vector3(amount,delta.length(),amount))

func send_out(with_throw: bool) -> bool:
	_actor(0.0)
	ball.position = origin if with_throw else target
	if with_throw:
		cue.emit("summon_throw")
		if not await _step(0.28, func(p: float):
			ball.position = origin.lerp(target,p) + Vector3.UP * sin(p*PI)*0.8
			ball.rotation.x = -TAU*p
		): return false
	ball.rotation = Vector3.ZERO
	cue.emit("summon_release")
	if not await _step(0.12,func(p: float): _open(p)): return false
	cue.emit("cry")
	if not await _step(0.32,func(p: float):
		_actor(smoothstep(0.0,1.0,p), (target-actor_origin)*(1.0-smoothstep(0.0,1.0,p)))
		_burst(target,p)
		ball.scale = Vector3.ONE * maxf(0.001,1.0-p)
	): return false
	_actor(1.0)
	return true

func recall() -> bool:
	ball.position = origin
	_open(1.0)
	cue.emit("summon_release")
	if not await _step(0.30,func(p: float):
		_actor(1.0-smoothstep(0.0,1.0,p),(origin-actor_origin)*smoothstep(0.0,1.0,p))
		_ray(target.lerp(origin,p),origin,sin(p*PI))
		_burst(origin,p,true)
	): return false
	_actor(0.0)
	beam.visible = false
	return await _step(0.10,func(p: float): _open(1.0-p))

func capture(shakes: int, caught: bool) -> bool:
	ball.position = origin
	cue.emit("capture_throw")
	if not await _step(0.34,func(p: float):
		ball.position = origin.lerp(target,p) + Vector3.UP*sin(p*PI)*1.0
		ball.rotation.x = -TAU*p
	): return false
	ball.rotation = Vector3.ZERO
	_open(1.0)
	cue.emit("capture_absorb")
	if not await _step(0.26,func(p: float):
		_actor(1.0-smoothstep(0.0,1.0,p),(target-actor_origin)*smoothstep(0.0,1.0,p))
		_burst(target,p)
	): return false
	_actor(0.0)
	if not await _step(0.10,func(p: float): _open(1.0-p)): return false
	if not await _step(0.24,func(p: float): ball.position = target.lerp(floor_point,p*p)): return false
	if not await _step(0.14,func(p: float): ball.position = floor_point + Vector3.UP*sin(p*PI)*0.16): return false
	for i in clampi(shakes,0,3):
		cue.emit("capture_shake")
		if not await _step(0.28,func(p: float):
			ball.rotation.z = sin(p*TAU)*0.4
			ball.position.x = floor_point.x + sin(p*TAU)*0.045
		): return false
		if not await _step(0.09,func(_p: float): pass): return false
	if caught:
		cue.emit("capture_success")
		if not await _step(0.24,func(p: float): _burst(floor_point,p)): return false
	else:
		cue.emit("capture_break")
		_open(1.0)
		if not await _step(0.28,func(p: float):
			_actor(smoothstep(0.0,1.0,p), (target-actor_origin)*(1.0-smoothstep(0.0,1.0,p)))
			_burst(target,p)
			ball.scale = Vector3.ONE*maxf(0.001,1.0-p)
		): return false
		_actor(1.0)
	return true

func cancel() -> void:
	cancelled = true
	visible = false
