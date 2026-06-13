extends Node2D

class_name MoveAnimationPlayer

signal animation_finished

@export_file("*.json") var data_path := ""
@export_file("*.png") var sheet_path := ""
@export_file("*.png") var background_path := ""
@export_file("*.png") var foreground_path := ""
@export var sound_paths: Dictionary = {}
@export var autoplay: bool = true
@export var loop: bool = false
@export var free_on_finish: bool = false
@export var show_timing_backgrounds: bool = false
@export var show_timing_foregrounds: bool = false
@export var show_pink_visual: bool = true
@export var visual_color: Color = Color(1.0, 0.2, 0.75, 1.0)
@export var sprite_tint: Color = Color(1.0, 0.78, 1.0, 1.0)
@export_range(0.0, 0.5, 0.01) var overlay_peak_alpha: float = 0.20
@export_range(0, 48, 1) var sparkle_count: int = 14
@export_range(0.25, 4.0, 0.05) var speed_scale: float = 1.0
@export_range(-8, 8, 1) var pattern_offset: int = 0
@export_range(-1, 999, 1) var pattern_override: int = -1

var data: Dictionary = {}
var sprites: Array[Sprite2D] = []
var frame_index: int = 0
var frame_time: float = 0.0
var is_playing: bool = false
var played_events: Dictionary = {}
var pink_overlay_alpha: float = 0.0
var bg_hide_frame: int = -1
var fg_hide_frame: int = -1
var sheet_texture: Texture2D
var sound_players: Dictionary = {}
var data_override: Dictionary = {}
var sheet_texture_override: Texture2D
var background_texture_override: Texture2D
var foreground_texture_override: Texture2D
var sound_streams: Dictionary = {}

@onready var bg: Sprite2D = Sprite2D.new()
@onready var fg: Sprite2D = Sprite2D.new()


func _ready() -> void:
	_load_animation_data()
	_build_nodes()
	if autoplay:
		play()


func play() -> void:
	if data.is_empty() or not _animation_data_is_valid(data):
		animation_finished.emit()
		if free_on_finish:
			queue_free()
		return

	frame_index = 0
	frame_time = 0.0
	pink_overlay_alpha = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	played_events.clear()
	is_playing = true
	_apply_frame(frame_index)


func stop() -> void:
	is_playing = false
	for sprite: Sprite2D in sprites:
		sprite.visible = false
	bg.modulate.a = 0.0
	fg.modulate.a = 0.0
	bg_hide_frame = -1
	fg_hide_frame = -1
	pink_overlay_alpha = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if not is_playing or data.is_empty():
		return

	pink_overlay_alpha = maxf(0.0, pink_overlay_alpha - delta * 0.42)
	queue_redraw()

	frame_time += delta
	var seconds_per_frame: float = 1.0 / (float(data.get("fps", 20)) * speed_scale)
	while frame_time >= seconds_per_frame:
		frame_time -= seconds_per_frame
		frame_index += 1
		if frame_index >= (data["frames"] as Array).size():
			if loop:
				frame_index = 0
				played_events.clear()
			else:
				stop()
				animation_finished.emit()
				if free_on_finish:
					queue_free()
				return
		_apply_frame(frame_index)


func _load_animation_data() -> void:
	if not data_override.is_empty():
		if _animation_data_is_valid(data_override):
			data = data_override
		else:
			push_error("Move animation data override is incomplete.")
		return

	if data_path == "":
		push_error("Move animation data_path is empty.")
		return

	var parsed_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if parsed_data == null or not parsed_data is Dictionary:
		push_error("Could not read %s" % data_path)
		return
	var parsed_dictionary: Dictionary = parsed_data as Dictionary
	if not _animation_data_is_valid(parsed_dictionary):
		push_error("Move animation data is incomplete: %s" % data_path)
		return
	data = parsed_dictionary


func _animation_data_is_valid(animation_data: Dictionary) -> bool:
	var frames_value: Variant = animation_data.get("frames", [])
	if not frames_value is Array or (frames_value as Array).is_empty():
		return false

	var tile_size_value: Variant = animation_data.get("tile_size", [])
	if not tile_size_value is Array or (tile_size_value as Array).size() < 2:
		return false

	if float(animation_data.get("fps", 20.0)) <= 0.0:
		return false

	return true


func _build_nodes() -> void:
	sheet_texture = sheet_texture_override
	if sheet_texture == null:
		sheet_texture = load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_error("Could not load move animation sheet: %s" % sheet_path)
		return

	if background_texture_override != null:
		bg.texture = background_texture_override
	elif background_path != "":
		bg.texture = load(background_path) as Texture2D
	bg.centered = false
	bg.modulate.a = 0.0
	add_child(bg)

	for i: int in range(32):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = sheet_texture
		sprite.region_enabled = true
		sprite.visible = false
		sprite.centered = true
		sprites.append(sprite)
		add_child(sprite)

	if foreground_texture_override != null:
		fg.texture = foreground_texture_override
	elif foreground_path != "":
		fg.texture = load(foreground_path) as Texture2D
	fg.centered = false
	fg.modulate.a = 0.0
	add_child(fg)

	for sound_name: Variant in sound_paths.keys():
		var sound_key: String = str(sound_name)
		var stream: AudioStream = sound_streams.get(sound_key, null) as AudioStream
		var sound_path: String = str(sound_paths.get(sound_name, ""))
		if stream == null:
			stream = load(sound_path) as AudioStream
		if stream == null:
			push_warning("Could not load move animation sound: %s" % sound_path)
			continue

		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = SettingsManager.SFX_BUS
		sound_players[sound_key] = player
		add_child(player)


