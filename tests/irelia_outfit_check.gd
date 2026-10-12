extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const PARTS := {"top": "Irelia_Shirt", "bottom": "Irelia_Trousers", "shoes": "Irelia_Shoes", "hair": "Irelia_Hair", "headgear": "Irelia_Circlet", "cape": "Irelia_Blades", "cape_overlay": "Irelia_Blades"}
const NODES := {"top": "TopSprite", "bottom": "BottomSprite", "shoes": "ShoesSprite", "hair": "HairSprite", "headgear": "HeadgearSprite", "cape": "CapeSprite", "cape_overlay": "CapeOverlaySprite"}
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var save := root.get_node("PlayerSave")
	var previous: Dictionary = save.to_appearance_state()
	var old_gender: String = save.gender
	for gender: String in ["male", "female"]:
		var appearance := PARTS.duplicate()
		appearance.erase("cape_overlay")
		appearance["gender"] = gender
		var trainer_layers := BATTLE.build_layers(appearance)
		for category: String in PARTS:
			var part_id: String = PARTS[category]
			if category != "cape_overlay":
				_check(APPEARANCE.get_available_part_ids(category, gender).has(part_id), "%s %s registered" % [gender, category])
				_check(not APPEARANCE.is_free_part_id(category, part_id), "%s needs ownership" % category)
			for movement: String in ["walk", "run", "fish", "ride", "surf", "mount", "surf_fish", "pickpocket"]:
				var frames := APPEARANCE.get_part_frames(category, part_id, gender, movement)
				_check(frames != null, "%s %s %s loads" % [gender, category, movement])
				if frames == null:
					continue
				for direction: String in ["down", "left", "right", "up"]:
					var animation := StringName("walk_" + direction)
					_check(frames.get_frame_count(animation) == 4, "%s %s has four %s frames" % [category, movement, direction])
					if category == "hair" and direction == "up":
						for frame: int in range(4):
							var rear_mask := frames.get_frame_texture(animation, frame)
							_check(rear_mask != null and rear_mask.get_image().get_used_rect().has_area(), "%s %s rear hair visible in frame %d" % [gender, movement, frame])
					if movement in ["walk", "fish", "ride"]:
						var suffix := "" if movement == "walk" else movement
						var expected := "res://assets/player/%s/%s/%s%s%s.png" % [gender, category, suffix + "/" if suffix != "" else "", part_id, "_" + suffix if suffix != "" else ""]
						var atlas := frames.get_frame_texture(animation, 0) as AtlasTexture
						_check(atlas != null and atlas.atlas.resource_path == expected, "%s %s uses authored pose" % [category, movement])
			var matching := trainer_layers.filter(func(layer: Dictionary) -> bool: return layer.category == category)
			_check(matching.size() == 1, "%s trainer %s present" % [gender, category])
			if matching.size() == 1:
				var texture := matching[0].get("texture") as Texture2D
				_check(not matching[0].get("fallback", true) and texture != null and texture.get_size() == Vector2(160, 160), "%s trainer uses authored %s" % [gender, category])
		appearance["cape"] = "__none__"
		_check(not BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return str(layer.category).begins_with("cape")), "unequip Back removes both trainer planes")
		_check(BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return layer.category == "hair"), "hair stays equipped without blades")
		for item: String in ["outfit", "shirt", "trousers", "shoes", "hair", "circlet", "blades"]:
			var item_id := "irelia-" + item
			_check(APPEARANCE.get_cosmetic_item_allowed_genders(item_id) == ["male", "female"], "%s supports either gender" % item_id)
			var icon := APPEARANCE.get_cosmetic_item_icon(item_id, gender)
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s %s icon visible" % [gender, item_id])
		# Exercise the real local and remote appearance synchronization paths.
		save.gender = gender
		var local = load("res://scenes/player.tscn").instantiate()
		local.look_node = local.get_node("Look")
		local.call("_cache_appearance_sprites")
		var remote = load("res://scripts/world/remote_player_avatar.gd").new()
		remote.current_body_gender = gender
		for node_name: String in ["BodySprite", "TopSprite", "BottomSprite", "ShoesSprite", "HairSprite", "HeadgearSprite", "CapeSprite", "CapeOverlaySprite"]:
			var sprite := AnimatedSprite2D.new()
			sprite.name = node_name
			remote.add_child(sprite)
			remote.appearance_sprites.append(sprite)
		for actor: Node in [local, remote]:
			var body := actor.call("_get_appearance_sprite", "BodySprite") as AnimatedSprite2D
			body.sprite_frames = APPEARANCE.get_body_frames("Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1", gender)
			var sync_method := "_sync_part_sprite_to_animation" if actor == local else "_sync_sprite_to_body"
			for category: String in PARTS:
				actor.call("_apply_appearance_part", category, PARTS[category], "walk")
				var sprite := actor.call("_get_appearance_sprite", NODES[category]) as AnimatedSprite2D
				var follows := sprite != null and sprite.sprite_frames != null
				for direction: String in ["down", "left", "right", "up"]:
					body.animation = StringName("walk_" + direction)
					for frame: int in range(4):
						body.frame = frame
						actor.call(sync_method, sprite)
						follows = follows and sprite.frame == frame and sprite.animation == body.animation
				_check(follows, "%s %s %s follows every body frame" % [gender, "local" if actor == local else "remote", category])
		for style: String in ["fish", "ride", "surf_fish", "pickpocket"]:
			local.body_sprite_frames_movement_style = style
			remote.current_body_movement_style = style
			for item_id: String in ["Irelia_Hair"]:
				save.appearance_hair_id = item_id
				remote.current_appearance_state = {"hair": item_id}
				for direction: String in ["down", "left", "right", "up"]:
					_check(local._get_activity_layer_offset("hair", direction) == Vector2.ZERO and remote._get_activity_layer_offset("hair", direction) == Vector2.ZERO, "%s %s uses authored head alignment for %s" % [gender, item_id, style])
		for style: String in ["fish", "ride", "surf_fish", "pickpocket"]:
			local.body_sprite_frames_movement_style = style
			remote.current_body_movement_style = style
			save.appearance_headgear_id = "Irelia_Circlet"
			remote.current_appearance_state = {"headgear": "Irelia_Circlet"}
			for direction: String in ["down", "left", "right", "up"]:
				_check(local._get_activity_layer_offset("headgear", direction) == Vector2.ZERO and remote._get_activity_layer_offset("headgear", direction) == Vector2.ZERO, "%s circlet retains its authored %s head alignment" % [gender, style])
		_check(not APPEARANCE.is_tintable_part("hair", "Irelia_Hair"), "Irelia hair keeps its authored colours")
		_check_trainer_colours(gender)
		local.free()
		remote.free()
	save.gender = old_gender
	save.apply_appearance_state(previous)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var texts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for suffix: String in ["outfit", "shirt", "trousers", "shoes", "hair", "circlet", "blades"]:
			_check(texts.has("irelia-" + suffix), "%s has %s text" % [locale, suffix])
	var encoded := APPEARANCE.encode_presence_body_with_appearance("Gen4_Base_v1", PARTS)
	var decoded := APPEARANCE.decode_presence_body_appearance(encoded)
	_check(decoded.get("cape") == PARTS.cape and decoded.get("hair") == PARTS.hair, "Back and hair travel with multiplayer presence")
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)


