extends SceneTree
## Exported debug diagnostic: unchanged approved models, real downloader/renderer.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Platform = preload("res://scripts/battle/battle_ui/model_platform.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const SPECIES := ["Pikachu", "Bulbasaur", "Charmander", "Dragonite", "Garchomp", "Roaring Moon", "Wailord", "Weezing", "Charizard", "Charizard-Mega-X"]
const REPORT := "user://android-3d-pilot-details.json"
const CONFIG = preload("res://data/android_3d_pilot.json")
const CACHE_ONLY_MARKER := "user://android-3d-pilot-cache-only"
var cache_only := false
var stage: Control
var service: Node
var settings: Node
var title: Label
var failures: Array[String] = []
var samples: Array[float] = []
var observing := false
var last_tick := 0
var peak_static := 0.0
var peak_render := 0.0
var cases: Array[Dictionary] = []
var finished := false
var total_started := 0
var shiny := false
var selected := 0

class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()

func _init() -> void:
	process_frame.connect(_sample_frame)
	_run.call_deferred()

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		print("ANDROID_3D_PILOT_FAIL ", reason)
	return ok

func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if observing and last_tick > 0:
		samples.append((now - last_tick) / 1000.0)
	last_tick = now
	peak_static = maxf(peak_static, Performance.get_monitor(Performance.MEMORY_STATIC))
	peak_render = maxf(peak_render, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	if not finished and not sink.errors.is_empty():
		_finish()
	if is_instance_valid(title) and service != null and is_instance_valid(service.active_request):
		title.text = service.progress_text()

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _observe(seconds: float) -> void:
	# Pose observation has the same wall duration across devices. A software
	# emulator must still draw several frames, rather than spend minutes counting
	# frames that represent only a second on a phone. This is a functional probe.
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	var frames := 0
	while frames < 3 or Time.get_ticks_msec() < deadline:
		await process_frame
		frames += 1

func _ui() -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var panel := HBoxContainer.new()
	panel.position = Vector2(20, 20)
	layer.add_child(panel)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)

