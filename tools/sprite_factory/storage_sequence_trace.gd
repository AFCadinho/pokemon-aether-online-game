extends "res://tools/sprite_factory/storage_components_check.gd"
## Read-only sequence diagnostics against the existing component artifact.
var snapshots := {}
var leases := []
var sink := ErrorSink.new()
var persistent_stage: Stage
var retained_resources := []
var capture_context := {}

func clear_cache() -> void:
	if OS.get_environment("TRACE_WARM_CACHE") != "1":
		super.clear_cache()

func stop_on_pixel_mismatch() -> bool:
	return OS.get_environment("TRACE_COLLECT") != "1"

func diagnostic_state(node: Node3D) -> Dictionary:
	var animation_player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if OS.get_environment("TRACE_RAYS") == "1" and animation_player.assigned_animation == "faint_start" and animation_player.current_animation_position > animation_player.get_animation("faint_start").length * 0.99:
		var cam := node.get_viewport().get_camera_3d()
		for sample in [Vector2(0.375, 0.125), Vector2(0.875, 0.375), Vector2(0.125, 0.625), Vector2(0.625, 0.875)]:
			var screen: Vector2 = Vector2(265, 308) + sample
			var origin := cam.project_ray_origin(screen)
			var direction := cam.project_ray_normal(screen)
			var hits := []
			for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				var baked: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
				for surface in baked.get_surface_count():
					var arrays := baked.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					for offset in range(0, indices.size(), 3):
						var a: Vector3 = mesh.global_transform * vertices[indices[offset]]
						var b: Vector3 = mesh.global_transform * vertices[indices[offset+1]]
						var c: Vector3 = mesh.global_transform * vertices[indices[offset+2]]
						var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
						if hit != null:
							hits.append({"mesh": str(mesh.name), "surface": surface, "triangle": offset/3, "distance": origin.distance_to(hit), "facing": (b-a).cross(c-a).dot(direction)})
			hits.sort_custom(func(a,b): return a.distance < b.distance)
			if not report.has("pixel_rays"):
				report.pixel_rays = []
			report.pixel_rays.append({"capture": capture_context.duplicate(), "sample": sample, "hits": hits.slice(0, 4)})
	if OS.get_environment("TRACE_RUNTIME") != "1":
		return {}
	var values := {}
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var baked: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in baked.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			var properties: Variant = material
			if material is ShaderMaterial:
				properties = {"shader": material.shader}
				for uniform in material.shader.get_shader_uniform_list():
					# Runtime irradiance texture is compared through final pixels.
					if uniform.name != "light_map":
						properties[uniform.name] = material.get_shader_parameter(uniform.name)
			values[str(node.get_path_to(mesh)) + ":" + str(surface)] = {
				"posed_arrays": Components.fingerprint(baked.surface_get_arrays(surface)),
				"material": Components.fingerprint(properties)}
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	values["animation"] = [player.assigned_animation, player.current_animation_position, player.is_playing()]
	return values

class ErrorSink:
	extends Logger
	var lock := Mutex.new()
	var errors := []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		errors.append({"function": function, "file": file, "line": line, "code": code, "rationale": rationale, "kind": kind})
		lock.unlock()
	func snapshot() -> Array:
		lock.lock()
		var result := errors.duplicate(true)
		lock.unlock()
		return result

func save_report() -> void:
	report["engine_errors"] = sink.snapshot()
	super.save_report()

func load_entry(entry: Dictionary, prototype: bool) -> Dictionary:
	var use_components := prototype and OS.get_environment("TRACE_ORIGINAL_ONLY") != "1"
	var loaded := super.load_entry(entry, use_components)
	if OS.get_environment("TRACE_UNSHADED") == "1":
		for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(i).duplicate(false)
				if material is BaseMaterial3D:
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(i, material)
	if OS.get_environment("TRACE_UNSHARE_MESH") == "1":
		for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
			mesh.mesh = mesh.mesh.duplicate(false)
	if OS.get_environment("TRACE_RETAIN_SHARED") == "1":
		retained_resources.append(cache[cache_key(entry, use_components)])
	if OS.get_environment("TRACE_STABLE_ORDER") == "1":
		var priority := -64
		for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(i).duplicate(false)
				material.render_priority = priority
				priority += 1
				mesh.set_surface_override_material(i, material)
	if OS.get_environment("TRACE_PIN_MATERIALS") == "1":
		var materials := []
		for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				materials.append(mesh.get_active_material(i))
		loaded["material_leases"] = materials
	if OS.get_environment("TRACE_HASH") == "1":
		var item: Dictionary = cache[cache_key(entry, use_components)]
		snapshots[entry.identity] = resource_hashes(item)
		print("RESOURCE_BEFORE ", entry.identity, " components=", use_components, " ", snapshots[entry.identity])
		for key in item:
			leases.append({"identity": entry.identity, "kind": key, "resource": weakref(item[key])})
	return loaded

