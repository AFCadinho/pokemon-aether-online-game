extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const PARTS := {"top": "Fishing_Guru_Vest", "bottom": "Fishing_Guru_Trousers", "shoes": "Fishing_Guru_Shoes", "hair": "Fishing_Guru_Hair", "headgear": "Fishing_Guru_Hat", "cape": "Fishing_Guru_Rod", "cape_overlay": "Fishing_Guru_Rod"}
const NODES := {"top": "TopSprite", "bottom": "BottomSprite", "shoes": "ShoesSprite", "hair": "HairSprite", "headgear": "HeadgearSprite", "cape": "CapeSprite", "cape_overlay": "CapeOverlaySprite"}
const ITEMS := ["outfit", "shirt", "trousers", "shoes", "hair", "hat", "rod"]
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var save := root.get_node("PlayerSave")
	var previous: Dictionary = save.to_appearance_state()
	var old_gender: String = save.gender
	save.gender = "male"
	var state := PARTS.duplicate()
	state.erase("cape_overlay")
	state["gender"] = "male"
	state["hair_color"] = "#ff00ff"
	var trainer := BATTLE.build_layers(state)
	for category: String in PARTS:
		var part_id: String = PARTS[category]
		if category != "cape_overlay":
			_check(APPEARANCE.get_available_part_ids(category, "male").has(part_id), category + " registered")
			_check(not APPEARANCE.get_available_part_ids(category, "female").has(part_id), category + " has no unsupported female variant")
			_check(not APPEARANCE.is_free_part_id(category, part_id), category + " requires ownership")
		for movement: String in ["walk", "run", "fish", "ride", "surf", "mount", "surf_fish", "pickpocket"]:
			var frames := APPEARANCE.get_part_frames(category, part_id, "male", movement)
			_check(frames != null, "%s/%s resolves" % [category, movement])
			if frames == null:
				continue
			var pose := APPEARANCE.resolve_layer_movement_style(movement, category)
			var suffix := "" if pose == "walk" else "_" + pose
			var directory := "" if pose == "walk" else pose + "/"
			var expected := "res://assets/player/male/%s/%s%s%s.png" % [category, directory, part_id, suffix]
			for direction: String in ["down", "left", "right", "up"]:
				var animation := StringName("walk_" + direction)
				_check(frames.get_frame_count(animation) == 4, "%s/%s/%s has four frames" % [category, movement, direction])
				var atlas := frames.get_frame_texture(animation, 0) as AtlasTexture
				_check(atlas != null and atlas.atlas.resource_path == expected, "%s/%s uses authored texture" % [category, movement])
				if category == "cape" and pose == "fish":
					_check(not frames.get_frame_texture(animation, 0).get_image().get_used_rect().has_area(), "carried rod hidden while fishing")
		var matches := trainer.filter(func(layer: Dictionary) -> bool: return layer.category == category)
		_check(matches.size() == 1, "trainer " + category + " present")
		if matches.size() == 1:
			var layer: Dictionary = matches[0]
			_check(layer.part_id == part_id and not layer.fallback, "trainer " + category + " uses requested art")
			var texture := layer.texture as Texture2D
			_check(texture.get_size() == Vector2(160, 160), "trainer " + category + " full canvas")
			var source_path := str(BATTLE._get_manifest().genders.male.categories[category].parts[part_id].path)
			var source := load(source_path) as Texture2D
			_check(texture.get_image().get_data() == source.get_image().get_data(), "trainer " + category + " keeps fixed colours")
		_check(not APPEARANCE.is_tintable_part(category, part_id), category + " fixed colours")
	_check(trainer[0].category == "cape", "trainer rod behind body")
	state["cape"] = "__none__"
	_check(not BATTLE.build_layers(state).any(func(layer: Dictionary) -> bool: return str(layer.category).begins_with("cape")), "removing rod removes both planes")
	state["cape"] = PARTS.cape
	var portrait := BATTLE.build_dialogue_portrait(state)
	_check(portrait != null and portrait.get_image().get_used_rect().has_area(), "trainer portrait renders")
	if portrait != null:
		_check_protected_trainer_pixels(trainer, portrait.get_image())
	var review_dir := OS.get_environment("POKEAETHER_ART_REVIEW_DIR")
	if review_dir.is_empty():
		review_dir = "user://"
	DirAccess.make_dir_recursive_absolute(review_dir)
	if portrait != null:
		portrait.get_image().save_png(review_dir.path_join("fishing-guru-trainer-portrait.png"))
	for suffix: String in ITEMS:
		var item_id := "fishing-guru-" + suffix
		_check(APPEARANCE.get_cosmetic_item_allowed_genders(item_id) == ["male"], item_id + " male eligibility")
		var icon := APPEARANCE.get_cosmetic_item_icon(item_id, "male")
		_check(icon != null and icon.get_image().get_used_rect().has_area(), item_id + " icon visible")
		if icon != null:
			icon.get_image().save_png(review_dir.path_join("%s-icon.png" % item_id))
	var local = load("res://scenes/player.tscn").instantiate()
	local.look_node = local.get_node("Look")
	local.call("_cache_appearance_sprites")
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	remote.current_body_gender = "male"
	for node_name: String in ["BodySprite", "TopSprite", "BottomSprite", "ShoesSprite", "HairSprite", "HeadgearSprite", "CapeSprite", "CapeOverlaySprite"]:
		var sprite := AnimatedSprite2D.new()
		sprite.name = node_name
		remote.add_child(sprite)
		remote.appearance_sprites.append(sprite)
	for actor: Node in [local, remote]:
		var body := actor.call("_get_appearance_sprite", "BodySprite") as AnimatedSprite2D
		body.sprite_frames = APPEARANCE.get_body_frames("Gen4_Base_v1", "male")
		for category: String in PARTS:
			actor.call("_apply_appearance_part", category, PARTS[category], "walk")
			var sprite := actor.call("_get_appearance_sprite", NODES[category]) as AnimatedSprite2D
			var follows := sprite != null and sprite.sprite_frames != null
			for direction: String in ["down", "left", "right", "up"]:
				body.animation = StringName("walk_" + direction)
				for frame: int in range(4):
					body.frame = frame
					actor.call("_sync_part_sprite_to_animation" if actor == local else "_sync_sprite_to_body", sprite)
					follows = follows and sprite.frame == frame and sprite.animation == body.animation
			_check(follows, ("local " if actor == local else "remote ") + category + " follows body")
	for style: String in ["fish", "ride", "surf_fish", "pickpocket"]:
		local.body_sprite_frames_movement_style = style
		remote.current_body_movement_style = style
		for category: String in ["hair", "headgear"]:
			save.set("appearance_" + category + "_id", PARTS[category])
			remote.current_appearance_state = {category: PARTS[category]}
			for direction: String in ["down", "left", "right", "up"]:
				_check(local._get_activity_layer_offset(category, direction) == Vector2.ZERO and remote._get_activity_layer_offset(category, direction) == Vector2.ZERO, category + "/" + style + " keeps authored head alignment")
	local.free()
	remote.free()
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var texts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for suffix: String in ITEMS:
			_check(texts.has("fishing-guru-" + suffix), locale + " " + suffix + " translation")
	var decoded := APPEARANCE.decode_presence_body_appearance(APPEARANCE.encode_presence_body_with_appearance("Gen4_Base_v1", state))
	_check(decoded.get("cape") == PARTS.cape and decoded.get("headgear") == PARTS.headgear, "rod and hat serialize for multiplayer")
	save.gender = old_gender
	save.apply_appearance_state(previous)
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)

func _check_protected_trainer_pixels(layers: Array[Dictionary], portrait: Image) -> void:
	var reference := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	var body_image: Image
	for layer: Dictionary in layers:
		if str(layer.category) in ["body", "hair", "eyebrows"]:
			var image := (layer.texture as Texture2D).get_image()
			reference.blend_rect(image, Rect2i(0, 0, 160, 160), Vector2i.ZERO)
			if layer.category == "body":
				body_image = image
	var dressed := portrait.duplicate() as Image
	dressed.flip_x() # Portrait orientation is handled by the actual catalog.
	var changed := 0
	for y: int in range(160):
		for x: int in range(160):
			var point := Vector2i(x >> 1, y >> 1)
			var protected := Rect2i(36, 16, 17, 9).has_point(point) or Rect2i(21, 18, 6, 11).has_point(point) or Rect2i(50, 40, 6, 9).has_point(point)
			if protected and body_image.get_pixel(x, y).a > 0.0 and dressed.get_pixel(x, y) != reference.get_pixel(x, y):
				changed += 1
	_check(changed == 0, "trainer preserves face, ball and free-hand pixels")
