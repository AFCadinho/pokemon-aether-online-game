extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const DIRECTIONS := ["down", "left", "right", "up"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var output := "user://zekrom_turbo"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 680)
	root.content_scale_size = root.size
	var viewport := SubViewport.new()
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("344b42")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var actors: Array = []
	for variant in range(2):
		for dir in range(4):
			var label := Label.new()
			label.text = ("Shiny Zekrom" if variant else "Zekrom") + " · " + ["Voor", "Links", "Rechts", "Achter"][dir]
			label.position = Vector2(20 + dir * 320, 16 + variant * 320)
			viewport.add_child(label)
			var actor: Variant = load("res://scripts/ui/mount_rider_preview.gd").new()
			viewport.add_child(actor)
			actor.set_process(false)
			var appearance := Appearance.get_default_appearance("male")
			appearance.merge({"gender": "male", "headgear": "", "hair": "Adinho_Hair", "facial_hair": "Adinho_Beard", "facegear": "Adinho_Glasses", "top": "Adinho_Shirt", "bottom": "Adinho_Trousers", "shoes": "Adinho_Shoes"}, true)
			actor.configure("zekrom_shiny" if variant else "zekrom", appearance, DIRECTIONS[dir], false)
			actor.scale = Vector2(2, 2)
			actor.position = Vector2(160 + dir * 320, 235 + variant * 320)
			actor.base_look_position = Vector2(0, -16)
			actors.append(actor)
	var status := Label.new()
	status.position = Vector2(20, 648)
	viewport.add_child(status)
	for step in range(64):
		var moving := step >= 10 and step < 50
		status.text = "Bewegen · turbo aan" if moving else "Stilstaan · turbo uit"
		for actor: Variant in actors:
			actor._sync_mount_animation(moving, actor.last_direction)
			actor.mount_sprite.pause()
			actor.mount_sprite.frame = (step / 5) % 4 if moving else 0
			actor._on_mount_frame_changed()
			actor._update_mount_hover(0.05)
			actor.mount_turbo_effect.set_process(false)
			actor.mount_turbo_effect.advance(0.05)
		await create_timer(0.05).timeout
		RenderingServer.force_draw(false)
		var error := viewport.get_texture().get_image().save_png(output.path_join("turbo_%03d.png" % step))
		if error != OK:
			quit(1)
			return
	print("Zekrom turbo preview saved to ", output)
	quit()
