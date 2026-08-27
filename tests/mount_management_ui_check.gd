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
		MountServiceScript.get_mount_ids_for_mode("land") == ["cyclizar"],
		"land catalog contains Cyclizar"
	)
	_check(
		MountServiceScript.get_unlocked_mount_ids_for_mode("land", []).is_empty()
		and MountServiceScript.get_unlocked_mount_ids_for_mode(
			"land",
			["cyclizar-mount"]
		) == ["cyclizar"],
		"Cyclizar only appears after its untradeable mount item is owned"
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
	var overlay_scene_source := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	_check(
		overlay_source.contains("MOUNT_LOADOUT_PANEL_SCENE")
		and overlay_source.contains("func _setup_mount_loadout_panel()")
		and overlay_source.contains("mount_button.pressed.connect(_on_mount_button_pressed)"),
		"overworld overlay connects one utility button to the mount manager"
	)
	_check(
		overlay_scene_source.contains('[node name="MountButton" type="Button" parent="Control"]')
		and not overlay_scene_source.contains('[node name="MountSlot"')
		and overlay_scene_source.contains('path="res://assets/ui/mount_management.svg" id="33_mounts"')
		and overlay_scene_source.contains('icon = ExtResource("33_mounts")'),
		"mount management uses one bottom-right character utility button"
	)

	var panel_scene := load(MOUNT_LOADOUT_PANEL_PATH) as PackedScene
	_check(panel_scene != null, "mount loadout panel scene loads")
	var panel := panel_scene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	_check(not panel.visible, "mount manager stays hidden until its utility button is pressed")
	panel.call("open_manager")
	_check(panel.visible, "mount utility button can open the manager")
	var manager_close_button := panel.get("manager_close_button") as Button
	_check(
		manager_close_button != null and manager_close_button.text == "×",
		"mount manager has a clear header close button"
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
	manager_close_button.pressed.emit()
	_check(not panel.visible, "mount manager close button hides the complete popup")
	panel.call("open_manager")

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
		"land selector hides Cyclizar before it is unlocked"
	)
	panel.call("_on_inventory_changed", [{"itemId": "cyclizar-mount", "quantity": 1}])
	panel.call("_open_selector", "land")
	_check(
		selector_options.get_child_count() == 1
		and (selector_options.get_child(0) as Button).text.contains("Cyclizar"),
		"land selector lists Cyclizar after the mount item is owned"
	)

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
		"res://localization/zh_CN.json",
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
