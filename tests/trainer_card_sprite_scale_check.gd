extends SceneTree

const OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"
const CATALOG := preload("res://scripts/battle/battle_ui/battle_player_trainer_catalog.gd")
const VARIANTS := preload("res://scripts/services/cosmetic_variant_catalog.gd")
const SLOTS: Array[String] = ["bottom", "shoes", "top", "hair", "facial_hair", "headgear", "facegear", "cape"]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Load after autoloads are initialized, without constructing the full HUD.
	var overlay_script := load(OVERLAY_SCRIPT) as Script
	if overlay_script == null or not overlay_script.can_instantiate():
		push_error("Trainer Card overlay failed to compile")
		quit(1)
		return
	var overlay = overlay_script.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(184, 272)
	viewport.transparent_bg = true
	root.add_child(viewport)
	var capture_dir := OS.get_environment("POKEAETHER_TRAINER_SCALE_CAPTURE")
	var capture_display: TextureRect
	if not capture_dir.is_empty():
		root.show()
		capture_display = TextureRect.new()
		capture_display.texture = viewport.get_texture()
		root.add_child(capture_display)
	var covered: Dictionary = {}
	var cases := _catalog_cases()
	for entry: Dictionary in cases:
		var gender := str(entry["gender"])
		var outfit := str(entry["name"])
		var appearance: Dictionary = entry["appearance"]
		for layer: Dictionary in CATALOG.build_layers(appearance):
			if str(layer["category"]) != "body":
				covered["%s/%s/%s" % [gender, layer["category"], layer["part_id"]]] = true
		for species: String in ["", "pikachu"]:
			var profile := {"favoritePokemon": species}
			overlay.set("own_trainer_card_data", profile)
			for preview: String in ["TrainerCardBattlePreview", "PublicTrainerAvatarPreview"]:
				overlay.call("_populate_trainer_card_battle_art", viewport, appearance, preview, profile)
				var art := viewport.get_node(preview) as Node2D
				var context := "%s %s %s companion=%s" % [gender, outfit, preview, species]
				var expected_scale := 1.5 if species.is_empty() else 1.0
				_check(art.scale == Vector2.ONE * expected_scale, "%s keeps the shared trainer scale" % context)
				var body := art.get_node("Body") as Sprite2D
				var feet_y := (body.texture.get_image().get_used_rect().end.y - body.texture.get_height() * 0.5) * art.scale.y + art.position.y
				_check(is_equal_approx(feet_y, 248.0 if species.is_empty() else 238.0), "%s keeps the foot baseline" % context)
				var visible_bounds := _visible_bounds(art)
				_check(visible_bounds.position.y >= 0.0 and visible_bounds.end.y <= viewport.size.y, "%s fits vertically" % context)
				_check(visible_bounds.position.x >= 0.0 and visible_bounds.end.x <= viewport.size.x, "%s fits horizontally including accessories" % context)
				if species.is_empty():
					_check(absf(visible_bounds.get_center().x - 92.0) <= 0.5, "%s centers only visible layers" % context)
				else:
					_check(viewport.get_node_or_null("FavoritePokemon") is Sprite2D, "%s renders the companion" % context)
				if not capture_dir.is_empty() and preview == "TrainerCardBattlePreview" and bool(entry["full_outfit"]):
					viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
					await process_frame
					await process_frame
					RenderingServer.force_draw()
					viewport.get_texture().get_image().save_png(capture_dir.path_join("%s-%s-%s.png" % [gender, outfit, "solo" if species.is_empty() else "companion"]))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG.MANIFEST_PATH))
	for gender: String in manifest["genders"]:
		for category: String in manifest["genders"][gender]["categories"]:
			for part_id: String in manifest["genders"][gender]["categories"][category]["parts"]:
				var key := "%s/%s/%s" % [gender, category, part_id]
				_check(covered.has(key), "catalog layer exercised: %s" % key)
	print("CATALOG cases=%s layers=%s" % [cases.size(), covered.size()])
	if capture_display != null:
		capture_display.free()
	viewport.free()
	overlay.free()
	quit(1 if failed else 0)


func _catalog_cases() -> Array[Dictionary]:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG.MANIFEST_PATH))
	var cases: Array[Dictionary] = []
	for gender: String in manifest["genders"]:
		var categories: Dictionary = manifest["genders"][gender]["categories"]
		for top_id: String in categories["top"]["parts"]:
			var appearance := _starter(gender)
			var prefix := top_id.trim_suffix("_Chroma").trim_suffix("_Shirt").trim_suffix("_Dress")
			if top_id != "Shirt":
				appearance["headgear"] = "__none__"
				for category: String in SLOTS:
					var parts: Dictionary = categories.get(category, {}).get("parts", {})
					var candidates: Array[String] = []
					for candidate: String in parts:
						if candidate.begins_with(prefix + "_"):
							candidates.append(candidate)
					if not candidates.is_empty():
						var selected := candidates[0]
						for candidate: String in candidates:
							if candidate.ends_with("_Chroma") == top_id.ends_with("_Chroma"):
								selected = candidate
								break
						appearance[category] = VARIANTS.logical_part_id(category, selected, gender)
			appearance["top"] = VARIANTS.logical_part_id("top", top_id, gender)
			cases.append({"gender": gender, "name": top_id, "appearance": appearance, "full_outfit": true})
		for category: String in SLOTS:
			for part_id: String in categories.get(category, {}).get("parts", {}):
				var appearance := _starter(gender)
				appearance[category] = VARIANTS.logical_part_id(category, part_id, gender)
				cases.append({"gender": gender, "name": category + "-" + part_id, "appearance": appearance, "full_outfit": false})
	return cases


func _starter(gender: String) -> Dictionary:
	return {
		"gender": gender, "hair": "Hair", "top": "Shirt", "bottom": "Trousers",
		"shoes": "Shoes", "headgear": "Cap", "facegear": "__none__", "cape": "__none__",
	}


func _visible_bounds(art: Node2D) -> Rect2:
	var bounds := Rect2()
	for sprite: Sprite2D in art.get_children():
		var used := sprite.texture.get_image().get_used_rect()
		if not used.has_area():
			continue
		var layer_rect := Rect2((Vector2(used.position) - sprite.texture.get_size() * 0.5) * sprite.scale, Vector2(used.size) * sprite.scale)
		layer_rect.position.x = -layer_rect.end.x
		var rendered := Rect2(layer_rect.position * art.scale + art.position, layer_rect.size * art.scale)
		bounds = rendered if not bounds.has_area() else bounds.merge(rendered)
	return bounds


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
