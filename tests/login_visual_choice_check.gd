extends SceneTree
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var had_settings := FileAccess.file_exists(settings.SETTINGS_PATH)
	var original := FileAccess.get_file_as_bytes(settings.SETTINGS_PATH) if had_settings else PackedByteArray()
	var old_locale: String = settings.locale
	if OS.has_feature("mobile") or OS.has_feature("web"):
		_write({"battle_presentation_mode": "3d", "battle_visual_choice_completed": true, "battle_visual_choice_version": settings.BATTLE_VISUAL_CHOICE_VERSION})
		settings.load_settings()
		_check(settings.battle_presentation_mode == "2d" and not settings.needs_battle_visual_choice(), "unsupported platforms stay in 2D without onboarding")
		_check(not settings.battle_visual_choice_completed, "unsupported platform does not claim to have offered a choice")
		_check(not settings.confirm_battle_visual_choice("3d"), "unsupported platform cannot confirm 3D")
	else:
		for mode: String in ["2d", "3d", "2.5d"]:
			for marker: Variant in [null, false, true]:
				var legacy := {"battle_presentation_mode": mode, "battle_presentation_schema": 2, "master_volume": 36}
				if marker != null:
					legacy["battle_visual_choice_completed"] = marker
				_write(legacy)
				settings.load_settings()
				_check(settings.battle_presentation_mode == mode and settings.needs_battle_visual_choice(), "legacy " + mode + " profile receives the one-time choice regardless of old completion flag")
				settings.save_settings()
				settings.load_settings()
				_check(settings.needs_battle_visual_choice() and settings.master_volume == 36, "legacy auto-save keeps choice pending and preserves other preferences")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
		settings.load_settings()
		_check(settings.battle_presentation_mode == "2d" and settings.needs_battle_visual_choice(), "fresh desktop profile has no implicit 3D choice")
		settings.save_settings() # Unrelated settings changes must not dismiss first-run choice.
		settings.load_settings()
		_check(settings.needs_battle_visual_choice(), "first-run auto-save does not mark choice complete")
		for mode: String in ["3d", "2d"]:
			if mode == "3d":
				# Reproduce an existing player's first login after the rollout.
				_write({"battle_presentation_mode": "3d", "battle_visual_choice_completed": true})
				settings.load_settings()
			else:
				settings.battle_visual_choice_completed = false
				settings.save_settings()
			var packed := load("res://scenes/interface/login_screen.tscn") as PackedScene
			var login := packed.instantiate()
			login.set_script(load("res://tests/fixtures/offline_visual_choice_login.gd"))
			root.add_child(login)
			await process_frame
			await process_frame
			var dialog: Control = login.battle_visual_choice
			_check(dialog != null and dialog.visible and dialog.confirm_button.disabled, "fresh login opens mandatory unselected choice")
			_check(not dialog.choices["2d"].button_pressed and not dialog.choices["3d"].button_pressed, "neither choice is preselected")
			_check(dialog.choices["2d"].focus_mode == Control.FOCUS_ALL, "choice works with keyboard focus")
			_check(dialog.choices["2d"].find_next_valid_focus() == dialog.choices["3d"], "Tab stays inside the chooser")
			login._show_saved_session_card()
			_check(root.gui_get_focus_owner() == dialog.choices["2d"], "restored sessions cannot steal chooser focus")
			var count := login.get_child_count()
			login._on_continue_button_pressed()
			login._submit_login()
			login._enter_world()
			_check(login.get_child_count() == count and not login.is_loading, "login and saved-session paths cannot bypass the choice or duplicate the dialog")
			dialog._cancel()
			_check(dialog.visible and settings.needs_battle_visual_choice(), "Escape does not silently select a renderer")
			_check(dialog.sizes["3d"].text.contains("19 GB") and dialog.sizes["2d"].text.contains("470 MB"), "approximate full collection storage is shown")
			for example_mode: String in ["2d", "3d"]:
				var example := dialog.find_child("Example" + example_mode.to_upper(), true, false) as TextureRect
				_check(example.texture != null and example.texture.get_width() > 0, "example is visible without downloads: " + example_mode)
				# user:// PNGs have no importer metadata, reproducing a fresh pull
				# before the editor has scanned the two new presentation examples.
				var raw_path := "user://visual_choice_unimported_" + example_mode + ".png"
				var raw_file := FileAccess.open(raw_path, FileAccess.WRITE)
				raw_file.store_buffer(FileAccess.get_file_as_bytes(dialog.EXAMPLE_PATHS[example_mode]))
				raw_file.close()
				_check(not ResourceLoader.exists(raw_path, "Texture2D"), "regression fixture has no Godot texture import")
				var raw_texture: Texture2D = dialog._load_example(raw_path)
				_check(raw_texture is ImageTexture and raw_texture.get_size() == example.texture.get_size(), "unimported PNG remains visible: " + example_mode)
				raw_texture = null
				DirAccess.remove_absolute(ProjectSettings.globalize_path(raw_path))
			settings.set_locale("nl")
			_check(dialog.choices["3d"].text == "Kies 3D" and "Ruimte voor alle Pokémon" in dialog.sizes["3d"].text, "locale changes translate the open chooser")
			var capture := OS.get_environment("VISUAL_CHOICE_CAPTURE")
			if not capture.is_empty() and mode == "3d":
				DisplayServer.window_set_size(Vector2i(1280, 720))
				for frame in 10: await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture)
			dialog.choices[mode].pressed.emit()
			_check(not dialog.confirm_button.disabled and dialog.selected_mode == mode, "player explicitly selects " + mode)
			dialog.confirm_button.pressed.emit()
			await process_frame
			_check(login.battle_visual_choice == null and settings.battle_presentation_mode == mode, "confirmation closes the dialog and applies " + mode)
			_check(root.gui_get_focus_owner() == login.continue_button, "confirmation returns focus to the saved session")
			settings.load_settings()
			_check(settings.battle_presentation_mode == mode and not settings.needs_battle_visual_choice(), "chosen " + mode + " survives restart and updates")
			_check(settings.battle_visual_choice_version == settings.BATTLE_VISUAL_CHOICE_VERSION, "confirmed choice records rollout completion")
			_check(not login._show_battle_visual_choice(), "re-entering login does not ask again")
			login.free()
			await process_frame
		_check(not settings.confirm_battle_visual_choice("unknown"), "invalid renderer is rejected")
		settings.battle_visual_choice_completed = false
		settings.battle_visual_choice_version = 0
		settings.set_battle_presentation_mode(settings.battle_presentation_mode)
		_check(not settings.needs_battle_visual_choice(), "explicit choice in Settings also completes onboarding")
		settings.load_settings()
		_check(not settings.needs_battle_visual_choice(), "explicit choice in Settings survives restart without another dialog")
		# A failed write must leave the question pending rather than pretend it saved.
		settings.battle_visual_choice_completed = false
		settings.battle_visual_choice_version = 0
		var previous_mode: String = settings.battle_presentation_mode
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
		_check(not settings.confirm_battle_visual_choice("3d"), "write failure is reported")
		_check(settings.needs_battle_visual_choice() and settings.battle_presentation_mode == previous_mode, "failed persistence rolls back the choice")
		_check(settings.battle_visual_choice_version == 0, "failed persistence does not mark the rollout complete")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
	var policy = load("res://scripts/services/settings_manager.gd")
	_check(not policy.supports_battle_visual_choice(true, false) and not policy.supports_battle_visual_choice(false, true), "web and mobile capability gates suppress onboarding")
	_check(policy.supports_battle_visual_choice(false, false), "desktop capability gate enables onboarding")
	for flags: Array in [[true, false], [false, true]]:
		var probe: Node = load("res://tests/fixtures/visual_choice_platform_settings.gd").new()
		probe.is_web = flags[0]
		probe.is_mobile = flags[1]
		root.add_child(probe)
		_write({"battle_presentation_mode": "3d", "battle_visual_choice_completed": true, "battle_visual_choice_version": settings.BATTLE_VISUAL_CHOICE_VERSION})
		probe.load_settings()
		_check(probe.battle_presentation_mode == "2d" and not probe.needs_battle_visual_choice(), "2D-only device ignores a saved 3D preference")
		_check(not probe.battle_visual_choice_completed and not probe.confirm_battle_visual_choice("3d"), "2D-only device never accepts or claims a 3D choice")
		probe.set_battle_presentation_mode("3d")
		_check(probe.battle_presentation_mode == "2d", "settings cannot enable 3D on a 2D-only device")
		probe.free()
	if had_settings:
		var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SETTINGS_PATH))
	settings.load_settings()
	settings.set_locale(old_locale)
	print("login_visual_choice_check: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)

func _write(data: Dictionary) -> void:
	var file := FileAccess.open("user://settings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