func _run() -> void:
	service = root.get_node("OnDemand3DBundleService")
	settings = root.get_node("SettingsManager")
	OS.add_logger(sink)
	total_started = Time.get_ticks_msec()
	_ui()
	if not _check(OS.has_feature("android") and OS.has_feature("android_3d_pilot") and Platform.supported(), "Requires the tagged Android debug pilot APK"):
		_finish()
		return
	settings.battle_presentation_mode = "3d" # This test process only; never saved.
	settings.battle_3d_arena = "stadium"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = false
	cache_only = FileAccess.file_exists(CACHE_ONLY_MARKER)
	if cache_only:
		await _verify_restart_cache()
		_finish()
		return
	if not await _forest():
		_finish()
		return
	stage = Stage.new()
	root.add_child(stage)
	stage.setup()
	# A large opponent also exercises memory pressure, without Mega dependencies.
	stage.set_combatant(1, "Wailord")
	for name: String in SPECIES:
		for variant: bool in [false, true]:
			var tick := Time.get_ticks_msec()
			stage.set_combatant(0, name, variant)
			await stage.await_prepared(true, 30000)
			if not _check(stage.active and stage.handles("p1") and not stage.preparation_failed, name + " preparation: " + stage.reason):
				_finish()
				return
			var key: String = Reviewed.key(name, variant)
			_check(stage.identities[0] == key, name + " correct normal/shiny identity")
			_check(stage.entries[key].runtime_sha256 == Reviewed.DATA.data.models[key].sha256, name + " exact reviewed model hash")
			stage.set_sleeping(0, false)
			samples.clear()
			observing = true
			await _observe(1.5)
			_check(stage.current_actions[0] == "idle", name + " idle pose")
			stage.start_action("p1", "physical_attack")
			_check(stage.current_actions[0] == "physical_attack", name + " physical attack clip")
			await _observe(1.0)
			await stage.wait_action("p1")
			stage.set_sleeping(0, true)
			await _observe(0.5)
			_check(stage.current_actions[0] == "sleep", name + " sleep pose")
			stage.set_sleeping(0, false)
			await _observe(0.1)
			_check(stage.current_actions[0] == "idle", name + " return to idle")
			observing = false
			cases.append(_case(name, variant, tick))
			title.text = name + (" shiny" if variant else " normal") + " · stadium"
			if variant:
				await _capture(name.to_lower().replace(" ", "-") + "-shiny")
			else:
				await _capture(name.to_lower().replace(" ", "-") + "-normal")
			print("ANDROID_3D_PILOT_CASE ", name, " shiny=", variant)
	# Production preparation includes possible Mega forms before their reveal.
	stage.set_combatant(0, "Charizard")
	await stage.await_prepared(true, 30000)
	var source: String = settings.get_battle_3d_catalog_path()
	var mega_ids: Array[String] = ["charizard-mega-x"]
	var already_installed: Dictionary = await service.ensure_models(mega_ids, source)
	_check(not bool(already_installed.get("catalog_changed", true)), "Mega X already downloaded before transformation")
	var ready: bool = await stage.prepare_mega_form("p1", "Charizard-Mega-X", false, 10000)
	_check(ready, "Mega form prepared while the base model remains visible")
	stage.set_combatant(0, "Charizard-Mega-X")
	await stage.await_prepared(true, 30000)
	_check(stage.identities[0] == "charizard-mega-x" and stage.active, "Mega form reveal uses 3D")
	stage.start_move_action("p1", "Flamethrower")
	var effect: Node = stage.create_move_effect("Flamethrower", "p1", "p2", {})
	_check(effect != null, "Real 3D attack effect created")
	await _frames(1)
	await _capture("mega-flamethrower")
	await _observe(2.5)
	settings.battle_3d_arena = "forest"
	stage.set_battle_context(&"grass", "wild")
	stage.set_combatant(0, "Roaring Moon")
	var tick := Time.get_ticks_msec()
	await stage.await_prepared(true, 30000)
	_check(stage.active and stage.arena_id == "forest", "Actual grassfield art loaded, without classic fallback: " + stage.arena_problem)
	samples.clear()
	observing = true
	await _observe(3.0)
	observing = false
	cases.append(_case("Roaring Moon / grassfield", false, tick))
	await _capture("grassfield")
	var identities: Array[String] = []
	for name: String in SPECIES:
		identities.append(Reviewed.key(name, false))
		identities.append(Reviewed.key(name, true))
	var cached: Dictionary = await service.ensure_models(identities, settings.get_battle_3d_catalog_path())
	_check(str(cached.get("error", "")).is_empty() and not bool(cached.get("catalog_changed", true)), "Repeated complete cohort reuses verified files")
	_finish()
	_manual_controls()

func _verify_restart_cache() -> void:
	# A separate process verifies delivery reuse without exercising the emulator's
	# unstable graphics backend again. Rendering qualification is the full run.
	var identities: Array[String] = []
	for name: String in SPECIES:
		identities.append(Reviewed.key(name, false))
		identities.append(Reviewed.key(name, true))
	var installed: Dictionary = await service.ensure_models(identities, "")
	_check(str(installed.get("error", "")).is_empty() and not bool(installed.get("catalog_changed", true)), "Restart reuses complete installed cohort")
	var verified: Dictionary = installed.get("verified_models", {})
	for identity: String in identities:
		var file: Dictionary = verified.get(identity, {})
		var ok: bool = str(file.get("sha256", "")) == Reviewed.DATA.data.models[identity].sha256
		_check(ok, "Restart verifies exact reviewed model: " + identity)
		cases.append({"identity": identity, "cache_verified": ok})
	var forest_cached: bool = service._valid_file(ProjectSettings.globalize_path("user://android-3d-pilot-forest.zip"), int(CONFIG.data.forest.bytes), CONFIG.data.forest.sha256)
	_check(forest_cached, "Forest archive persisted with its approved hash")
	var forest_ok: bool = await _forest()
	cases.append({"asset": "forest", "cache_verified": forest_cached and forest_ok})