func _draw() -> void:
	if not show_pink_visual or pink_overlay_alpha <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, Vector2(512, 384)), Color(visual_color.r, visual_color.g, visual_color.b, pink_overlay_alpha), true)
	for i: int in range(sparkle_count):
		var angle: float = float(i) * 0.85 + float(frame_index) * 0.18
		var radius: float = 44.0 + float((i * 17) % 85)
		var center: Vector2 = Vector2(256, 188) + Vector2(cos(angle), sin(angle * 1.27)) * radius
		var sparkle_alpha: float = pink_overlay_alpha * (0.35 + 0.45 * absf(sin(angle)))
		draw_circle(center, 2.5 + float(i % 3), Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, sparkle_alpha))


func _apply_frame(index: int) -> void:
	_apply_timing_events(index)
	_expire_timing_layers(index)
	_update_pink_visual(index)

	var frames: Array = data["frames"] as Array
	var cells: Array = frames[index] as Array
	for sprite: Sprite2D in sprites:
		sprite.visible = false

	var tile_size: Array = data["tile_size"] as Array
	var tile_w: int = int(tile_size[0])
	var tile_h: int = int(tile_size[1])
	var columns: int = maxi(1, int(sheet_texture.get_width() / tile_w))
	var sprite_i: int = 0

	for cell_value: Variant in cells:
		if sprite_i >= sprites.size():
			break
		if not cell_value is Dictionary:
			continue

		var cell: Dictionary = cell_value as Dictionary
		if int(cell["source"]) < 0:
			continue

		var sprite: Sprite2D = sprites[sprite_i]
		var pattern: int = pattern_override if pattern_override >= 0 else maxi(0, int(cell["pattern"]) + pattern_offset)
		sprite.region_rect = Rect2(
			(pattern % columns) * tile_w,
			int(pattern / columns) * tile_h,
			tile_w,
			tile_h
		)
		sprite.position = Vector2(float(cell["x"]), float(cell["y"]))
		var zoom: float = float(cell["zoom"]) / 100.0
		sprite.scale = Vector2(-zoom if bool(cell["mirror"]) else zoom, zoom)
		sprite.rotation_degrees = float(cell["angle"])
		var alpha: float = float(cell["opacity"]) / 255.0
		sprite.modulate = Color(sprite_tint.r, sprite_tint.g, sprite_tint.b, alpha) if show_pink_visual else Color(1.0, 1.0, 1.0, alpha)
		sprite.visible = true
		sprite_i += 1


func _update_pink_visual(index: int) -> void:
	if not show_pink_visual:
		return

	if index < 8:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha * 0.6)
	elif index >= 28 and index <= 46:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha)
	elif index > 46:
		pink_overlay_alpha = maxf(pink_overlay_alpha, overlay_peak_alpha * 0.4)
	queue_redraw()


func _apply_timing_events(index: int) -> void:
	var timings: Array = data["timings"] as Array
	for event_value: Variant in timings:
		if not event_value is Dictionary:
			continue

		var event: Dictionary = event_value as Dictionary
		if int(event["frame"]) != index:
			continue

		var event_key: String = "%s:%s:%s" % [event["frame"], event["type"], event["name"]]
		if played_events.has(event_key):
			continue
		played_events[event_key] = true

		match int(event["type"]):
			0:
				_play_sound_event(event)
			1:
				if show_timing_backgrounds:
					bg.modulate.a = 1.0
					bg_hide_frame = _timing_hide_frame(index, event)
			2:
				if show_timing_backgrounds:
					bg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else bg.modulate.a
					bg_hide_frame = _timing_hide_frame(index, event) if bg.modulate.a > 0.0 else -1
			3:
				if show_timing_foregrounds:
					fg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else 1.0
					fg_hide_frame = _timing_hide_frame(index, event)
			4:
				if show_timing_foregrounds:
					fg.modulate.a = float(event["opacity"]) / 255.0 if event["opacity"] != null else fg.modulate.a
					fg_hide_frame = _timing_hide_frame(index, event) if fg.modulate.a > 0.0 else -1


func _expire_timing_layers(index: int) -> void:
	if bg_hide_frame >= 0 and index >= bg_hide_frame:
		bg.modulate.a = 0.0
		bg_hide_frame = -1
	if fg_hide_frame >= 0 and index >= fg_hide_frame:
		fg.modulate.a = 0.0
		fg_hide_frame = -1


func _timing_hide_frame(index: int, event: Dictionary) -> int:
	var duration: int = int(event.get("duration", 0))
	return index + maxi(1, duration) if duration > 0 else -1


func _play_sound_event(event: Dictionary) -> void:
	var player: AudioStreamPlayer = sound_players.get(str(event["name"]), null) as AudioStreamPlayer
	if player == null:
		return

	var volume: float = float(event["volume"]) / 100.0
	var pitch: float = float(event["pitch"]) / 100.0
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = pitch
	player.play()
