extends SceneTree
const EnvironmentService = preload("res://scripts/services/android_3d_environment_service.gd")
var failures := 0
class EntryProbe extends Node:
	var requested := false
	func begin_entry_arena() -> void:
		requested = true
func _init() -> void:
	_run.call_deferred()
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _write(value: Dictionary) -> void:
	var file := FileAccess.open("user://settings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
func _run() -> void:
	var settings := root.get_node("SettingsManager")
	if OS.has_feature("android") and OS.has_feature("android_3d_experimental"):
		_check(settings.is_android_3d_experimental() and settings.supports_3d_presentation(), "Native Android build exposes only the explicit experimental capability")
		_check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Experimental choice preserves the regular Android renderer")
		# Exercise the real mobile screen-host gate without shaders, downloads or
		# battle state: it must request the 3D arena instead of revealing 2D first.
		var original_mode: String = settings.battle_presentation_mode
		settings.battle_presentation_mode = "3d"
		var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		root.add_child(host)
		var battle := Control.new()
		host.content.add_child(battle)
		var stage := Node.new()
		stage.name = "BattleStage"
		battle.add_child(stage)
		stage.owner = battle
		stage.unique_name_in_owner = true
		var entry := EntryProbe.new()
		entry.name = "ExperimentalBattle3D"
		stage.add_child(entry)
		host.battle = battle
		host.reveal_pending_entry()
		_check(host.early_arena_requested and entry.requested and host.reveal_tween == null, "Native Android enters the prepared 3D arena without an initial 2D reveal")
		host.released = true
		host.battle = null
		host.queue_free()
		settings.battle_presentation_mode = original_mode
		await process_frame
	var original := FileAccess.get_file_as_bytes(settings.SETTINGS_PATH)
	var reporter := root.get_node("ClientCrashReportService")
	var previous_recovery: bool = reporter.android_3d_recovery_required
	var previous_recovered: bool = reporter.android_3d_recovered_this_session
	var probe: Node = load("res://tests/fixtures/visual_choice_platform_settings.gd").new()
	probe.is_mobile = true
	probe.experimental_android = true
	root.add_child(probe)
	# A copied desktop completion flag is not Android experimental consent.
	_write({"battle_presentation_mode": "3d", "battle_visual_choice_completed": true, "battle_visual_choice_version": 1, "master_volume": 31})
	probe.load_settings()
	_check(probe.battle_presentation_mode == "2d" and probe.needs_battle_visual_choice(), "Android asks explicitly and begins in 2D")
	for mode in ["3d", "2d"]:
		_check(probe.confirm_battle_visual_choice(mode), "Android can explicitly choose " + mode)
		probe.load_settings()
		_check(probe.battle_presentation_mode == mode and not probe.needs_battle_visual_choice(), "Android choice survives reload: " + mode)
		_check(probe.android_visual_choice_version == 1 and probe.master_volume == 31, "Separate consent version and other settings are retained")
	probe.set_battle_presentation_mode("3d")
	probe.set_battle_presentation_mode("2.5d")
	_check(probe.battle_presentation_mode == "3d", "Android exposes only the two requested choices")
	reporter.android_3d_recovery_required = true
	probe.load_settings()
	_check(probe.battle_presentation_mode == "2d" and not probe.needs_battle_visual_choice(), "Interrupted experiment recovers into 2D without repeating onboarding")
	probe.load_settings()
	_check(probe.battle_presentation_mode == "2d", "Recovery persists")
	probe.is_web = true
	probe.load_settings()
	_check(not probe.supports_3d_presentation() and not probe.confirm_battle_visual_choice("3d"), "Browser never gains 3D from the Android experiment")
	probe.free()
	reporter.android_3d_recovery_required = previous_recovery
	reporter.android_3d_recovered_this_session = previous_recovered
	var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	settings.load_settings()
	var previous_locale: String = settings.locale
	var dialog: Control = load("res://scenes/interface/aether_confirmation_dialog.tscn").instantiate()
	dialog.set_script(load("res://tests/fixtures/android_visual_choice_dialog.gd"))
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(840, 600))
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").set_locale(locale)
		dialog.refresh_locale()
		for frame in 3: await process_frame
		_check(dialog.choices["3d"].text != "ui.visual_choice.android.choose.3d", "Experimental choice is localized: " + locale)
		_check(root.get_visible_rect().encloses(dialog.panel.get_global_rect()), "Android choice and confirmation fit the game viewport: " + locale)
	var capture := OS.get_environment("ANDROID_VISUAL_CHOICE_CAPTURE")
	if not capture.is_empty():
		root.get_node("LocalizationManager").set_locale("en")
		dialog.refresh_locale()
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture)
	dialog.queue_free()
	root.get_node("LocalizationManager").set_locale(previous_locale)
	# Installing cached/pinned art runs only file operations on a worker.
	var archive := OS.get_environment("ANDROID_3D_ARENA_ARCHIVE")
	if not archive.is_empty():
		var destination := ProjectSettings.globalize_path("user://android-environment-install-check")
		var work := EnvironmentService.InstallWork.new()
		work.run(EnvironmentService.DESCRIPTOR.data.arena, archive, destination)
		_check(work.result.is_empty(), "Pinned arena extracts with exact PCK hash")
		work = EnvironmentService.InstallWork.new()
		work.run(EnvironmentService.DESCRIPTOR.data.arena, "missing-download.zip", destination)
		_check(work.result.is_empty(), "Installed verified PCK needs no new download")
		var bad := EnvironmentService.DESCRIPTOR.data.arena.duplicate()
		bad.pack_sha256 = "0".repeat(64)
		work = EnvironmentService.InstallWork.new()
		work.run(bad, archive, destination.path_join("corrupt"))
		_check(not work.result.is_empty(), "Changed pack pin is rejected")
	print("ANDROID_VISUAL_CHOICE_CHECK ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
