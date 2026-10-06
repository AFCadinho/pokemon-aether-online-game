extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const IDS := ["giratina_origin", "ho_oh", "yveltal", "miraidon", "reshiram"]
const DIRECTIONS := ["down", "left", "right", "up"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://land_mount_collection_preview"
	var shiny := "--shiny" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("193346")
	background.z_index = -10
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var previews: Array = []
	var script: Script = load("res://scripts/ui/mount_rider_preview.gd")
	for gi in range(2):
		var gender: String = ["male","female"][gi]
		for row in range(4):
			var label := Label.new()
			label.position = Vector2(18+row*320,14+gi*360)
			viewport.add_child(label)
			var actor: Variant = script.new()
			actor.position = Vector2(160+row*320,275+gi*350)
			actor.scale = Vector2(2,2)
			var tile := ReferenceRect.new()
			tile.position = actor.position - Vector2(32,32)
			tile.size = Vector2(64,64)
			tile.border_color = Color(0.4,0.8,0.9,0.4)
			tile.editor_only = false
			viewport.add_child(tile)
			viewport.add_child(actor)
			actor.base_look_position = Vector2(0,-16)
			actor.set_process(false)
			var appearance := Appearance.get_default_appearance(gender)
			appearance["gender"] = gender
			previews.append({"actor":actor,"label":label,"appearance":appearance,"gender":gender,"direction":DIRECTIONS[row]})
	for base_id: String in IDS:
		var id := base_id + ("_shiny" if shiny else "")
		for item: Dictionary in previews:
			item.actor.configure(id,item.appearance,item.direction,false)
			item.actor._update_mount_hover(0.0)
			item.label.text = id + " / " + item.gender + " / " + item.direction
		for moving: bool in [false,true]:
			for item: Dictionary in previews:
				item.actor._sync_mount_animation(moving,item.actor.last_direction)
				item.actor.mount_sprite.pause()
			for phase in range(4 if moving else 1):
				for item: Dictionary in previews:
					item.actor.mount_sprite.frame = phase
					item.actor._on_mount_frame_changed()
				await process_frame
				RenderingServer.force_draw(false)
				var pixels := viewport.get_texture().get_image()
				var error := pixels.save_png(output.path_join("%s_%s_%d.png" % [id,"walk" if moving else "idle",phase]))
				if error != OK:
					push_error("Cannot save mount preview")
					quit(1)
					return
	print("Land mount runtime previews saved to ",output)
	quit()
