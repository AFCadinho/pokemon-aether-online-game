extends SceneTree

# Live Route 1 grass viewer. Space affects only tall-grass animations.
class MapView extends Node2D:
	var camera: Camera2D
	var entries: Array[Dictionary] = []
	var enabled := true
	var label: Label
	var view_index := 0
	func set_view(index: int) -> void:
		view_index = index % 3
		camera.position = [Vector2(368,496),Vector2(496,544),Vector2(880,1200)][view_index]
		camera.zoom = Vector2.ONE * [2.0,1.0,0.32][view_index]
	func _process(delta: float) -> void:
		var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += direction * delta * 500.0 / camera.zoom.x
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				get_tree().quit()
			elif event.physical_keycode == KEY_TAB:
				set_view(view_index+1)
			elif event.physical_keycode == KEY_SPACE:
				toggle()
			elif event.physical_keycode in [KEY_EQUAL,KEY_KP_ADD]:
				camera.zoom = Vector2.ONE * minf(camera.zoom.x * 1.25,4.0)
			elif event.physical_keycode in [KEY_MINUS,KEY_KP_SUBTRACT]:
				camera.zoom = Vector2.ONE * maxf(camera.zoom.x / 1.25,0.2)
	func toggle() -> void:
		enabled = not enabled
		for entry in entries:
			var source: TileSetAtlasSource = entry.source
			source.set_tile_animation_frames_count(entry.coords,entry.durations.size() if enabled else 1)
			if enabled:
				for f in entry.durations.size():
					source.set_tile_animation_frame_duration(entry.coords,f,entry.durations[f])
		label.text = "Tall grass: %s  ·  Spatie: aan/uit  ·  Tab: ander beeld\nWASD: bewegen  ·  +/−: zoom  ·  Esc: sluiten" % ("aan" if enabled else "uit")

func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var id := "route_1"
	for arg in args:
		if not arg.begins_with("--"):
			id = arg
	if not id.is_valid_identifier():
		quit(2)
		return
	var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id,id]
	if not ResourceLoader.exists(path):
		push_error("Unknown map: " + id)
		quit(2)
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1200,840)
	root.size = Vector2i(1200,840)
	root.title = "PokeAether · " + id + " · animated tiles"
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var view := MapView.new()
	var map := (load(path) as PackedScene).instantiate()
	view.add_child(map)
	var layers: Array[TileMapLayer] = []
	preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd").new()._collect(map,layers)
	var tiles := layers[0].tile_set.duplicate(true) as TileSet
	var bounds := Rect2i()
	for layer in layers:
		layer.tile_set = tiles
		bounds = bounds.merge(layer.get_used_rect())
	for i in tiles.get_source_count():
		var source := tiles.get_source(tiles.get_source_id(i)) as TileSetAtlasSource
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var count := source.get_tile_animation_frames_count(coords)
			if count != 50:
				continue
			var durations: Array[float] = []
			for f in count:
				durations.append(source.get_tile_animation_frame_duration(coords,f))
			view.entries.append({"source":source,"coords":coords,"durations":durations})
	view.camera = Camera2D.new()
	view.camera.position = Vector2(bounds.get_center()) * Vector2(tiles.tile_size)
	view.camera.zoom = Vector2.ONE * minf(1100.0/(bounds.size.x*tiles.tile_size.x),740.0/(bounds.size.y*tiles.tile_size.y))
	view.add_child(view.camera)
	var ui := CanvasLayer.new()
	view.add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,16)
	ui.add_child(panel)
	view.label = Label.new()
	panel.add_child(view.label)
	view.enabled = false
	view.toggle()
	view.set_view(0)
	root.add_child(view)
	if "--capture" in args:
		var directory := "user://tall_grass_preview_capture"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		for f in 100:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("frame_%03d.png" % f))
			await create_timer(0.08).timeout
		view.toggle()
		for f in 2:
			await create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(directory.path_join("paused_%d.png" % f))
		print("TALL_GRASS_PREVIEW animations=",view.entries.size()," ",ProjectSettings.globalize_path(directory))
		quit()
