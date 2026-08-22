extends SceneTree

const WORLD_INTERACTABLE_SCRIPT := preload("res://scripts/world/interactables/world_interactable.gd")

class TestPlayer extends CharacterBody2D:
	var last_direction := Vector2.RIGHT

	func get_feet_position() -> Vector2:
		return global_position

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_root := Node2D.new()
	root.add_child(test_root)

	var item := WORLD_INTERACTABLE_SCRIPT.new()
	item.name = "OverworldItem"
	item.position = Vector2(80, 80)
	test_root.add_child(item)

	var player := TestPlayer.new()
	player.name = "Player"
	player.position = Vector2(48, 80)
	var player_shape := CollisionShape2D.new()
	var player_rectangle := RectangleShape2D.new()
	player_rectangle.size = Vector2(32, 32)
	player_shape.shape = player_rectangle
	player.add_child(player_shape)
	test_root.add_child(player)

	await physics_frame
	await physics_frame

	_check(item.player_nearby, "an adjacent player enters the overworld item interaction area")
	_check(item.nearby_player == player, "the overworld item tracks the adjacent local player")
	_check(item._is_player_facing_interactable(player), "the adjacent player can face the overworld item")

	test_root.queue_free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
