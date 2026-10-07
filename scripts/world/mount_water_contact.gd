extends AnimatedSprite2D

# Child of the mount foreground: identical actor world depth and local ordering.
# Frames follow the mount explicitly, so idle/fishing has no wake and preview
# pause/angle controls never leave a second animation running independently.
static var frames_cache: Dictionary = {}
var configuration_key := ""


func configure(definition: Dictionary) -> void:
	var path := str(definition.get("waterContactSheet", ""))
	var idle_path := str(definition.get("idleWaterContactSheet", ""))
	var idle_count := clampi(int(definition.get("idleFrameCount", 1)), 1, 4) if not idle_path.is_empty() else 1
	var size_values: Array = definition.get("frameSize", [64, 64])
	var size := Vector2i(int(size_values[0]), int(size_values[1]))
	var key := "%s:%s:%s:%s" % [path, idle_path, size, idle_count]
	if key == configuration_key:
		return
	configuration_key = key
	visible = false
	stop()
	sprite_frames = null
	if path.is_empty():
		return
	if not frames_cache.has(key):
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != size * Vector2i(4, 8):
			push_error("Invalid mount water-contact sheet: " + path)
			return
		var idle_texture := load(idle_path) as Texture2D if not idle_path.is_empty() else texture
		if idle_texture == null or (not idle_path.is_empty() and Vector2i(idle_texture.get_size()) != size * Vector2i(idle_count, 4)):
			push_error("Invalid mount idle water-contact sheet: " + idle_path)
			return
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for moving: bool in [false, true]:
			for row in range(4):
				var direction: String = ["down", "left", "right", "up"][row]
				var animation_name := StringName(("walk_" if moving else "idle_") + direction)
				frames.add_animation(animation_name)
				for phase in range(4 if moving else idle_count):
					var frame_texture := AtlasTexture.new()
					frame_texture.atlas = texture if moving else idle_texture
					frame_texture.region = Rect2(Vector2i(phase, row + (4 if moving else 0)) * size, size)
					frames.add_frame(animation_name, frame_texture)
		frames_cache[key] = frames
	sprite_frames = frames_cache[key]
	animation = &"idle_down"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = true


func sync_frame(mount: AnimatedSprite2D) -> void:
	if not visible or sprite_frames == null or mount == null:
		return
	if not sprite_frames.has_animation(mount.animation):
		return
	animation = mount.animation
	frame = mini(mount.frame, sprite_frames.get_frame_count(animation) - 1)
	pause()
