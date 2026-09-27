extends Node2D

const VISUAL := preload("res://generated/tiled_visuals/pallet_animated_tiles_test/pallet_animated_tiles_test.visual.tscn")
var camera: Camera2D
var view_index := 0
var enabled := true
var animations: Array[Dictionary] = []
var status: Label
var ui: CanvasLayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var map := VISUAL.instantiate()
	add_child(map)
	var tiles := (map.get_child(0) as TileMapLayer).tile_set.duplicate(true) as TileSet
	for layer in map.get_children():
		if layer is TileMapLayer:
			layer.tile_set = tiles
	for i in tiles.get_source_count():
		var source := tiles.get_source(tiles.get_source_id(i)) as TileSetAtlasSource
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var count := source.get_tile_animation_frames_count(coords)
			if count <= 1:
				continue
			var durations: Array[float] = []
			for f in count:
				durations.append(source.get_tile_animation_frame_duration(coords, f))
			animations.append({"source": source, "coords": coords, "durations": durations})
	camera = Camera2D.new()
	add_child(camera)
	ui = CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,16)
	ui.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	status = Label.new()
	margin.add_child(status)
	set_view(0)

func set_view(index: int) -> void:
	view_index = index % 3
	camera.position = [Vector2(800,640), Vector2(650,410), Vector2(520,990)][view_index]
	camera.zoom = [Vector2(0.6,0.6), Vector2(1.25,1.25), Vector2(1.15,1.15)][view_index]
	_update_label()

func set_animation_enabled(value: bool) -> void:
	enabled = value
	for entry in animations:
		var source: TileSetAtlasSource = entry.source
		source.set_tile_animation_frames_count(entry.coords, entry.durations.size() if enabled else 1)
		if enabled:
			for f in entry.durations.size():
				source.set_tile_animation_frame_duration(entry.coords, f, entry.durations[f])
	_update_label()

func _update_label() -> void:
	status.text = "Pallet Town · water, bladeren en bloemen\n%s · Animaties: %s\nTab: ander beeld · Spatie: aan/uit · Esc: sluiten" % [["Hele stad", "Bloementuin", "Vijver"][view_index], "aan" if enabled else "uit"]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB: set_view(view_index + 1)
			KEY_SPACE: set_animation_enabled(not enabled)
			KEY_ESCAPE: get_tree().quit()
