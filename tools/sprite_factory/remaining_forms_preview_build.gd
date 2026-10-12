extends SceneTree
## Explicitly unapproved scenes in a standalone diagnostic project.
const Minior = preload("remaining_minior_preview.gdshader")

func _vector(values: Array) -> Vector4:
	return Vector4(values[0],values[1],values[2],values[3])

func _minior_materials(actor: Node, specs: Dictionary) -> void:
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var name := mesh.get_active_material(surface).resource_name
			if not specs.has(name): continue
			var spec: Dictionary = specs[name]
			var mat := ShaderMaterial.new()
			mat.shader = Shader.new()
			mat.shader.code = Minior.code
			mat.resource_name = name
			for key: String in spec.textures:
				var record: Dictionary = spec.textures[key]
				assert(FileAccess.get_sha256(record.path) == record.sha256)
				var image := Image.load_from_file(record.path)
				assert(image != null and image.get_width()==record.size[0] and image.get_height()==record.size[1])
				image.generate_mipmaps()
				mat.set_shader_parameter(key,ImageTexture.create_from_image(image))
			for key: String in spec.parameters:
				var value: Variant = spec.parameters[key]
				mat.set_shader_parameter(key,_vector(value) if value is Array else value)
			mesh.set_surface_override_material(surface,mat)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2 and args[0].is_absolute_path() and args[1].is_absolute_path())
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	assert(stage.runtime_approved == false)
	var output: String = args[1]
	assert(not FileAccess.file_exists(output.path_join("catalog.json")))
	DirAccess.make_dir_recursive_absolute(output)
	var entries := []
	for entry: Dictionary in stage.entries:
		assert(not entry.runtime_approved)
		assert(FileAccess.get_sha256(entry.path) == entry.glb_sha256)
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(entry.path,state)==OK)
		var actor := doc.generate_scene(state,60)
		assert(actor != null)
		var players := actor.find_children("*","AnimationPlayer",true,false)
		assert(players.size()==1)
		var player: AnimationPlayer = players[0]
		for action: String in entry.animations:
			assert(player.has_animation(action))
			var animation := player.get_animation(action)
			assert(absf(animation.length - float(entry.animations[action].duration)) < 0.02)
			animation.loop_mode = Animation.LOOP_LINEAR if entry.animations[action].loop else Animation.LOOP_NONE
		var completion := preload("complete_pose_channels.gd").new()
		assert(completion.apply(actor),completion.failure)
		if entry.has("minior_materials"): _minior_materials(actor,entry.minior_materials)
		if entry.has("visibility"):
			var visibility := preload("visibility_pack.gd").new()
			assert(visibility.apply(actor,entry.visibility,entry.glb_sha256),visibility.failure)
			for action: String in entry.animations:
				var animation := player.get_animation(action)
				for track in animation.get_track_count():
					if str(animation.track_get_path(track)).ends_with(":visible"):
						animation.value_track_set_update_mode(track,Animation.UPDATE_CONTINUOUS)
		actor.set_meta("remaining_forms_local_preview",true)
		var packed := PackedScene.new()
		assert(packed.pack(actor)==OK)
		var path := output.path_join(entry.species+".scn")
		assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
		var result := entry.duplicate(true)
		result["runtime_path"] = path
		result["runtime_sha256"] = FileAccess.get_sha256(path)
		result["status"] = "exported_for_review"
		result["review_poses"] = [["idle",0.0,"face"],["idle",0.5,"back"],["idle",0.5,"side"],
			["physical_attack",0.5,"front"],["special_attack",0.5,"front"],["damage",0.5,"front"],
			["sleep",0.5,"face"],["faint_start",1.0,"front"]]
		entries.append(result)
		actor.free()
	var file := FileAccess.open(output.path_join("catalog.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"runtime_approved":false,"entries":entries},"  "))
	file.close()
	print("REMAINING_FORMS_PREVIEW_BUILT ",entries.size())
	quit()
