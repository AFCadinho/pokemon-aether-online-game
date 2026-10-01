extends Node3D
## Lightweight deck spectator; each person cheers at their own pace.
var phase := 0.0
var elapsed := 0.0
var left_arm: Node3D
var right_arm: Node3D

func _process(delta: float) -> void:
	elapsed += delta
	var wave := sin(elapsed * 2.1 + phase)
	var cheer := smoothstep(-0.35, 0.65, sin(elapsed * 0.7 + phase))
	left_arm.rotation.z = -(0.35 + cheer * (1.85 + wave * 0.12))
	right_arm.rotation.z = 0.35 + cheer * (1.65 - wave * 0.18)
