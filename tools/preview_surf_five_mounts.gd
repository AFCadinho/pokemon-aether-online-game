extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const Followers := preload("res://scripts/services/follower_sprite_service.gd")
const DIRS := ["down", "left", "right", "up"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://surf_five_previews"
	var mount_ids: Array[String] = ["wailmer", "drednaw", "mantine", "basculegion", "wailord"]
	var adinho_outfit := "--adinho" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mount="):
			mount_ids = [arg.trim_prefix("--mount=")]
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("193346")
	background.size = Vector2(viewport.size)
	background.z_index = -10
	viewport.add_child(background)
	var water := TextureRect.new()
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/tilesets/fiver/tiles_env2_water32.png")
	texture.region = Rect2(32, 32, 32, 32)
	water.texture = texture
	water.stretch_mode = TextureRect.STRETCH_TILE
	water.size = Vector2(viewport.size) / 2
	water.scale = Vector2(2, 2)
	water.z_index = -9
	viewport.add_child(water)
	if "--land-bg" in OS.get_cmdline_user_args():
		water.hide()
		background.color = Color("73985a")
	var script: Script = load("res://scripts/ui/mount_rider_preview.gd")
	var previews: Array = []
	for gi in range(2):
		var gender: String = ["male", "female"][gi]
		for row in range(4):
			var position := Vector2(160+row*320, 230+gi*360)
			var label := Label.new()
			label.position = Vector2(18+row*320, 14+gi*360)
			viewport.add_child(label)
			var tile := ReferenceRect.new()
			tile.position = position - Vector2(32, 32)
			tile.size = Vector2(64, 64)
			tile.border_color = Color(0.4, 0.8, 0.9, 0.4)
			tile.editor_only = false
			if "--anchors" in OS.get_cmdline_user_args():
				tile.z_index = 4095
				tile.border_color = Color("ffcf55")
				viewport.add_child(tile)
				var line := Line2D.new()
				line.points = PackedVector2Array([position-Vector2(120,0),position+Vector2(120,0)])
				line.default_color = Color("ffcf55")
				line.width = 1
				line.z_index = 4095
				viewport.add_child(line)
			else:
				tile.free()
			if "--poliwag" in OS.get_cmdline_user_args():
				# Same physical tile row and 32 world pixels away, as in the map.
				var neighbour := AnimatedSprite2D.new()
				neighbour.sprite_frames = Followers.get_sprite_frames("poliwag", false)
				neighbour.animation = &"idle_right" if DIRS[row] != "right" else &"idle_left"
				var side := 1 if DIRS[row] == "right" else -1
				neighbour.position = position + Vector2(side * 64, -32)
				neighbour.scale = Vector2(2, 2)
				viewport.add_child(neighbour)
			var actor: Variant = script.new()
			viewport.add_child(actor)
			actor.base_look_position = Vector2(0, -16)
			actor.set_process(false)
			var appearance := Appearance.get_default_appearance(gender)
			appearance["gender"] = gender
			if adinho_outfit and gender == "male":
				appearance.merge({"headgear": "", "hair": "Adinho_Hair", "facial_hair": "Adinho_Beard", "facegear": "Adinho_Glasses", "top": "Adinho_Shirt", "bottom": "Adinho_Trousers", "shoes": "Adinho_Shoes"}, true)
			previews.append({"actor": actor, "label": label, "appearance": appearance, "gender": gender, "direction": DIRS[row], "position": position})
	for base_id: String in mount_ids:
		var id := base_id + ("_shiny" if "--shiny" in OS.get_cmdline_user_args() else "")
		for activity: String in ["ride", "surf-fish"]:
			for item: Dictionary in previews:
				var actor: Variant = item.actor
				actor.configure(id, item.appearance, item.direction, false)
				if activity == "surf-fish":
					actor.current_activity_style = activity
					actor.current_body_movement_style = ""
					actor.current_appearance_signature = ""
					actor._apply_appearance_state(item.appearance)
					actor._sync_mount_visual()
					actor._update_animation(false)
					actor._sync_activity_layer_offsets()
				# configure() fits a Store viewport; restore exact world-scale placement.
				actor.position = item.position
				actor.scale = Vector2(2, 2)
				actor.look_node.position = Vector2(0, -16)
				item.label.text = id + " / " + item.gender + " / " + item.direction + " / " + activity
			for moving: bool in ([false, true] if activity == "ride" else [false]):
				for item: Dictionary in previews:
					item.actor._sync_mount_animation(moving, item.actor.last_direction)
					item.actor.mount_sprite.pause()
				var phase_count := 4 if moving else int(previews[0].actor.mount_sprite.sprite_frames.get_frame_count(previews[0].actor.mount_sprite.animation)) if "--idle-cycle" in OS.get_cmdline_user_args() and activity == "ride" else 1
				for phase in range(phase_count):
					for item: Dictionary in previews:
						item.actor.mount_sprite.frame = phase
						item.actor._on_mount_frame_changed()
					await process_frame
					RenderingServer.force_draw(false)
					var capture := viewport.get_texture().get_image()
					var result := capture.save_png(output.path_join("%s_%s_%s_%d.png" % [id, activity, "walk" if moving else "idle", phase]))
					if result != OK:
						push_error("Cannot save mount preview")
						quit(1)
						return
	print("Surf mount runtime previews saved to ", output)
	quit()
