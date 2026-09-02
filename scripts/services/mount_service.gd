extends RefCounted

class_name MountService

const CATALOG_PATH := "res://data/mounts.json"
const FRAME_COLUMNS := 4
const FRAME_ROWS := 4
const DEFAULT_FRAME_SIZE := Vector2i(64, 64)
const IDLE_ANIMATION_SPEED := 5.0
const WALK_ANIMATION_SPEED := 7.5
const MOVEMENT_MODE_LAND := "land"
const MOVEMENT_MODE_SURF := "surf"
const AVAILABLE_MOVEMENT_MODES: Array[String] = [MOVEMENT_MODE_LAND, MOVEMENT_MODE_SURF]

static var _catalog: Dictionary = {}
static var _mount_frames_cache: Dictionary = {}
static var _mount_foreground_frames_cache: Dictionary = {}
static var _rider_frames_cache: Dictionary = {}
static var _mask_image_cache: Dictionary = {}


static func get_default_mount_id(movement_mode: String) -> String:
	var normalized_mode := movement_mode.strip_edges().to_lower()
	var defaults_value: Variant = _get_catalog().get("defaults", {})
	if not defaults_value is Dictionary:
		return ""
	return normalize_mount_id(str((defaults_value as Dictionary).get(normalized_mode, "")))


static func normalize_mount_id(mount_id: String) -> String:
	var normalized_id := mount_id.strip_edges().to_lower()
	if normalized_id == "":
		return ""
	var definitions := _get_mount_definitions()
	return normalized_id if definitions.has(normalized_id) else ""


static func get_mount_definition(mount_id: String) -> Dictionary:
	var normalized_id := normalize_mount_id(mount_id)
	if normalized_id == "":
		return {}
	var definition_value: Variant = _get_mount_definitions().get(normalized_id, {})
	return (definition_value as Dictionary).duplicate(true) \
		if definition_value is Dictionary \
		else {}


static func get_mount_movement_mode(mount_id: String) -> String:
	return str(get_mount_definition(mount_id).get("movementMode", "")).strip_edges().to_lower()


static func get_mount_display_name(mount_id: String) -> String:
	var definition := get_mount_definition(mount_id)
	var fallback := normalize_mount_id(mount_id).replace("_", " ").replace("-", " ").capitalize()
	return str(definition.get("displayName", fallback)).strip_edges()


static func get_mount_unlock_item_id(mount_id: String) -> String:
	return str(get_mount_definition(mount_id).get("unlockItemId", "")).strip_edges().to_lower()


static func get_mount_id_for_unlock_item(item_id: String) -> String:
	var normalized_item_id := item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if normalized_item_id == "":
		return ""
	for mount_id_value: Variant in _get_mount_definitions().keys():
		var mount_id := normalize_mount_id(str(mount_id_value))
		if mount_id != "" and get_mount_unlock_item_id(mount_id) == normalized_item_id:
			return mount_id
	return ""


static func is_mount_unlocked(mount_id: String, owned_item_ids: Array) -> bool:
	var unlock_item_id := get_mount_unlock_item_id(mount_id)
	return unlock_item_id.is_empty() or unlock_item_id in owned_item_ids


static func get_mount_ids_for_mode(movement_mode: String) -> Array[String]:
	var normalized_mode := movement_mode.strip_edges().to_lower()
	if normalized_mode not in AVAILABLE_MOVEMENT_MODES:
		return []
	var mount_ids: Array[String] = []
	for mount_id_value: Variant in _get_mount_definitions().keys():
		var mount_id := normalize_mount_id(str(mount_id_value))
		if mount_id != "" and get_mount_movement_mode(mount_id) == normalized_mode:
			mount_ids.append(mount_id)
	mount_ids.sort()
	return mount_ids


static func get_unlocked_mount_ids_for_mode(
	movement_mode: String,
	owned_item_ids: Array
) -> Array[String]:
	var mount_ids: Array[String] = []
	for mount_id: String in get_mount_ids_for_mode(movement_mode):
		if is_mount_unlocked(mount_id, owned_item_ids):
			mount_ids.append(mount_id)
	return mount_ids


