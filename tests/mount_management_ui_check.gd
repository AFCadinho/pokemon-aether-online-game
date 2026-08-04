extends SceneTree

const MountServiceScript := preload("res://scripts/services/mount_service.gd")
const MOUNT_LOADOUT_PANEL_PATH := "res://scenes/interface/mount_loadout_panel.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings_manager := root.get_node_or_null("SettingsManager")
	var localization_manager := root.get_node_or_null("LocalizationManager")
	_check(settings_manager != null, "settings autoload is available to mount management")
	_check(localization_manager != null, "localization autoload is available to mount management")
	if settings_manager == null or localization_manager == null:
		quit(1)
		return
	_check(
		MountServiceScript.get_mount_ids_for_mode("surf") == ["lapras"],
		"Surf catalog exposes Lapras to the loadout selector"
	)
	_check(
		MountServiceScript.get_mount_ids_for_mode("land").is_empty(),
		"land loadout remains empty until a land mount is available"
	)
	_check(
		MountServiceScript.get_mount_icon_texture("lapras") != null,
		"Lapras supplies a preview texture for mount management"
	)
	_check(
		str(settings_manager.call("get_selected_mount_id", "surf")) == "lapras",
		"Lapras is selected in the default Surf loadout"
	)
	_check(
		not bool(settings_manager.call("set_selected_mount_id", "land", "lapras")),
		"a Surf mount cannot be assigned to the land slot"
	)
	_check(
		bool(settings_manager.call("set_selected_mount_id", "surf", "lapras")),
		"valid Surf selection is accepted"
	)

	var settings_source := FileAccess.get_file_as_string(
		"res://scripts/services/settings_manager.gd"
	)
	_check(
		settings_source.contains('"selected_land_mount_id": selected_land_mount_id')
		and settings_source.contains('"selected_surf_mount_id": selected_surf_mount_id')
		and settings_source.contains("signal mount_loadout_changed"),
		"mount loadout persists and publishes focused changes"
	)

	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	_check(
		player_source.contains("SettingsManager.get_selected_mount_id")
		and player_source.contains("SettingsManager.mount_loadout_changed.connect"),
		"local player uses the selected Surf mount"
	)

	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		overlay_source.contains("MOUNT_LOADOUT_PANEL_SCENE")
		and overlay_source.contains("func _setup_mount_loadout_panel()"),
		"overworld overlay creates the mount loadout panel"
	)

	var panel_scene := load(MOUNT_LOADOUT_PANEL_PATH) as PackedScene
	_check(panel_scene != null, "mount loadout panel scene loads")
	var panel := panel_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	_check(
		is_equal_approx(panel.anchor_left, 1.0)
		and is_equal_approx(panel.anchor_right, 1.0)
		and is_equal_approx(panel.offset_top, 76.0)
		and is_equal_approx(panel.offset_right, -360.0),
		"mount loadout occupies the top-right cluster without covering its action rails"
	)
	_check(
		(panel.get("slots_panel") as PanelContainer).size.x <= panel.size.x
		and (panel.get("selector_panel") as PanelContainer).position.y
		>= (panel.get("slots_panel") as PanelContainer).size.y + 6.0,
		"mount cards fit their rail and the selector opens below it"
	)
	var slot_buttons := panel.get("slot_buttons") as Dictionary
	var land_button := slot_buttons.get("land") as Button
	var surf_button := slot_buttons.get("surf") as Button
	_check(
		land_button != null
		and land_button.text.contains(str(localization_manager.call("text", "ui.mounts.none_selected"))),
		"land slot clearly shows its empty state"
	)
	_check(
		surf_button != null and surf_button.text.contains("Lapras") and surf_button.icon != null,
		"Surf slot shows the selected Lapras name and preview"
	)

	panel.call("_open_selector", "surf")
	var selector_panel := panel.get("selector_panel") as PanelContainer
	var selector_options := panel.get("selector_options") as VBoxContainer
	var selector_empty_label := panel.get("selector_empty_label") as Label
	_check(selector_panel.visible, "clicking a slot opens its mount selector")
	_check(
		selector_options.get_child_count() == 1
		and (selector_options.get_child(0) as Button).text.contains("Lapras"),
		"Surf selector lists Lapras"
	)
	panel.call("_open_selector", "land")
	_check(
		selector_options.get_child_count() == 0 and selector_empty_label.visible,
		"land selector explains that no land mounts are available yet"
	)

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
	]:
		var locale_source := FileAccess.get_file_as_string(locale_path)
		_check(
			locale_source.contains('"ui.mounts.title"')
			and locale_source.contains('"ui.mounts.none_available"'),
			"%s contains mount management translations" % locale_path
		)

	panel.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
