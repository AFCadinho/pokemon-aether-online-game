extends SceneTree
## Diagnostic output only. No runtime validator, catalog or release is changed.
const Core = preload("zygarde_preview_core.gdshader")
const Shell = preload("zygarde_preview_shell.gdshader")

func _initialize() -> void:
	_run.call_deferred()

func _vector(a: Array) -> Vector4:
	assert(a.size() == 4)
	return Vector4(a[0],a[1],a[2],a[3])

func _texture(record: Dictionary) -> ImageTexture:
	assert(FileAccess.get_sha256(record.path) == record.sha256)
	var image := Image.load_from_file(record.path)
	assert(image != null and not image.is_empty())
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _material_tracks(actor: Node, player: AnimationPlayer, entry: Dictionary) -> Array:
	var origin := player.get_node(player.root_node)
	var checks := []
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var name := material.resource_name
			if entry.static_emission.has(name):
				assert(material.next_pass == null)
				var baseline := StandardMaterial3D.new()
				baseline.albedo_color = Color.BLACK
				baseline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				baseline.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				baseline.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				baseline.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				baseline.emission_enabled = true
				baseline.emission = Color.WHITE
				baseline.emission_texture = _texture(entry.static_emission[name])
				baseline.emission_energy_multiplier = entry.static_emission[name].strength
				material.next_pass = baseline
			var clips: Dictionary
			var property: String
			var colour := false
			if entry.material_motion.emission.has(name):
				clips = entry.material_motion.emission[name].clips
				property = "shader_parameter/emission_power" if material is ShaderMaterial else "emission_energy_multiplier"
			elif name == "eff_body_d":
				clips = entry.material_motion.effect_alpha
				property = "albedo_color"
				colour = true
			else: continue
			# Give every affected surface an explicit override so all property paths
			# remain stable after serialization (including ordinary body surfaces).
			mesh.set_surface_override_material(surface,material)
			var path := NodePath(str(origin.get_path_to(mesh))+":surface_material_override/"+str(surface)+":"+property)
			for action: String in entry.animations:
				var animation := player.get_animation(action)
				var track := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track,path)
				animation.track_set_interpolation_type(track,Animation.INTERPOLATION_LINEAR)
				for key: Array in clips[action]:
					animation.track_insert_key(track,key[0],Color(1,1,1,key[1]) if colour else float(key[1]))
			checks.append({"path":str(path),"material":name,"property":property,"alpha":colour,"clips":clips})
	assert(not checks.is_empty())
	return checks