static func resolve_mount_id_for_mode(
	mount_id: String,
	movement_mode: String,
	use_default_fallback := false
) -> String:
	var normalized_mode := movement_mode.strip_edges().to_lower()
	var normalized_id := normalize_mount_id(mount_id)
	if normalized_id != "" and get_mount_movement_mode(normalized_id) == normalized_mode:
		return normalized_id
	return get_default_mount_id(normalized_mode) if use_default_fallback else ""


static func get_mount_icon_texture(mount_id: String) -> Texture2D:
	var frames := get_mount_frames(mount_id)
	if frames == null or not frames.has_animation(&"idle_down"):
		return null
	if frames.get_frame_count(&"idle_down") <= 0:
		return null
	return frames.get_frame_texture(&"idle_down", 0)


static func get_rider_frame_delta(mount_id: String, direction: String, frame_index: int) -> Vector2i:
	return get_rider_frame_offset(mount_id, direction, frame_index) \
		- get_rider_frame_offset(mount_id, direction, 0)


static func get_rider_frame_offset(mount_id: String, direction: String, frame_index: int) -> Vector2i:
	var definition := get_mount_definition(mount_id)
	var rider_offsets_value: Variant = definition.get("riderOffsets", {})
	if not rider_offsets_value is Dictionary:
		return Vector2i.ZERO
	return _get_rider_offset(rider_offsets_value as Dictionary, direction, frame_index)


static func get_mount_frames(mount_id: String) -> SpriteFrames:
	var normalized_id := normalize_mount_id(mount_id)
	if normalized_id == "":
		return null
	if _mount_frames_cache.has(normalized_id):
		return _mount_frames_cache[normalized_id] as SpriteFrames

	var definition := get_mount_definition(normalized_id)
	var texture_path := str(definition.get("spriteSheet", ""))
	if texture_path == "" or not ResourceLoader.exists(texture_path):
		return null
	var texture := ResourceLoader.load(texture_path) as Texture2D
	var frame_size := _get_mount_frame_size(definition)
	if texture == null or Vector2i(texture.get_size()) != frame_size * Vector2i(FRAME_COLUMNS, FRAME_ROWS):
		return null

	var frames := _build_sprite_frames(texture, frame_size)
	_mount_frames_cache[normalized_id] = frames
	return frames


static func get_mount_foreground_frames(mount_id: String) -> SpriteFrames:
	var normalized_id := normalize_mount_id(mount_id)
	if normalized_id == "":
		return null
	if _mount_foreground_frames_cache.has(normalized_id):
		return _mount_foreground_frames_cache[normalized_id] as SpriteFrames

	var definition := get_mount_definition(normalized_id)
	var regions_value: Variant = definition.get("foregroundRegions", {})
	if not regions_value is Dictionary or (regions_value as Dictionary).is_empty():
		return null
	var mount_frames := get_mount_frames(normalized_id)
	if mount_frames == null:
		return null

	var foreground_frames := SpriteFrames.new()
	if foreground_frames.has_animation(&"default"):
		foreground_frames.remove_animation(&"default")
	for animation_name_text: String in mount_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		foreground_frames.add_animation(animation_name)
		foreground_frames.set_animation_speed(
			animation_name,
			mount_frames.get_animation_speed(animation_name)
		)
		foreground_frames.set_animation_loop(
			animation_name,
			mount_frames.get_animation_loop(animation_name)
		)
		var direction := _direction_from_animation(animation_name_text)
		var region := _foreground_region(regions_value as Dictionary, direction)
		var frame_count := mount_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var source_image := _get_texture_image(
				mount_frames.get_frame_texture(animation_name, frame_index)
			)
			var foreground_image := _extract_foreground(source_image, region)
			foreground_frames.add_frame(
				animation_name,
				ImageTexture.create_from_image(foreground_image),
				mount_frames.get_frame_duration(animation_name, frame_index)
			)

	_mount_foreground_frames_cache[normalized_id] = foreground_frames
	return foreground_frames


