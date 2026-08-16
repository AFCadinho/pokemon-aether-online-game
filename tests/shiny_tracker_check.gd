extends SceneTree

const TRACKER_SCENE := preload("res://scenes/interface/shiny_tracker_popup.tscn")
const TRACKER_ICON := preload("res://assets/items/icons/SHINYTRACKER.png")
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const SERVICE_PATH := "res://scripts/services/shiny_tracker_service.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	_check(popup.hunt_sprite.texture != null, "Active hunts show the target Pokémon sprite")
	_check(popup.hunt_count_label.text == "0", "Active hunt count renders as a standalone number")
	_check(popup.hunt_count_context_label.visible, "Active hunt count shows its hunt context")
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
	popup.queue_free()
	await process_frame

	var service_source := FileAccess.get_file_as_string(SERVICE_PATH)
	_check(service_source.contains('const TRACKER_ENDPOINT := "/game/shiny-tracker"'), "Tracker uses its server-authoritative API")
	_check(service_source.contains("func share_hunt") and service_source.contains("func load_shared_hunt"), "Tracker supports live share summaries")

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(overlay_source.contains('entry_type == "key_item_action" and entry_id == "shiny-tracker"'), "Tracker can be launched from the hotbar")
	_check(overlay_source.contains("_create_chat_shiny_hunt_button"), "Chat renders clickable Shiny hunt cards")
	_check(overlay_source.contains("PokemonAssets.load_home_sprite(target_species)"), "Chat hunt cards show the target Pokémon sprite")
	_check(overlay_source.contains("chat_card_encounters"), "Chat hunt cards show a dedicated encounter badge")
	_check(overlay_source.contains("_on_chat_shiny_hunt_pressed"), "Shared cards load their current server state")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