func _build(entry: Dictionary, output: String) -> Dictionary:
	assert(FileAccess.get_sha256(entry.path) == entry.glb_sha256)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(entry.path,state)==OK)
	var actor := doc.generate_scene(state,60)
	assert(actor != null)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	for action: String in entry.animations:
		assert(player.has_animation(action))
		var animation := player.get_animation(action)
		assert(absf(animation.length - float(entry.animations[action].duration)) < 0.001)
		animation.loop_mode = Animation.LOOP_LINEAR if entry.animations[action].loop else Animation.LOOP_NONE
	var completion := preload("complete_pose_channels.gd").new()
	assert(completion.apply(actor),completion.failure)
	var visibility := preload("visibility_pack.gd").new()
	assert(visibility.apply(actor,entry.visibility,entry.glb_sha256),visibility.failure)
	for action in player.get_animation_list():
		var animation := player.get_animation(action)
		for track in animation.get_track_count():
			if str(animation.track_get_path(track)).ends_with(":visible"):
				animation.value_track_set_update_mode(track,Animation.UPDATE_CONTINUOUS)
	var core := ShaderMaterial.new()
	core.shader = Shader.new()
	core.shader.code = Core.code
	core.resource_name = "body_b_01"
	core.set_meta("zygarde_local_preview",true)
	assert(not preload("res://scripts/battle/battle_ui/material_effect.gd").valid(core))
	var spec: Dictionary = entry.materials.body_b_01
	var textures := {"BaseColorMap":"base_tex","BaseColorMap1":"detail_tex","NormalMap":"normal_tex",
		"NormalMap1":"detail_normal_tex","AOMap":"ao_tex","LocalSpecularProbe":"probe_tex"}
	for name: String in textures:
		var texture := _texture(entry.core_textures[name])
		if name == "LocalSpecularProbe":
			var image := texture.get_image()
			for y in image.get_height():
				for x in image.get_width(): assert(image.get_pixel(x,y).is_equal_approx(Color.WHITE))
		core.set_shader_parameter(textures[name],texture)
	for pair in [["tint","BaseColor"],["detail_tint","BaseColorLayer1"],["uv_base","UVScaleOffset"],["uv_detail","UVScaleOffset1"]]:
		core.set_shader_parameter(pair[0],_vector(spec.colors[pair[1]]))
	core.set_shader_parameter("emission_colour",_vector(spec.colors.EmissionColor))
	for pair in [["normal_height","NormalHeight"],["detail_normal_height","NormalHeight1"],["metallic","Metallic"],
		["roughness","Roughness"],["fresnel_min","FresnelAlphaMin"],["fresnel_max","FresnelAlphaMax"],
		["fresnel_bias","FresnelAngleBias"],["probe_intensity","LocalSpecularProbeIntensity"]]:
		core.set_shader_parameter(pair[0],spec.floats[pair[1]])
	var changed := {}
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			assert(material != null)
			var name := material.resource_name
			if name == "body_b_01":
				assert(not mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV2].is_empty())
				mesh.set_surface_override_material(surface,core)
				changed[name] = true
			elif name == "body_a_02":
				var shell := ShaderMaterial.new()
				shell.shader = Shader.new()
				shell.shader.code = Shell.code
				shell.resource_name = name
				shell.set_shader_parameter("color_tex",material.albedo_texture)
				assert(material.normal_texture != null)
				shell.set_shader_parameter("normal_tex",material.normal_texture)
				assert(material.emission_texture != null)
				shell.set_shader_parameter("emission_tex",material.emission_texture)
				shell.set_meta("zygarde_local_preview",true)
				mesh.set_surface_override_material(surface,shell)
				changed[name] = true
			elif name in ["eff_body_c","eff_body_d"]:
				var add := material.duplicate() as StandardMaterial3D
				add.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				add.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				add.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface,add)
				changed[name] = true
	assert(changed.size() == 4)
	var eyes := preload("eye_motion_pack.gd").new()
	assert(eyes.apply(actor,entry.eye_motion,entry.glb_sha256),eyes.failure)
	var checks := _material_tracks(actor,player,entry)
	assert(not checks.is_empty())
	actor.set_meta("zygarde_local_preview",true)
	var packed := PackedScene.new()
	assert(packed.pack(actor)==OK)
	var path := output.path_join(entry.species+".scn")
	assert(ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)==OK)
	actor.free()
	var result := entry.duplicate(true)
	result["runtime_path"] = path
	result["runtime_sha256"] = FileAccess.get_sha256(path)
	result["material_checks"] = checks
	result["status"] = "exported_for_review"
	result["maximum_pose_extent"] = 12
	result["review_poses"] = [["idle",0.0,"front"],["idle",0.5,"back"],["idle",0.5,"side"],
		["physical_attack",0.5,"front"],["special_attack",0.5,"front"],["damage",0.5,"front"],
		["sleep",0.5,"front"],["faint_start",1.0,"front"],["faint_loop",0.5,"front"]]
	return result

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_ZYGARDE_PREVIEW")
	assert(path.is_absolute_path())
	var stage: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("stage.json")))
	assert(stage.runtime_approved == false and stage.entries.size()==2)
	var revision := OS.get_environment("POKEAETHER_ZYGARDE_REVISION")
	if revision.is_empty(): revision = "native"
	assert(revision == revision.get_file() and revision not in [".",".."])
	var output := path.path_join(revision)
	assert(not DirAccess.dir_exists_absolute(output),"Choose a fresh prototype revision")
	DirAccess.make_dir_recursive_absolute(output)
	var entries := []
	for entry: Dictionary in stage.entries:
		var built := _build(entry,output)
		if not built.has("runtime_path"):
			printerr("ZYGARDE_PREVIEW_BUILD_FAILED")
			quit(1)
			return
		entries.append(built)
	var file := FileAccess.open(path.path_join("catalog.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"runtime_approved":false,"entries":entries},"  "))
	file.close()
	print("ZYGARDE_PREVIEW_BUILT ",entries.size())
	quit()
