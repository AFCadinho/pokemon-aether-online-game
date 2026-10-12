extends RefCounted
## Temporary camera-local blue sky/haze, owned by the native move lifetime.
## The arena, world clock and weather resources are never recoloured in place.
const BLUE := Color("081f68")
const LIVE_PROPERTIES := [
	"background_mode", "background_color", "background_energy_multiplier", "sky",
	"ambient_light_color", "ambient_light_energy", "ambient_light_source",
	"ambient_light_sky_contribution", "reflected_light_source",
	"fog_enabled", "fog_mode", "fog_light_color", "fog_light_energy", "fog_density",
	"fog_sky_affect", "fog_sun_scatter", "fog_aerial_perspective", "fog_height",
	"fog_height_density", "fog_depth_begin", "fog_depth_end", "fog_depth_curve",
]
var effect: Node
var camera: Camera3D
var original: Environment
var source: Environment
var atmosphere: Environment
var strength := 0.0

func begin(owner: Node) -> void:
	suspend()
	effect = owner

func clear(owner: Node = null) -> void:
	if owner != null and effect != owner: return
	suspend()
	effect = null

func suspend() -> void:
	# Weather may change beneath the move. Unwrap before weather takes/restores
	# its own camera override, then sample the new weather on the next apply.
	if is_instance_valid(camera) and camera.environment == atmosphere:
		camera.environment = original
	camera = null
	original = null
	source = null
	atmosphere = null
	strength = 0.0

func apply(stage: Node) -> void:
	if not stage.active or stage._is_hybrid_presentation() or not is_instance_valid(stage.camera) or not is_instance_valid(stage.world):
		suspend()
		return
	if not is_instance_valid(effect) or effect.done or not effect.clock.is_valid() or not effect.valid.is_valid() or not effect.valid.call():
		suspend()
		return
	var p := clampf(float(effect.clock.call()) / effect.duration, 0.0, 1.0)
	var weight := smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.86, 1.0, p))
	if weight <= 0.00001:
		suspend()
		return
	if camera != stage.camera or camera.environment != atmosphere or atmosphere == null:
		suspend()
		camera = stage.camera
		original = camera.environment
		source = original
		if source == null:
			for child in stage.world.get_children():
				if child is WorldEnvironment:
					source = child.environment
					break
		if source == null: return
		atmosphere = source.duplicate()
		camera.environment = atmosphere
	strength = weight
	for property in LIVE_PROPERTIES:
		atmosphere.set(property, source.get(property))
	atmosphere.background_color = source.background_color.lerp(BLUE, weight)
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = source.fog_light_color.lerp(BLUE, weight) if source.fog_enabled else BLUE
	atmosphere.fog_light_energy = lerpf(source.fog_light_energy, 1.0, weight)
	atmosphere.fog_sky_affect = lerpf(source.fog_sky_affect if source.fog_enabled else 0.0, 0.98, weight)
	atmosphere.fog_sun_scatter = source.fog_sun_scatter * (1.0 - weight)
	atmosphere.fog_aerial_perspective = source.fog_aerial_perspective * (1.0 - weight)
	if source.fog_enabled:
		# Retain the weather's fog shape while blending its colour and density.
		var density := 0.035 if source.fog_mode == Environment.FOG_MODE_EXPONENTIAL else 0.9
		atmosphere.fog_density = lerpf(source.fog_density, maxf(source.fog_density, density), weight)
	else:
		# Place the blue backdrop behind the subject, leaving nearby Pokemon
		# and the golden meteors readable even in a close camera shot.
		var points: Dictionary = effect.anchors.call()
		var subject: Vector3 = points.source if p < 0.43 else points.target
		var distance := camera.position.distance_to(subject)
		atmosphere.fog_mode = Environment.FOG_MODE_DEPTH
		atmosphere.fog_depth_begin = maxf(6.0, distance + 1.0)
		atmosphere.fog_depth_end = atmosphere.fog_depth_begin + 22.0
		atmosphere.fog_depth_curve = 0.85
		atmosphere.fog_density = 0.9 * weight
