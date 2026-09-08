extends SceneTree

const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const REMOTE_PLAYER_SCRIPT_PATH := "res://scripts/world/remote_player_avatar.gd"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world_script := load(WORLD_SCRIPT_PATH) as Script
	var avatar_script := load(REMOTE_PLAYER_SCRIPT_PATH) as Script
	var world: Node = world_script.new()
	var container := Node2D.new()
	world.remote_players_container = container
	for user_id: int in [30, 10, 20]:
		var avatar: Node = avatar_script.new()
		avatar.user_id = user_id
		container.add_child(avatar)

	world.remote_player_order_dirty = true
	world._sort_remote_player_avatar_nodes()
	_check(_user_ids(container) == [10, 20, 30], "dirty avatar order is sorted by user id")
	container.move_child(container.get_child(2), 0)
	world._sort_remote_player_avatar_nodes()
	_check(
		_user_ids(container) == [30, 10, 20],
		"movement-only updates skip sorting when roster order is clean"
	)
	world.remote_player_order_dirty = true
	world._sort_remote_player_avatar_nodes()
	_check(_user_ids(container) == [10, 20, 30], "a later roster change restores ordering")
	_check(not world.remote_player_order_dirty, "successful ordering clears the dirty marker")

	container.free()
	world.free()
	print("remote_player_ordering_performance_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _user_ids(container: Node) -> Array[int]:
	var user_ids: Array[int] = []
	for child: Node in container.get_children():
		user_ids.append(int(child.user_id))
	return user_ids


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
