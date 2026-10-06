extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var outfits: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/male_adventure_outfits.json"))
	_check(outfits.size() == 6, "all six adaptive outfits are registered")
	for outfit: Dictionary in outfits:
		_check_male_fit(outfit)
		for gender: String in ["male", "female"]:
			_check_outfit(outfit, gender)
	quit(1 if failed else 0)

func _check_male_fit(outfit: Dictionary) -> void:
	# Compare every animation pixel to the existing Starter garments. This catches
	# high/wide hips and boots even when the sheet paths and dimensions are valid.
	for category: String in ["bottom", "shoes"]:
		var starter_id := "Trousers" if category == "bottom" else "Shoes"
		for movement: String in ["walk", "fish", "ride"]:
			var actual := APPEARANCE.get_part_frames(category, outfit["parts"][category], "male", movement)
			var starter := APPEARANCE.get_part_frames(category, starter_id, "male", movement)
			if actual == null or starter == null:
				_check(false, "%s %s fit comparison has both sheets" % [outfit["name"], movement])
				continue
			for direction: String in ["down", "left", "right", "up"]:
				var animation := StringName("walk_" + direction)
				for index: int in range(4):
					var garment := actual.get_frame_texture(animation, index).get_image()
					var reference := starter.get_frame_texture(animation, index).get_image()
					var same_mask := garment.get_size() == reference.get_size()
					if same_mask:
						for y: int in range(reference.get_height()):
							for x: int in range(reference.get_width()):
								if garment.get_pixel(x, y).a != reference.get_pixel(x, y).a:
									same_mask = false
					_check(same_mask, "%s %s %s %s frame %d matches Starter fit" % [outfit["name"], category, movement, direction, index])

func _check_outfit(outfit: Dictionary, gender: String) -> void:
	var parts: Dictionary = outfit["parts"]
	var items: Array[String] = [str(outfit["slug"]) + "-outfit"]
	for part: String in parts.values():
		items.append(str(outfit["slug"]) + "-" + part.get_slice("_", 1).to_lower())
	for category: String in parts:
		var part_id: String = parts[category]
		_check(APPEARANCE.get_available_part_ids(category, gender).has(part_id), "%s is available for %s models" % [part_id, gender])
		_check(not APPEARANCE.is_free_part_id(category, part_id), "%s requires its wardrobe item" % part_id)
		_check(not APPEARANCE.is_tintable_part(category, part_id), "%s keeps its authored colours" % part_id)
		for movement: String in ["walk", "run", "fish", "ride", "surf", "mount"]:
			var suffix := "fish" if movement == "fish" else ("ride" if movement in ["ride", "surf", "mount"] else "")
			var expected := "res://assets/player/%s/%s/%s%s%s.png" % [gender, category, suffix + "/" if not suffix.is_empty() else "", part_id, "_" + suffix if not suffix.is_empty() else ""]
			var frames: SpriteFrames = APPEARANCE.get_part_frames(category, part_id, gender, movement)
			_check(frames != null, "%s loads %s" % [part_id, movement])
			if frames == null:
				continue
			for direction: String in ["down", "left", "right", "up"]:
				var animation := StringName("walk_" + direction)
				_check(frames.get_frame_count(animation) == 4, "%s %s %s has four frames" % [part_id, movement, direction])
				for index: int in range(frames.get_frame_count(animation)):
					var atlas := frames.get_frame_texture(animation, index) as AtlasTexture
					if atlas == null or atlas.atlas.resource_path != expected or atlas.region.size != Vector2(64, 64):
						_check(false, "%s %s uses its own registered sheet, not a starter fallback" % [part_id, movement])
	for item: String in items:
		_check(APPEARANCE.get_cosmetic_item_allowed_genders(item) == ["male", "female"], "%s declares its compatible model" % item)
		for icon_gender: String in ["male", "female"]:
			var icon: Texture2D = APPEARANCE.get_cosmetic_item_icon(item, icon_gender)
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s has a visible %s bag icon" % [item, icon_gender])
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for item: String in items:
			_check(catalog.has(item), "%s has %s item text" % [item, locale])
	for movement: String in ["walk", "fish", "ride"]:
		var sheet := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		var layers: Array[SpriteFrames] = [APPEARANCE.get_body_frames("Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1", gender, movement)]
		for category: String in ["bottom", "shoes", "top", "facegear"]:
			if parts.has(category):
				layers.append(APPEARANCE.get_part_frames(category, parts[category], gender, movement))
		for row: int in range(4):
			for column: int in range(4):
				for frames: SpriteFrames in layers:
					if frames == null:
						continue
					var frame := frames.get_frame_texture(StringName("walk_" + ["down", "left", "right", "up"][row]), column).get_image()
					frame.convert(Image.FORMAT_RGBA8)
					sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(column * 64, row * 64))
		_check(sheet.save_png("user://%s_%s_%s_check.png" % [outfit["slug"], gender, movement]) == OK, "%s %s engine render saved" % [outfit["name"], movement])

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL %s" % label)
	else:
		print("PASS ", label)
