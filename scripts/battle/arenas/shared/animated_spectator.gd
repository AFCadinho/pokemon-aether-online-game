extends Node3D
## Shared Quaternius spectators alternate a rigged wave with a quiet idle.
const MODELS := [
	preload("res://assets/models/battle/ss_anne_audience/male_suit.glb"),
	preload("res://assets/models/battle/ss_anne_audience/female_formal.glb"),
	preload("res://assets/models/battle/ss_anne_audience/male_casual.glb"),
	preload("res://assets/models/battle/ss_anne_audience/female_casual.glb"),
]
var elapsed := 0.0
var animation_player: AnimationPlayer
var visibility_throttled := false
var on_screen := true
var animation_budget_time := 0.0
var animation_elapsed_delta := 0.0
func throttle_outside_camera(model_scale: float) -> void:
	visibility_throttled = true
	on_screen = false
	animation_player.active = false
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_budget_time = fmod(elapsed, 1.0 / 30.0)
	var notifier := VisibleOnScreenNotifier3D.new()
	# Conservative envelope includes the raised arms throughout Wave.
	notifier.aabb = AABB(Vector3(-1.2, -0.2, -1.2) * model_scale, Vector3(2.4, 3.8, 2.4) * model_scale)
	notifier.screen_entered.connect(func():
		on_screen = true
		animation_elapsed_delta = 0.0
		animation_budget_time = fmod(elapsed, 1.0 / 30.0)
		animation_player.active = true
		_update_animation()
		animation_player.seek(fmod(elapsed, animation_player.current_animation_length), true))
	notifier.screen_exited.connect(func():
		on_screen = false
		animation_player.active = false)
	add_child(notifier)

func configure(scene: PackedScene, phase: float, model_scale := 1.15) -> void:
	elapsed = phase
	var model := scene.instantiate() as Node3D
	model.name = "Character"
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	for accessory in model.find_children("Pistol", "MeshInstance3D", true, false):
		accessory.free()
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	animation_player = model.get_node("AnimationPlayer")
	# Each person owns loop flags and playback; source resources stay untouched.
	var library := AnimationLibrary.new()
	for animation_name in ["Idle_Neutral", "Wave"]:
		var animation: Animation = animation_player.get_animation(animation_name).duplicate()
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(animation_name, animation)
	animation_player.remove_animation_library("")
	animation_player.add_animation_library("", library)
	_update_animation()
	animation_player.seek(fmod(phase, animation_player.current_animation_length), true)

func _process(delta: float) -> void:
	elapsed += delta
	if not visibility_throttled or on_screen:
		_update_animation()
	if visibility_throttled and on_screen:
		# Distant stadium supporters animate at 30 Hz, staggered by their phases.
		animation_budget_time += delta
		animation_elapsed_delta += delta
		if animation_budget_time >= 1.0 / 30.0:
			animation_player.advance(animation_elapsed_delta)
			animation_elapsed_delta = 0.0
			animation_budget_time = fmod(animation_budget_time, 1.0 / 30.0)

func _update_animation() -> void:
	var next := "Wave" if fmod(elapsed, 7.0) < 3.2 else "Idle_Neutral"
	if animation_player.current_animation != next:
		animation_player.play(next, 0.25)
