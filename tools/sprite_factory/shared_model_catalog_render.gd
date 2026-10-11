extends "res://tools/sprite_factory/cohort_render_review.gd"
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Visibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
const Flight = preload("res://scripts/battle/animations/gliscor_flight.gd")
const Standing = preload("res://scripts/battle/animations/mega_garchomp_standing.gd")
const Breath = preload("res://scripts/battle/animations/charmander_breath.gd")
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

class ProbeSettings:
	extends Node
	var battle_presentation_mode := "3d"
	var battle_animations := true
	var terrain_effects := false
	var weather_effects := false
	func is_android_3d_experimental() -> bool:
		return false # Desktop reference settings; preserve the 512x512/MSAA4 contract.

const POSES = [["idle", 0.0], ["physical_attack", 0.5], ["special_attack", 0.5], ["sleep", 0.5], ["faint_loop", 0.5]]

func effect_time(actor: Node, seconds: float) -> void:
	# Older approved fire materials have this authored review uniform without
	# the newer material-effect metadata. Inspect the uniform itself so both
	# unchanged controls and candidates show the same instant of the effect.
	var seen := {}
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			while material != null and not seen.has(material.get_instance_id()):
				seen[material.get_instance_id()] = true
				if material is ShaderMaterial and material.shader != null:
					for uniform: Dictionary in material.shader.get_shader_uniform_list():
						if uniform.name == "review_time":
							material.set_shader_parameter("review_time", seconds)
				material = material.next_pass

