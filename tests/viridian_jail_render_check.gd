# Native render regression; run with a display (not --headless).
extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const CASES := [
	["rear_outside", "JailBack", Vector2(1584, 1200), true],
	["rear_inside_edge", "JailBack", Vector2(1584, 1232), false],
	["rear_inside", "JailBack", Vector2(1584, 1264), false],
	["front_inside", "JailFront", Vector2(1584, 1424), true],
	["front_outside", "JailFront", Vector2(1584, 1456), false],
]
const OUTPUT := "user://viridian-jail-boundary-render"
var failed := false
var comparisons := 0
var discriminating := 0
var viewport: SubViewport
var visual: Node2D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Jail render check needs a display driver")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 448)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	visual = load("res://generated/tiled_visuals/viridian_city/viridian_city.visual.tscn").instantiate()
	viewport.add_child(visual)
	viewport.canvas_transform.origin = -Vector2(44 * 32, 33 * 32)
	var world: Node = load("res://scripts/world/world.gd").new()
	world.call("_normalize_map_depth_layer_z_indices", visual)
	world.free()
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	game_state.current_map = visual
	for remote in [false, true]:
		var actor: Node2D
		if remote:
			actor = load("res://scripts/world/remote_player_avatar.gd").new()
		else:
			actor = load("res://scenes/player.tscn").instantiate()
			actor.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
			actor.get_node("Camera2D").enabled = false
			actor.set("depth_map", visual)
		visual.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		for mount_id in ["", "zekrom", "rayquaza"]:
			print("JAIL_RENDER_START remote=%s mount=%s" % [remote, mount_id])
			for facing in ["down", "up", "left", "right"]:
				for sample: Array in CASES:
					for frame in [0, 2]:
						_configure_actor(actor, remote, mount_id, facing, sample[2], frame)
						var wall := visual.get_node(sample[1] + "DepthGroups").get_child(0) as TileMapLayer
						var normal_z := wall.z_index
						var rect := wall.get_used_rect()
						var crop := Rect2i(rect.position * 32 + Vector2i(viewport.canvas_transform.origin), rect.size * 32)
						var actual := await _capture()
						# Independent reference: force the complete wall in front of or
						# behind the actor according to the labelled scene, not group math.
						wall.z_index = actor.z_index + (100 if sample[3] else -100)
						var expected := await _capture()
						wall.z_index = actor.z_index + (-100 if sample[3] else 100)
						var reversed := await _capture()
						wall.z_index = normal_z
						comparisons += 1
						var key := "%s_%s_%s_%s_%d" % ["remote" if remote else "local", "foot" if mount_id == "" else mount_id, facing, sample[0], frame]
						if actual.get_region(crop).get_data() != expected.get_region(crop).get_data():
							failed = true
							push_error("Jail occlusion differs: " + key)
							actual.save_png(OUTPUT + "/" + key + "_actual.png")
							expected.save_png(OUTPUT + "/" + key + "_expected.png")
						if expected.get_region(crop).get_data() != reversed.get_region(crop).get_data():
							discriminating += 1
						else:
							failed = true
							push_error("Jail render sample has no visible wall/actor overlap: " + key)
						if facing == "down" and frame == 0:
							actual.save_png(OUTPUT + "/" + key + ".png")
		actor.free()
	game_state.current_map = previous_map
	viewport.free()
	print("JAIL_RENDER comparisons=%d visible_occlusion_cases=%d %s" % [comparisons, discriminating, "FAIL" if failed else "PASS"])
	print("Jail render evidence: ", ProjectSettings.globalize_path(OUTPUT))
	quit(1 if failed else 0)


func _configure_actor(actor: Node2D, remote: bool, mount_id: String, facing: String, point: Vector2, frame: int) -> void:
	var direction: Vector2 = {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[facing]
	if remote:
		actor.call("apply_state", {"userId": 1, "gender": "male", "facingDirection": facing,
			"position": {"x": point.x, "y": point.y},
			"movement": {"isMoving": false, "activityStyle": "ride" if mount_id != "" else "walk", "mountId": mount_id}})
	else:
		actor.set("active_mount_id", mount_id)
		actor.set("activity_style", "ride" if mount_id != "" else "walk")
		actor.set("last_direction", direction)
		actor.call("_apply_body_appearance", Appearance.DEFAULT_MALE_BODY_ID)
		actor.call("_sync_mount_visual")
	actor.position = point
	actor.get_node("Look").show()
	actor.call("_update_sort_z")
	_pose(actor.get_node("Look"), "walk_" + facing, frame)
	actor.call("_sync_mount_rider_delta")
	actor.call("_update_mount_hover", 0.3 if frame == 2 else 0.0)
	for child: Node in actor.get_children():
		if child is CanvasItem and child.name != "Look":
			child.hide()


func _pose(node: Node, animation: String, frame: int) -> void:
	if node is AnimatedSprite2D and node.sprite_frames != null:
		if node.sprite_frames.has_animation(animation):
			node.animation = animation
			node.pause()
			node.frame = mini(frame, node.sprite_frames.get_frame_count(animation) - 1)
	for child: Node in node.get_children():
		_pose(child, animation, frame)


func _capture() -> Image:
	await process_frame
	viewport.canvas_transform = Transform2D(0.0, -Vector2(44 * 32, 33 * 32))
	RenderingServer.force_draw(true, 0.0)
	return viewport.get_texture().get_image()
