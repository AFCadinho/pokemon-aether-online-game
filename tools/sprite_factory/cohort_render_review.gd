extends "res://tools/sprite_factory/control_render_probe.gd"

const ACTIONS = ["idle","physical_attack","special_attack","damage","sleep","faint_start","faint_loop"]

class ReviewStage:
	extends ControlStage
	func _build_classic_ground() -> void:
		pass # Isolate raw model geometry; an arena floor must not hide uncalibrated source poses.

func effect_time(actor: Node, seconds: float) -> void:
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(surface)
			if mat is ShaderMaterial and mat.get_meta("pokeaether_material_effect",0)==1:
				mat.set_shader_parameter("review_time",seconds)

func save_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"  "))
	f.close()

func _run() -> void:
	base = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	output = OS.get_environment("COHORT_REVIEW_OUTPUT")
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sprite_factory/catalog_100_visual_triage_results.json"))
	for row: Dictionary in ledger.entries:
		if row.technical_status != "converted":
			continue
		var path: String = base.path_join(row.runtime_path)
		assert(FileAccess.get_sha256(path)==row.runtime_sha256)
		var directory := output.path_join(row.species)
		DirAccess.make_dir_recursive_absolute(directory)
		var stage := ReviewStage.new()
		root.add_child(stage)
		stage.setup()
		stage.set_process(false)
		stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stage.size = Vector2(512,512)
		stage.active = true
		stage._build_world()
		stage.viewport.size = Vector2i(512,512)
		stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var packed: PackedScene = load(path)
		var actor: Node3D = packed.instantiate()
		stage.world.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		var box: AABB = await _sample(actor,player,"idle",0)
		actor.scale *= 2.8/maxf(box.size.y,0.1)
		box = _bounds(actor)
		actor.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
		var union := _bounds(actor)
		for action in ACTIONS:
			assert(player.has_animation(action))
			for i in 9:
				union = union.merge(await _sample(actor,player,action,float(i)/8.0))
		# Bounding sphere of all sampled motion, unchanged per model across views/clips.
		stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		stage.camera.size = maxf(union.size.length()*1.2,1.0)
		stage.camera.far = maxf(stage.camera.size*10,1000)
		var target := union.get_center()
		stage.camera.position = target+Vector3(0.4,0.2,1).normalized()*stage.camera.size*3
		stage.camera.look_at(target)
		stage.packed[row.species] = packed
		stage.identities[0] = row.species
		stage.actors[0] = actor
		var helper: Node = stage.material_response
		helper._process(0)
		assert(helper.viewport.get_parent()==stage.viewport)
		helper._sync()
		var record := {"species":row.species,"runtime_sha256":row.runtime_sha256,"runtime_approved":false,"camera_size":stage.camera.size,"sampled_union_min":[union.position.x,union.position.y,union.position.z],"sampled_union_size":[union.size.x,union.size.y,union.size.z],"clips":[],"static_images":[]}
		for view in ["front","back"]:
			var direction := Vector3(0.4,0.2,1) if view=="front" else Vector3(-0.4,0.2,-1)
			stage.camera.position = target+direction.normalized()*stage.camera.size*3
			stage.camera.look_at(target)
			for pose in [["idle",0.0],["special_attack",0.5],["sleep",0.5],["faint_start",1.0],["faint_loop",0.5]]:
				await _sample(actor,player,pose[0],pose[1])
				effect_time(actor,pose[1])
				helper._sync()
				await RenderingServer.frame_post_draw
				var name: String = pose[0]+"-"+view+".png"
				assert(stage.viewport.get_texture().get_image().save_png(directory.path_join(name))==OK)
				record.static_images.append(name)
		stage.camera.position = target+Vector3(0.4,0.2,1).normalized()*stage.camera.size*3
		stage.camera.look_at(target)
		for action in ACTIONS:
			player.stop()
			for skeleton in actor.find_children("*","Skeleton3D",true,false):
				skeleton.reset_bone_poses()
			player.play(action)
			player.pause()
			player.seek(0,true)
			var duration := player.get_animation(action).length
			var loop: bool = action in ["idle","sleep","faint_loop"]
			var count := int(ceil(duration*12))*(2 if loop else 1)
			var mismatches := 0
			for tick in count+1:
				player.advance(1.0/12.0 if tick>0 else 0)
				effect_time(actor,float(tick)/12.0)
				helper._sync()
				await RenderingServer.frame_post_draw
				mismatches+=int(mismatch(helper).different>0)
				assert(stage.viewport.get_texture().get_image().save_png(directory.path_join(action+"-%04d.png"%tick))==OK)
			record.clips.append({"action":action,"duration":duration,"frames":count+1,"fps":12,"cycles":2 if loop else 1,"bone_mismatch_frames":mismatches})
		assert(FileAccess.get_sha256(path)==row.runtime_sha256)
		save_json(directory.path_join("report.json"),record)
		results.append(record)
		stage.free()
		print("COHORT_REVIEW_DONE ",row.species," ",results.size(),"/88")
		await process_frame
	save_json(output.path_join("report.json"),results)
	assert(results.size()==88)
	quit()