func _check_trainer_colours(gender: String) -> void:
	var state := PARTS.duplicate()
	state.erase("cape_overlay")
	state["gender"] = gender
	state["hair_color"] = "#ff00ff"
	var source_hair := load("res://assets/battles/trainers/player/%s/irelia/Hair.png" % gender) as Texture2D
	var hair_layer: Dictionary = BATTLE.build_layers(state).filter(func(layer: Dictionary) -> bool: return layer.category == "hair")[0]
	_check(hair_layer.texture.get_image().get_data() == source_hair.get_image().get_data(), "%s trainer hair ignores ordinary hair tint" % gender)
	for category: String in PARTS:
		var variants: Array[Dictionary] = BATTLE.build_layers(state).filter(func(layer: Dictionary) -> bool: return layer.category == category)
		var layer: Dictionary = variants[0]
		var original := load("res://assets/battles/trainers/player/%s/irelia/%s.png" % [gender, {"top": "Shirt", "bottom": "Trousers", "shoes": "Shoes", "hair": "Hair", "headgear": "Headgear", "cape": "BackRear", "cape_overlay": "BackFront"}[category]]) as Texture2D
		_check(layer.texture.get_image().get_data() == original.get_image().get_data(), "%s %s preserves approved fixed colours" % [gender, category])
	var portrait := BATTLE.build_dialogue_portrait(state)
	_check(portrait != null and portrait.get_image().get_used_rect().has_area(), "%s trainer portrait renders" % gender)
	portrait.get_image().save_png("user://irelia-%s-trainer.png" % gender)
