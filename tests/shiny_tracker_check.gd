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
		"boxes": [{"itemId": "rayquaza-mount-box", "name": "Rayquaza Mount Box", "quantity": 2, "normalMountId": "rayquaza", "shinyMountId": "rayquaza_shiny", "nextShinyChancePercent": 80}],
		"recentOpenings": [{"mountId": "rayquaza_shiny", "isShiny": true, "alreadyOwned": true, "shinyChancePercent": 70}],
	}
	popup.call("_render_tracker")
	popup.call("_select_tracker_tab", "mounts")
	_check(popup.mount_workspace.visible and not popup.pokemon_workspace.visible, "Mounts tab switches away from Pokémon")
	_check(popup.mount_stat_labels["totalBoxesOpened"].text == "4", "Mount counters render independently")
	_check(popup.mount_open_buttons.size() == 1 and not popup.mount_open_buttons[0].disabled, "Owned box can be opened from tracker")
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
	store.apply_store_state({"gems": 1000}, {"items": [{"itemId": "rayquaza-mount-box", "costs": [{"currency": "gems", "amount": 500}]}]})
	store.call("_select_category", "mounts")
	store.call("_select_product", "rayquaza-mount-box")
	_check(not store.purchase_button.disabled, "Gift Store permits the authoritative box purchase")
	_check(store.selection_price_label.text.contains("500") and store.selection_price_label.text.contains("€5.00"), "Box price includes Gems and euro value")
	_check(store.selection_description_label.text.contains("50%") and store.selection_description_label.text.contains("80%") and store.selection_description_label.text.contains("Duplicates"), "Store discloses chance rules before purchase")
	if localization_manager != null:
		localization_manager.set_locale("nl")
		_check(store.selection_price_label.text.contains("€5,00"), "Dutch Store uses the approved €5,00 price")
		_check(store.selection_description_label.text.contains("Dubbele mounts"), "Dutch Store discloses duplicate outcomes")
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
