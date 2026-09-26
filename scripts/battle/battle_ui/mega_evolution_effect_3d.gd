extends Node3D
## Battle-local 3D charge and reveal. The caller owns the form swap.

signal reveal_requested
signal finished

const SPARK = preload("res://tools/sprite_factory/mega_evolution_preview_assets/spark_04.png")
const CHARGE_SOUND = preload("res://assets/battles/animations/common/megaevolution/PRSFX- Mega Evolution1.wav")
const REVEAL_SOUND = preload("res://assets/battles/animations/common/megaevolution/PRSFX- Mega Evolution2.wav")
const CHARGE_SECONDS := 1.35
const TOTAL_SECONDS := CHARGE_SECONDS + 181.0 / 60.0 + 0.35

var elapsed := 0.0
var speed := 1.0
var revealed := false
var done := false
var sparkles: Array[MeshInstance3D] = []
var rings: Array[MeshInstance3D] = []
var flash: MeshInstance3D
var charge_audio: AudioStreamPlayer
var reveal_audio: AudioStreamPlayer

func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material

func start(playback_speed: float) -> void:
	speed = maxf(playback_speed, 0.5)
	var spark_material := _glow(Color("cba4ff"))
	spark_material.albedo_texture = SPARK
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for index in 30:
		var sparkle := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.3, 0.3)
		sparkle.mesh = quad
		sparkle.material_override = spark_material
		add_child(sparkle)
		sparkles.append(sparkle)
	for index in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.55
		torus.outer_radius = 1.59
		torus.rings = 64
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = _glow(Color("b57bff"))
		ring.position.y = 0.55 + index * 0.65
		add_child(ring)
		rings.append(ring)
	flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.35
	sphere.height = 2.7
	flash.mesh = sphere
	flash.material_override = _glow(Color(0.95, 0.78, 1.0, 0.75))
	flash.position.y = 1.2
	add_child(flash)
	charge_audio = AudioStreamPlayer.new()
	charge_audio.stream = CHARGE_SOUND
	charge_audio.pitch_scale = speed
	add_child(charge_audio)
	reveal_audio = AudioStreamPlayer.new()
	reveal_audio.stream = REVEAL_SOUND
	reveal_audio.pitch_scale = speed
	add_child(reveal_audio)
	charge_audio.play()
	_update_visuals()
	set_process(true)

func cancel() -> void:
	if done:
		return
	done = true
	set_process(false)
	charge_audio.stop()
	reveal_audio.stop()
	finished.emit()
	queue_free()

func _process(delta: float) -> void:
	if done:
		return
	elapsed += delta * speed
	_update_visuals()
	if not revealed and elapsed >= CHARGE_SECONDS:
		revealed = true
		reveal_audio.play()
		reveal_requested.emit()
	if elapsed >= TOTAL_SECONDS:
		done = true
		set_process(false)
		finished.emit()
		queue_free()

func _update_visuals() -> void:
	var charge := clampf(elapsed / CHARGE_SECONDS, 0.0, 1.0)
	var fade := clampf((2.75 - elapsed) / 0.6, 0.0, 1.0)
	var strength := minf(charge * 2.6, 1.0) * fade if elapsed > 0.0 else 0.0
	for index in sparkles.size():
		var sparkle := sparkles[index]
		sparkle.visible = strength > 0.01
		var offset := float(index) / float(sparkles.size())
		var angle := offset * TAU * 3.0 + elapsed * (2.0 + offset)
		var radius := 1.1 + 0.95 * (1.0 - charge)
		sparkle.position = Vector3(cos(angle) * radius, 0.3 + fmod(offset * 4.5 + elapsed * 1.3, 2.65), sin(angle) * radius)
		sparkle.scale = Vector3.ONE * maxf(0.1, (0.7 + 0.55 * sin(elapsed * 13.0 + index)) * strength)
	for index in rings.size():
		var ring := rings[index]
		ring.visible = strength > 0.02
		ring.scale = Vector3.ONE * (1.15 - 0.35 * charge + 0.05 * sin(elapsed * 8.0 + index))
		ring.rotation.y = elapsed * (1.1 + index * 0.3)
		ring.transparency = 1.0 - strength * 0.75
	var flash_strength := clampf(1.0 - absf(elapsed - CHARGE_SECONDS) / 0.26, 0.0, 1.0)
	flash.visible = flash_strength > 0.01
	flash.scale = Vector3.ONE * (0.8 + flash_strength * 0.6)
	flash.transparency = 1.0 - flash_strength * 0.86
