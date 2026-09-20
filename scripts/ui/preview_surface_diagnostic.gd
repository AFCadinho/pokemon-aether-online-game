extends Control
## Local debug-only surface isolation; never changes sprite assets or playback.
## F8: original / flat / grid / grid without sprite. Shift+F8: restore.

var mode := 0

static func attach(stage: Control, surface: SubViewportContainer) -> Control:
	if not OS.is_debug_build():
		return null
	var diagnostic := new()
	diagnostic.name = "PreviewSurfaceDiagnostic"
	diagnostic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(diagnostic)
	stage.move_child(diagnostic, surface.get_index())
	diagnostic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return diagnostic

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	if event.pressed and not event.echo and event.keycode == KEY_F8:
		set_mode(0 if event.shift_pressed else (mode + 1) % 4)

func set_mode(value: int) -> void:
	mode = clampi(value, 0, 3)
	# Grid-only covers every layer, including sprite, background and card badges.
	z_index = 100 if mode == 3 else 0
	queue_redraw()
	if is_inside_tree():
		print("Preview diagnostic: ", ["original", "flat + sprite", "grid + sprite", "grid only"][mode],
			" logical=", size, " screen_transform=", get_screen_transform(),
			" window=", get_window().size)

func _draw() -> void:
	if mode == 0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#566675"))
	if mode >= 2:
		for x in range(0, int(size.x), 16):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color("#b6c4ce"), 1.0)
		for y in range(0, int(size.y), 16):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color("#b6c4ce"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 4),
		["", "F8: flat", "F8: grid", "F8: grid only"][mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
