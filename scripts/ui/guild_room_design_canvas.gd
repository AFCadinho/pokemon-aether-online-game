extends Control

const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
var art_viewport: SubViewport
var zoom := 1.0
var pan := Vector2.ZERO
var dragging := false

static func build_art(room_key: String, items: Array) -> Node2D:
	var art := Node2D.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var visual: Node2D = load("res://generated/tiled_visuals/guild_base_%s/guild_base_%s.visual.tscn" % [room_key, room_key]).instantiate()
	art.add_child(visual)
	for item: Dictionary in items:
		if item.get("parentId") == null:
			art.add_child(Furniture.instantiate_placement(art, item, items, true))
	return art

func configure(room_key: String, items: Array) -> void:
	if is_instance_valid(art_viewport):
		remove_child(art_viewport)
		art_viewport.queue_free()
	art_viewport = SubViewport.new()
	art_viewport.size = Vector2i(736, 608)
	art_viewport.transparent_bg = false
	art_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	art_viewport.disable_3d = true
	add_child(art_viewport)
	art_viewport.add_child(build_art(room_key, items))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	reset_view()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _fit_scale() -> float:
	return minf(size.x / 544.0, size.y / 480.0)

func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func zoom_at(factor: float, anchor: Vector2) -> void:
	var previous := zoom
	zoom = clampf(zoom * factor, 1.0, 6.0)
	pan = (pan + size * 0.5 - anchor) * (zoom / previous) + anchor - size * 0.5
	_clamp_pan()
	queue_redraw()

func _clamp_pan() -> void:
	var extent := (Vector2(544, 480) * _fit_scale() * zoom - size) * 0.5
	pan.x = clampf(pan.x, -maxf(extent.x, 0), maxf(extent.x, 0))
	pan.y = clampf(pan.y, -maxf(extent.y, 0), maxf(extent.y, 0))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050b14"))
	if not is_instance_valid(art_viewport):
		return
	var draw_size := Vector2(544, 480) * _fit_scale() * zoom
	var rect := Rect2((size - draw_size) * 0.5 + pan, draw_size)
	draw_texture_rect_region(art_viewport.get_texture(), rect, Rect2(96, 32, 544, 480))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at(1.25, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at(0.8, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		_clamp_pan()
		queue_redraw()
		accept_event()