func _render_model(path: String, directory: String, identity: String, framing := 0.0) -> Dictionary:
	var stage := ReviewStage.new()
	root.add_child(stage)
	stage.setup()
	stage.set_process(false)
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(512, 512)
	stage.active = true
	stage._build_world()
	stage.viewport.size = Vector2i(512, 512)
	stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.viewport.msaa_3d = Viewport.MSAA_4X
	var scene := ResourceLoader.load(ProjectSettings.localize_path(path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert(scene != null)
	var actor := scene.instantiate() as Node3D
	stage.world.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	var digest := FileAccess.get_sha256(path)
	var profile := Reviewed.resolve(identity, digest)
	assert(not profile.is_empty(), "Missing compiled model binding: " + identity)
	preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
	var corrections := {"visibility": Visibility.apply(actor, identity, digest),
		"flight": Flight.apply(player, identity, digest), "standing": Standing.apply(player, identity, digest),
		"breath": Breath.apply(player, identity, digest)}
	var animation_signature := Audit.signature(player.get_animation_library(""))
	var poses := POSES.duplicate(true)
	for extra in ["physical_attack_2", "special_attack_2"]:
		if player.has_animation(extra):
			poses.append([extra, 0.5])
	if not player.has_animation("faint_loop"):
		# The production presenter retains faint_start's end for legacy models.
		assert(player.has_animation("faint_start"))
		poses[4] = ["faint_start", 1.0]
	for pose in poses:
		assert(player.has_animation(pose[0]), "Missing authored source clip: " + str(pose[0]))
	var box := await _sample(actor, player, "idle", 0)
	actor.scale *= 2.8 / maxf(box.size.y, 0.1)
	box = _bounds(actor)
	actor.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	# Derive a matched camera from the source's visible sampled motion. Reuse
	# it for both controls and the candidate; wide models must not be cropped.
	if framing == 0.0:
		framing = 5.5
		for pose in poses:
			var bounds := await _sample(actor, player, pose[0], pose[1])
			for direction: Vector3 in [Vector3(0.4, 0.2, 1), Vector3(-0.4, 0.2, -1)]:
				var forward := direction.normalized()
				var right := forward.cross(Vector3.UP).normalized()
				var up := right.cross(forward).normalized()
				for corner in 8:
					var relative := bounds.get_endpoint(corner) - Vector3(0, 1.4, 0)
					framing = maxf(framing, maxf(absf(relative.dot(right)), absf(relative.dot(up))) * 2.2)
	stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.camera.size = framing
	stage.camera.far = 1000
	stage.packed["probe"] = scene
	stage.identities[0] = "probe"
	stage.actors[0] = actor
	var helper: Node = stage.material_response
	var authored_supported: bool = helper.supported_actor(actor)
	helper._process(0)
	helper._sync()
	var response_schema := int(actor.get_meta(helper.META, 0))
	if response_schema == 1:
		assert(authored_supported and helper.copies[0] != null)
	else:
		assert(helper.copies[0] == null)
	var frames := {}
	var paths := []
	var pose_signatures := {}
	DirAccess.make_dir_recursive_absolute(directory)
	for view in ["front", "back"]:
		var direction := Vector3(0.4, 0.2, 1) if view == "front" else Vector3(-0.4, 0.2, -1)
		stage.camera.position = Vector3(0, 1.4, 0) + direction.normalized() * 12
		stage.camera.look_at(Vector3(0, 1.4, 0))
		for pose in poses:
			await _sample(actor, player, pose[0], pose[1])
			effect_time(actor, pose[1])
			helper._sync()
			for wait_frame in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			assert(mismatch(helper).different == 0)
			var image := stage.viewport.get_texture().get_image()
			var key: String = view + "-" + pose[0]
			frames[key] = Audit.digest(image.get_data())
			pose_signatures[key] = Audit.signature(_signature(actor))
			var image_path := directory.path_join(key + ".png")
			assert(image.save_png(image_path) == OK)
			paths.append(image_path)
	var texture_bytes := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var scene_ref: WeakRef = weakref(scene)
	scene = null
	stage.free()
	await process_frame
	assert(scene_ref.get_ref() == null, "Packed scene remained after presentation release")
	return {"frames": frames, "paths": paths, "texture_counter_bytes": texture_bytes, "response_schema": response_schema, "camera_size": framing, "animation_signature": animation_signature,
		"pose_signatures": pose_signatures, "corrections": corrections}

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("CATALOG_RENDER_ABORT ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var error_sink := ErrorSink.new()

func _run() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	assert(DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null)
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_animations = true
	settings.terrain_effects = false
	settings.weather_effects = false
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for pin: Dictionary in input.packs:
		var checked := Pair.inspect(pin.path, pin.asset)
		assert(str(checked.error).is_empty(), str(checked.error))
		assert(Pair.mount_checked(pin.path, pin.asset, checked).is_empty())
	var directory: String = args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var records := []
	for row: Dictionary in input.models:
		assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
		assert(FileAccess.get_sha256(row.candidate_path) == row.candidate_sha256)
		var source := await _render_model(row.source_path, directory.path_join(row.identity + "/source"), row.identity)
		var repeat_source := await _render_model(row.source_path, directory.path_join(row.identity + "/repeat-source"), row.identity, source.camera_size)
		var candidate := await _render_model(row.candidate_path, directory.path_join(row.identity + "/candidate"), row.identity, source.camera_size)
		assert(source.animation_signature == repeat_source.animation_signature and source.animation_signature == candidate.animation_signature)
		assert(source.pose_signatures == repeat_source.pose_signatures and source.pose_signatures == candidate.pose_signatures)
		assert(source.corrections == repeat_source.corrections and source.corrections == candidate.corrections)
		var row_result := {"identity": row.identity, "source_sha256": row.source_sha256, "candidate_sha256": row.candidate_sha256,
			"source": source, "repeat_source": repeat_source, "candidate": candidate}
		records.append(row_result)
		save_json(directory.path_join(row.identity + "/receipt.json"), row_result)
		print("CATALOG_RENDERED ", row.identity, " frames=", source.frames.size(), " first_exact=", source.frames == candidate.frames)
	save_json(directory.path_join("report.json"), {"schema": 1, "prototype_only": true, "production_approved": false,
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "complete": records.size() == input.models.size(), "records": records})
	quit()
