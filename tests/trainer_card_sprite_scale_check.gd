extends SceneTree

const OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"

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
	for gender: String in ["male", "female"]:
		for outfit: String in ["Starter", "Kakashi", "SS4"]:
			var prefix := "" if outfit == "Starter" else outfit + "_"
			var appearance := {
				"gender": gender,
				"hair": prefix + "Hair",
				"top": prefix + "Shirt",
				"bottom": prefix + "Trousers",
				"shoes": prefix + "Shoes",
				"headgear": "Cap" if outfit == "Starter" else ("Kakashi_Headgear" if outfit == "Kakashi" else "__none__"),
				"facegear": "Kakashi_Mask" if outfit == "Kakashi" else "__none__",
				"cape": "SS4_Tail" if outfit == "SS4" else "__none__",
			}
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
					_check(visible_bounds.position.x >= 0.0 and visible_bounds.end.x <= viewport.size.x, "%s fits horizontally including the SS4 tail" % context)
					if species.is_empty():
						_check(absf(visible_bounds.get_center().x - 92.0) <= 0.5, "%s centers only visible layers" % context)
					else:
						_check(viewport.get_node_or_null("FavoritePokemon") is Sprite2D, "%s renders the companion" % context)
					if not capture_dir.is_empty() and preview == "TrainerCardBattlePreview":
						viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
						await process_frame
						await process_frame
						RenderingServer.force_draw()
						viewport.get_texture().get_image().save_png(capture_dir.path_join("%s-%s-%s.png" % [gender, outfit, "solo" if species.is_empty() else "companion"]))
	if capture_display != null:
		capture_display.free()
	viewport.free()
	overlay.free()
	quit(1 if failed else 0)


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
