extends Button

# Screen-space feedback keeps the hit target stable while the ring animates.
var feedback_state := ""
var time_fraction := 1.0
var state_elapsed := 0.0
var _last_pop_font_size := -1
var hint: Label


func _ready() -> void:
	hint = Label.new()
	hint.name = "FishingHint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-68, 56)
	hint.size = Vector2(180, 24)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color.WHITE)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.05, 0.09, 0.94)
	background.set_corner_radius_all(6)
	background.content_margin_top = 3
	background.content_margin_bottom = 3
	hint.add_theme_stylebox_override("normal", background)
	add_child(hint)


func update_feedback(state: String, remaining: float, duration: float, caption: String) -> void:
	if feedback_state != state:
		feedback_state = state
		state_elapsed = 0.0
		_last_pop_font_size = -1
	time_fraction = clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)
	if hint != null:
		hint.text = caption
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	state_elapsed += delta
	if feedback_state in ["cast", "waiting"]:
		text = ".".repeat(1 + int(state_elapsed * 2.0) % 3)
	elif feedback_state == "bite":
		var pop_size := 20 + roundi(6.0 * sin(minf(state_elapsed / 0.18, 1.0) * PI))
		if pop_size != _last_pop_font_size:
			_last_pop_font_size = pop_size
			add_theme_font_size_override("font_size", pop_size)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if feedback_state == "bite":
		var pop := maxf(1.0 - state_elapsed / 0.18, 0.0)
		var radius := 28.0 + sin(pop * PI * 0.5) * 5.0
		draw_arc(center, radius, 0, TAU, 64, Color(0.04, 0.08, 0.12, 0.95), 5.0, true)
		if time_fraction > 0.0:
			draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * time_fraction, 64, Color(1.0, 0.91, 0.35), 3.0, true)
	elif feedback_state == "reel_success":
		draw_polyline(PackedVector2Array([center + Vector2(-10, 0), center + Vector2(-3, 7), center + Vector2(11, -8)]), Color(0.02, 0.16, 0.06), 3.0, true)