func _forest() -> bool:
	var pin: Dictionary = CONFIG.data.forest
	title.text = "Preparing grassfield assets…"
	var archive := "user://android-3d-pilot-forest.zip"
	if not service._valid_file(ProjectSettings.globalize_path(archive), int(pin.bytes), pin.sha256):
		var error: String = await service._fetch(pin.url, archive, int(pin.bytes), pin.sha256, 128 * 1024 * 1024, "grassfield")
		if not _check(error.is_empty(), "Hash-pinned forest pack download: " + error):
			return false
	var zip := ZIPReader.new()
	if not _check(zip.open(archive) == OK, "Forest archive readable"):
		return false
	if not _check(zip.get_files().size() == 2 and "forest-runtime/forest.pck" in zip.get_files() and "forest-runtime/forest.json" in zip.get_files(), "Forest archive contains exactly its approved files"):
		zip.close()
		return false
	var folder := "user://android-3d-pilot-forest"
	DirAccess.make_dir_recursive_absolute(folder)
	for name: String in zip.get_files():
		var path := folder.path_join(name.get_file())
		var bytes := zip.read_file(name)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		if not service._valid_file(ProjectSettings.globalize_path(path), bytes.size(), hashing.finish().hex_encode()):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if not _check(file != null, "Forest extraction file writable"):
				zip.close()
				return false
			file.store_buffer(bytes)
			file.close()
	zip.close()
	settings.battle_3d_forest_manifest = folder.path_join("forest.json")
	return true

func _case(name: String, variant: bool, started: int) -> Dictionary:
	var ordered := samples.duplicate()
	ordered.sort()
	return {"species": name, "shiny": variant, "elapsed_ms": Time.get_ticks_msec() - started,
		"preparation": stage.preparation_metrics.duplicate(true), "frames": ordered.size(),
		"frame_p95_ms": ordered[int(ordered.size() * 0.95)] if not ordered.is_empty() else 0,
		"frame_max_ms": ordered.back() if not ordered.is_empty() else 0,
		"render_size": {"width": stage.viewport.size.x, "height": stage.viewport.size.y},
		"static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"render_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://android-3d-pilot-" + name + ".png")

func _finish() -> void:
	if finished:
		return
	finished = true
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	var report := {"schema": 1, "platform": OS.get_name(), "pilot": OS.has_feature("android_3d_pilot"),
		"cache_only": cache_only,
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "failures": failures, "engine_errors": sink.errors,
		"elapsed_ms": Time.get_ticks_msec() - total_started, "peak_static_bytes": peak_static,
		"peak_render_bytes": peak_render, "downloaded_model_bytes": service.downloaded_bytes(),
		"cache_entries": Cache.items.size(), "cases": cases,
		"completed_downloads": service.get("completed_downloads"),
		"limitation": "Emulator results do not certify physical ARM64 phone FPS, battery or thermal behavior."}
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	title.text = "3D Android pilot · " + ("PASS" if failures.is_empty() and sink.errors.is_empty() else "CHECK REPORT")
	print("ANDROID_3D_PILOT_COMPLETE ", JSON.stringify({"cases": cases.size(), "failures": failures.size(), "engine_errors": sink.errors.size()}))
	quit(0 if failures.is_empty() and sink.errors.is_empty() else 1)

func _manual_controls() -> void:
	var panel := HBoxContainer.new()
	panel.position = Vector2(20, 70)
	root.add_child(panel)
	var select := OptionButton.new()
	for name: String in SPECIES:
		select.add_item(name)
	select.item_selected.connect(func(index: int): selected = index; _manual_pair())
	panel.add_child(select)
	var variant := CheckButton.new()
	variant.text = "Shiny"
	variant.toggled.connect(func(value: bool): shiny = value; _manual_pair())
	panel.add_child(variant)
	var camera := Button.new()
	camera.text = "Other side"
	camera.pressed.connect(func(): stage.user_camera_yaw = PI if is_zero_approx(stage.user_camera_yaw) else 0.0)
	panel.add_child(camera)
	for arena: String in ["stadium", "forest"]:
		var button := Button.new()
		button.text = arena.capitalize()
		button.pressed.connect(func(): settings.battle_3d_arena = arena; stage.set_battle_context(&"grass", "wild"); _manual_pair())
		panel.add_child(button)

func _manual_pair() -> void:
	stage.set_combatant(0, SPECIES[selected], shiny)
	await stage.await_prepared(true, 30000)
	title.text = SPECIES[selected] + (" shiny" if shiny else " normal")