func resource_hashes(item: Dictionary) -> Dictionary:
	var result := {}
	for key in item:
		result[key] = Components.fingerprint(item[key])
	return result

func pose(node: Node3D, action: String, fraction: float) -> void:
	super.pose(node, action, fraction)
	var hidden := OS.get_environment("TRACE_HIDE_NODE")
	if not hidden.is_empty():
		var target := node.find_child(hidden, true, false) as Node3D
		assert(target != null)
		target.hide()

func make_stage() -> Stage:
	if OS.get_environment("TRACE_PERSISTENT_STAGE") == "1" and is_instance_valid(persistent_stage):
		return persistent_stage
	var stage := super.make_stage()
	if not OS.get_environment("TRACE_CAMERA_NEAR").is_empty():
		stage.camera.near = float(OS.get_environment("TRACE_CAMERA_NEAR"))
	if OS.get_environment("TRACE_PERSISTENT_STAGE") == "1":
		persistent_stage = stage
	if OS.get_environment("TRACE_NO_SHADOWS") == "1":
		for light: DirectionalLight3D in stage.world.find_children("*", "DirectionalLight3D", true, false):
			light.shadow_enabled = false
	if OS.get_environment("TRACE_NO_MSAA") == "1":
		stage.viewport.msaa_3d = Viewport.MSAA_DISABLED
	return stage

func dispose_stage(stage: Stage) -> void:
	if OS.get_environment("TRACE_PERSISTENT_STAGE") != "1":
		super.dispose_stage(stage)
		return
	for child in stage.get_children():
		if child.get_script() == Response:
			child.free()
	for actor in stage.actors:
		if is_instance_valid(actor):
			actor.queue_free()
	stage.actors = [null, null]
	stage.packed.clear()

func capture(entry: Dictionary, prototype: bool, two_pass: bool, transform: Transform3D) -> Dictionary:
	capture_context = {"identity": entry.identity, "components": prototype, "response": two_pass}
	if two_pass and OS.get_environment("TRACE_SKIP_RESPONSE") == "1":
		return {"unsupported_response": true}
	var result := await super.capture(entry, prototype, two_pass, transform)
	if OS.get_environment("TRACE_RUNTIME") == "1" and result.has("diagnostics"):
		if not report.has("runtime_states"):
			report.runtime_states = []
		report.runtime_states.append({"identity": entry.identity, "components": prototype,
			"response": two_pass, "states": result.diagnostics})
	if OS.get_environment("TRACE_HASH") == "1":
		var use_components := prototype and OS.get_environment("TRACE_ORIGINAL_ONLY") != "1"
		var after := resource_hashes(cache[cache_key(entry, use_components)])
		var unchanged: bool = after == snapshots[entry.identity]
		report.traces.append({"identity": entry.identity, "components": prototype,
			"actual_components": use_components,
			"response": two_pass, "before": snapshots[entry.identity], "after": after, "unchanged": unchanged})
		print("RESOURCE_AFTER ", entry.identity, " unchanged=", unchanged)
		if not unchanged:
			report["resource_mutation"] = true
			report["failure"] = "Shared/source resource mutated: " + str(entry.identity)
		save_report()
	return result

