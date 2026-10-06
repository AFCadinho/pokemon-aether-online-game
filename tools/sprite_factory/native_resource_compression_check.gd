extends "res://tools/sprite_factory/storage_components_check.gd"
## Compare native resources with identical decompressed streams; no component assembly.
var native_entries: Array
var native_resource_lease := {}

class ErrorSink extends Logger:
	var errors: Array = []
	var lock := Mutex.new()
	var tree: SceneTree
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		errors.append({"function": function, "file": file, "line": line, "code": code, "rationale": rationale, "kind": kind})
		lock.unlock()
		if tree != null:
			tree.call_deferred("native_error_abort")

var sink := ErrorSink.new()

func native_error_abort() -> void:
	report.complete = false
	report["failure"] = "Engine or script error; inspect engine_errors"
	if not OS.get_environment("STORAGE_COMPONENT_REPORT").is_empty():
		save_report()
	quit(2)

func memory() -> Dictionary:
	var values := super.memory()
	# procfs reports a zero file length; get_file_as_string does not read it.
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status != null:
		while not status.eof_reached():
			var line := status.get_line()
			if line.begins_with("VmRSS:"):
				values.rss_bytes = int(line.trim_prefix("VmRSS:").strip_edges().split("kB")[0]) * 1024
				break
	return values

func load_entry(entry: Dictionary, prototype: bool) -> Dictionary:
	var key := cache_key(entry, prototype)
	var started := Time.get_ticks_usec()
	var hit := cache.has(key)
	if not hit:
		while order.size() >= 2:
			cache.erase(order.pop_front())
		var use_candidate := prototype and OS.get_environment("NATIVE_ORIGINAL_ONLY") != "1"
		var path: String = entry.candidate_path if use_candidate else entry.source_path
		var scene: PackedScene
		if OS.get_environment("NATIVE_REFERENCE_LEASE") == "1" and native_resource_lease.has(path):
			scene = native_resource_lease[path]
		else:
			scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			if OS.get_environment("NATIVE_REFERENCE_LEASE") == "1":
				# Diagnostic only: repeated source captures share immutable resource
				# RIDs. Original and candidate paths NEVER share a PackedScene.
				native_resource_lease[path] = scene
		assert(scene != null, "Native resource did not load: " + entry.identity)
		cache[key] = {"scene": scene}
	order.erase(key)
	order.append(key)
	var item: Dictionary = cache[key]
	var node := item.scene.instantiate() as Node3D
	assert(node != null)
	loads.append({"identity": key, "hit": hit, "ms": (Time.get_ticks_usec() - started) / 1000.0})
	return {"node": node, "scene": item.scene}

func save_report() -> void:
	report["engine_errors"] = sink.errors.duplicate(true)
	super.save_report()

func native_pair_lifecycle(entry: Dictionary, candidate_first: bool) -> Dictionary:
	var results := []
	var signatures := []
	var references := []
	var stage := make_stage()
	for candidate in [candidate_first, not candidate_first]:
		clear_cache()
		var loaded := load_entry(entry, candidate)
		var duplicate := load_entry(entry, candidate)
		var node: Node3D = loaded.node
		var other: Node3D = duplicate.node
		assert(loaded.scene == duplicate.scene, "Native scene cache hit failed")
		references.append(weakref(loaded.scene))
		stage.world.add_child(node)
		stage.world.add_child(other)
		await process_frame
		pose(other, "idle", 0.0)
		var idle := signature(other)
		var states := {}
		var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for action in player.get_animation_list():
			if action == "RESET":
				continue
			for fraction in [0.0, 0.5, 0.999]:
				pose(node, action, fraction)
				assert(signature(other) == idle, "Independent actor inherited animation")
				states[str(action) + ":" + str(fraction)] = signature(node)
		assert(node.visible, "Native faint unexpectedly hid actor")
		signatures.append(states)
		results.append({"candidate": candidate, "memory_with_two_actors": memory()})
		node.queue_free()
		other.queue_free()
		for frame in 3:
			await process_frame
		loaded.clear()
		duplicate.clear()
		clear_cache()
		await process_frame
	assert(signatures[0] == signatures[1], "Native posed actor state changed: " + entry.identity)
	for reference: WeakRef in references:
		assert(reference.get_ref() == null, "Native scene retained after cache eviction")
	stage.queue_free()
	for frame in 3:
		await process_frame
	return {"identity": entry.identity, "candidate_first": candidate_first,
		"states_equal": true, "pose_comparisons": signatures[0].size(),
		"scene_references_released": true, "samples": results}

func native_lifecycle() -> void:
	# Alternating load order avoids the earlier source-always-first diagnostic.
	# These are warm-filesystem loader measurements, not battle/FPS qualification.
	report["lifecycle"] = []
	report["memory_before_cycles"] = memory()
	for cycle in 3:
		var start := Time.get_ticks_usec()
		for index in native_entries.size():
			var entry: Dictionary = native_entries[index]
			var result := await native_pair_lifecycle(entry, (cycle + index) % 2 == 0)
			result["cycle"] = cycle
			report.lifecycle.append(result)
		for frame in 8:
			await process_frame
		report.cycles.append({"cycle": cycle, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0,
			"after_clear": memory()})
		save_report()
		print("NATIVE_LIFECYCLE_OK cycle=", cycle, " entries=", native_entries.size())

