extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const DIRS := ["down", "left", "right", "up"]
var actors: Array = []
var viewport: SubViewport


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var preview_script: Script = load("res://scripts/ui/mount_rider_preview.gd")
	var output := "user://primal_kyogre_preview"
	var mount_id := "primal_kyogre_shiny" if "--shiny" in OS.get_cmdline_user_args() else "primal_kyogre"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--mount="):
			mount_id = arg.trim_prefix("--mount=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1536, 864)
	root.content_scale_size = root.size
	viewport = SubViewport.new()
	viewport.size = Vector2i(1536, 864)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("193346")
	background.size = Vector2(1536, 864)
	viewport.add_child(background)
	if "--water" in OS.get_cmdline_user_args():
		var water := TextureRect.new()
		var texture := AtlasTexture.new()
		texture.atlas = load("res://assets/tilesets/fiver/tiles_env2_water32.png")
		texture.region = Rect2(32, 32, 32, 32)
		water.texture = texture
		water.stretch_mode = TextureRect.STRETCH_TILE
		water.size = Vector2(768, 432)
		water.scale = Vector2(2, 2)
		viewport.add_child(water)
	for gender_index in range(2):
		var gender: String = ["male", "female"][gender_index]
		for row in range(4):
			var label := Label.new()
			label.text = gender + " / " + DIRS[row]
			label.position = Vector2(20+384*row, 16+432*gender_index)
			viewport.add_child(label)
			var actor: Variant = preview_script.new()
			actor.position = Vector2(192+384*row, 200+432*gender_index)
			var tile := ReferenceRect.new()
			tile.position = actor.position - Vector2(32, 32)
			tile.size = Vector2(64, 64)
			tile.border_color = Color(0.4, 0.8, 0.9, 0.5)
			tile.editor_only = false
			viewport.add_child(tile)
			if "--anchors" in OS.get_cmdline_user_args():
				tile.z_index = 4095
				tile.border_color = Color("ffcf55")
				for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN]:
					var cross := Line2D.new()
					cross.position = actor.position
					cross.points = PackedVector2Array([-axis * 8, axis * 8])
					cross.width = 2
					cross.default_color = Color("ffcf55")
					cross.z_index = 4095
					viewport.add_child(cross)
			actor.scale = Vector2(2, 2)
			viewport.add_child(actor)
			var appearance := Appearance.get_default_appearance(gender)
			appearance["gender"] = gender
			actor.configure(mount_id, appearance, DIRS[row], false)
			# Store fitting changes scale/origin; captures use exact world geometry.
			actor.position = Vector2(192+384*row, 200+432*gender_index)
			actor.scale = Vector2(2, 2)
			actor.base_look_position = Vector2(0, -16)
			actor.set_process(false)
			actor.look_node.position = Vector2(0, -16)
			if "--anchors" in OS.get_cmdline_user_args():
				var reference: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
				viewport.add_child(reference)
				var reference_position: Vector2 = actor.position - Vector2(128, 0)
				reference.call("apply_state", {
					"userId": 100 + row + 4 * gender_index, "gender": gender,
					"appearance": appearance,
					"position": {"x": reference_position.x, "y": reference_position.y},
					"movement": {"isMoving": false, "activityStyle": "walk", "mountId": ""}
				})
				reference.set("last_direction", actor.last_direction)
				reference.call("_update_animation", false)
				reference.scale = Vector2(2, 2)
				reference.set_process(false)
				var baseline := Line2D.new()
				baseline.points = PackedVector2Array([reference_position, actor.position])
				baseline.width = 1
				baseline.default_color = Color("ffcf55")
				baseline.z_index = 4095
				viewport.add_child(baseline)
			actors.append({"actor": actor, "appearance": appearance, "direction": DIRS[row]})
	print("Configured eight mount previews")
	for activity: String in ["idle", "ride", "surf-fish"]:
		for item: Dictionary in actors:
			var actor: Variant = item.actor
			actor.current_activity_style = "ride" if activity == "idle" else activity
			actor.current_body_movement_style = ""
			actor.current_appearance_signature = ""
			actor._apply_appearance_state(item.appearance)
			actor._sync_mount_visual()
			actor._update_animation(false)
			actor._sync_activity_layer_offsets()
		for phase in range(4 if activity == "ride" else 1):
			for item: Dictionary in actors:
				var actor: Variant = item.actor
				actor._sync_mount_animation(activity == "ride", actor.last_direction)
				actor.mount_sprite.pause()
				actor.mount_sprite.frame = phase
				actor._on_mount_frame_changed()
			await process_frame
			RenderingServer.force_draw(false)
			var capture := viewport.get_texture().get_image()
			capture.save_png(output.path_join("Godot_%s_%d.png" % [activity, phase]))
	print("Primal Kyogre runtime previews saved to ", output)
	quit()
