extends SceneTree

const TRACKER_SCENE := preload("res://scenes/interface/shiny_tracker_popup.tscn")
const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
const ItemIcons := preload("res://scripts/services/item_icon_resolver.gd")

const TRACKER_ICON := preload("res://assets/items/icons/SHINYTRACKER.png")
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const SERVICE_PATH := "res://scripts/services/shiny_tracker_service.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		localization_manager.set_locale("en")
	var popup := TRACKER_SCENE.instantiate()
	root.add_child(popup)
	await process_frame
	_check(popup is ShinyTrackerPopup, "Tracker scene uses the dedicated Shiny Tracker interface")
	_check(popup.custom_minimum_size == Vector2(900, 610), "Tracker has a full searchable workspace")
	_check(TRACKER_ICON != null and TRACKER_ICON.get_width() == 48, "Tracker has a 48px pixel-art item icon")
	popup.tracker_state = {
		"stats": null,
		"activeHunt": null,
		"recentHunts": null,
	}
	popup.call("_render_tracker")
	_check(popup.stop_button.disabled, "Tracker accepts an API null when there is no active hunt")
	_check(popup.share_button.disabled, "Tracker disables sharing when the active hunt is null")
	popup.tracker_state = {
		"stats": {},
		"activeHunt": {
			"targetSpeciesName": "Pidgey",
			"evolutionLineName": "Pidgey",
			"evolutionLineMembers": [],
			"encounterCount": 0,
		},
		"recentHunts": [],
	}
	popup.call("_render_tracker")
	_check(popup.hunt_sprite.texture != null, "Active hunts show the target's Shiny Pokémon sprite")
	_check(popup.hunt_count_label.text == "0", "Active hunt count renders as a standalone number")
	_check(popup.hunt_count_context_label.visible, "Active hunt count shows its hunt context")
	popup.tracker_state["mounts"] = {
		"activeBoxItemId": "rayquaza-mount-box", "totalBoxesOpened": 4,
		"shinyMountsReceived": 1, "boxesSinceLastShiny": 3, "longestDryStreak": 3,
		"boxes": [{"itemId": "rayquaza-mount-box", "name": "Rayquaza Mount Box", "quantity": 2, "normalMountId": "rayquaza", "shinyMountId": "rayquaza_shiny", "nextShinyChancePercent": 80}, {"itemId": "shadow-lugia-mount-box", "name": "Shadow Lugia Mount Box", "quantity": 1, "normalMountId": "shadow_lugia", "shinyMountId": "shadow_lugia_shiny", "nextShinyChancePercent": 50}, {"itemId": "mega-alakazam-mount-box", "name": "Mega Alakazam Mount Box", "quantity": 1, "normalMountId": "mega_alakazam", "shinyMountId": "mega_alakazam_shiny", "nextShinyChancePercent": 50}, {"itemId": "glaceon-mount-box", "name": "Glaceon Mount Box", "quantity": 1, "normalMountId": "glaceon", "shinyMountId": "glaceon_shiny", "nextShinyChancePercent": 50}, {"itemId": "cobalion-mount-box", "name": "Cobalion Mount Box", "quantity": 1, "normalMountId": "cobalion", "shinyMountId": "cobalion_shiny", "nextShinyChancePercent": 50}],
		"recentOpenings": [{"mountId": "rayquaza_shiny", "isShiny": true, "alreadyOwned": true, "shinyChancePercent": 70}],
	}
	popup.call("_render_tracker")
	popup.call("_select_tracker_tab", "mounts")
	_check(popup.mount_workspace.visible and not popup.pokemon_workspace.visible, "Mounts tab switches away from Pokémon")
	_check(popup.mount_stat_labels["totalBoxesOpened"].text == "4", "Mount counters render independently")
	_check(popup.mount_open_buttons.size() == 5 and not popup.mount_open_buttons[0].disabled and not popup.mount_open_buttons[1].disabled and not popup.mount_open_buttons[2].disabled and not popup.mount_open_buttons[3].disabled and not popup.mount_open_buttons[4].disabled, "Owned box can be opened from tracker")
	_check(popup.mount_history_list.get_child(0).text.contains("70%") and popup.mount_history_list.get_child(0).text.contains("duplicate"), "History discloses used chance and duplicate outcomes")
	popup.request_busy = true
	popup.call("_refresh_actions")
	_check(popup.mount_open_buttons[0].disabled, "Pending opening blocks repeated clicks")
	popup.request_busy = false
	popup.call("_refresh_actions")
	popup.call("_on_mount_open_pressed", popup.tracker_state["mounts"]["boxes"][0])
	_check(popup.mount_confirmation.dialog_text.contains("80%") and popup.mount_confirmation.dialog_text.contains("resets") and popup.mount_confirmation.dialog_text.contains("Duplicates"), "Confirmation shows personal chance, resets and duplicates")
	popup.mount_confirmation.hide()
	_check(ItemIcons.load_icon("rayquaza-mount-box") != null, "Mount box has an item icon")
	popup.call("_on_mount_open_pressed", popup.tracker_state["mounts"]["boxes"][1])
	_check(popup.pending_mount_box_id == "shadow-lugia-mount-box" and popup.mount_confirmation.dialog_text.contains("50%") and popup.mount_confirmation.dialog_text.contains("Shadow Lugia"), "Switching to Shadow Lugia discloses its base chance and targets the correct box")
	popup.mount_confirmation.hide()
	_check(ItemIcons.load_icon("shadow-lugia-mount-box") != null, "Shadow Lugia box has its registered mount icon")
	popup.call("_on_mount_open_pressed", popup.tracker_state["mounts"]["boxes"][2])
	_check(popup.pending_mount_box_id == "mega-alakazam-mount-box" and popup.mount_confirmation.dialog_text.contains("50%") and popup.mount_confirmation.dialog_text.contains("Mega Alakazam"), "Tracker opens the Mega Alakazam box with its own chance")
	popup.mount_confirmation.hide()
	popup.call("_on_mount_open_pressed", popup.tracker_state["mounts"]["boxes"][3])
	_check(popup.pending_mount_box_id == "glaceon-mount-box" and popup.mount_confirmation.dialog_text.contains("50%") and popup.mount_confirmation.dialog_text.contains("Glaceon"), "Tracker opens the Glaceon box with its own chance")
	popup.mount_confirmation.hide()
	_check(ItemIcons.load_icon("glaceon-mount-box") != null, "Glaceon box has its mount icon")
	popup.call("_on_mount_open_pressed", popup.tracker_state["mounts"]["boxes"][4])
	_check(popup.pending_mount_box_id == "cobalion-mount-box" and popup.mount_confirmation.dialog_text.contains("50%") and popup.mount_confirmation.dialog_text.contains("Cobalion"), "Tracker opens the Cobalion box with its own chance")
	popup.mount_confirmation.hide()
	_check(ItemIcons.load_icon("cobalion-mount-box") != null, "Cobalion box has its mount icon")

	if "--preview-mounts" in OS.get_cmdline_user_args():
		root.size = Vector2i(1200, 800)
		popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		popup.position = Vector2(100, 60)
		popup.size = Vector2(1000, 680)
		popup.visible = true
		await process_frame
		await process_frame
		_check(popup.size.y <= 680, "Mount layout fits the popup without expanding beyond the window")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://mount-tracker-preview.png")
		print("PREVIEW ", ProjectSettings.globalize_path("user://mount-tracker-preview.png"))
	popup.open_shared_hunt({
		"ownerDisplayName": "Trainer",
		"stats": {"lifetimeEligibleEncounters": 12},
		"hunt": {
			"targetSpeciesName": "Pidgey",
			"evolutionLineName": "Pidgey",
			"evolutionLineMembers": [],
			"encounterCount": 3,
		},
	})
	_check(popup.stats_title.visible, "Shared hunts show overall encounter stats")
	_check(int(popup.stat_labels["lifetimeEligibleEncounters"].text) == 12, "Shared hunts render the owner's overall encounter count")
	_check(popup.mounts_tab.disabled and not popup.mount_workspace.visible, "Shared Pokémon hunts keep private mount data hidden")
	popup.call("_select_tracker_tab", "mounts")
	_check(not popup.mount_workspace.visible, "Shared mode cannot select personal Mounts tab")
	popup.queue_free()
	await process_frame

	var store := STORE_SCENE.instantiate()
	root.add_child(store)
	await process_frame
	store.apply_store_state({"gems": 1000}, {"items": [{"itemId": "rayquaza-mount-box", "costs": [{"currency": "gems", "amount": 750}]}, {"itemId": "shadow-lugia-mount-box", "costs": [{"currency": "gems", "amount": 750}]}, {"itemId": "mega-alakazam-mount-box", "costs": [{"currency": "gems", "amount": 750}]}, {"itemId": "glaceon-mount-box", "costs": [{"currency": "gems", "amount": 500}]}, {"itemId": "cobalion-mount-box", "costs": [{"currency": "gems", "amount": 500}]}]})
	store.call("_select_category", "mounts")
	store.call("_select_product", "rayquaza-mount-box")
	_check(not store.purchase_button.disabled, "Gift Store permits the authoritative box purchase")
	_check(store.selection_price_label.text == "750 Aether Gems", "Box price shows currency only")
	_check(store.selection_description_label.text == "Contains a Rayquaza mount. Base shiny chance: 50%.", "Store concisely names the reward and initial shiny chance")
	_check(store.call("_catalog_item", "nimbus_mount").is_empty() and store.call("_catalog_item", "aether_board_mount").is_empty(), "Removed Nimbus and Aether Board previews are absent from the Store")
	store.call("_select_product", "shadow-lugia-mount-box")
	_check(not store.purchase_button.disabled, "Gift Store permits the authoritative Shadow Lugia box purchase")
	_check(store.selection_title_label.text.contains("Shadow Lugia") and store.selection_description_label.text.contains("Shadow Lugia") and not store.selection_description_label.text.contains("Rayquaza"), "Shadow Lugia box shows the correct localized reward description")
	_check(store.selection_price_label.text == "750 Aether Gems", "Shadow Lugia box displays currency only")
	await _check_mount_preview(store, "shadow_lugia")
	store.call("_select_product", "rayquaza-mount-box")
	await _check_mount_preview(store, "rayquaza")
	store.call("_select_product", "mega-alakazam-mount-box")
	_check(not store.purchase_button.disabled and store.selection_description_label.text == "Contains a Mega Alakazam mount. Base shiny chance: 50%.", "Mega Alakazam box uses a short reward description and authoritative purchase")
	await _check_mount_preview(store, "mega_alakazam")
	store.call("_select_product", "glaceon-mount-box")
	_check(not store.purchase_button.disabled and store.selection_description_label.text == "Contains a Glaceon mount. Base shiny chance: 50%.", "Glaceon box uses a short reward description and authoritative purchase")
	await _check_mount_preview(store, "glaceon")
	store.call("_select_product", "cobalion-mount-box")
	_check(not store.purchase_button.disabled and store.selection_description_label.text == "Contains a Cobalion mount. Base shiny chance: 50%.", "Cobalion box has an authoritative purchase and short description")
	await _check_mount_preview(store, "cobalion")
	store.call("_select_product", "shadow-lugia-mount-box")
	if localization_manager != null:
		localization_manager.set_locale("nl")
		_check(store.selection_price_label.text == "750 Aether Gems", "Dutch Store shows currency only")
		_check(store.selection_description_label.text == "Bevat een Shadow Lugia-mount. Shiny-basiskans: 50%.", "Dutch Store concisely names the reward and initial shiny chance")
	if "--preview-mounts" in OS.get_cmdline_user_args():
		store.visible = true
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://mount-store-preview.png")
		print("PREVIEW ", ProjectSettings.globalize_path("user://mount-store-preview.png"))
	if localization_manager != null:
		localization_manager.set_locale("en")
	store.queue_free()
	await process_frame

	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	_check(service_source.contains('const TRACKER_ENDPOINT := "/game/shiny-tracker"'), "Tracker uses its server-authoritative API")
	_check(service_source.contains("func share_hunt") and service_source.contains("func load_shared_hunt"), "Tracker supports live share summaries")

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	var tracker_source := FileAccess.get_file_as_string("res://scripts/ui/shiny_tracker_popup.gd")
	_check(tracker_source.contains("load_home_sprite(target_species, true)"), "Tracker prefers Shiny Pokémon sprites")
	_check(overlay_source.contains('entry_type == "key_item_action" and entry_id == "shiny-tracker"'), "Tracker can be launched from the hotbar")
	_check(overlay_source.contains("_create_chat_shiny_hunt_button"), "Chat renders clickable Shiny hunt cards")
	_check(overlay_source.contains("SHINY_TRACKER_ICON"), "Chat hunt cards show the Shiny Tracker icon")
	_check(overlay_source.contains("chat_card_title"), "Chat hunt cards clearly identify the Shiny Tracker")
	_check(overlay_source.contains("_on_chat_shiny_hunt_pressed"), "Shared cards load their current server state")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)


