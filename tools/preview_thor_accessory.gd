extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const EFFECT := preload("res://scripts/world/thor_accessory_effect.gd")
var sprites: Array[AnimatedSprite2D] = []
var effects: Array[Node] = []
var caption: Label
var canvas: SubViewport

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1120, 560)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1120, 560)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	root.title = "PokeAether — Thor cape"
	var background := ColorRect.new()
	background.size = Vector2(1120, 560)
	background.color = Color("263746")
	canvas.add_child(background)
	caption = Label.new()
	caption.position = Vector2(24, 18)
	caption.add_theme_font_size_override("font_size", 22)
	canvas.add_child(caption)
	for g: int in range(2):
		var gender := "male" if g == 0 else "female"
		for d: int in range(4):
			var group := Node2D.new()
			group.position = Vector2(140 + d * 280, 145 + g * 240)
			group.scale = Vector2(3, 3)
			canvas.add_child(group)
			var parts := {"cape": "Thor_Hammer", "body": "Gen4_Base_v1" if g == 0 else "Gen4_Base_F_v1", "bottom": "Thor_Trousers", "shoes": "Thor_Shoes", "top": "Thor_Shirt", "cape_overlay": "Thor_Hammer", "hair": "Hair"}
			for category: String in parts:
				var sprite := AnimatedSprite2D.new()
				sprite.sprite_frames = APPEARANCE.get_body_frames(parts[category], gender) if category == "body" else APPEARANCE.get_part_frames(category, parts[category], gender)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.animation = StringName("idle_" + ["down", "left", "right", "up"][d])
				group.add_child(sprite)
				sprites.append(sprite)
				if category in ["cape", "cape_overlay"]:
					EFFECT.configure(sprite, category, "Thor_Hammer", gender, "walk")
					var effect := sprite.get_node(EFFECT.NODE_NAME)
					effect.set_process(false)
					effects.append(effect)
			var label := Label.new()
			label.text = gender.capitalize() + " · " + ["Voor", "Links", "Rechts", "Achter"][d]
			label.position = Vector2(80 + d * 280, 254 + g * 240)
			canvas.add_child(label)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "user://thor-preview"
	DirAccess.make_dir_recursive_absolute(output)
	for tick: int in range(48):
		var walking := tick >= 8 and tick < 32
		caption.text = "Thor · " + ("Lopen — cape waait naar achteren" if walking else ("Cape zakt terug" if tick >= 32 and tick < 36 else "Stilstaan — af en toe een vonk"))
		for sprite: AnimatedSprite2D in sprites:
			var suffix := str(sprite.animation).get_slice("_", 1)
			sprite.animation = StringName(("walk_" if walking else "idle_") + suffix)
			sprite.frame = (tick / 2) % 4 if walking else 0
		for effect: Node in effects:
			effect.advance(0.1)
		await process_frame
		RenderingServer.force_draw(false)
		var image := canvas.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Thor preview requires a rendering display.")
			quit(1)
			return
		image.save_png(output.path_join("frame_%02d.png" % tick))
	quit()
