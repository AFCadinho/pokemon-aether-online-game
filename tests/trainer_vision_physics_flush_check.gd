extends SceneTree

var failures := 0
var callback_seen := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var trainer: Variant = load("res://tests/fixtures/trainer_vision_probe.gd").new()
	var look := Node2D.new()
	look.name = "Look"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	look.add_child(sprite)
	trainer.add_child(look)
	var feet := Marker2D.new()
	feet.name = "FeetMarker"
	trainer.add_child(feet)
	var interaction := Area2D.new()
	interaction.name = "InteractionArea"
	trainer.add_child(interaction)
	var vision := Area2D.new()
	vision.name = "VisionArea"
	vision.monitoring = false
	trainer.add_child(vision)
	var sensor := CollisionShape2D.new()
	sensor.name = "CollisionShape2D"
	sensor.shape = RectangleShape2D.new()
	vision.add_child(sensor)
	root.add_child(trainer)
	trainer.trainer_progress_loaded = true
	trainer.trainer_progress_state = trainer.STATE_FIRST_ENCOUNTER

	var exit_area := Area2D.new()
	exit_area.position = Vector2(200, 200)
	var exit_shape := CollisionShape2D.new()
	exit_shape.shape = RectangleShape2D.new()
	exit_area.add_child(exit_shape)
	exit_area.body_entered.connect(func(_body: Node2D) -> void:
		callback_seen = true
		trainer.sight_range_tiles = 0
		trainer._update_directional_sensors()
		_check(not sensor.disabled, "Sensor changes wait until the physics callback finishes")
	)
	root.add_child(exit_area)
	var body := StaticBody2D.new()
	body.position = exit_area.position
	var body_shape := CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	body.add_child(body_shape)
	root.add_child(body)
	for frame in range(10):
		await physics_frame
		await process_frame
		if callback_seen and sensor.disabled:
			break
	_check(callback_seen and sensor.disabled, "A real body_entered callback safely disables trainer vision")
	trainer.sight_range_tiles = 3
	trainer.facing_direction = Vector2.RIGHT
	trainer._update_directional_sensors()
	await process_frame
	_check(not sensor.disabled, "Active trainers retain their vision after deferred updates")
	_check(sensor.position == Vector2(64, 0) and sensor.shape.size == Vector2(96, 32), "Deferred vision follows the new facing direction and sight range")
	body.queue_free()
	exit_area.queue_free()
	trainer.queue_free()
	await process_frame
	if failures == 0:
		print("trainer_vision_physics_flush_check: PASS")
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
