extends "res://tools/sprite_factory/cohort_render_review.gd"
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")

class ProbeSettings:
	extends Node
	var battle_presentation_mode := "3d"
	var battle_animations := true
	var terrain_effects := false
	var weather_effects := false

func _render(path: String, directory: String) -> Dictionary:
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
	var box := await _sample(actor, player, "idle", 0)
	actor.scale *= 2.8 / maxf(box.size.y, 0.1)
	box = _bounds(actor)
	actor.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.camera.size = 5.5
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
	DirAccess.make_dir_recursive_absolute(directory)
	for view in ["front", "back"]:
		var direction := Vector3(0.4, 0.2, 1) if view == "front" else Vector3(-0.4, 0.2, -1)
		stage.camera.position = Vector3(0, 1.4, 0) + direction.normalized() * 12
		stage.camera.look_at(Vector3(0, 1.4, 0))
		for pose in [["idle", 0.0], ["physical_attack", 0.5], ["special_attack", 0.5], ["sleep", 0.5], ["faint_loop", 0.5]]:
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
			var image_path := directory.path_join(key + ".png")
			assert(image.save_png(image_path) == OK)
			paths.append(image_path)
	await create_timer(1.2).timeout
	var texture_bytes := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var scene_ref: WeakRef = weakref(scene)
	scene = null
	stage.free()
	await process_frame
	assert(scene_ref.get_ref() == null, "Packed scene remained after presentation release")
	return {"frames": frames, "paths": paths, "texture_counter_bytes": texture_bytes, "response_schema": response_schema}

func _run() -> void:
	var settings := ProbeSettings.new()
	settings.name = "SettingsManager"
	root.add_child(settings)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for pin: Dictionary in report.get("packs", []):
		assert(FileAccess.get_sha256(pin.path) == pin.sha256)
		assert(ProjectSettings.load_resource_pack(pin.path, false))
	var directory: String = args[1]
	assert(not DirAccess.dir_exists_absolute(directory))
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var records := []
	for row: Dictionary in report.models:
		if not row.has("candidate_path"):
			continue
		assert(FileAccess.get_sha256(row.source_path) == row.source_sha256)
		assert(FileAccess.get_sha256(row.candidate_path) == row.candidate_sha256)
		var source := await _render(row.source_path, directory.path_join(row.identity + "/source"))
		var repeat_source := await _render(row.source_path, directory.path_join(row.identity + "/repeat-source"))
		var candidate := await _render(row.candidate_path, directory.path_join(row.identity + "/candidate"))
		records.append({"identity": row.identity, "source": source, "candidate": candidate,
			"repeat_source": repeat_source, "all_pixels_exact": source.frames == candidate.frames,
			"repeat_source_pixels_exact": source.frames == repeat_source.frames,
			"frames": source.frames.size(), "prototype_only": true})
		print("MODEL_TEXTURE_RENDER_OK ", row.identity, " frames=", source.frames.size(),
			" pixel_exact=", source.frames == candidate.frames,
			" repeat_source_exact=", source.frames == repeat_source.frames,
			" texture_counter_delta=", source.texture_counter_bytes - candidate.texture_counter_bytes)
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "records": records}, "\t"))
	file.close()
	assert(not records.is_empty() and records.size() == report.models.size())
	quit()
