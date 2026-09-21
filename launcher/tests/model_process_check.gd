extends SceneTree
const Store = preload("res://scripts/model_pack_store.gd")
const ModelsPanel = preload("res://scripts/model_packs_panel.gd")
var child_pid := -1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.get_name() == "Linux", "This process fixture tests the Linux launcher path")
	var isolated_data := OS.get_environment("POKEAETHER_E2E_DATA_HOME")
	assert(isolated_data.is_absolute_path() and OS.get_environment("XDG_DATA_HOME") == isolated_data, "Explicit isolated userdata required")
	assert(ProjectSettings.globalize_path("user://").begins_with(isolated_data.trim_suffix("/") + "/"))
	var output := OS.get_environment("POKEAETHER_E2E_OUTPUT")
	var phase := OS.get_environment("POKEAETHER_E2E_PHASE")
	assert(output.is_absolute_path() and phase in ["install", "restart"])
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var store := Store.new()
	var panel := ModelsPanel.new()
	root.add_child(panel)
	var localization := root.get_node("LauncherLocalization")
	localization.set_locale("nl")
	panel.setup(localization.text)
	panel.popup_centered()
	if phase == "install":
		assert(store.installed().is_empty() and store.selected_id().is_empty(), "Use fresh isolated launcher userdata")
		# Exercise the file-picker signal and selection button, not the store directly.
		panel.picker.file_selected.emit(OS.get_environment("POKEAETHER_MODEL_PACK_ZIP"))
		await _wait_panel(panel)
		assert(store.installed().size() == 1, panel.status.text)
		assert(store.selected_catalog().is_empty())
		panel.choices.select(1)
		panel.select_button.pressed.emit()
		await _wait_panel(panel)
	else:
		assert(store.installed().size() == 1 and panel.choices.selected == 1, "Selection lost across launcher process restart")
	var catalog := store.selected_catalog()
	assert(not catalog.is_empty())
	await RenderingServer.frame_post_draw
	assert(panel.get_texture().get_image().save_png(output.path_join(phase + "-launcher.png")) == OK)
	panel.hide()
	panel.queue_free()
	await process_frame
	var launcher: Variant = load("res://scripts/launcher.gd").new()
	launcher.locale = "nl"
	OS.set_environment("POKEAETHER_E2E_GODOT", OS.get_executable_path())
	OS.set_environment("POKEAETHER_E2E_CHILD_LOG", output.path_join(phase + "-game.log"))
	OS.set_environment("POKEAETHER_E2E_PARENT_PID", str(OS.get_process_id()))
	assert(not FileAccess.file_exists(output.path_join(phase + "-result.json")), "Use a fresh result path")
	# Parent sentinel must be restored, while the child receives the selected catalog.
	OS.set_environment("POKEAETHER_MODEL_CATALOG", "parent-sentinel")
	var executable := OS.get_environment("POKEAETHER_E2E_ENTRY")
	if executable.is_empty():
		executable = ProjectSettings.globalize_path("res://tests/fixtures/model game entry.sh")
	assert(executable.is_absolute_path() and FileAccess.file_exists(executable))
	child_pid = launcher._create_game_process(executable)
	assert(child_pid > 0, "Actual child process did not start")
	assert(OS.get_environment("POKEAETHER_MODEL_CATALOG") == "parent-sentinel")
	launcher.free()
	var deadline := Time.get_ticks_msec() + 220000
	while OS.is_process_running(child_pid):
		if Time.get_ticks_msec() > deadline:
			OS.kill(child_pid) # Only the child created by this test.
			push_error("Game child timed out")
			quit(1)
			return
		await create_timer(0.1).timeout
	var report := Store._json(output.path_join(phase + "-result.json"))
	var log := FileAccess.get_file_as_string(output.path_join(phase + "-game.log"))
	assert(report.get("complete", false) and report.get("catalog_sha256") == FileAccess.get_sha256(catalog))
	assert(report.get("pid") == child_pid and report.get("launcher_pid") == OS.get_process_id())
	if not OS.get_environment("POKEAETHER_E2E_GAME_BINARY").is_empty():
		assert(not OS.has_feature("editor") and report.get("standalone_runtime", false))
	assert(not log.contains("SCRIPT ERROR") and not log.contains("ERROR:"), "Child log contains an error")
	assert(log.contains("MODEL_PROCESS_CHILD_OK"))
	print("MODEL_PROCESS_PARENT_OK phase=", phase, " separate_process=true selection_persisted=true")
	quit()

func _wait_panel(panel: AcceptDialog) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while panel.thread != null:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
