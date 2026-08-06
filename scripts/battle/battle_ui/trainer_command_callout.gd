extends Control

class_name TrainerCommandCallout

const DISPLAY_SECONDS := 1.45
const FADE_IN_SECONDS := 0.12
const FADE_OUT_SECONDS := 0.18
const BUBBLE_SIZE := Vector2(214.0, 56.0)
const BUBBLE_FILL := Color(0.025, 0.055, 0.09, 0.96)
const BUBBLE_BORDER := Color(0.12, 0.72, 1.0, 1.0)

@onready var panel: PanelContainer = $Panel
@onready var message_label: Label = $Panel/MarginContainer/MessageLabel

var active_tween: Tween
var points_right := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(BUBBLE_SIZE.x * 0.5, BUBBLE_SIZE.y * 0.5)
	_apply_panel_style()
	clear_command()


func show_command(message: String, trainer_faces_left: bool) -> void:
	var cleaned_message := message.strip_edges()
	if cleaned_message == "":
		clear_command()
		return

	points_right = trainer_faces_left
	# Keep commands over the trainer who gives them, outside the space occupied
	# by the active Pokemon. The opponent variant sits against the right edge;
	# the local variant stays between the party rail and the player's Pokemon.
	position = Vector2(-107.0, -154.0) if points_right else Vector2(-55.0, -158.0)
	message_label.text = cleaned_message
	message_label.add_theme_font_size_override("font_size", 14 if cleaned_message.length() > 42 else 16)
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.94, 0.94)
	queue_redraw()

	_kill_active_tween()
	active_tween = create_tween()
	active_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)
	active_tween.parallel().tween_property(self, "scale", Vector2.ONE, FADE_IN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_interval(DISPLAY_SECONDS)
	active_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS)
	active_tween.tween_callback(_finish_hiding)


func clear_command() -> void:
	_kill_active_tween()
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	if message_label != null:
		message_label.text = ""


func _draw() -> void:
	var tail_points := PackedVector2Array([
		Vector2(95.0, 54.0),
		Vector2(119.0, 54.0),
		Vector2(107.0, 72.0),
	]) if points_right else PackedVector2Array([
		Vector2(43.0, 54.0),
		Vector2(67.0, 54.0),
		Vector2(55.0, 72.0),
	])
	draw_colored_polygon(tail_points, BUBBLE_FILL)
	draw_polyline(PackedVector2Array([
		tail_points[0],
		tail_points[2],
		tail_points[1],
	]), BUBBLE_BORDER, 2.0, true)


func _apply_panel_style() -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = BUBBLE_FILL
	style.border_color = BUBBLE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)


func _kill_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	active_tween = null


func _finish_hiding() -> void:
	visible = false
	active_tween = null
