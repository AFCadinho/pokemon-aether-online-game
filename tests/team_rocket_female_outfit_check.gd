extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const PARTS := {"top": "TeamRocket_Shirt", "bottom": "TeamRocket_Trousers", "shoes": "TeamRocket_Shoes", "headgear": "TeamRocket_Cap", "hair": "TeamRocketFemale_Hair"}
const ITEMS := ["team-rocket-female-outfit", "team-rocket-female-shirt", "team-rocket-female-skirt", "team-rocket-female-boots", "team-rocket-female-cap", "team-rocket-female-hair"]
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for category: String in PARTS:
		var part_id: String = PARTS[category]
		_check(APPEARANCE.get_available_part_ids(category, "female").has(part_id), "%s is available for female models" % part_id)
		_check(APPEARANCE.get_available_part_ids(category, "male").has(part_id) == (category != "hair"), "%s shares ownership except for the optional bob" % part_id)
		_check(not APPEARANCE.is_free_part_id(category, part_id), "%s requires its wardrobe item" % part_id)
		_check(not APPEARANCE.is_tintable_part(category, part_id), "%s keeps its authored colours" % part_id)
		for movement: String in ["walk", "run", "fish", "ride", "surf", "mount"]:
			var suffix := "fish" if movement == "fish" else ("ride" if movement in ["ride", "surf", "mount"] else "")
			var sprite_id := APPEARANCE.VARIANTS.render_part_id(category, part_id, "female")
			var expected := "res://assets/player/female/%s/%s%s%s.png" % [category, suffix + "/" if not suffix.is_empty() else "", sprite_id, "_" + suffix if not suffix.is_empty() else ""]
			var frames: SpriteFrames = APPEARANCE.get_part_frames(category, part_id, "female", movement)
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
	var appearance := PARTS.duplicate()
	appearance["gender"] = "female"
	var battle_layers: Array[Dictionary] = BATTLE.build_layers(appearance)
	for category: String in PARTS:
		var found := false
		for layer: Dictionary in battle_layers:
			if str(layer.get("category")) != category:
				continue
			var texture := layer.get("texture") as Texture2D
			found = str(layer.get("part_id")) == APPEARANCE.VARIANTS.render_part_id(category, PARTS[category], "female") and str(layer.get("requested_part_id")) == PARTS[category] and not bool(layer.get("fallback", true)) and texture != null and texture.get_size() == Vector2(160, 160) and is_equal_approx(float(layer.get("scale", 0)), 1.0)
		_check(found, "%s resolves its 160px trainer sprite without fallback" % category)
	appearance["gender"] = "male"
	for layer: Dictionary in BATTLE.build_layers(appearance):
		_check(not str(layer.get("part_id", "")).begins_with("TeamRocketFemale_"), "male trainer does not use female Team Rocket art")
	for item: String in ITEMS:
		var expected_genders := ["female"] if item == "team-rocket-female-hair" else ["male", "female"]
		_check(APPEARANCE.get_cosmetic_item_allowed_genders(item) == expected_genders, "%s declares its compatible model" % item)
		for gender: String in ["female", "male"]:
			var icon: Texture2D = APPEARANCE.get_cosmetic_item_icon(item, gender)
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s has a visible %s bag icon" % [item, gender])
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for item: String in ITEMS:
			_check(catalog.has(item), "%s has %s item text" % [item, locale])
	var store_source := FileAccess.get_file_as_string("res://scripts/ui/donator_store_popup.gd")
	_check(not store_source.contains("team-rocket-female-outfit"), "Team Rocket box is absent from the store fallback catalog")
	_check_fit()
	_save_render_previews(battle_layers)
	quit(1 if failed else 0)


func _save_render_previews(battle_layers: Array[Dictionary]) -> void:
	var trainer := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	for layer: Dictionary in battle_layers:
		var texture := layer.get("texture") as Texture2D
		if texture != null:
			var image := texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			trainer.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	_check(trainer.save_png("user://team_rocket_female_trainer_check.png") == OK, "trainer render preview saved")
	for movement: String in ["walk", "fish", "ride"]:
		var layers: Array[SpriteFrames] = [APPEARANCE.get_body_frames("Gen4_Base_F_v1", "female", movement)]
		for category: String in ["bottom", "shoes", "top", "hair", "headgear"]:
			layers.append(APPEARANCE.get_part_frames(category, PARTS[category], "female", movement))
		var sheet := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		var row := 0
		for direction: String in ["down", "left", "right", "up"]:
			for column: int in range(4):
				for frames: SpriteFrames in layers:
					if frames == null:
						continue
					var image := frames.get_frame_texture(StringName("walk_" + direction), column).get_image()
					image.convert(Image.FORMAT_RGBA8)
					sheet.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(column * 64, row * 64))
			row += 1
		_check(sheet.save_png("user://team_rocket_female_%s_check.png" % movement) == OK, "%s render preview saved" % movement)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)


func _check_fit() -> void:
	var body := (load("res://assets/player/female/body/Gen4_Base_F_v1.png") as Texture2D).get_image()
	var boots := (load("res://assets/player/female/shoes/TeamRocketFemale_Boots.png") as Texture2D).get_image()
	var top := (load("res://assets/player/female/top/TeamRocketFemale_Shirt.png") as Texture2D).get_image()
	for row: int in range(4):
		for col: int in range(4):
			var covered := true
			for y: int in range(58, 64):
				for x: int in range(12, 52):
					var point := Vector2i(col * 64 + x, row * 64 + y)
					if body.get_pixelv(point).a > 0.5:
						covered = covered and boots.get_pixelv(point).a > 0.5
			_check(covered, "female boots cover the body toes row %s frame %s" % [row, col])
			if row in [0, 3]:
				var y := 42 - (2 if col % 2 else 0)
				_check(top.get_pixel(col * 64 + 30, row * 64 + y).a == 0, "female collar leaves the neck visible")
	var save := root.get_node("PlayerSave")
	var previous_gender: String = save.gender
	var previous_hair: String = save.appearance_hair_id
	var previous_hat: String = save.appearance_headgear_id
	save.gender = "female"
	save.appearance_hair_id = "TeamRocketFemale_Hair"
	save.appearance_headgear_id = "TeamRocketFemale_Cap"
	var local = load("res://scenes/player.tscn").instantiate()
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	remote.current_body_gender = "female"
	remote.current_appearance_state = {"hair": "TeamRocketFemale_Hair", "headgear": "TeamRocketFemale_Cap"}
	for style: String in ["fish", "ride"]:
		local.body_sprite_frames_movement_style = style
		remote.current_body_movement_style = style
		for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			local.last_direction = direction
			remote.last_direction = direction
			for category: String in ["hair", "headgear"]:
				_check(local._get_activity_layer_offset(category) == Vector2.ZERO and remote._get_activity_layer_offset(category) == Vector2.ZERO, "authored female %s follows %s head without an extra offset" % [category, style])
	local.free()
	remote.free()
	save.gender = previous_gender
	save.appearance_hair_id = previous_hair
	save.appearance_headgear_id = previous_hat
