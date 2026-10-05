extends "res://tests/battle_3d_mega_catalog_stress_check.gd"
## Same real battle, three rounds and prepared frame intervals for 58 forms.
var observed_drawn_frame := -1
var forced_test_frames := 0
var last_draw_tick := 0
var reported_failure := false

func _sample_frame() -> void:
	super._sample_frame()
	if is_instance_valid(stage) and stage.preparation_failed and not reported_failure:
		reported_failure = true
		print("REGIONAL_STRESS_PREPARATION_DIAGNOSTIC ", {"context": context,
			"metrics": stage.preparation_metrics, "identities": stage.identities,
			"failed_models": stage.failed_models, "packed": stage.packed.keys(),
			"pending": stage._models_pending(), "active": stage.active,
			"loaded_path": stage.loaded_path, "arena_preparing": stage.arena_preparing,
			"forced_test_frames": forced_test_frames, "drawn_frames": Engine.get_frames_drawn(),
			"window_mode": root.mode, "window_visible": root.visible, "window_size": root.size})

func _ensure_test_frame() -> void:
	if DisplayServer.get_name() != "headless" and root.mode == Window.MODE_MINIMIZED:
		root.mode = Window.MODE_WINDOWED
		root.grab_focus()
	var now := Time.get_ticks_msec()
	if Engine.get_frames_drawn() != observed_drawn_frame:
		last_draw_tick = now
	# A skipped draw between process frames is normal. Only intervene after a
	# sustained stall, avoiding extra GPU submissions during the measured run.
	if DisplayServer.get_name() != "headless" and now - last_draw_tick >= 250:
		RenderingServer.force_draw(false)
		forced_test_frames += 1
		last_draw_tick = now
	observed_drawn_frame = Engine.get_frames_drawn()

func _run() -> void:
	process_frame.connect(_ensure_test_frame)
	# WindowFit/Settings apply a deferred startup resolution. Let them finish
	# before the inherited benchmark requests its fixed 1280 x 720 viewport.
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.always_on_top = true
		root.show()
		root.grab_focus()
	await super._run()
	var path := OS.get_environment("POKEAETHER_BATCH01_STRESS_OUTPUT")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report["forced_test_frames"] = forced_test_frames
	report["window_size"] = [root.size.x, root.size.y]
	report["window_mode"] = root.mode
	report["render_policy"] = "Actual viewport draws forced only when compositor suppressed automatic frames; original preparation and frame-time thresholds retained"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()

func _ready_pair(species: String, left_shiny: bool, right_shiny: bool) -> void:
	await super._ready_pair(species, left_shiny, right_shiny)
	assert(root.size == Vector2i(1280, 720), "Benchmark window changed from 1280 x 720")