func _run() -> void:
	OS.add_logger(sink)
	report["traces"] = []
	report["trace_flags"] = {}
	for flag in ["TRACE_ONLY", "TRACE_CAMERA_NEAR", "TRACE_REPEAT", "TRACE_COLLECT", "TRACE_WARM_CACHE", "TRACE_RAYS", "TRACE_RUNTIME", "TRACE_GEOMETRY", "TRACE_HIDE_NODE", "TRACE_UNSHADED", "TRACE_ORIGINAL_ONLY", "TRACE_HASH", "TRACE_NO_SHADOWS", "TRACE_NO_MSAA", "TRACE_SKIP_RESPONSE", "TRACE_PIN_MATERIALS", "TRACE_STABLE_ORDER", "TRACE_PERSISTENT_STAGE", "TRACE_RETAIN_SHARED", "TRACE_UNSHARE_MESH"]:
		report.trace_flags[flag] = OS.get_environment(flag)
	if OS.get_environment("STORAGE_COMPONENT_MODE") == "lease_probe":
		directory = OS.get_environment("STORAGE_COMPONENT_OUTPUT")
		manifest = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("prototype.json")))
		for id in manifest.components:
			assert(FileAccess.get_sha256(resource_path(id)) == manifest.components[id].sha256)
		for source in manifest.entries:
			assert(FileAccess.get_sha256(source.source_path) == source.source_sha256)
		report["lease_probe"] = []
		var entry: Dictionary = manifest.entries.filter(func(e): return e.identity == "articuno")[0]
		for cycle in 3:
			for kind in ["original", "private_unpinned", "private_pinned", "private_detached"]:
				await probe_lease(entry, kind)
				clear_cache()
				for frame in 3:
					await process_frame
		report.complete = true
		save_report()
		quit()
	else:
		await super._run()

func visuals() -> void:
	var only := OS.get_environment("TRACE_ONLY").split(",", false)
	if not only.is_empty():
		manifest.entries = manifest.entries.filter(func(e): return e.identity in only)
	var entries: Array = manifest.entries.duplicate()
	for repeat_index in range(1, maxi(1, int(OS.get_environment("TRACE_REPEAT")))):
		manifest.entries.append_array(entries)
	if OS.get_environment("TRACE_GEOMETRY") == "1":
		report["geometry_overlaps"] = []
		for entry in manifest.entries:
			var loaded := load_entry(entry, false)
			var stage := make_stage()
			stage.world.add_child(loaded.node)
			pose(loaded.node, "damage", 0)
			var triangles := {}
			var overlaps := {}
			for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
				var baked: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
				for surface in baked.get_surface_count():
					var label := str(loaded.node.get_path_to(mesh)) + ":" + str(surface)
					var arrays := baked.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					print("SURFACE ", label, " vertices=", vertices.size(), " material=", mesh.get_active_material(surface).resource_name, " cull=", mesh.get_active_material(surface).get("cull_mode"))
					for offset in range(0, indices.size(), 3):
						var points := []
						for corner in 3:
							points.append(mesh.global_transform * vertices[indices[offset + corner]])
						points.sort_custom(func(a: Vector3, b: Vector3): return a.x < b.x if a.x != b.x else (a.y < b.y if a.y != b.y else a.z < b.z))
						var key := Components.sha(var_to_bytes(points))
						if triangles.has(key):
							var pair := str(triangles[key]) + " -> " + label
							overlaps[pair] = overlaps.get(pair, 0) + 1
						else:
							triangles[key] = label
			print("GEOMETRY_OVERLAPS ", entry.identity, " ", overlaps)
			report.geometry_overlaps.append({"identity": entry.identity, "exact_posed_triangle_overlaps": overlaps})
			stage.free()
		report.complete = true
		return
	await super.visuals()
	super.clear_cache()
	retained_resources.clear()
	if is_instance_valid(persistent_stage):
		persistent_stage.queue_free()
		persistent_stage = null
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var remaining := []
	for lease in leases:
		if lease.resource.get_ref() != null:
			remaining.append({"identity": lease.identity, "kind": lease.kind})
	report["resources_alive_after_final_clear"] = remaining
	report["loads"] = loads
	# This fixed artifact has seven clips, three samples per clip, two modes.
	var expected: int = manifest.entries.size() * 42 - report.get("response_skipped", []).size() * 21
	report["all_samples_collected"] = report.comparisons.size() == expected
	save_report()

func probe_lease(entry: Dictionary, kind: String) -> void:
	var loaded := super.load_entry(entry, kind != "original")
	var held := []
	var watched := []
	for mesh: MeshInstance3D in loaded.node.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			watched.append(weakref(mesh.get_active_material(surface)))
			if kind == "private_pinned":
				held.append(mesh.get_active_material(surface))
			if kind == "private_detached":
				mesh.set_surface_override_material(surface, null)
	var before := sink.snapshot().size()
	loaded.node.free()
	for frame in 3:
		await process_frame
	var alive := 0
	for ref in watched:
		if ref.get_ref() != null:
			alive += 1
	var item := {"kind": kind, "engine_errors": sink.snapshot().size() - before,
		"materials_alive_after_node_free": alive}
	report.lease_probe.append(item)
	print("LEASE_PROBE ", item)