static func get_mounted_rider_frames(
	base_frames: SpriteFrames,
	mount_id: String,
	rider_offset_adjustments: Dictionary = {}
) -> SpriteFrames:
	if base_frames == null:
		return null
	var normalized_id := normalize_mount_id(mount_id)
	if normalized_id == "":
		return base_frames

	var cache_key := "%s:%d:%s" % [
		normalized_id,
		base_frames.get_instance_id(),
		JSON.stringify(rider_offset_adjustments),
	]
	if _rider_frames_cache.has(cache_key):
		return _rider_frames_cache[cache_key] as SpriteFrames

	var mask_image := _get_mask_image(normalized_id)
	if mask_image == null:
		return base_frames
	var definition := get_mount_definition(normalized_id)
	var rider_offsets_value: Variant = definition.get("riderOffsets", {})
	if not rider_offsets_value is Dictionary:
		return base_frames

	var transformed := SpriteFrames.new()
	if transformed.has_animation(&"default"):
		transformed.remove_animation(&"default")

	for animation_name_text: String in base_frames.get_animation_names():
		var animation_name := StringName(animation_name_text)
		transformed.add_animation(animation_name)
		transformed.set_animation_speed(animation_name, base_frames.get_animation_speed(animation_name))
		transformed.set_animation_loop(animation_name, base_frames.get_animation_loop(animation_name))
		var direction := _direction_from_animation(animation_name_text)
		var direction_row := _direction_row(direction)
		var frame_count := base_frames.get_frame_count(animation_name)
		for frame_index: int in range(frame_count):
			var source_texture := base_frames.get_frame_texture(animation_name, frame_index)
			var source_image := _get_texture_image(source_texture)
			var offset := _get_rider_offset(rider_offsets_value as Dictionary, direction, frame_index)
			offset += _get_rider_offset_adjustment(rider_offset_adjustments, direction)
			var mounted_image := _transform_rider_frame(
				source_image,
				mask_image,
				direction_row,
				mini(frame_index, FRAME_COLUMNS - 1),
				offset
			)
			var mounted_texture := ImageTexture.create_from_image(mounted_image) \
				if mounted_image != null \
				else source_texture
			transformed.add_frame(
				animation_name,
				mounted_texture,
				base_frames.get_frame_duration(animation_name, frame_index)
			)

	_rider_frames_cache[cache_key] = transformed
	return transformed


static func _get_catalog() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		_catalog = parsed as Dictionary
	return _catalog


static func _get_mount_definitions() -> Dictionary:
	var definitions_value: Variant = _get_catalog().get("mounts", {})
	return definitions_value as Dictionary if definitions_value is Dictionary else {}


static func _get_mount_frame_size(definition: Dictionary) -> Vector2i:
	var frame_size_value: Variant = definition.get("frameSize", [])
	if frame_size_value is Array and (frame_size_value as Array).size() >= 2:
		var values := frame_size_value as Array
		var frame_size := Vector2i(int(values[0]), int(values[1]))
		if frame_size.x > 0 and frame_size.y > 0:
			return frame_size
	return DEFAULT_FRAME_SIZE


static func _get_mask_image(mount_id: String) -> Image:
	if _mask_image_cache.has(mount_id):
		return _mask_image_cache[mount_id] as Image
	var definition := get_mount_definition(mount_id)
	var mask_path := str(definition.get("riderMaskSheet", ""))
	if mask_path == "" or not ResourceLoader.exists(mask_path):
		return null
	var texture := ResourceLoader.load(mask_path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.get_size() != DEFAULT_FRAME_SIZE * Vector2i(FRAME_COLUMNS, FRAME_ROWS):
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_mask_image_cache[mount_id] = image
	return image


static func _transform_rider_frame(
	source_image: Image,
	mask_image: Image,
	direction_row: int,
	frame_column: int,
	offset: Vector2i
) -> Image:
	if source_image == null:
		return null
	var source := source_image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source_image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var output := Image.create(
		DEFAULT_FRAME_SIZE.x,
		DEFAULT_FRAME_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	output.fill(Color.TRANSPARENT)
	for source_y: int in range(source.get_height()):
		for source_x: int in range(source.get_width()):
			var target_x := source_x + offset.x
			var target_y := source_y + offset.y
			var source_color := source.get_pixel(source_x, source_y)
			if target_x >= 0 and target_y >= 0 \
				and target_x < DEFAULT_FRAME_SIZE.x and target_y < DEFAULT_FRAME_SIZE.y:
				var mask_position := Vector2i(
					frame_column * DEFAULT_FRAME_SIZE.x + target_x,
					direction_row * DEFAULT_FRAME_SIZE.y + target_y
				)
				if mask_image.get_pixelv(mask_position).a > 0.001:
					source_color = Color.TRANSPARENT
			output.set_pixel(source_x, source_y, source_color)
	return output


static func _foreground_region(regions: Dictionary, direction: String) -> Rect2i:
	var region_value: Variant = regions.get(direction, [])
	if not region_value is Array or (region_value as Array).size() < 4:
		return Rect2i()
	var values := region_value as Array
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))