func native_diagnostic() -> void:
	# The renderer previously showed a sequence-sensitive one-pixel difference
	# even for original A/A scenes. Preserve exact image comparisons and report
	# the unchanged-reference control instead of accepting a pixel tolerance.
	var entry: Dictionary = native_entries.filter(func(item): return item.identity == "dragonite")[0]
	report["diagnostic"] = []
	for two_pass in [false, true]:
		clear_cache()
		var a := await capture(entry, false, two_pass, Transform3D.IDENTITY)
		clear_cache()
		var b := await capture(entry, false, two_pass, a.camera)
		clear_cache()
		var c := await capture(entry, true, two_pass, a.camera)
		for key in a.images:
			var bytes_a: PackedByteArray = a.images[key].get_data()
			var bytes_b: PackedByteArray = b.images[key].get_data()
			var bytes_c: PackedByteArray = c.images[key].get_data()
			var aa := 0
			var ac := 0
			for index in range(0, bytes_a.size(), 4):
				if bytes_a.slice(index, index + 4) != bytes_b.slice(index, index + 4):
					aa += 1
				if bytes_a.slice(index, index + 4) != bytes_c.slice(index, index + 4):
					ac += 1
			report.diagnostic.append({"pose": key, "response": two_pass,
				"original_vs_original_pixels": aa, "original_vs_recompressed_pixels": ac})
		save_report()

func _run() -> void:
	sink.tree = self
	OS.add_logger(sink)
	directory = OS.get_environment("NATIVE_COMPRESSION_OUTPUT")
	assert(directory.is_absolute_path())
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("report.json")))
	assert(source.complete and source.entries.size() > 0)
	native_entries = source.entries
	report["godot"] = Engine.get_version_info().string
	report["source_script_sha256"] = FileAccess.get_sha256("res://tools/sprite_factory/native_resource_compression_check.gd")
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["original_only_control"] = OS.get_environment("NATIVE_ORIGINAL_ONLY") == "1"
	report["reference_resource_lease_diagnostic"] = OS.get_environment("NATIVE_REFERENCE_LEASE") == "1"
	assert(not (report.reference_resource_lease_diagnostic and OS.get_environment("NATIVE_COMPRESSION_LIFECYCLE") == "1"), "Retention diagnostic cannot qualify eviction")
	report["container_report_sha256"] = FileAccess.get_sha256(directory.path_join("report.json"))
	report["source_streams_byte_exact"] = true
	report["semantics"] = []
	for entry: Dictionary in native_entries:
		if not entry.has("source_path"):
			# Reference installation from the already hash-verified archive. This
			# creates a private test fixture; source archives are read in place.
			var baseline := directory.path_join("baseline")
			assert(DirAccess.make_dir_recursive_absolute(baseline) == OK)
			entry.source_path = baseline.path_join(str(entry.identity) + ".scn")
			if not FileAccess.file_exists(entry.source_path):
				var reader := ZIPReader.new()
				assert(reader.open(entry.source_archive) == OK)
				var variant := "shiny" if str(entry.identity).ends_with("@shiny") else "normal"
				var bytes := reader.read_file("models/" + variant + ".scn")
				reader.close()
				assert(Components.sha(bytes) == entry.source_sha256)
				var file := FileAccess.open(entry.source_path, FileAccess.WRITE)
				assert(file != null)
				file.store_buffer(bytes)
				file.close()
		assert(FileAccess.get_sha256(entry.source_path) == entry.source_sha256)
		assert(FileAccess.get_sha256(entry.candidate_path) == entry.candidate_sha256)
		var started := Time.get_ticks_usec()
		var original: PackedScene = ResourceLoader.load(entry.source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var original_ms := (Time.get_ticks_usec() - started) / 1000.0
		started = Time.get_ticks_usec()
		var candidate_path: String = entry.source_path if report.original_only_control else entry.candidate_path
		var candidate: PackedScene = ResourceLoader.load(candidate_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var candidate_ms := (Time.get_ticks_usec() - started) / 1000.0
		assert(original != null and candidate != null)
		assert(Components.fingerprint(original) == Components.fingerprint(candidate), "Stored native resource semantics changed: " + entry.identity)
		var original_actor: Node3D = original.instantiate()
		var candidate_actor: Node3D = candidate.instantiate()
		assert(Components.actor_content(original_actor) == Components.actor_content(candidate_actor), "Instantiated actor data changed: " + entry.identity)
		original_actor.free()
		candidate_actor.free()
		original = null
		candidate = null
		report.semantics.append({"identity": entry.identity, "stored_equal": true, "actor_equal": true,
			"original_load_ms": original_ms, "candidate_load_ms": candidate_ms})
		print("NATIVE_SEMANTICS_OK ", entry.identity)
		save_report()
		await process_frame
	assert(sink.errors.is_empty(), "Native loading produced engine errors")
	if OS.get_environment("NATIVE_COMPRESSION_LIFECYCLE") == "1":
		await native_lifecycle()
	elif OS.get_environment("NATIVE_COMPRESSION_DIAGNOSTIC") == "1":
		assert(DisplayServer.get_name() != "headless")
		await native_diagnostic()
	elif OS.get_environment("NATIVE_COMPRESSION_VISUAL") == "1":
		assert(DisplayServer.get_name() != "headless", "Visual comparisons require an actual renderer")
		var requested := OS.get_environment("NATIVE_COMPRESSION_IDENTITIES").split(",", false)
		manifest = {"entries": native_entries.filter(func(entry): return requested.is_empty() or entry.identity in requested)}
		assert(not manifest.entries.is_empty())
		await visuals()
		if report.has("failure"):
			save_report()
			quit(2)
			return
	clear_cache()
	native_resource_lease.clear()
	for frame in 3:
		await process_frame
	report["loads"] = loads
	report.complete = sink.errors.is_empty()
	save_report()
	if not sink.errors.is_empty():
		print("NATIVE_RESOURCE_CHECK_FAILED engine_errors=", sink.errors.size())
		quit(2)
		return
	print("NATIVE_RESOURCE_CHECK_OK scenes=", native_entries.size(), " comparisons=", report.comparisons.size())
	quit()
