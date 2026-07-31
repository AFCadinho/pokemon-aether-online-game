extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const OUTPUT_PATH := "res://assets/npcs/custom/adinho_dad.png"
const FRAMES_OUTPUT_PATH := "res://assets/npcs/custom/adinho_dad_frames.tres"
const SHEET_SIZE := Vector2i(256, 256)

const LAYERS: Array[Dictionary] = [
	{
		"path": "res://assets/player/male/body/Gen4_Base_v1.png",
		"skin_tone": Color("#e7b894"),
	},
	{
		"path": "res://assets/player/male/bottom/Adinho_Trousers.png",
	},
	{
		"path": "res://assets/player/male/shoes/Adinho_Shoes.png",
	},
	{
		"path": "res://assets/player/male/top/Adinho_Shirt.png",
	},
	{
		"path": "res://assets/player/male/eyes/Eyes.png",
		"tint": Color("#3d6f86"),
		"preserve_luminance": false,
	},
	{
		"path": "res://assets/player/male/eyebrows/Adinho_Eyebrows.png",
		"tint": Color("#201a18"),
		"preserve_luminance": true,
	},
	{
		"path": "res://assets/player/hair/Bald_Hair.png",
		"tint": Color("#201a18"),
		"preserve_luminance": false,
	},
	{
		"path": "res://assets/player/male/hair/Adinho_Hair.png",
		"tint": Color("#201a18"),
		"preserve_luminance": true,
	},
	{
		"path": "res://assets/player/male/facial_hair/Adinho_Beard.png",
		"tint": Color("#201a18"),
		"preserve_luminance": true,
	},
	{
		"path": "res://assets/player/male/facegear/Adinho_Glasses.png",
	},
]


func _init() -> void:
	var sheet := Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	for layer: Dictionary in LAYERS:
		var texture := load(str(layer.get("path", ""))) as Texture2D
		if texture == null:
			push_error("Dad NPC generator could not load %s" % layer.get("path", ""))
			quit(1)
			return
		var layer_texture := texture
		if layer.has("skin_tone"):
			layer_texture = APPEARANCE._make_skin_tinted_texture(
				texture,
				layer.get("skin_tone", Color.WHITE) as Color
			)
		elif layer.has("tint"):
			layer_texture = APPEARANCE._make_tinted_texture(
				texture,
				layer.get("tint", Color.WHITE) as Color,
				bool(layer.get("preserve_luminance", false))
			)
		var layer_image := layer_texture.get_image()
		if layer_image == null or layer_image.get_size() != SHEET_SIZE:
			push_error("Dad NPC layer has an invalid size: %s" % layer.get("path", ""))
			quit(1)
			return
		if layer_image.get_format() != Image.FORMAT_RGBA8:
			layer_image.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(layer_image, Rect2i(Vector2i.ZERO, SHEET_SIZE), Vector2i.ZERO)

	var output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := sheet.save_png(output_path)
	if error != OK:
		push_error("Dad NPC generator could not save %s (error %d)" % [output_path, error])
		quit(1)
		return
	var npc_texture := ResourceLoader.load(
		OUTPUT_PATH,
		"Texture2D",
		ResourceLoader.CACHE_MODE_REPLACE
	) as Texture2D
	if npc_texture == null:
		push_error("Dad NPC generator could not reload %s" % OUTPUT_PATH)
		quit(1)
		return
	var sprite_frames := APPEARANCE._build_sprite_frames(npc_texture)
	error = ResourceSaver.save(sprite_frames, FRAMES_OUTPUT_PATH)
	if error != OK:
		push_error("Dad NPC generator could not save %s (error %d)" % [FRAMES_OUTPUT_PATH, error])
		quit(1)
		return
	print("Generated %s and %s" % [OUTPUT_PATH, FRAMES_OUTPUT_PATH])
	quit()
