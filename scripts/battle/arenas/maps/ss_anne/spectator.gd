extends Node3D
## Quaternius passengers alternate a rigged wave with a quiet idle.
var elapsed := 0.0
var animation_player: AnimationPlayer

func configure(scene: PackedScene, phase: float) -> void:
	elapsed = phase
	var model := scene.instantiate() as Node3D
	model.name = "Character"
	model.scale = Vector3.ONE * 1.15
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
	_update_animation()

func _update_animation() -> void:
	var next := "Wave" if fmod(elapsed, 7.0) < 3.2 else "Idle_Neutral"
	if animation_player.current_animation != next:
		animation_player.play(next, 0.25)
