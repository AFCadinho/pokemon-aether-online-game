extends SceneTree

const SETTINGS_SCENE_PATH := "res://scenes/interface/settings/settings_menu.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings_manager := root.get_node_or_null("SettingsManager")
	_expect(settings_manager != null, "Overworld hotkey check can access SettingsManager")
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	_expect(packed != null, "Settings scene loads with configurable overworld hotkeys")
	if settings_manager == null or packed == null:
		quit(1)
		return

	var expected_label := str(settings_manager.call("get_input_binding_label", "fish"))
	var running_shoes_keycode := int(settings_manager.call(
		"get_input_binding_keycode",
		"toggle_running_shoes"
	))
	var settings_constants: Dictionary = settings_manager.get_script().get_script_constant_map()
	var default_bindings: Dictionary = settings_constants.get("DEFAULT_INPUT_BINDINGS", {})
	var legacy_running_shoes_default: Key = settings_constants.get(
		"LEGACY_RUNNING_SHOES_DEFAULT",
		KEY_X
	)
	var running_shoes_events := InputMap.action_get_events("toggle_running_shoes")
	_expect(
		int(default_bindings.get("toggle_running_shoes", KEY_NONE)) == int(KEY_N),
		"Running Shoes defaults to N"
	)
	var migrated_bindings: Dictionary = settings_manager.call(
		"_validated_input_bindings",
		{"toggle_running_shoes": int(legacy_running_shoes_default)}
	)
	_expect(
		int(migrated_bindings.get("toggle_running_shoes", KEY_NONE)) == int(KEY_N),
		"Existing Running Shoes X binding migrates to N"
	)
	_expect(
		not running_shoes_events.is_empty()
		and running_shoes_events[0] is InputEventKey
		and int((running_shoes_events[0] as InputEventKey).physical_keycode) == running_shoes_keycode,
		"Saved Running Shoes hotkey is applied to the live Input Map"
	)
	var configured_keycode := int(settings_manager.call("get_input_binding_keycode", "fish"))
	var events := InputMap.action_get_events("fish")
	_expect(
		not events.is_empty()
		and events[0] is InputEventKey
		and int((events[0] as InputEventKey).physical_keycode) == configured_keycode,
		"Saved Fishing hotkey is applied to the live Input Map"
	)
	var pickpocket_keycode := int(settings_manager.call("get_input_binding_keycode", "pickpocket"))
	var pickpocket_events := InputMap.action_get_events("pickpocket")
	_expect(
		not pickpocket_events.is_empty()
		and pickpocket_events[0] is InputEventKey
		and int((pickpocket_events[0] as InputEventKey).physical_keycode) == pickpocket_keycode,
		"Saved Thieving hotkey is applied to the live Input Map"
	)

	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame
	var binding_button := menu.find_child("FishingBindingButton", true, false) as Button
	var running_shoes_button := menu.find_child("RunningShoesBindingButton", true, false) as Button
	_expect(running_shoes_button != null, "Controls tab exposes the Running Shoes hotkey button")
	_expect(
		running_shoes_button != null
		and running_shoes_button.text
		== str(settings_manager.call("get_input_binding_label", "toggle_running_shoes")),
		"Running Shoes hotkey button displays the active binding"
	)
	_expect(binding_button != null, "Controls tab exposes the Fishing hotkey button")
	_expect(
		binding_button != null and binding_button.text == expected_label,
		"Fishing hotkey button displays the active binding"
	)
	var pickpocket_button := menu.find_child("ThievingBindingButton", true, false) as Button
	_expect(pickpocket_button != null, "Controls tab exposes the Thieving hotkey button")
	_expect(
		pickpocket_button != null
		and pickpocket_button.text
		== str(settings_manager.call("get_input_binding_label", "pickpocket")),
		"Thieving hotkey button displays the active binding"
	)
	menu.call("_start_input_binding_capture", "fish")
	var localization_manager := root.get_node("LocalizationManager")
	_expect(
		binding_button != null
		and binding_button.text == str(localization_manager.call(
			"text",
			"ui.settings.controls.press_key"
		)),
		"Fishing hotkey button enters key-capture mode"
	)
	menu.call("_cancel_input_binding_capture")
	_expect(
		binding_button != null and binding_button.text == expected_label,
		"Cancelling key capture preserves the configured binding"
	)
	menu.call("_start_input_binding_capture", "pickpocket")
	_expect(
		pickpocket_button != null
		and pickpocket_button.text == str(localization_manager.call(
			"text",
			"ui.settings.controls.press_key"
		)),
		"Thieving hotkey button enters key-capture mode"
	)
	menu.call("_cancel_input_binding_capture")

	menu.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