static func _extract_foreground(source_image: Image, region: Rect2i) -> Image:
	var output_size := DEFAULT_FRAME_SIZE
	if source_image != null:
		output_size = source_image.get_size()
	var output := Image.create(
		output_size.x,
		output_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	output.fill(Color.TRANSPARENT)
	if source_image == null or region.size.x <= 0 or region.size.y <= 0:
		return output
	var source := source_image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = source_image.duplicate()
		source.convert(Image.FORMAT_RGBA8)
	var clipped_region := region.intersection(Rect2i(Vector2i.ZERO, output_size))
	if clipped_region.size.x > 0 and clipped_region.size.y > 0:
		output.blit_rect(source, clipped_region, clipped_region.position)
	return output


static func _get_rider_offset(
	rider_offsets: Dictionary,
	direction: String,
	frame_index: int
) -> Vector2i:
	var offsets_value: Variant = rider_offsets.get(direction, [])
	if not offsets_value is Array or (offsets_value as Array).is_empty():
		return Vector2i.ZERO
	var offsets := offsets_value as Array
	var offset_value: Variant = offsets[mini(frame_index, offsets.size() - 1)]
	if not offset_value is Array or (offset_value as Array).size() < 2:
		return Vector2i.ZERO
	return Vector2i(int((offset_value as Array)[0]), int((offset_value as Array)[1]))


static func _get_rider_offset_adjustment(adjustments: Dictionary, direction: String) -> Vector2i:
	var adjustment_value: Variant = adjustments.get(direction, Vector2i.ZERO)
	if adjustment_value is Vector2i:
		return adjustment_value as Vector2i
	if adjustment_value is Vector2:
		return Vector2i(adjustment_value as Vector2)
	return Vector2i.ZERO


static func _direction_from_animation(animation_name: String) -> String:
	for direction: String in ["down", "left", "right", "up"]:
		if animation_name.ends_with("_%s" % direction):
			return direction
	return "down"


static func _direction_row(direction: String) -> int:
	match direction:
		"left":
			return 1
		"right":
			return 2
		"up":
			return 3
		_:
			return 0


static func _build_sprite_frames(texture: Texture2D, frame_size: Vector2i) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for row: int in range(FRAME_ROWS):
		var direction: String = str(["down", "left", "right", "up"][row])
		var idle_name := StringName("idle_%s" % direction)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, IDLE_ANIMATION_SPEED)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, _make_frame_texture(texture, 0, row, frame_size))

		var walk_name := StringName("walk_%s" % direction)
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WALK_ANIMATION_SPEED)
		frames.set_animation_loop(walk_name, true)
		for column: int in range(FRAME_COLUMNS):
			frames.add_frame(walk_name, _make_frame_texture(texture, column, row, frame_size))
	return frames


static func _make_frame_texture(
	texture: Texture2D,
	column: int,
	row: int,
	frame_size: Vector2i
) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(
		Vector2(column * frame_size.x, row * frame_size.y),
		Vector2(frame_size)
	)
	return frame


static func _get_texture_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image := atlas_texture.atlas.get_image()
		if atlas_image == null:
			return null
		var region := atlas_texture.region
		return atlas_image.get_region(Rect2i(
			Vector2i(region.position),
			Vector2i(region.size)
		))
	return texture.get_image()
