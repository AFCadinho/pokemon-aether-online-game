extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const PARTS := {"top": "EmeraldLuchador_Shirt", "bottom": "EmeraldLuchador_Trousers", "shoes": "EmeraldLuchador_Shoes", "facegear": "EmeraldLuchador_Mask", "cape": "EmeraldLuchador_Wings", "cape_overlay": "EmeraldLuchador_Wings"}
const NODES := {"top": "TopSprite", "bottom": "BottomSprite", "shoes": "ShoesSprite", "facegear": "FaceGearSprite", "cape": "CapeSprite", "cape_overlay": "CapeOverlaySprite"}
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
		_check(BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return layer.category == "facegear"), "mask stays equipped without wings")
		for item: String in ["outfit", "shirt", "trousers", "shoes", "mask", "wings"]:
			var item_id := "emerald-luchador-" + item
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
		for node_name: String in ["BodySprite", "TopSprite", "BottomSprite", "ShoesSprite", "FaceGearSprite", "CapeSprite", "CapeOverlaySprite"]:
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
			for item_id: String in ["EmeraldLuchador_Mask", "RotomEngineer_Goggles", "LugiaSkyCaptain_Goggles"]:
				save.appearance_facegear_id = item_id
				remote.current_appearance_state = {"facegear": item_id}
				for direction: String in ["down", "left", "right", "up"]:
					_check(local._get_activity_layer_offset("facegear", direction) == Vector2.ZERO and remote._get_activity_layer_offset("facegear", direction) == Vector2.ZERO, "%s %s uses authored head alignment for %s" % [gender, item_id, style])
			if style in ["fish", "ride"]:
				save.appearance_facegear_id = "Adinho_Glasses"
				remote.current_appearance_state = {"facegear": "Adinho_Glasses"}
				var expected: Vector2 = local.ACTIVITY_LAYER_OFFSETS[style]["left"]["facegear"]
				_check(expected != Vector2.ZERO and local._get_activity_layer_offset("facegear", "left") == expected and remote._get_activity_layer_offset("facegear", "left") == expected, "legacy glasses keep %s fallback alignment" % style)
		local.free()
		remote.free()
	save.gender = old_gender
	save.apply_appearance_state(previous)
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var texts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		for suffix: String in ["outfit", "shirt", "trousers", "shoes", "mask", "wings"]:
			_check(texts.has("emerald-luchador-" + suffix), "%s has %s text" % [locale, suffix])
	var encoded := APPEARANCE.encode_presence_body_with_appearance("Gen4_Base_v1", PARTS)
	var decoded := APPEARANCE.decode_presence_body_appearance(encoded)
	_check(decoded.get("cape") == PARTS.cape and decoded.get("facegear") == PARTS.facegear, "Back and mask travel with multiplayer presence")
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