func _check_mount_preview(store: Node, normal_mount_id: String) -> void:
	var expected_price := "500 Aether Gems" if normal_mount_id in ["glaceon", "cobalion"] else "750 Aether Gems"
	var appearance := load("res://scripts/services/character_appearance_service.gd").get_default_appearance("female") as Dictionary
	appearance["gender"] = "female"
	appearance["hair_color"] = "#dd66aa"
	store.set_trainer_appearance(appearance)
	var preview: Node2D = store.character_preview_viewport.get_node("MountRiderPreview")
	_check(preview.current_gender == "female" and preview.current_appearance_state["hair_color"] == "#dd66aa", "Mount preview uses the player's appearance")
	_check(preview.current_mount_id == normal_mount_id and preview.mount_sprite.visible and preview.call("_get_body_sprite").visible, "Mount preview includes both rider and mount")
	_check(not preview.is_in_group("remote_player_avatar") and preview.interaction_hit_area == null, "Preview stays separate from world players and interaction")
	_check(store.mount_preview_controls.visible and store.character_preview_direction_row.visible and not store.character_preview_palette.visible, "Mount controls replace cosmetic color controls")
	store.mount_preview_shiny_toggle.button_pressed = true
	_check(preview.current_mount_id == normal_mount_id + "_shiny", "Shiny toggle displays the correct alternate reward")
	_check(store.selected_item_id.ends_with("-mount-box") and store.selection_price_label.text == expected_price, "Shiny preview keeps the box and purchase price unchanged")
	for direction: String in ["down", "left", "right", "up"]:
		store.character_preview_direction_buttons[direction].pressed.emit()
		_check(preview.mount_sprite.animation == StringName("walk_" + direction), "Direction buttons turn the mounted rider: " + direction)
		preview.mount_sprite.frame = 1
		_check(preview.call("_get_body_sprite").frame == 1 and preview.mount_foreground_sprite.frame == 1, "Rider mask and foreground follow the animated mount")
	store.mount_preview_animation_toggle.button_pressed = false
	_check(not preview.mount_sprite.is_playing() and preview.mount_sprite.animation == &"idle_up", "Animation toggle stops in the selected direction")
	var position_before: Vector2 = preview.look_node.position
	await create_timer(0.3).timeout
	_check(preview.mount_sprite.frame == 0 and preview.look_node.position == position_before, "Disabled animation freezes both flight and hover")
	store.mount_preview_animation_toggle.button_pressed = true
	var frame_duration: float = 1.0 / preview.mount_sprite.sprite_frames.get_animation_speed(preview.mount_sprite.animation)
	await create_timer(frame_duration + 0.05).timeout
	_check(preview.mount_sprite.is_playing() and preview.mount_sprite.frame != 0, "Enabled animation advances the flight loop")
	store.mount_preview_shiny_toggle.button_pressed = false
	store.call("_select_character_preview_direction", "down")
	store.call("_select_product", "surf-charm")
	_check(not store.mount_preview_controls.visible and not store.character_preview_direction_row.visible and store.character_preview_viewport.get_node_or_null("MountRiderPreview") == null, "Mount controls and renderer disappear for other products")
