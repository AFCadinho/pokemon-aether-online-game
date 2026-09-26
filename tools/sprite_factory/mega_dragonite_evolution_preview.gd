extends SceneTree
## Local 3D form-change review. Loads external candidate scenes; changes no catalog.

const SPARK = preload("res://tools/sprite_factory/mega_evolution_preview_assets/spark_04.png")
const CHARGE_SOUND = preload("res://assets/battles/animations/common/megaevolution/PRSFX- Mega Evolution1.wav")
const REVEAL_SOUND = preload("res://assets/battles/animations/common/megaevolution/PRSFX- Mega Evolution2.wav")
const CHARGE_SECONDS := 1.35
const APPEAL_SECONDS := 181.0 / 60.0
const TOTAL_SECONDS := CHARGE_SECONDS + APPEAL_SECONDS + 0.35

var stage: Node3D
var base_actor: Node3D
var mega_actor: Node3D
var base_player: AnimationPlayer
var mega_player: AnimationPlayer
var camera: Camera3D
var sparkles: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var flash: MeshInstance3D
var status: Label
var charge_sound: AudioStreamPlayer
var reveal_sound: AudioStreamPlayer
var running := false
var swapped := false
var elapsed := 0.0
var camera_angle := 0.45
var autoplay := true
var autoquit := false
var screenshot_dir := ""
var captured := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var base_path := OS.get_environment("POKEAETHER_MEGA_PREVIEW_BASE")
	var mega_path := OS.get_environment("POKEAETHER_MEGA_PREVIEW_MEGA")
	if not FileAccess.file_exists(base_path) or not FileAccess.file_exists(mega_path):
		printerr("Set POKEAETHER_MEGA_PREVIEW_BASE and POKEAETHER_MEGA_PREVIEW_MEGA to local .scn files")
		quit(2)
		return
	var base_scene := ResourceLoader.load(base_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var mega_scene := ResourceLoader.load(mega_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if base_scene == null or mega_scene == null:
		printerr("Could not load both 3D candidate scenes")
		quit(2)
		return
	root.title = "Mega Dragonite · 3D evolution preview"
	root.size = Vector2i(1120, 700)
	stage = Node3D.new()
	root.add_child(stage)
	_build_world()
	base_actor = base_scene.instantiate() as Node3D
	mega_actor = mega_scene.instantiate() as Node3D
	if base_actor == null or mega_actor == null:
		printerr("Candidate scene root must be Node3D")
		quit(2)
		return
	stage.add_child(base_actor)
	stage.add_child(mega_actor)
	base_actor.position.y = 0.05
	mega_actor.position.y = 0.05
	base_actor.rotation.y = PI
	mega_actor.rotation.y = PI
	base_player = _find_player(base_actor)
	mega_player = _find_player(mega_actor)
	if base_player == null or mega_player == null or not mega_player.has_animation("mega_appeal"):
		printerr("Missing AnimationPlayer or native mega_appeal clip")
		quit(2)
		return
	_build_effect()
	_build_controls()
	charge_sound = AudioStreamPlayer.new()
	charge_sound.stream = CHARGE_SOUND
	root.add_child(charge_sound)
	reveal_sound = AudioStreamPlayer.new()
	reveal_sound.stream = REVEAL_SOUND
	root.add_child(reveal_sound)
	_reset()
	autoquit = OS.get_environment("POKEAETHER_MEGA_PREVIEW_AUTOQUIT") == "1"
	screenshot_dir = OS.get_environment("POKEAETHER_MEGA_PREVIEW_SCREENSHOTS")
	if not screenshot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(screenshot_dir)
	if autoplay:
		await create_timer(0.5).timeout
		_start()

func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null

func _material(color: Color, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142334")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b2bbdc")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 3.7
	cylinder.bottom_radius = 3.8
	cylinder.height = 0.15
	platform.mesh = cylinder
	platform.position.y = -0.14
	platform.material_override = _material(Color("879b98"))
	stage.add_child(platform)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(2, 4, 4)
	fill.light_color = Color("d8ddff")
	fill.light_energy = 0.8
	fill.omni_range = 12.0
	stage.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	camera.current = true
	stage.add_child(camera)
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(camera_angle) * 9.0, 3.7, cos(camera_angle) * 9.0)
	camera.look_at(Vector3(0, 1.2, 0))

func _build_effect() -> void:
	var spark_material := _material(Color("cba4ff"), true)
	spark_material.albedo_texture = SPARK
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for index in 30:
		var sparkle := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		sparkle.mesh = quad
		sparkle.material_override = spark_material
		sparkle.visible = false
		stage.add_child(sparkle)
		sparkles.append(sparkle)
	for index in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.55
		torus.outer_radius = 1.59
		torus.rings = 64
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = _material(Color("b57bff"), true)
		ring.position.y = 0.55 + index * 0.65
		ring.visible = false
		stage.add_child(ring)
		rings.append(ring)
	flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.35
	sphere.height = 2.7
	flash.mesh = sphere
	flash.material_override = _material(Color(0.95, 0.78, 1.0, 0.75), true)
	flash.position.y = 1.2
	flash.visible = false
	stage.add_child(flash)

func _build_controls() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var heading := Label.new()
	heading.text = "MEGA DRAGONITE  /  3D TRANSFORMATIEPROEF"
	heading.position = Vector2(22, 16)
	heading.add_theme_font_size_override("font_size", 21)
	canvas.add_child(heading)
	status = Label.new()
	status.position = Vector2(22, 52)
	status.add_theme_font_size_override("font_size", 16)
	canvas.add_child(status)
	var replay := Button.new()
	replay.text = "Speel transformatie"
	var button_y := root.get_visible_rect().size.y - 260.0
	replay.position = Vector2(22, button_y)
	replay.size = Vector2(190, 42)
	replay.pressed.connect(_start)
	canvas.add_child(replay)
	var reset := Button.new()
	reset.text = "Gewone vorm"
	reset.position = Vector2(224, button_y)
	reset.size = Vector2(140, 42)
	reset.pressed.connect(_reset)
	canvas.add_child(reset)
	var turn := Button.new()
	turn.text = "Draai camera"
	turn.position = Vector2(376, button_y)
	turn.size = Vector2(140, 42)
	turn.pressed.connect(func(): camera_angle += PI * 0.5; _update_camera())
	canvas.add_child(turn)

func _reset() -> void:
	running = false
	swapped = false
	elapsed = 0.0
	base_actor.visible = true
	mega_actor.visible = false
	base_player.play("idle")
	mega_player.play("idle")
	if charge_sound != null:
		charge_sound.stop()
	if reveal_sound != null:
		reveal_sound.stop()
	_set_effect(0.0)
	status.text = "Gewone Dragonite · klaar voor Mega Evolution"

func _start() -> void:
	_reset()
	running = true
	captured.clear()
	charge_sound.play()
	status.text = "Mega-energie verzamelt zich rond Dragonite"

func _set_effect(time: float) -> void:
	var charge := clampf(time / CHARGE_SECONDS, 0.0, 1.0)
	var fade := clampf((2.75 - time) / 0.6, 0.0, 1.0)
	var strength := minf(charge * 2.6, 1.0) * fade if time > 0.0 else 0.0
	for index in sparkles.size():
		var sparkle := sparkles[index]
		sparkle.visible = strength > 0.01
		var offset := float(index) / float(sparkles.size())
		var angle := offset * TAU * 3.0 + time * (2.0 + offset)
		var radius := 1.1 + 0.95 * (1.0 - charge)
		sparkle.position = Vector3(cos(angle) * radius, 0.3 + fmod(offset * 4.5 + time * 1.3, 2.65), sin(angle) * radius)
		var pulse := 0.7 + 0.55 * sin(time * 13.0 + index)
		sparkle.scale = Vector3.ONE * maxf(0.1, pulse * strength)
	for index in rings.size():
		var ring := rings[index]
		ring.visible = strength > 0.02
		ring.scale = Vector3.ONE * (1.15 - 0.35 * charge + 0.05 * sin(time * 8.0 + index))
		ring.rotation.y = time * (1.1 + index * 0.3)
		ring.transparency = 1.0 - strength * 0.75
	var flash_strength := clampf(1.0 - absf(time - CHARGE_SECONDS) / 0.26, 0.0, 1.0)
	flash.visible = flash_strength > 0.01
	flash.scale = Vector3.ONE * (0.8 + flash_strength * 0.6)
	flash.transparency = 1.0 - flash_strength * 0.86

func _process(delta: float) -> bool:
	if not running:
		return false
	elapsed += delta
	_set_effect(elapsed)
	if not swapped and elapsed >= CHARGE_SECONDS:
		swapped = true
		base_actor.visible = false
		mega_actor.visible = true
		mega_player.play("mega_appeal")
		reveal_sound.play()
		status.text = "Mega Dragonite · oorspronkelijke ZA Mega-pose"
		print("MEGA_PREVIEW_SWAP native_appeal=", mega_player.has_animation("mega_appeal"))
	if swapped:
		# The native entrance begins with the tail below its idle ground clearance.
		# Let the new actor descend while the swap flash still covers its first pose.
		mega_actor.position.y = 0.05 + 0.5 * (1.0 - clampf((elapsed - CHARGE_SECONDS) / 0.55, 0.0, 1.0))
	if not screenshot_dir.is_empty():
		for moment in [0.35, 1.15, 1.5, 2.25, 4.45]:
			if elapsed >= moment and not captured.has(moment):
				captured[moment] = true
				var filename := screenshot_dir.path_join("mega-evolution-%04d.png" % roundi(moment * 100.0))
				root.get_texture().get_image().save_png(filename)
	if elapsed >= TOTAL_SECONDS:
		running = false
		_set_effect(0.0)
		mega_player.play("idle")
		status.text = "Mega Dragonite · transformatie voltooid"
		print("MEGA_PREVIEW_COMPLETE")
		if autoquit:
			quit()
	return false
