extends SceneTree

const WORLD_PATH := "res://scripts/world/world.gd"
const REMOTE_AVATAR_PATH := "res://scripts/world/remote_player_avatar.gd"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"

var failures := 0


func _init() -> void:
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var remote_avatar_source := FileAccess.get_file_as_string(REMOTE_AVATAR_PATH)
	var player_scene_source := FileAccess.get_file_as_string(PLAYER_SCENE_PATH)

	_check(
		world_source.contains('active_map.get_node_or_null("Entities/Players")'),
		"remote players resolve the active map's player render branch"
	)
	_check(
		world_source.contains("target_parent.add_child(remote_players_container)"),
		"new remote-player containers start in the resolved map branch"
	)
	_check(
		world_source.contains("remote_players_container.reparent(target_parent, true)"),
		"existing remote-player containers follow map changes"
	)
	_check(
		world_source.contains("_ensure_remote_players_container(map)"),
		"moving the local player also aligns the remote-player render branch"
	)
	_check(
		world_source.contains("remote_players_container.reparent(self, true)"),
		"remote-player containers survive removal of the previous map"
	)
	_check(
		world_source.contains("remote_parent.move_child(remote_players_container, player.get_index())"),
		"the local player still wins exact player overlap ties"
	)
	_check(
		player_scene_source.contains("y_sort_enabled = true"),
		"the local player enables child y-sorting"
	)
	_check(
		remote_avatar_source.contains("\ty_sort_enabled = true"),
		"remote avatars mirror the local player's child y-sorting"
	)

	if failures == 0:
		print("Remote player render layer checks passed.")
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
