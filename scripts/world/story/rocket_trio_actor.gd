@tool
extends AnimatedSprite2D

## A fixed 4x4 overworld sheet. Positions represent feet, as on existing NPCs.
@export var sheet: Texture2D
@export_enum("down", "left", "right", "up") var initial_direction := "down"


func _ready() -> void:
	sprite_frames = build_frames(sheet)
	offset = Vector2(0, -16)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play("idle_" + initial_direction)


func _process(_delta: float) -> void:
	# Match BaseNPC's absolute foot-depth sorting, including during a cutscene.
	z_as_relative = false
	z_index = clampi(floori(global_position.y), -4096, 4096)


static func build_frames(texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	if texture == null:
		return frames
	var cell := Vector2(texture.get_width() / 4.0, texture.get_height() / 4.0)
	var directions: Array[String] = ["down", "left", "right", "up"]
	for row: int in range(4):
		for prefix: String in ["idle_", "walk_"]:
			var animation_name := prefix + directions[row]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 7.5)
			for column: int in range(1 if prefix == "idle_" else 4):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(column, row) * cell, cell)
				frames.add_frame(animation_name, atlas)
	return frames
