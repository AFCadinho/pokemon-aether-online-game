extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
const Mounts := preload("res://scripts/services/mount_service.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.size = Vector2(1280, 800)
	viewport.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	store.show()
	var items: Array = []
	for item: Dictionary in store.CATALOG:
		if item.has("price"):
			items.append({"itemId": item.id, "voucherEligible": "mounts" in item.get("categories", []) or "cosmetics" in item.get("categories", []), "costs": [{"currency": "gems", "amount": item.price}]})
	store.apply_store_state({"gems": 1000, "gift_voucher_balance": 1000}, {"items": items})
	store.call("_select_category", "mounts")
	_check(store.mount_mode_bar.visible and store.active_mount_mode == "land", "Mounts opens with Land selected")
	_check(store.product_buttons.size() == 5 and not store.product_buttons.has("primal-kyogre-mount-box"), "Land lists the five land boxes only")
	store.mount_mode_buttons.surf.pressed.emit()
	_check(store.product_buttons.keys() == ["primal-kyogre-mount-box"], "Surf lists only the Kyogre box")
	store.call("_select_product", "primal-kyogre-mount-box")
	_check(not store.purchase_button.disabled, "1,000 Gems can buy the Surf box")
	_check(not store.selection_price_label.text.contains("€") and store.selection_price_label.text == store.call("_mount_box_price_text", 1000), "Price is currency only")
	_check(store.selection_description_label.text.contains("50%"), "Short description displays the base chance")
	for shiny in [false, true]:
		store.mount_preview_shiny_toggle.button_pressed = shiny
		var preview: Node2D = store.character_preview_viewport.get_node("MountRiderPreview")
		_check(preview.get("current_mount_id") == ("primal_kyogre_shiny" if shiny else "primal_kyogre"), "Shiny toggle selects the matching mount")
		for direction: String in ["down", "left", "right", "up"]:
			store.call("_select_character_preview_direction", direction)
			store.mount_preview_animation_toggle.button_pressed = true
			var mount: AnimatedSprite2D = preview.get("mount_sprite")
			mount.pause()
			for frame in range(4):
				mount.frame = frame
				preview.call("_on_mount_frame_changed")
				_check_visible_bounds(preview.get_node("Look"), store.character_preview_viewport.size)
		store.mount_preview_animation_toggle.button_pressed = false
		_check(not preview.get("animation_enabled"), "Animation can be stopped")
	store.call("_on_catalog_search_changed", "rayquaza")
	_check(store.product_buttons.is_empty(), "Search stays within the Surf tab")
	store.mount_mode_buttons.land.pressed.emit()
	_check(store.selected_item_id.is_empty() and store.catalog_search_text.is_empty(), "Switching modes clears stale selection and search")
	_check(not store.mount_preview_controls.visible, "Switching modes clears the previous mount preview")
	_check(store.product_buttons.size() == 5, "Returning to Land restores its products")
	for locale: String in ["nl", "pt_BR", "zh_CN", "en"]:
		root.get_node("LocalizationManager").set_locale(locale)
		_check(not store.mount_mode_buttons.land.text.begins_with("ui."), "Tab labels are translated")
	store.call("_select_category", "charms")
	_check(not store.mount_mode_bar.visible, "Mount tabs stay hidden outside Mounts")
	store.call("_select_category", "mounts")
	store.call("_select_mount_mode", "surf")
	store.call("_select_product", "primal-kyogre-mount-box")
	store.call("_select_character_preview_direction", "left")
	store.mount_preview_shiny_toggle.button_pressed = true
	for i in range(5):
		await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			RenderingServer.force_draw(false)
			viewport.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	host.free()
	await process_frame
	print("Gift Store Land/Surf checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_visible_bounds(node: Node, viewport_size: Vector2i) -> void:
	if node is AnimatedSprite2D and node.visible:
		var sprite := node as AnimatedSprite2D
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var used := Mounts._get_texture_image(texture).get_used_rect()
		if used.has_area():
			var start := Vector2(used.position) - texture.get_size() / 2.0 + sprite.offset
			var end := start + Vector2(used.size)
			var bounds := Rect2(sprite.to_global(start), sprite.to_global(end) - sprite.to_global(start))
			_check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(bounds), "Preview contains " + str(sprite.name) + " without clipping")
	for child: Node in node.get_children():
		_check_visible_bounds(child, viewport_size)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
