extends Node2D

# One equipped Back item owns cape, hammer and sparks. The two existing cape
# planes provide world/mount depth sorting; this child never joins the body clock.
const PART_ID := "Thor_Hammer"
const NODE_NAME := "ThorAccessoryEffect"
const ASSET_ROOT := "res://assets/player/effects/thor"
const RISE_SECONDS := 0.16
const SETTLE_SECONDS := 0.30
var source: AnimatedSprite2D
var sheets: Array[Texture2D] = []
var sheet_images: Array[Image] = []
var billow := 0.0
var elapsed := 0.0
var moving := false
var pose := 0
var direction := 0
var column := 0
var overlay := false
var spark_points: Array[Vector2] = []
var last_cell := Vector3i(-1, -1, -1)


static func configure(sprite: AnimatedSprite2D, category: String, part_id: String, gender: String, movement: String) -> void:
	if category not in ["cape", "cape_overlay"]:
		return
	var effect := sprite.get_node_or_null(NODE_NAME)
	var enabled := part_id == PART_ID and movement in ["walk", "run"]
	if not enabled:
		if effect != null:
			sprite.remove_child(effect)
			effect.queue_free()
		sprite.self_modulate = Color.WHITE
		return
	if effect == null:
		effect = load("res://scripts/world/thor_accessory_effect.gd").new()
		effect.name = NODE_NAME
		sprite.add_child(effect)
	effect.setup(sprite, category, gender)


func setup(parent_sprite: AnimatedSprite2D, category: String, gender: String) -> void:
	source = parent_sprite
	overlay = category == "cape_overlay"
	sheets.clear()
	sheet_images.clear()
	for index: int in range(3):
		var texture := load("%s/%s/%s_%d.png" % [ASSET_ROOT, gender, category, index]) as Texture2D
		sheets.append(texture)
		sheet_images.append(texture.get_image())
	source.self_modulate = Color(1, 1, 1, 0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	last_cell = Vector3i(-1, -1, -1)
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if source == null or sheets.is_empty():
		return
	moving = str(source.animation).begins_with("walk_")
	billow = move_toward(billow, 1.0 if moving else 0.0, delta / (RISE_SECONDS if moving else SETTLE_SECONDS))
	pose = 2 if billow >= 0.72 else (1 if billow >= 0.18 else 0)
	var direction_name := str(source.animation).get_slice("_", 1)
	direction = maxi(0, ["down", "left", "right", "up"].find(direction_name))
	column = clampi(source.frame, 0, 3)
	elapsed = fmod(elapsed + delta, 60.0)
	# Honor future sprite offsets without moving the parent's mount depth plane.
	position = source.offset
	var cell_id := Vector3i(pose, direction, column)
	if cell_id != last_cell:
		last_cell = cell_id
		cache_spark_points()
	queue_redraw()


func cache_spark_points() -> void:
	spark_points.clear()
	var image := sheet_images[pose]
	var cell_size := image.get_width() / 4
	var half := cell_size / 2
	# Select only visible cloth/hammer edge pixels, not skin or face positions.
	for y: int in range(0, cell_size, 2):
		for x: int in range(0, cell_size, 2):
			var color := image.get_pixel(column * cell_size + x, direction * cell_size + y)
			if color.a == 0.0:
				continue
			if x > 0 and image.get_pixel(column * cell_size + x - 2, direction * cell_size + y).a > 0.0:
				continue
			spark_points.append(Vector2(x - half, y - half))


func _draw() -> void:
	if sheets.is_empty():
		return
	# Larger cloth cells keep the same body origin; extra space is transparent.
	var cell_size := sheets[pose].get_width() / 4
	var half := cell_size / 2
	draw_texture_rect_region(sheets[pose], Rect2(-half, -half, cell_size, cell_size), Rect2(column * cell_size, direction * cell_size, cell_size, cell_size))
	if spark_points.is_empty():
		return
	var tick := floori(elapsed * 12.0)
	# Quiet occasional sparks at rest; moving cloth has two short electric arcs.
	if not moving and billow < 0.18 and tick % 24 > 2:
		return
	var count := 2 if moving else 1
	for index: int in range(count):
		var point := spark_points[(tick * 7 + index * 11) % spark_points.size()]
		var outward := -2.0 if point.x < 0 else 2.0
		var a := point + Vector2(outward, 0)
		var b := a + Vector2(outward * 2, -2)
		var c := b + Vector2(-outward, -2)
		draw_line(a, Vector2(b.x, a.y), Color("177e98"), 4, false)
		draw_line(a, Vector2(b.x, a.y), Color("39d5e7"), 2, false)
		draw_line(Vector2(b.x, a.y), b, Color("39d5e7"), 2, false)
		draw_line(b, c, Color("d4fcff"), 2, false)
		var drift := Vector2(outward * (2 + tick % 3), -4 - tick % 3 * 2)
		draw_rect(Rect2(point + drift, Vector2(2, 2)), Color("83efff"))
