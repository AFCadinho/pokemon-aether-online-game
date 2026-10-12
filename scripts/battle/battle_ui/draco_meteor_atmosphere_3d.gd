extends RefCounted
## Temporary camera-local move lighting, owned by the native move lifetime.
## The arena, world clock and weather resources are never recoloured in place.
const BLUE := Color("081f68")
const ORBS := {
	"shadowball": {"tint":Color("8543c9"), "flash":Color("b67ce8"), "brightness":0.92, "energy":1.4},
	"focusblast": {"tint":Color("75bfff"), "flash":Color("fff0bd"), "brightness":1.0, "energy":1.8},
	"moonblast": {"tint":Color("a6baff"), "flash":Color("ffe0f2"), "brightness":1.02, "energy":1.5},
}
const LIVE_PROPERTIES := [
	"background_mode", "background_color", "background_energy_multiplier", "sky",
	"ambient_light_color", "ambient_light_energy", "ambient_light_source",
	"ambient_light_sky_contribution", "reflected_light_source",
	"fog_enabled", "fog_mode", "fog_light_color", "fog_light_energy", "fog_density",
	"fog_sky_affect", "fog_sun_scatter", "fog_aerial_perspective", "fog_height",
	"fog_height_density", "fog_depth_begin", "fog_depth_end", "fog_depth_curve",
	"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation", "adjustment_color_correction",
]
var effect: Node
var camera: Camera3D
var original: Environment
var source: Environment
var atmosphere: Environment
var strength := 0.0
var pulse := 0.0
var orb_light: OmniLight3D

func supports(key: String) -> bool:
	return key == "dracometeor" or ORBS.has(key)

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
	pulse = 0.0
	if is_instance_valid(orb_light):
		orb_light.hide()
		orb_light.queue_free()
	orb_light = null

func apply(stage: Node) -> void:
	if not stage.active or stage._is_hybrid_presentation() or not is_instance_valid(stage.camera) or not is_instance_valid(stage.world):
		suspend()
		return
	if not is_instance_valid(effect) or effect.done or not effect.clock.is_valid() or not effect.valid.is_valid() or not effect.valid.call():
		suspend()
		return
	var seconds := float(effect.clock.call())
	var p := clampf(seconds / effect.duration, 0.0, 1.0)
	var weight := smoothstep(0.0, 0.22, p) * (1.0 - smoothstep(0.86, 1.0, p))
	if ORBS.has(effect.key):
		var charge := smoothstep(effect.effect_start, maxf(effect.launch, effect.effect_start + 0.01), seconds)
		weight = charge * (1.0 - smoothstep(effect.impact, effect.duration, seconds))
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
	if ORBS.has(effect.key):
		_apply_orb(stage, seconds, weight)
		return
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

func _apply_orb(stage: Node, seconds: float, weight: float) -> void:
	var profile: Dictionary = ORBS[effect.key]
	var after: float = (seconds - effect.impact) / maxf(effect.duration, 0.01)
	# One soft pulse on a confirmed hit. Misses and blocked impacts only recover.
	pulse = smoothstep(0.0, 0.025, after) * (1.0 - smoothstep(0.025, 0.14, after)) if effect.hit else 0.0
	var tint: Color = profile.tint
	var flash: Color = profile.flash
	var lighting := tint.lerp(flash, pulse)
	atmosphere.ambient_light_color = source.ambient_light_color.lerp(lighting, weight * 0.25)
	atmosphere.ambient_light_sky_contribution = source.ambient_light_sky_contribution * (1.0 - weight * 0.25)
	atmosphere.ambient_light_energy = source.ambient_light_energy * lerpf(1.0, float(profile.brightness), weight)
	atmosphere.background_color = source.background_color.lerp(tint, weight * 0.12)
	if source.fog_enabled:
		atmosphere.fog_light_color = source.fog_light_color.lerp(lighting, weight * 0.16)
	# Keep the sky and fog shape intact; only Draco owns a full arena backdrop.
	atmosphere.adjustment_enabled = true
	if not source.adjustment_enabled:
		atmosphere.adjustment_contrast = 1.0
		atmosphere.adjustment_saturation = 1.0
		atmosphere.adjustment_color_correction = null
	var brightness := source.adjustment_brightness if source.adjustment_enabled else 1.0
	atmosphere.adjustment_brightness = brightness * (lerpf(1.0, float(profile.brightness), weight) + pulse * 0.035)
	if not is_instance_valid(orb_light):
		orb_light = OmniLight3D.new()
		orb_light.name = "MoveOrbGlow"
		orb_light.set_meta("battle_field_visual", true)
		orb_light.shadow_enabled = false
		stage.world.add_child(orb_light)
	var points: Dictionary = effect.anchors.call()
	var origin: Vector3 = effect.launch_origin if effect.launched else points.source
	var flight := clampf((seconds - effect.launch) / maxf(effect.impact - effect.launch, 0.01), 0.0, 1.0)
	orb_light.position = origin.lerp(points.target, flight)
	orb_light.light_color = lighting
	var local_weight := weight if seconds < effect.impact else pulse
	orb_light.light_energy = float(profile.energy) * local_weight
	orb_light.omni_range = clampf(3.0 * effect.emission_scale, 2.5, 5.0) + pulse
	orb_light.omni_attenuation = 1.5
