extends SceneTree
const Components = preload("res://tools/sprite_factory/storage_components.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
var directory: String
var manifest: Dictionary
var cache := {}
var order := []
var loads := []
var report := {"prototype_only": true, "complete": false, "comparisons": [], "cycles": []}

class Stage:
	extends Control
	var viewport: SubViewport
	var world: Node3D
	var camera: Camera3D
	var actors := [null, null]
	var identities := ["model", ""]
	var packed := {}
	var active := true
	var forest_lease := {}

func _initialize() -> void:
	_run.call_deferred()

func save_report() -> void:
	var file := FileAccess.open(OS.get_environment("STORAGE_COMPONENT_REPORT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))

func memory() -> Dictionary:
	var rss := 0
	for line in FileAccess.get_file_as_string("/proc/self/status").split("\n"):
		if line.begins_with("VmRSS:"):
			rss = int(line.trim_prefix("VmRSS:").strip_edges().split("kB")[0]) * 1024
	return {"rss_bytes": rss, "godot_static_bytes": OS.get_static_memory_usage(),
		"texture_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"buffer_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)}

func resource_path(id: String) -> String:
	return directory.path_join(manifest.components[id].file)

func load_entry(entry: Dictionary, prototype: bool) -> Dictionary:
	var key: String = entry.identity
	var start := Time.get_ticks_usec()
	var hit := cache.has(key)
	if not hit:
		while order.size() >= 2:
			cache.erase(order.pop_front())
		if prototype:
			cache[key] = {"scene": ResourceLoader.load(resource_path(entry.shared)),
				"appearance": ResourceLoader.load(resource_path(entry.appearance))}
		else:
			cache[key] = {"scene": ResourceLoader.load(entry.source_path)}
	order.erase(key)
	order.append(key)
	var item: Dictionary = cache[key]
	var node: Node3D = Components.instantiate(item.scene, item.appearance) if prototype else item.scene.instantiate()
	loads.append({"identity": key, "hit": hit, "ms": (Time.get_ticks_usec() - start) / 1000.0})
	return {"node": node, "scene": item.scene}

func clear_cache() -> void:
	cache.clear()
	order.clear()

func make_stage() -> Stage:
	var stage := Stage.new()
	root.add_child(stage)
	stage.viewport = SubViewport.new()
	stage.viewport.size = Vector2i(512, 512)
	stage.viewport.own_world_3d = true
	stage.viewport.transparent_bg = true
	stage.viewport.msaa_3d = Viewport.MSAA_4X
	stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(stage.viewport)
	stage.world = Node3D.new()
	stage.viewport.add_child(stage.world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.15, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	stage.world.add_child(env)
	Response.apply_neutral_lighting(stage.world)
	stage.camera = Camera3D.new()
	stage.camera.fov = 34
	stage.world.add_child(stage.camera)
	return stage

func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform * vertex
				box = AABB(point, Vector3.ZERO) if first else box.expand(point)
				first = false
	return box

func pose(node: Node3D, action: String, fraction: float) -> void:
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null and player.has_animation(action))
	player.stop()
	for skeleton: Skeleton3D in node.find_children("*", "Skeleton3D", true, false):
		skeleton.reset_bone_poses()
	player.play(action)
	player.pause()
	player.seek(player.get_animation(action).length * fraction, true)
	for skeleton: Skeleton3D in node.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()

func signature(node: Node3D) -> Array:
	var values := []
	for child: Node3D in node.find_children("*", "Node3D", true, false):
		var path := str(node.get_path_to(child))
		# Engine-created simulator IDs differ per instantiation, not per asset.
		# Still compare its class, parent, transform and visibility.
		if child is PhysicalBoneSimulator3D and child.owner == null:
			path = str(node.get_path_to(child.get_parent())) + "/@PhysicalBoneSimulator3D"
		values.append([path, child.transform, child.visible])
		if child is Skeleton3D:
			for bone in child.get_bone_count():
				values.append(child.get_bone_pose(bone))
		if child is MeshInstance3D:
			for shape in child.get_blend_shape_count():
				values.append(child.get_blend_shape_value(shape))
	return values

func capture(entry: Dictionary, prototype: bool, two_pass: bool, camera_transform: Transform3D) -> Dictionary:
	var loaded := load_entry(entry, prototype)
	var node: Node3D = loaded.node
	# Check admission before attaching rendering instances. The earlier harness
	# attached then synchronously freed unsupported legacy actors in one frame.
	if two_pass and (not Response.supported_actor(node) or node.get_meta(Response.META, 0) != 1):
		node.free()
		return {"unsupported_response": true}
	var stage := make_stage()
	stage.world.add_child(node)
	stage.actors[0] = node
	pose(node, "idle", 0)
	if camera_transform == Transform3D.IDENTITY:
		var box := bounds(node)
		stage.camera.position = box.get_center() + Vector3(0, 0.1, 1).normalized() * maxf(box.size.length(), 0.1) * 2
		stage.camera.look_at(box.get_center())
	else:
		stage.camera.transform = camera_transform
	stage.camera.far = 1000
	var response: Node
	if two_pass:
		var packed := PackedScene.new()
		assert(packed.pack(node) == OK)
		stage.packed["model"] = packed
		response = Response.new()
		response.stage = stage
		stage.add_child(response)
	var images := {}
	var signatures := {}
	var placement := {}
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for action in player.get_animation_list():
		if action == "RESET":
			continue
		for fraction in [0.0, 0.5, 0.999]:
			pose(node, action, fraction)
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var key := str(action) + ":" + str(fraction)
			var image := stage.viewport.get_texture().get_image()
			images[key] = image
			signatures[key] = signature(node)
			placement[key] = bounds(node)
	var result := {"images": images, "signatures": signatures, "bounds": placement, "camera": stage.camera.transform}
	stage.queue_free()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return result

func visuals() -> void:
	for entry in manifest.entries:
		for two_pass in [false, true]:
			clear_cache()
			var original := await capture(entry, false, two_pass, Transform3D.IDENTITY)
			clear_cache()
			if original.get("unsupported_response", false):
				var alternative := await capture(entry, true, two_pass, Transform3D.IDENTITY)
				assert(alternative.get("unsupported_response", false), "Response admission changed")
				if not report.has("response_skipped"):
					report["response_skipped"] = []
				report.response_skipped.append(entry.identity)
				continue
			var prototype := await capture(entry, true, two_pass, original.camera)
			if original.signatures != prototype.signatures or original.bounds != prototype.bounds:
				for key in original.signatures:
					if original.signatures[key] != prototype.signatures[key]:
						for index in original.signatures[key].size():
							if original.signatures[key][index] != prototype.signatures[key][index]:
								print("POSE_DIFF ", entry.identity, " ", key, " ", index, " ", original.signatures[key][index], " vs ", prototype.signatures[key][index])
								break
						break
				report["failure"] = "Animation/visibility/grounding state differs: " + entry.identity
				save_report()
				quit(2)
				return
			for key in original.images:
				var a: Image = original.images[key]
				var b: Image = prototype.images[key]
				var equal := a.get_data() == b.get_data()
				report.comparisons.append({"identity": entry.identity, "response": two_pass,
					"pose": key, "pixel_exact": equal, "sha256_original": Components.sha(a.get_data()),
					"sha256_prototype": Components.sha(b.get_data())})
				if not equal:
					report["failure"] = "Pixel mismatch: " + entry.identity + " " + key
					a.save_png(directory.path_join("mismatch-original.png"))
					b.save_png(directory.path_join("mismatch-prototype.png"))
					save_report()
					push_error("STOP: Pixel mismatch " + entry.identity + " " + key)
					quit(2)
					return
			clear_cache()
			print("COMPONENT_VISUAL_OK ", entry.identity, " response=", two_pass)
			save_report()
	report.complete = true

func exercise(entry: Dictionary, prototype: bool, stage: Stage) -> void:
	var loaded := load_entry(entry, prototype)
	var duplicate := load_entry(entry, prototype)
	var node: Node3D = loaded.node
	var other: Node3D = duplicate.node
	stage.world.add_child(node)
	stage.world.add_child(other)
	pose(other, "idle", 0)
	var idle_signature: Array = signature(other)
	for action in ["idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"]:
		pose(node, action, 0.5)
		assert(signature(other) == idle_signature, "Duplicate actor inherited animation")
		await process_frame
	assert(node.visible, "Faint unexpectedly hid actor")
	if prototype:
		var left: MeshInstance3D = node.find_children("*", "MeshInstance3D", true, false)[0]
		var right: MeshInstance3D = other.find_children("*", "MeshInstance3D", true, false)[0]
		assert(left.mesh == right.mesh, "Expected shared immutable geometry")
		assert(left.get_active_material(0) != right.get_active_material(0), "Material state must be instance-owned")
	node.free()
	other.free()

func lifecycle(prototype: bool) -> void:
	report["format"] = "components" if prototype else "original"
	report["baseline_memory"] = memory()
	var stage := make_stage()
	stage.camera.position = Vector3(0, 2, 8)
	stage.camera.look_at(Vector3(0, 1, 0))
	for cycle in 3:
		var start := Time.get_ticks_usec()
		var resident := []
		for entry in manifest.entries:
			await exercise(entry, prototype, stage)
			resident.append(memory())
		clear_cache()
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var retained := []
		for id in manifest.components:
			if ResourceLoader.has_cached(resource_path(id)):
				retained.append(id)
		if prototype:
			assert(retained.is_empty(), "Component resources retained after eviction")
		report.cycles.append({"cycle": cycle, "elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0,
			"resident_samples": resident, "after_clear": memory(), "retained_components": retained.size()})
		print("COMPONENT_LIFECYCLE ", report.format, " cycle=", cycle)
		save_report()
	stage.free()
	report["loads"] = loads
	report.complete = true

func diagnostic() -> void:
	# A/A control: distinguish representation changes from renderer variance.
	var entry: Dictionary = manifest.entries.filter(func(e): return e.identity == "dragonite")[0]
	var a := await capture(entry, false, false, Transform3D.IDENTITY)
	clear_cache()
	var b := await capture(entry, false, false, a.camera)
	clear_cache()
	var c := await capture(entry, true, false, a.camera)
	report["diagnostic"] = []
	for key in a.images:
		var pixels_a: PackedByteArray = a.images[key].get_data()
		var pixels_b: PackedByteArray = b.images[key].get_data()
		var pixels_c: PackedByteArray = c.images[key].get_data()
		var aa := 0
		var ac := 0
		for i in range(0, pixels_a.size(), 4):
			if pixels_a.slice(i, i+4) != pixels_b.slice(i, i+4):
				aa += 1
			if pixels_a.slice(i, i+4) != pixels_c.slice(i, i+4):
				ac += 1
		report.diagnostic.append({"pose": key, "original_vs_original_pixels": aa, "original_vs_components_pixels": ac})
		print("AA_DIAGNOSTIC ", key, " original=", aa, " prototype=", ac)
	report.complete = true

func original_release() -> void:
	# Baseline-only reproduction; no prototype resource is ever loaded.
	var entry: Dictionary = manifest.entries.filter(func(e): return e.identity == "articuno")[0]
	for iteration in 3:
		clear_cache()
		var loaded := load_entry(entry, false)
		loaded.node.free()
		await process_frame
		print("ORIGINAL_RELEASE ", iteration)
	report["note"] = "Original-only rapid instantiate/free; inspect renderer stderr as well as this report."
	report.complete = true

func _run() -> void:
	directory = OS.get_environment("STORAGE_COMPONENT_OUTPUT")
	manifest = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("prototype.json")))
	var start := Time.get_ticks_usec()
	for id in manifest.components:
		assert(FileAccess.get_sha256(resource_path(id)) == manifest.components[id].sha256)
	for entry in manifest.entries:
		assert(FileAccess.get_sha256(entry.source_path) == entry.source_sha256)
	report["integrity_check_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["godot"] = Engine.get_version_info().string
	var mode := OS.get_environment("STORAGE_COMPONENT_MODE")
	if mode == "original_release":
		await original_release()
	elif mode == "diagnostic":
		await diagnostic()
	elif mode == "visual":
		await visuals()
	else:
		await lifecycle(mode == "components")
	save_report()
	print("STORAGE_COMPONENT_CHECK_COMPLETE ", mode, " success=", report.complete)
	quit(0 if report.complete else 2)
