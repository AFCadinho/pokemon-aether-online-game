extends SceneTree

const SETTINGS_SCENE_PATH := "res://scenes/interface/settings/settings_menu.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings_manager := root.get_node_or_null("SettingsManager")
	_expect(settings_manager != null, "Fishing hotkey check can access SettingsManager")
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	_expect(packed != null, "Settings scene loads with configurable Fishing hotkeys")
	if settings_manager == null or packed == null:
		quit(1)
		return

	var expected_label := str(settings_manager.call("get_input_binding_label", "fish"))
	var configured_keycode := int(settings_manager.call("get_input_binding_keycode", "fish"))
	var events := InputMap.action_get_events("fish")
	_expect(
		not events.is_empty()
		and events[0] is InputEventKey
		and int((events[0] as InputEventKey).physical_keycode) == configured_keycode,
		"Saved Fishing hotkey is applied to the live Input Map"
	)

	var menu := packed.instantiate()
	root.add_child(menu)
	await process_frame
	var binding_button := menu.find_child("FishingBindingButton", true, false) as Button
	_expect(binding_button != null, "Controls tab exposes the Fishing hotkey button")
	_expect(
		binding_button != null and binding_button.text == expected_label,
		"Fishing hotkey button displays the active binding"
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

	menu.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
