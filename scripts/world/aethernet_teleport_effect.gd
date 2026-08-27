extends Node2D

class_name AethernetTeleportEffect

signal finished

const TELEPORT_TEXTURE: Texture2D = preload(
	"res://assets/battles/animations/teleport/PRAS- Teleport.png"
)
const DURATION_SECONDS := 0.82
const AETHER_PURPLE := Color(0.69, 0.25, 1.0)
const AETHER_BLUE := Color(0.34, 0.78, 1.0)

var _target: CanvasItem
var _phase := "depart"
var _elapsed := 0.0
var _target_base_modulate := Color.WHITE
var _streak: Sprite2D
var _completed := false


func start(target: CanvasItem, phase: String, play_sound := false) -> void:
	_target = target
	_phase = "arrive" if phase == "arrive" else "depart"
	_target_base_modulate = target.modulate if target != null else Color.WHITE
	if _phase == "arrive":
		_target_base_modulate.a = 1.0
	z_as_relative = false
	_create_streak()
	if _phase == "arrive":
		_set_target_alpha(0.0)
	if play_sound:
		var sfx_manager := get_node_or_null("/root/SfxManager")
		if sfx_manager != null and sfx_manager.has_method("play"):
			sfx_manager.call("play", "aethernet_teleport", -2.0, 0.9)
	set_process(true)
	queue_redraw()


func cancel_and_restore() -> void:
	_restore_target()
	_completed = true
	queue_free()


func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, DURATION_SECONDS)
	var progress := _elapsed / DURATION_SECONDS
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position
		z_index = clampi(int(_target.global_position.y) + 2, -4096, 4096)
	_apply_target_fade(progress)
	_update_streak(progress)
	queue_redraw()
	if progress >= 1.0:
		_complete()


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION_SECONDS, 0.0, 1.0)
	var pulse := sin(progress * PI)
	var reverse_progress := 1.0 - progress if _phase == "arrive" else progress
	var ring_radius := lerpf(9.0, 35.0, reverse_progress)
	var ring_alpha := 0.72 * pulse
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 40, Color(AETHER_PURPLE, ring_alpha), 2.2)
	draw_arc(Vector2(0.0, -23.0), 13.0 + 7.0 * pulse, 0.0, TAU, 32, Color(AETHER_BLUE, 0.42 * pulse), 1.4)
	for index in 10:
		var angle := float(index) * TAU / 10.0 + progress * 1.8
		var distance := lerpf(7.0, 31.0, fposmod(reverse_progress + float(index) * 0.083, 1.0))
		var point := Vector2(cos(angle) * distance, -28.0 + sin(angle) * distance * 0.72)
		var spark_color := AETHER_PURPLE.lerp(AETHER_BLUE, float(index % 3) / 2.0)
		draw_circle(point, 1.2 + 1.8 * pulse, Color(spark_color, 0.78 * pulse))


func _create_streak() -> void:
	_streak = Sprite2D.new()
	_streak.texture = TELEPORT_TEXTURE
	_streak.hframes = 2
	_streak.centered = true
	_streak.position = Vector2(0.0, -31.0)
	_streak.scale = Vector2(0.48, 0.48)
	_streak.material = CanvasItemMaterial.new()
	(_streak.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(_streak)


func _apply_target_fade(progress: float) -> void:
	if _phase == "arrive":
		_set_target_alpha(smoothstep(0.08, 0.66, progress))
	else:
		_set_target_alpha(1.0 - smoothstep(0.28, 0.88, progress))


func _update_streak(progress: float) -> void:
	if _streak == null:
		return
	_streak.frame = int(floor(progress * 12.0)) % 2
	var pulse := sin(progress * PI)
	_streak.modulate = Color(AETHER_PURPLE.lerp(AETHER_BLUE, progress * 0.35), 0.82 * pulse)
	var width := lerpf(0.34, 0.62, pulse)
	_streak.scale = Vector2(width, lerpf(0.38, 0.58, pulse))


func _set_target_alpha(alpha: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var next_modulate := _target_base_modulate
	next_modulate.a = _target_base_modulate.a * clampf(alpha, 0.0, 1.0)
	_target.modulate = next_modulate


func _restore_target() -> void:
	if _target != null and is_instance_valid(_target):
		_target.modulate = _target_base_modulate


func _complete() -> void:
	if _completed:
		return
	_completed = true
	if _phase == "arrive":
		_restore_target()
	finished.emit()
	queue_free()
