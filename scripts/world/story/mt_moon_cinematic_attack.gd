extends Node2D

class_name MtMoonCinematicAttack

const TYPE_COLORS := {
	"normal": Color("d8d5a4"),
	"fire": Color("ff7a3d"),
	"water": Color("67c9ff"),
	"electric": Color("facc15"),
	"grass": Color("a7e582"),
	"ice": Color("c4fffb"),
	"fighting": Color("ef6a5f"),
	"poison": Color("c084fc"),
	"ground": Color("f3d98b"),
	"flying": Color("c9b8ff"),
	"psychic": Color("ff8caf"),
	"bug": Color("d2e84a"),
	"rock": Color("e0ce65"),
	"ghost": Color("a58ad0"),
	"dragon": Color("9b74ff"),
	"dark": Color("a78b75"),
	"steel": Color("ddddf0"),
	"fairy": Color("f5b4d2"),
}

var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()
var source_position := Vector2.ZERO
var target_positions: Array[Vector2] = []
var attack_type := "normal"


func play(source: Vector2, targets: Array[Vector2], type_id: String) -> void:
	source_position = source
	target_positions = targets.duplicate()
	attack_type = type_id.strip_edges().to_lower()
	progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	queue_free()


func _draw() -> void:
	if target_positions.is_empty():
		return
	var color: Color = TYPE_COLORS.get(attack_type, TYPE_COLORS.normal)
	var visibility := sin(progress * PI)
	var glow := color
	glow.a = visibility * 0.72
	var core := Color.WHITE
	core.a = visibility * 0.9

	if attack_type == "psychic":
		_draw_future_sight(glow, core)
	elif attack_type == "water":
		_draw_hydro_cannon(glow, core)
	else:
		_draw_type_burst(glow, core)


func _draw_future_sight(glow: Color, core: Color) -> void:
	for target: Vector2 in target_positions:
		var radius := 44.0 - progress * 24.0
		for ring_index: int in range(3):
			draw_arc(target, radius + ring_index * 10.0, 0.0, TAU, 36, glow, 3.0)
		draw_line(source_position, target, glow, 5.0)
		draw_circle(target, 8.0 + sin(progress * PI) * 10.0, core)


func _draw_hydro_cannon(glow: Color, core: Color) -> void:
	for target: Vector2 in target_positions:
		var end := source_position.lerp(target, minf(progress * 1.8, 1.0))
		draw_line(source_position, end, glow, 18.0, true)
		draw_line(source_position, end, core, 6.0, true)
		if progress > 0.45:
			draw_circle(target, (progress - 0.45) * 54.0, glow)


func _draw_type_burst(glow: Color, core: Color) -> void:
	for target: Vector2 in target_positions:
		var end := source_position.lerp(target, minf(progress * 1.7, 1.0))
		draw_line(source_position, end, glow, 12.0, true)
		draw_line(source_position, end, core, 3.0, true)
		if progress > 0.5:
			for ray_index: int in range(8):
				var direction := Vector2.RIGHT.rotated(float(ray_index) * TAU / 8.0)
				draw_line(target, target + direction * 28.0 * progress, glow, 4.0)
