extends "res://tools/sprite_factory/battle_3d_runtime_probe.gd"
## Visual comparison only: imported model materials are still experimental.

var entries: Array = []
var species_choice: OptionButton
var action_choice: OptionButton
var side_choice: OptionButton
var sprites: Array[AnimatedSprite2D] = []
var panels: Array[Node] = []
var elapsed := 0.0
var current_spec: Dictionary = {}
var zoom := 1.0

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_REPRESENTATION_REVIEW")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		push_error("Set POKEAETHER_REPRESENTATION_REVIEW to prepared index")
		quit(2)
		return
	entries = data
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1080, 450)
	root.position = Vector2i(40, 60)
	DisplayServer.window_set_title("PokeAether — Sprite / 3D comparison (research)")
	DisplayServer.window_set_size(Vector2i(1080, 450))
	Engine.max_fps = 60
	RenderingServer.set_default_clear_color(Color("242632"))
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 16)
	root.add_child(bar)
	species_choice = OptionButton.new()
	for entry: Dictionary in entries:
		species_choice.add_item(entry.model.species)
	bar.add_child(species_choice)
	action_choice = OptionButton.new()
	for action in entries[0].sprites.front:
		action_choice.add_item(action)
	bar.add_child(action_choice)
	side_choice = OptionButton.new()
	side_choice.add_item("front")
	side_choice.add_item("back")
	bar.add_child(side_choice)
	var zoom_button := Button.new()
	zoom_button.text = "Zoom 1× / 2×"
	bar.add_child(zoom_button)
	zoom_button.pressed.connect(func():
		zoom = 2.0 if zoom == 1.0 else 1.0
		_load_selection())
	for choice in [species_choice, action_choice, side_choice]:
		choice.item_selected.connect(func(_index): _load_selection())
	var note := Label.new()
	note.position = Vector2(16, 395)
	note.text = "60 FPS source timing • 3D: experimental simplified materials/lighting • separate review, not the game"
	root.add_child(note)
	_load_selection()
	if OS.get_environment("POKEAETHER_REVIEW_SMOKE") == "1":
		var checked := 0
		for species_index in entries.size():
			species_choice.select(species_index)
			for side_index in 2:
				side_choice.select(side_index)
				for action_index in action_choice.item_count:
					action_choice.select(action_index)
					_load_selection()
					assert(sprites.size() == 3 and players.size() == 1)
					for sprite in sprites:
						assert(sprite.sprite_frames.get_frame_count("default") == int(current_spec.count))
					assert(players[0].has_animation(action_choice.get_item_text(action_index)))
					await process_frame
					checked += 1
		print("REVIEW_SMOKE_OK cases=", checked)
		quit()
		return
	if OS.get_environment("POKEAETHER_REVIEW_CAPTURE") != "":
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("POKEAETHER_REVIEW_CAPTURE"))
		quit()

func _load_selection() -> void:
	for panel in panels:
		panel.free()
	panels.clear()
	sprites.clear()
	players.clear()
	viewports.clear()
	var entry: Dictionary = entries[species_choice.selected]
	var action := action_choice.get_item_text(action_choice.selected)
	var side := side_choice.get_item_text(side_choice.selected)
	var profiles: Dictionary = entry.sprites[side][action]
	var index := 0
	for label in ["512-q95", "512-q70", "256-q75", "3D"]:
		var title := Label.new()
		title.position = Vector2(16 + index * 266, 72)
		title.text = label
		root.add_child(title)
		panels.append(title)
		if label == "3D":
			var state := GLTFState.new()
			var document := GLTFDocument.new()
			if document.append_from_file(entry.model.path, state) != OK:
				push_error("Unable to open model")
				return
			var camera: Dictionary = entry.model.cameras[side].duplicate(true)
			camera.ortho_scale = float(camera.ortho_scale) / zoom
			var view := _make_view(document.generate_scene(state, 60), camera, 0)
			var container := view.get_parent() as SubViewportContainer
			container.position = Vector2(16 + index * 266, 106)
			container.scale = Vector2(0.5, 0.5)
			panels.append(container)
		else:
			current_spec = profiles[label]
			var frame_set := SpriteFrames.new()
			var rect: Array = current_spec.rect
			var logical := int(current_spec.size)
			for page: Dictionary in current_spec.pages:
				var image := Image.load_from_file(page.file)
				for frame in int(page.count):
					var region := Rect2i((frame % int(page.columns)) * int(rect[2]), (frame / int(page.columns)) * int(rect[3]), int(rect[2]), int(rect[3]))
					var cell := image.get_region(region)
					cell.generate_mipmaps()
					var texture := AtlasTexture.new()
					texture.atlas = ImageTexture.create_from_image(cell)
					texture.region = Rect2(0, 0, rect[2], rect[3])
					texture.margin = Rect2(rect[0], rect[1], logical - int(rect[2]), logical - int(rect[3]))
					frame_set.add_frame("default", texture)
			var clip := Control.new()
			clip.position = Vector2(16 + index * 266, 106)
			clip.size = Vector2(256, 256)
			clip.clip_contents = true
			root.add_child(clip)
			panels.append(clip)
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frame_set
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sprite.position = Vector2(128, 128)
			sprite.scale = Vector2.ONE * 256.0 / logical * zoom
			clip.add_child(sprite)
			sprites.append(sprite)
		index += 1
	for player in players:
		player.play(action)
		player.pause()
	elapsed = 0.0

func _process(delta: float) -> bool:
	if current_spec.is_empty():
		return false
	elapsed += delta * float(current_spec.speed)
	var duration := float(current_spec.count) / 60.0
	var position := fmod(elapsed, duration) if current_spec.loop else minf(elapsed, duration - 1.0 / 60.0)
	for sprite in sprites:
		sprite.frame = mini(int(position * 60), int(current_spec.count) - 1)
	for player in players:
		player.seek(minf(position, player.current_animation_length), true)
	return false
