extends SceneTree
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
var failures: Array[String] = []
var report := {"schema": 1, "prototype_only": true, "cases": []}
var output := ""
var expected_cases := 0
var baseline_signatures := {}
var trace_identities: Array = []
const ORIGIN := "http://127.0.0.1:8799/"
class ErrorSink extends Logger:
	var errors: Array[String] = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			errors.append(code + " " + rationale)
var sink := ErrorSink.new()

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, reason: String) -> bool:
	if not ok:
		failures.append(reason)
		print("MODEL_PAIR_FAIL ", reason)
	return ok

func _fetch(name: String) -> PackedByteArray:
	var request := HTTPRequest.new()
	request.timeout = 45
	request.body_size_limit = 134217728
	root.add_child(request)
	if not _check(request.request(ORIGIN + name) == OK, "Loopback fixture request"):
		request.queue_free()
		return PackedByteArray()
	var response: Array = await request.request_completed
	request.queue_free()
	return response[3] if _check(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200, "HTTP fixture") else PackedByteArray()

func _install(pin: Dictionary, directory: String) -> bool:
	var bytes := await _fetch(pin.pack)
	if not _check(bytes.size() == int(pin.pack_bytes) and Audit.digest(bytes) == pin.pack_sha256, "Pinned experiment PCK"):
		return false
	DirAccess.make_dir_recursive_absolute(directory)
	var pack_path := directory.path_join(pin.pack)
	var file := FileAccess.open(pack_path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return _check(ProjectSettings.load_resource_pack(pack_path, false), "Mount pinned namespace")

func _case(directory: String, manifest: Dictionary) -> Dictionary:
	var error := Contract.validate(directory, manifest)
	if not _check(error.is_empty(), "Pre-load contract: " + error):
		return {}
	var row := {"species": manifest.species, "variant": manifest.variant, "models": [], "shared_objects": 0}
	var scenes: Array[PackedScene] = []
	var sets: Array[Dictionary] = []
	var references: Array[WeakRef] = []
	for model: Dictionary in manifest.models:
		var path := ProjectSettings.localize_path(directory.path_join(model.path))
		var started := Time.get_ticks_usec()
		if not _check(ResourceLoader.load_threaded_request(path, "PackedScene", false, ResourceLoader.CACHE_MODE_IGNORE) == OK, "Threaded load request"):
			return {}
		var deadline := Time.get_ticks_msec() + 60000
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline:
			await process_frame
		if not _check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED, "Threaded load completes"):
			return {}
		var scene := ResourceLoader.load_threaded_get(path) as PackedScene
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		if not _check(scene != null, "Loaded PackedScene"):
			return {}
		var semantic := Audit.signature(scene)
		# ShaderMaterial can expose declared defaults only with a real renderer
		# (dummy returns null). Keep the headless golden check, and compare the
		# complete native graph against the hash-pinned ORIGINAL on that runtime.
		# No property is omitted, and no tolerance/normalization is introduced.
		if DisplayServer.get_name() == "headless":
			_check(semantic == model.semantic_sha256, "Exact headless semantic values: " + str(model.identity))
		if manifest.variant == "baseline":
			baseline_signatures[model.identity] = semantic
		else:
			_check(baseline_signatures.has(model.identity) and semantic == baseline_signatures.get(model.identity), "Exact runtime original semantic values: " + str(model.identity))
		var fingerprints := {}
		if model.identity in trace_identities:
			Contract.fingerprints(scene, "scene", fingerprints, {})
		var objects := Contract.textures(scene, {}, {})
		for texture: Texture2D in objects.values():
			references.append(weakref(texture))
		sets.append(objects)
		scenes.append(scene)
		row.models.append({"identity": model.identity, "load_ms": elapsed, "textures": objects.size(),
			"semantic_sha256": semantic, "matches_headless_reference": semantic == model.semantic_sha256,
			"original_runtime_semantic_sha256": baseline_signatures.get(model.identity, ""), "fingerprints": fingerprints})
		objects = {}
		scene = null
	for id: int in sets[0]:
		if sets[1].has(id):
			row.shared_objects += 1
	_check((int(row.shared_objects) > 0) == (manifest.variant == "shared"), "Only shared bundle reuses actual texture objects")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.2).timeout
		row["texture_counter_bytes"] = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	# A remaining shiny scene must keep shared objects alive after normal leaves.
	sets.clear()
	scenes[0] = null
	await process_frame
	_check(not Contract.textures(scenes[1], {}, {}).is_empty(), "Shiny survives normal release")
	scenes.clear()
	await process_frame
	# Check weak refs in the caller after this coroutine's temporary Variant
	# values have left scope; otherwise its last get() can retain shiny.
	row["_texture_refs"] = references
	_check(Contract.validate(directory, manifest).is_empty(), "Post-load hashes unchanged")
	return row

func _run() -> void:
	OS.add_logger(sink)
	var fixture := {}
	var base := ""
	if OS.has_feature("android"):
		if not _check(OS.is_debug_build() and OS.has_feature("android_model_pairs"), "Separate tagged diagnostic app"):
			_finish()
			return
		fixture = JSON.parse_string((await _fetch("fixture.json")).get_string_from_utf8())
		report["run_id"] = fixture.get("run_id", "")
		base = "user://model-pair-textures-" + str(Time.get_unix_time_from_system()).replace(".", "-")
		output = "user://android-model-pairs-details.json"
	else:
		var args := OS.get_cmdline_user_args()
		if not _check(args.size() == 2, "Host fixture and output"):
			_finish()
			return
		fixture = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		base = args[0].get_base_dir()
		output = args[1].path_join("details.json")
		DirAccess.make_dir_recursive_absolute(args[1])
	if not _check(fixture.get("prototype_only", false) and fixture.get("pairs", []) is Array and not fixture.get("pairs", []).is_empty(), "Nonempty prototype cohort"):
		_finish()
		return
	expected_cases = fixture.pairs.size() * 2
	trace_identities = fixture.get("trace_identities", [])
	for pair: Dictionary in fixture.pairs:
		for variant in ["baseline", "shared"]:
			var pin: Dictionary = pair[variant]
			var directory := base.path_join(pair.species + "/" + variant)
			if OS.has_feature("android") and not await _install(pin, directory):
				_finish()
				return
			if not OS.has_feature("android"):
				var pack_path := base.path_join(pin.pack)
				_check(FileAccess.get_sha256(pack_path) == pin.pack_sha256, "Host PCK hash")
				_check(ProjectSettings.load_resource_pack(pack_path, false), "Host PCK mount")
			var row := await _case(pin.resource_root, pin.manifest)
			if row.has("_texture_refs"):
				await process_frame
				var alive := 0
				for reference: WeakRef in row._texture_refs:
					alive += int(reference.get_ref() != null)
				row.erase("_texture_refs")
				row["remaining_texture_refs"] = alive
				_check(alive == 0, "No textures retained after load scope leaves")
			report.cases.append(row)
			print("MODEL_PAIR_CASE ", pair.species, " ", variant, " shared=", row.get("shared_objects", -1), " remaining=", row.get("remaining_texture_refs", -1))
	_finish()

func _finish() -> void:
	report["failures"] = failures
	report["engine_errors"] = sink.errors
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["expected_cases"] = expected_cases
	report["success"] = failures.is_empty() and sink.errors.is_empty() and expected_cases > 0 and report.cases.size() == expected_cases
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("MODEL_PAIR_BUNDLE_COMPLETE ", report.success)
	quit(0 if report.success else 1)
