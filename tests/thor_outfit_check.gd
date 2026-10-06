extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const EFFECT := preload("res://scripts/world/thor_accessory_effect.gd")
const PARTS := {"top": "Thor_Shirt", "bottom": "Thor_Trousers", "shoes": "Thor_Shoes", "cape": "Thor_Hammer"}
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var save := root.get_node("PlayerSave")
	var previous: Dictionary = save.to_appearance_state()
	var old_gender: String = save.gender
	for gender: String in ["male", "female"]:
		_check_cape_origin(gender)
		for category: String in PARTS:
			_check(APPEARANCE.get_available_part_ids(category, gender).has(PARTS[category]), "%s %s registered" % [gender, category])
			_check(not APPEARANCE.is_free_part_id(category, PARTS[category]), "%s requires ownership" % category)
			for movement: String in ["walk", "run", "fish", "ride", "surf", "mount", "surf_fish", "pickpocket"]:
				var frames := APPEARANCE.get_part_frames(category, PARTS[category], gender, movement)
				_check(frames != null, "%s %s %s loads" % [gender, category, movement])
				if frames == null:
					continue
				for direction: String in ["down", "left", "right", "up"]:
					_check(frames.get_frame_count(StringName("walk_" + direction)) == 4, "four %s %s frames" % [category, direction])
		for category: String in ["bottom", "shoes"]:
			for movement: String in ["walk", "fish", "ride"]:
				var frames := APPEARANCE.get_part_frames(category, PARTS[category], gender, movement)
				var starter := APPEARANCE.get_part_frames(category, "Trousers" if category == "bottom" else "Shoes", gender, movement)
				for direction: String in ["down", "left", "right", "up"]:
					for c: int in range(4):
						var animation := StringName("walk_" + direction)
						var a := frames.get_frame_texture(animation, c).get_image()
						var b := starter.get_frame_texture(animation, c).get_image()
						var matches := true
						for y: int in range(64):
							for x: int in range(64):
								matches = matches and a.get_pixel(x, y).a == b.get_pixel(x, y).a
						_check(matches, "%s %s %s %s %d Starter fit" % [gender, category, movement, direction, c])
		for suffix: String in ["shirt", "trousers", "shoes", "hammer", "outfit"]:
			var icon := APPEARANCE.get_cosmetic_item_icon("thor-" + suffix, gender)
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s %s inventory icon" % [gender, suffix])
		var appearance := PARTS.duplicate()
		appearance["gender"] = gender
		var layers := BATTLE.build_layers(appearance)
		_check(layers.any(func(layer: Dictionary) -> bool: return layer.category == "cape"), "trainer rear cape")
		_check(layers.any(func(layer: Dictionary) -> bool: return layer.category == "cape_overlay"), "trainer hammer follows cape")
		appearance["cape"] = "__none__"
		_check(not BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return str(layer.category).begins_with("cape")), "trainer unequip removes hammer and cape")
		save.gender = gender
		var local = load("res://scenes/player.tscn").instantiate()
		local.look_node = local.get_node("Look")
		local.call("_cache_appearance_sprites")
		var remote = load("res://scripts/world/remote_player_avatar.gd").new()
		remote.current_body_gender = gender
		for node_name: String in ["BodySprite", "CapeSprite", "CapeOverlaySprite"]:
			var sprite := AnimatedSprite2D.new()
			sprite.name = node_name
			remote.add_child(sprite)
			remote.appearance_sprites.append(sprite)
		for actor: Node in [local, remote]:
			var body := actor.call("_get_appearance_sprite", "BodySprite") as AnimatedSprite2D
			body.sprite_frames = APPEARANCE.get_body_frames("Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1", gender)
			var sync_method := "_sync_part_sprite_to_animation" if actor == local else "_sync_sprite_to_body"
			for category: String in ["cape", "cape_overlay"]:
				actor.call("_apply_appearance_part", category, "Thor_Hammer", "walk")
				var sprite := actor.call("_get_appearance_sprite", "CapeSprite" if category == "cape" else "CapeOverlaySprite") as AnimatedSprite2D
				var effect := sprite.get_node(EFFECT.NODE_NAME)
				_check(effect != null and sprite.self_modulate.a == 0, "local/remote custom cape active")
				for direction: String in ["down", "left", "right", "up"]:
					body.animation = StringName("walk_" + direction)
					actor.call(sync_method, sprite)
					effect.advance(0.2)
					_check(effect.pose == 2, "%s walking raises cape" % direction)
					for frame: int in range(4):
						body.frame = frame
						actor.call(sync_method, sprite)
						effect.advance(0.0)
						_check(effect.column == frame, "cape and hammer follow body frame")
					body.animation = StringName("idle_" + direction)
					actor.call(sync_method, sprite)
					effect.advance(0.12)
					_check(effect.pose == 1, "stop transitions through halfway cape")
					effect.advance(0.3)
					_check(effect.pose == 0, "cape settles at rest")
				actor.call("_apply_appearance_part", category, "Thor_Hammer", "fish")
				_check(sprite.get_node_or_null(EFFECT.NODE_NAME) == null and sprite.self_modulate.a == 1, "fishing uses folded authored cape without walk effects")
				actor.call("_apply_appearance_part", category, "Thor_Hammer", "run")
				_check(sprite.get_node_or_null(EFFECT.NODE_NAME) != null, "running restores animated accessory")
				actor.call("_apply_appearance_part", category, "AetherRoyal_Cape", "walk")
				_check(sprite.get_node_or_null(EFFECT.NODE_NAME) == null and sprite.self_modulate.a == 1, "switching cape removes all Thor effects")
				actor.call("_apply_appearance_part", category, "Thor_Hammer", "walk")
				actor.call("_clear_appearance_part_sprite", category)
				_check(sprite.get_node_or_null(EFFECT.NODE_NAME) == null and not sprite.visible, "unequip removes cloth, hammer and sparks")
		local.free()
		remote.free()
	save.gender = old_gender
	save.apply_appearance_state(previous)
	var encoded := APPEARANCE.encode_presence_body_with_appearance("Gen4_Base_v1", {"cape": "Thor_Hammer"})
	_check(APPEARANCE.decode_presence_body_appearance(encoded).get("cape") == "Thor_Hammer", "hammer travels with multiplayer appearance")
	await process_frame
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)

# Expanded effect sheets must settle at the exact wardrobe origin, without a
# pop when switching to folded/static rendering. Compare every frame and plane.
func _check_cape_origin(gender: String) -> void:
	for category: String in ["cape", "cape_overlay"]:
		var static_image := (load("res://assets/player/%s/%s/Thor_Hammer.png" % [gender, category]) as Texture2D).get_image()
		var idle_image := (load("%s/%s/%s_0.png" % [EFFECT.ASSET_ROOT, gender, category]) as Texture2D).get_image()
		var size := idle_image.get_width() / 4
		var padding := (size - 64) / 2
		for direction: int in range(4):
			for frame: int in range(4):
				var expected := Image.create(size, size, false, Image.FORMAT_RGBA8)
				expected.blit_rect(static_image, Rect2i(frame * 64, direction * 64, 64, 64), Vector2i(padding, padding))
				var actual := idle_image.get_region(Rect2i(frame * size, direction * size, size, size))
				_check(expected.get_data() == actual.get_data(), "%s %s idle keeps body origin %d/%d" % [gender, category, direction, frame])
