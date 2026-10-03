extends Node2D

# Offline try-out using the actual multiplayer avatar renderer and ride assets.
const Preview := preload("res://scripts/ui/mount_rider_preview.gd")
var rider: Node2D
var direction := "down"
var gender := "male"
var mount_id := "mega_absol_z"
var animate := true
var camera: Camera2D

class TileGround extends Node2D:
	func _draw() -> void:
		for y in range(-64, 65):
			for x in range(-64, 65):
				var color := Color("293d3b") if (x + y) % 2 == 0 else Color("2b403e")
				draw_rect(Rect2(x * 32, y * 32, 32, 32), color)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("18232d"))
	var ground := TileGround.new()
	ground.z_index = -100
	add_child(ground)
	rider = Preview.new()
	add_child(rider)
	# Match the player's actual Look origin and gameplay foot line.
	rider.set("base_look_position", Vector2(0, -16))
	camera = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	add_child(camera)
	var hud := CanvasLayer.new()
	add_child(hud)
	var instructions := Label.new()
	instructions.position = Vector2(24, 20)
	instructions.text = "Mega Absol / Mega Absol Z — mount try-out\nWASD / arrows: move and turn  |  Space: animation on/off  |  G: male/female  |  M: change mount"
	instructions.add_theme_font_size_override("font_size", 22)
	hud.add_child(instructions)
	_configure()


func _configure() -> void:
	rider.call("configure", mount_id, {"gender": gender}, direction, animate)


func _process(delta: float) -> void:
	var movement := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	)
	if movement != Vector2.ZERO:
		var next_direction := "right" if movement.x > 0 else "left"
		if movement.y != 0:
			next_direction = "down" if movement.y > 0 else "up"
		if next_direction != direction:
			direction = next_direction
			_configure()
		rider.position += movement.normalized() * 100.0 * delta
		camera.position = rider.position


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.physical_keycode == KEY_SPACE:
		animate = not animate
		_configure()
	elif event.physical_keycode == KEY_G:
		gender = "female" if gender == "male" else "male"
		_configure()
	elif event.physical_keycode == KEY_M:
		mount_id = "mega_absol" if mount_id == "mega_absol_z" else "mega_absol_z"
		_configure()
