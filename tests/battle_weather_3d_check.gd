extends Node
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Weather = preload("res://scripts/battle/battle_ui/weather_effect_3d.gd")
const Presentation = preload("res://scripts/battle/battle_weather_presentation.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SettingsManager.battle_presentation_mode = "3d"
	SettingsManager.weather_effects = true
	var stage := Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	stage.camera = Camera3D.new()
	stage.world.add_child(stage.camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.fog_enabled = false
	stage.world.add_child(environment)
	var original := environment.environment
	stage.active = true
	var presentation := Presentation.new()
	presentation.model_presenter = stage
	presentation.weather_tint = ColorRect.new()
	add_child(presentation.weather_tint)
	presentation.weather_particles = GPUParticles2D.new()
	add_child(presentation.weather_particles)
	for weather in ["RainDance", "SunnyDay", "Sandstorm", "Snowscape", "Hail", "PrimordialSea", "DesolateLand", "DeltaStream"]:
		presentation.update_weather(weather)
		var effect: Node = stage.weather_effect
		assert(is_instance_valid(effect) and effect.key == Weather.normalize(weather))
		assert(not presentation.weather_tint.visible and not presentation.weather_particles.emitting, "Native weather owns presentation without a 2D overlay")
		assert(effect.field.multimesh.instance_count <= 620, "Bounded particle budget")
		effect.set_process(false)
		effect._process(1.0)
		var elapsed: float = effect.elapsed
		var transform: Transform3D = effect.field.multimesh.get_instance_transform(0)
		var atmosphere: Environment = stage.camera.environment
		assert(atmosphere != original and atmosphere.fog_enabled)
		assert(environment.environment == original and not original.fog_enabled, "Arena resource remains untouched")
		stage.playback_speed = 0
		effect._process(1.0)
		assert(effect.elapsed == elapsed and effect.field.multimesh.get_instance_transform(0).is_equal_approx(transform), "Replay pause freezes weather")
		stage.camera.rotation.y += 1.0
		effect._process(0.0)
		assert(effect.field.multimesh.get_instance_transform(0).is_equal_approx(transform), "Camera orbit does not drag weather around the Pokemon")
		stage.playback_speed = 2
		effect._process(0.25)
		assert(is_equal_approx(effect.elapsed, elapsed + 0.5), "Replay speed controls weather")
		stage.playback_speed = 1
		presentation.update_weather(weather)
		assert(stage.weather_effect == effect, "Repeated field snapshots do not restart particles")
		presentation.update_weather("")
		assert(stage.weather_effect == null and stage.camera.environment == null and effect.stopped, "Weather ending restores the camera atmosphere immediately")
		await get_tree().process_frame
	# Settings, 2D fallback and reactivation keep the announced weather.
	presentation.update_weather("RainDance")
	SettingsManager.weather_effects = false
	presentation.animate(0.0)
	assert(stage.weather_effect == null and not presentation.weather_particles.emitting)
	SettingsManager.weather_effects = true
	presentation.animate(0.0)
	assert(is_instance_valid(stage.weather_effect))
	stage._set_active(false)
	presentation.animate(0.0)
	assert(stage.weather_effect == null and presentation.weather_particles.emitting and presentation.weather_tint.visible)
	stage._set_active(true)
	presentation.animate(0.0)
	assert(is_instance_valid(stage.weather_effect) and not presentation.weather_particles.emitting)
	SettingsManager.battle_presentation_mode = "2.5d"
	stage._sync_weather()
	presentation.animate(0.0)
	assert(stage.weather_effect == null and presentation.weather_particles.emitting, "2.5D retains its screen-space weather")
	SettingsManager.battle_presentation_mode = "3d"
	stage._sync_weather()
	presentation.animate(0.0)
	stage.set_double_mode(true)
	assert(stage.weather_effect == null, "Changing battle layout releases the old weather")
	stage._set_active(true)
	presentation.animate(0.0)
	assert(stage.weather_effect.key == "rain", "Co-op uses the same field weather")
	# Preserve an existing camera override, including while changing weather.
	presentation.update_weather("")
	stage.camera.environment = original
	presentation.update_weather("Delta Stream")
	presentation.update_weather("Desolate Land")
	stage._set_active(false)
	assert(stage.camera.environment == original)
	presentation.weather_particles.queue_free()
	presentation.weather_tint.queue_free()
	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_WEATHER_3D_OK conditions=8 pause=true fallback=true settings=true cleanup=true")
	get_tree().quit()
