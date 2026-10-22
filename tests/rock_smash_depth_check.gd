extends SceneTree

class DepthMap extends Node2D:
	var actor_floor := -4096
	func get_actor_sort_z_floor(_point: Vector2) -> int:
		return actor_floor

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := DepthMap.new()
	map.position = Vector2(0, 96)
	root.add_child(map)
	var entities := Node2D.new()
	entities.z_index = 5
	map.add_child(entities)
	var rock = load("res://scenes/world/interactables/daily_smashable_rock.tscn").instantiate()
	rock.rock_id = "depth_fixture"
	rock.position = Vector2(48, 80)
	entities.add_child(rock)
	_check(rock.z_index == 176 and not rock.z_as_relative, "Rock uses world feet depth above ground details without adding parent Z")
	map.actor_floor = 2300
	rock._update_sort_z()
	_check(rock.z_index == 2300, "Elevated mountain depth still wins over ordinary feet depth")
	map.actor_floor = -4096
	rock.position.y = 10000
	rock._update_sort_z()
	_check(rock.z_index == RenderingServer.CANVAS_ITEM_Z_MAX, "Large map depth stays within renderer limits")
	map.free()
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
	else:
		print("PASS " + message)
