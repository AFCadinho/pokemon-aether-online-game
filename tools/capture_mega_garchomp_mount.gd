extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const DIRECTIONS := ["down", "left", "right", "up"]
var riders: Array[Node2D] = []

func _init() -> void:
	capture.call_deferred()

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Pass an output directory after --.")
		quit(1)
		return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(1280,820)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(1280,820)
	background.color = Color("#101a29")
	background.z_index = -100
	view.add_child(background)
	add_label(view,"MEGA GARCHOMP",Vector2(28,18),30)
	add_label(view,"V7 in de game · echte avatarrenderer · beide spelersmodellen",Vector2(28,60),18)
	for gender_index in range(2):
		var gender := "male" if gender_index == 0 else "female"
		for row in range(4):
			var card := ColorRect.new()
			card.position = Vector2(20+row*315,105+gender_index*330)
			card.size = Vector2(295,310)
			card.color = Color("#223448")
			card.z_index = -90
			view.add_child(card)
			add_label(view,["Voor","Links","Rechts","Achter"][row]+(" / man" if gender_index == 0 else " / vrouw"),card.position+Vector2(14,10),18)
			var rider: Node2D = load("res://scripts/ui/mount_rider_preview.gd").new()
			rider.position = Vector2(168+row*315,351+gender_index*330)
			rider.scale = Vector2(2,2)
			view.add_child(rider)
			rider.set("base_look_position",Vector2(0,-16))
			var appearance := Appearance.get_default_appearance(gender)
			appearance["headgear"] = ""
			rider.call("configure","mega_garchomp",appearance,DIRECTIONS[row],true)
			rider.set("animation_enabled",false)
			riders.append(rider)
	for phase in range(4):
		for rider in riders:
			var mount := rider.get_node("Look/MountSprite") as AnimatedSprite2D
			assert(mount.sprite_frames.get_frame_count(mount.animation) == 4)
			mount.pause()
			mount.frame = phase
			rider.call("_on_mount_frame_changed")
			assert(mount.frame == phase)
			assert(rider.get_node("Look/MountForegroundSprite").frame == phase)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png(output.path_join("Godot_Frame_%d.png" % phase)) == OK)
	print("PASS: actual game renderer captured all 16 poses with both player models.")
	quit()

func add_label(parent: Node, value: String, pos: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("#e4edf9"))
	parent.add_child(label)
