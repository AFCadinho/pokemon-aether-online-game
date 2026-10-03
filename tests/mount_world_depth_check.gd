extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Depth := preload("res://scripts/world/mount_visual_depth.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
var failed := false

class DepthMap extends Node2D:
	var floor_z := -4096
	func get_actor_sort_z_floor_for_actor(_point: Vector2, _actor: Node) -> int:
		return floor_z


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := DepthMap.new()
	root.add_child(map)
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	game_state.current_map = map
	var local: Node2D = load("res://scenes/player.tscn").instantiate()
	local.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	local.set("depth_map", map)
	map.add_child(local)
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	map.add_child(remote)
	remote.set_process(false)
	for id: String in Mounts.get_mount_ids_for_mode("land") + Mounts.get_mount_ids_for_mode("surf"):
		local.set("active_mount_id", id)
		local.set("activity_style", "ride")
		local.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID)
		local.call("_sync_mount_visual")
		remote.call("apply_state", {"userId": 1, "gender": "female", "position": {"x": 128, "y": 212.5}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": id}})
		for actor: Node2D in [local, remote]:
			actor.position = Vector2(128, 212.5)
			actor.call("_update_sort_z")
			_check(actor.z_index == 212, "world depth uses the normal ground origin for " + id)
			var look := actor.get_node("Look") as Node2D
			_check_flat_world_depth(look, actor.z_index)
			_check(look.get_node("MountSprite").get_index() < look.get_node("Rider").get_index(), "mount back is behind rider")
			_check(look.get_node("Rider").get_index() < look.get_node("MountForegroundSprite").get_index(), "mount foreground stays ahead of all rider parts")
			var before := actor.z_index
			actor.call("_update_mount_hover", 0.6)
			actor.call("_update_sort_z")
			_check(actor.z_index == before, "hovering does not change map depth")
			var gear := look.get_node("Rider/FaceGearSprite") as CanvasItem
			Depth.set_layer_z(gear, 12)
			_check(gear.z_index == 0 and gear.get_index() > look.get_node("Rider/HeadgearSprite").get_index(), "directional facegear updates local order without changing world depth")
			Depth.set_layer_z(gear, 8)
		map.floor_z = 700
		for actor: Node2D in [local, remote]:
			actor.call("_update_sort_z")
			_check(actor.z_index == 700, "mount retains map-specific bridge/mountain depth floors")
		map.floor_z = -4096
	local.set("active_mount_id", "")
	local.call("_sync_mount_visual")
	remote.set("current_mount_id", "")
	remote.call("_sync_mount_visual")
	for actor: Node2D in [local, remote]:
		var look := actor.get_node("Look")
		_check(look.get_node("MountSprite").z_index == -1, "dismount restores original mount depth")
		_check(look.get_node("MountForegroundSprite").z_index == 10, "dismount restores foreground depth")
		_check(look.get_node("Rider/HairSprite").z_index == 6, "dismount restores appearance depth")
		_check(look.get_node("Rider/FaceGearSprite").z_index == 8, "dismount restores current directional facegear depth")
		_check(look.get_node("MountForegroundSprite").get_index() < look.get_node("Rider").get_index(), "dismount restores original scene order")
	_check(local.call("get_visual_sort_depth") == 10, "dismount invalidates visual-depth cache for NPC sorting")
	game_state.current_map = previous_map
	map.queue_free()
	await process_frame
	print("Mount world depth checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_flat_world_depth(node: Node, world_z: int) -> void:
	var item := node as CanvasItem
	if item != null and item.z_as_relative:
		_check(item.z_index == 0, "map objects cannot render between mounted layers: " + str(node.name))
		_check(world_z + item.z_index < world_z + 1, "object one pixel south covers every mount part")
		_check(world_z + item.z_index > world_z - 1, "object one pixel north stays behind every mount part")
	for child: Node in node.get_children():
		_check_flat_world_depth(child, world_z)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
