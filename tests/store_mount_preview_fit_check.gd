extends SceneTree

const STORE := preload("res://scenes/interface/donator_store_popup.tscn")
const Mounts := preload("res://scripts/services/mount_service.gd")
const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const SIZE := Vector2i(258, 174)
const CONTENT := Rect2(16, 12, 226, 150)
const EXAMPLES := ["glaceon", "rayquaza", "arcanine", "ho_oh", "giratina_origin", "primal_kyogre", "latios", "metagross"]
var failed := false
var texture_bounds: Dictionary = {}
var montage := Image.create(1032, 696, false, Image.FORMAT_RGBA8)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	montage.fill(Color("#07111d"))
	var store := STORE.instantiate() as DonatorStorePopup
	root.add_child(store)
	store.show()
	var catalog_before := Mounts._get_catalog().duplicate(true)
	var checked := 0
	for gender: String in ["male", "female"]:
		var appearance := Appearance.get_default_appearance(gender)
		appearance["gender"] = gender
		appearance["hair"] = "Aether_Male_Hair_02" if gender == "male" else "Aether_Female_Hair_01"
		appearance["hair_color"] = "#247aca"
		store.set_trainer_appearance(appearance)
		var appearance_before := appearance.duplicate(true)
		for item: Dictionary in store.CATALOG:
			var box_id := str(item.get("id", ""))
			if not box_id.ends_with("-mount-box"):
				continue
			store.call("_select_category", "mounts")
			store.call("_select_mount_mode", "surf" if box_id in ["primal-kyogre-mount-box", "magikarp-mount-box"] else "land")
			store.call("_select_product", box_id)
			for shiny: bool in [false, true]:
				store.mount_preview_shiny_toggle.button_pressed = shiny
				var preview: Node2D = store.character_preview_viewport.get_node("MountRiderPreview")
				var id := str(preview.get("current_mount_id"))
				var zoom := preview.scale
				var origin := preview.position
				var envelope := Rect2()
				texture_bounds.clear()
				for direction: String in ["down", "left", "right", "up"]:
					store.call("_select_character_preview_direction", direction)
					for animate: bool in [false, true]:
						store.mount_preview_animation_toggle.button_pressed = animate
						var mount: AnimatedSprite2D = preview.get("mount_sprite")
						mount.pause()
						for frame in range(mount.sprite_frames.get_frame_count(mount.animation)):
							mount.frame = frame
							preview.call("_on_mount_frame_changed")
							for phase: float in [0.0, 0.25, 0.75]:
								var hover: Node2D = preview.get("mount_hover_visual")
								if hover != null and hover.visible:
									hover.set("elapsed", float(hover.get("period")) * phase)
									preview.call("_update_mount_hover", 0.0)
								var bounds := _visible_bounds(preview.get_node("Look"))
								_check(CONTENT.grow(0.01).encloses(bounds), id + " rider/mount stay inside padding: " + direction)
								envelope = bounds if not envelope.has_area() else envelope.merge(bounds)
						_check(preview.scale.is_equal_approx(zoom) and preview.position.is_equal_approx(origin), id + " keeps framing across directions/frames/animation toggles")
						if gender == "male" and not shiny and direction in ["down", "left"] and animate:
							_capture_example(preview, id, direction)
				var hover: Node2D = preview.get("mount_hover_visual")
				if hover != null and hover.visible:
					var shadow := Rect2(preview.to_global(Vector2(-22, 6)), Vector2(44, 12) * zoom)
					_check(CONTENT.grow(0.01).encloses(shadow), id + " ground shadow stays inside padding")
					envelope = envelope.merge(shadow)
				_check(envelope.get_center().distance_to(Vector2(SIZE) * 0.5) < 0.1, id + " complete animation envelope is centered")
				var occupancy := maxf(envelope.size.x / CONTENT.size.x, envelope.size.y / CONTENT.size.y)
				_check(absf(occupancy - 1.0) < 0.001, id + " uses the same available preview space")
				_check(is_equal_approx(zoom.x, zoom.y), id + " preserves aspect ratio")
				checked += 1
		_check(appearance == appearance_before, "preview fit preserves personal appearance")
	# Store opening rebuilds the preview before making the popup visible.
	store.hide()
	store.call("_select_mount_mode", "land")
	store.call("_select_product", "glaceon-mount-box")
	var hidden_preview: Node2D = store.character_preview_viewport.get_node("MountRiderPreview")
	_check(hidden_preview.get("preview_bounds").has_area(), "preview measures while the Store is closed")
	store.show()
	var resized := Vector2i(194, 142)
	hidden_preview.call("configure", "glaceon", Appearance.get_default_appearance("female"), "up", false, resized)
	var resized_bounds: Rect2 = hidden_preview.global_transform * hidden_preview.get("preview_bounds")
	_check(resized_bounds.get_center().distance_to(Vector2(resized) * 0.5) < 0.1, "viewport resizing recenters the preview")
	_check(Rect2(16, 12, 162, 118).grow(0.01).encloses(resized_bounds), "viewport resizing preserves padding")
	_check(Mounts._get_catalog() == catalog_before, "preview fitting preserves world mount definitions")
	_check(montage.save_png("user://store_mount_preview_fit.png") == OK, "mount comparison saved")
	print("MOUNT COMPARISON ", ProjectSettings.globalize_path("user://store_mount_preview_fit.png"))
	store.free()
	print("Store mount preview fit: ", "FAILED" if failed else "PASS", " (", checked, " rider/mount variants)")
	quit(1 if failed else 0)


func _visible_bounds(node: Node) -> Rect2:
	var bounds := Rect2()
	if node is CanvasItem and not node.is_visible_in_tree():
		return bounds
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if not texture_bounds.has(texture):
			texture_bounds[texture] = Mounts._get_texture_image(texture).get_used_rect()
		var used := Rect2(texture_bounds[texture])
		if used.has_area():
			used.position += sprite.offset - texture.get_size() * 0.5
			bounds = sprite.global_transform * used
	for child: Node in node.get_children():
		var child_bounds := _visible_bounds(child)
		if child_bounds.has_area():
			bounds = child_bounds if not bounds.has_area() else bounds.merge(child_bounds)
	return bounds


func _capture_example(preview: Node2D, id: String, direction: String) -> void:
	var index := EXAMPLES.find(id)
	if index < 0:
		return
	var mount: AnimatedSprite2D = preview.get("mount_sprite")
	mount.frame = 0
	preview.call("_on_mount_frame_changed")
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	_paint_layers(preview.get_node("Look"), image)
	var row := index / 4 + (2 if direction == "left" else 0)
	montage.blend_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i((index % 4) * SIZE.x, row * SIZE.y))


func _paint_layers(node: Node, target: Image) -> void:
	if node is CanvasItem and not node.is_visible_in_tree():
		return
	if node is AnimatedSprite2D:
		var sprite := node as AnimatedSprite2D
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var image := Mounts._get_texture_image(texture).duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
		var origin := sprite.to_global(sprite.offset - texture.get_size() * 0.5)
		var size := Vector2i((sprite.global_transform.get_scale() * texture.get_size()).round())
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		target.blend_rect(image, Rect2i(Vector2i.ZERO, size), Vector2i(origin.round()))
	for child: Node in node.get_children():
		_paint_layers(child, target)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
