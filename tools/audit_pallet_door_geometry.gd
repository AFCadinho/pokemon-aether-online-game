extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn") as PackedScene).instantiate()
	var collision := map.get_node("Collision") as TileMapLayer
	var actor := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var detection := actor.get_node("DetectionShape") as CollisionShape2D
	var actor_size: Vector2 = (detection.shape as RectangleShape2D).size
	var doors := {}
	var passed := true
	for name: String in ["ToPlayersHouse", "ToRivalsHouse", "ToOaksLab"]:
		var exit := map.get_node("Exits/" + name) as Area2D
		var shape := exit.get_node("CollisionShape2D") as CollisionShape2D
		var hint := exit.get_node("DoorTransitionHint") as Node2D
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		var trigger := Rect2(shape.global_position - size / 2, size)
		var actor_rect := Rect2(hint.global_position + detection.position - actor_size / 2, actor_size)
		var reachable := collision.get_cell_source_id(collision.local_to_map(hint.global_position)) == -1 and trigger.intersects(actor_rect)
		var connected := exit.is_connected("body_entered", Callable(exit, "_on_body_entered"))
		doors[name] = {
			"triggerCenter": [shape.global_position.x, shape.global_position.y],
			"triggerSize": [size.x, size.y],
			"doorTile": [hint.global_position.x, hint.global_position.y],
			"reachable": reachable, "signalConnected": connected,
			"feetInsideTrigger": exit.call("contains_world_position", hint.global_position),
		}
		passed = passed and reachable and connected
	print("PALLET_DOOR_GEOMETRY ", JSON.stringify(doors))
	actor.free()
	map.free()
	quit(0 if passed else 1)
