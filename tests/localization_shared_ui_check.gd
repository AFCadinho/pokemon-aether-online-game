extends SceneTree

const LOADING_SCENE_PATH := "res://scenes/interface/loading_screen.tscn"
const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false
var localization_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	_check(localization_manager != null, "shared UI check can access LocalizationManager")
	if localization_manager == null:
		quit(1)
		return
	var original_locale := str(localization_manager.get("current_locale"))
	_check_loading_screen()
	_check_navigation_and_world_status()
	localization_manager.call("set_locale", original_locale)
	await process_frame
	quit(1 if failed else 0)


func _check_loading_screen() -> void:
	var packed := load(LOADING_SCENE_PATH) as PackedScene
	_check(packed != null, "localized loading scene loads")
	if packed == null:
		return

	localization_manager.call("set_locale", "nl")
	var loading := packed.instantiate()
	loading.call("_build_layout")
	var title := loading.get("title_label") as Label
	var status := loading.get("status_label") as Label
	var stages := loading.get("stage_labels") as Array
	_check(title != null and title.text == "Je avontuur wordt voorbereid", "loading title renders in Dutch")
	_check(status != null and status.text == "Je Trainerprofiel wordt geladen...", "loading status renders in Dutch")
	_check(
		stages.size() == 3 and (stages[1] as Label).text.contains("TEAM"),
		"loading stages render in Dutch"
	)

	localization_manager.call("set_locale", "pt_BR")
	loading.call("_on_locale_changed", "pt_BR")
	_check(title != null and title.text == "Preparando sua aventura", "loading title updates to Portuguese")
	_check(
		stages.size() == 3 and (stages[2] as Label).text.contains("MUNDO"),
		"loading stages update to Portuguese"
	)
	loading.free()


func _check_navigation_and_world_status() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "localized shared UI scene loads")
	if packed == null:
		return

	var overlay := packed.instantiate()
	var store_button := overlay.get_node_or_null("Control/DonatorStoreButton") as Button
	var settings_button := overlay.get_node_or_null("Control/SettingsButton") as Button
	var time_of_day := overlay.get_node_or_null(
		"Control/LocationPanel/MarginContainer/VBoxContainer/StatusRow/TimeOfDayLabel"
	) as Label
	var weather := overlay.get_node_or_null(
		"Control/LocationPanel/MarginContainer/VBoxContainer/StatusRow/WeatherLabel"
	) as Label
	overlay.set("time_of_day_label", time_of_day)
	overlay.set("weather_label", weather)

	localization_manager.call("set_locale", "nl")
	localization_manager.call("localize_tree", overlay)
	_check(
		store_button != null and store_button.tooltip_text == "Cosmetica en cadeaus kopen",
		"main navigation tooltip renders in Dutch"
	)
	_check(
		settings_button != null and settings_button.tooltip_text == "Spelinstellingen wijzigen",
		"settings navigation tooltip renders in Dutch"
	)
	_check(
		not _tree_has_tooltip_prefix(overlay, "ui.navigation."),
		"all migrated navigation tooltips resolve in Dutch"
	)
	overlay.call("_refresh_time_of_day_label", 14)
	overlay.call("_refresh_location_weather", {"weather": "snow"})
	_check(time_of_day != null and time_of_day.text == "Middag", "time of day renders in Dutch")
	_check(weather != null and weather.text == "Sneeuw", "weather renders in Dutch")
	_check(overlay.call("_format_map_name", "") == "Onbekende locatie", "unknown location renders in Dutch")

	localization_manager.call("set_locale", "pt_BR")
	localization_manager.call("localize_tree", overlay)
	overlay.call("_refresh_time_of_day_label", 19)
	overlay.call("_refresh_location_weather", {"weather": "rain"})
	_check(
		store_button != null and store_button.tooltip_text == "Comprar cosméticos e presentes",
		"main navigation tooltip updates to Portuguese"
	)
	_check(
		not _tree_has_tooltip_prefix(overlay, "ui.navigation."),
		"all migrated navigation tooltips resolve in Portuguese"
	)
	_check(time_of_day != null and time_of_day.text == "Anoitecer", "time of day updates to Portuguese")
	_check(weather != null and weather.text == "Chuva", "weather updates to Portuguese")
	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()


func _tree_has_tooltip_prefix(node: Node, prefix: String) -> bool:
	if node is Control and (node as Control).tooltip_text.begins_with(prefix):
		return true
	for child: Node in node.get_children():
		if _tree_has_tooltip_prefix(child, prefix):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
