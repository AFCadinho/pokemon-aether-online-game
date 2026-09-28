extends SceneTree

const APPEARANCE := preload("res://scripts/services/character_appearance_service.gd")
const BATTLE := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const PARTS := {"top": "AetherRoyal_Shirt", "bottom": "AetherRoyal_Trousers", "shoes": "AetherRoyal_Shoes", "headgear": "AetherRoyal_Crown", "cape": "AetherRoyal_Cape"}
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var save := root.get_node("PlayerSave")
	var previous: Dictionary = save.to_appearance_state()
	var previous_gender: String = save.gender
	for gender: String in ["male", "female"]:
		var appearance := PARTS.duplicate()
		appearance["gender"] = gender
		appearance["body"] = "Gen4_Base_F_v1" if gender == "female" else "Gen4_Base_v1"
		for category: String in PARTS:
			_check(APPEARANCE.get_available_part_ids(category, gender).has(PARTS[category]), "%s %s registered" % [gender, category])
			_check(not APPEARANCE.is_free_part_id(category, PARTS[category]), "%s requires unlock" % category)
		for category: String in ["top", "bottom", "shoes", "headgear", "cape", "cape_overlay"]:
			var part_id: String = PARTS["cape" if category == "cape_overlay" else category]
			for movement: String in ["walk", "fish", "ride", "surf", "mount", "surf_fish", "pickpocket"]:
				var style := APPEARANCE.resolve_layer_movement_style(movement, category)
				var frames := APPEARANCE.get_part_frames(category, part_id, gender, movement)
				_check(frames != null, "%s %s %s loads" % [gender, category, movement])
				if frames == null:
					continue
				for direction: String in ["down", "left", "right", "up"]:
					var anim := StringName("walk_" + direction)
					_check(frames.get_frame_count(anim) == 4, "%s has four %s frames" % [category, direction])
					var atlas := frames.get_frame_texture(anim, 0) as AtlasTexture
					var suffix := "" if style == "walk" else "_%s" % style
					_check(atlas != null and atlas.atlas.resource_path.ends_with(part_id + suffix + ".png"), "authored %s %s sheet" % [category, movement])
		var layers := BATTLE.build_layers(appearance)
		var categories: Array[String] = []
		for layer: Dictionary in layers:
			categories.append(str(layer.category))
			_check(not bool(layer.get("fallback", false)), "royal trainer layer resolves without fallback")
		_check(categories.find("cape") < categories.find("body"), "trainer cape is behind the body")
		_check(categories.find("cape_overlay") > categories.find("top"), "trainer mantle overlays clothing")
		appearance["top"] = "Shirt"
		_check(BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return layer.category == "cape"), "cape works with starter shirt")
		appearance["cape"] = "__none__"
		_check(not BATTLE.build_layers(appearance).any(func(layer: Dictionary) -> bool: return str(layer.category).begins_with("cape")), "unequipping cape removes both trainer layers")
		for key: String in ["outfit", "shirt", "trousers", "shoes", "crown", "cape"]:
			var icon := APPEARANCE.get_cosmetic_item_icon("aether-royal-" + key, gender)
			_check(icon != null and icon.get_image().get_used_rect().has_area(), "%s %s has inventory icon" % [gender, key])
		# Exercise the local selection path: the auxiliary mantle must follow equip AND unequip.
		save.gender = gender
		save.apply_appearance_state(appearance)
		var player = load("res://scenes/player.tscn").instantiate()
		player.look_node = player.get_node("Look")
		player.call("_cache_appearance_sprites")
		player.set_appearance_part("cape", "AetherRoyal_Cape")
		var rear := player.get_node("Look/Rider/CapeSprite") as AnimatedSprite2D
		var overlay := player.get_node("Look/Rider/CapeOverlaySprite") as AnimatedSprite2D
		_check(rear.visible and overlay.visible and rear.sprite_frames != null and overlay.sprite_frames != null, "local cape equips both layers")
		_check(rear.get_index() < player.get_node("Look/Rider/BodySprite").get_index(), "rear cape draws before body")
		player.set_appearance_part("cape", "")
		_check(not rear.visible and not overlay.visible, "local cape unequips both layers")
		player.free()
		var remote = load("res://scripts/world/remote_player_avatar.gd").new()
		var a := {"body": appearance.body}
		var signature: String = remote.call("_get_appearance_signature", a)
		a["cape"] = "AetherRoyal_Cape"
		_check(signature != str(remote.call("_get_appearance_signature", a)), "remote appearance updates when only cape changes")
		remote.free()
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/items/%s.json" % locale))
		_check(items.has("aether-royal-cape") and items.has("aether-royal-outfit"), "%s item localization" % locale)
	var encoded := APPEARANCE.encode_presence_body_with_appearance("Gen4_Base_v1", {"cape": "AetherRoyal_Cape"})
	_check(APPEARANCE.decode_presence_body_appearance(encoded).get("cape") == "AetherRoyal_Cape", "cape survives presence encoding")
	save.gender = previous_gender
	save.apply_appearance_state(previous)
	print("Aether Royal independent cape checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + label)
