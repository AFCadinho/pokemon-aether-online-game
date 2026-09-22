extends "res://tools/sprite_factory/phase5_godot_review.gd"

class ControlStage:
	extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
	func _requested_arena() -> String:
		return "classic"

var base: String
var output: String
var results: Array = []

func mismatch(helper: Node) -> Dictionary:
	var bad := 0
	var total := 0
	for pair in helper.pairs[0]:
		if pair[0] is Skeleton3D:
			for bone in pair[0].get_bone_count():
				total += 1
				if not pair[0].get_bone_pose(bone).is_equal_approx(pair[1].get_bone_pose(bone)):
					bad += 1
	return {"bones":total,"different":bad}

func capture(stage: Node, name: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(stage.viewport.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)

func _run() -> void:
	base = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	output = OS.get_environment("CONTROL_REVIEW_OUTPUT")
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output)==OK)
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sprite_factory/catalog_100_visual_triage_results.json"))
	for row: Dictionary in ledger.entries:
		if row.species not in ["dragonite","jigglypuff","ditto","eevee"]:
			continue
		if not OS.get_environment("CONTROL_REVIEW_SPECIES").is_empty() and row.species != OS.get_environment("CONTROL_REVIEW_SPECIES"):
			continue
		var path: String = base.path_join(row.runtime_path)
		assert(FileAccess.get_sha256(path)==row.runtime_sha256)
		var stage := ControlStage.new()
		root.add_child(stage)
		stage.setup()
		stage.set_process(false) # No battle host/network/cache activity in diagnostic.
		stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stage.size = Vector2(640,640)
		stage.active = true
		stage._build_world()
		stage.viewport.size = Vector2i(640,640)
		stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		stage.viewport.msaa_3d = Viewport.MSAA_4X
		var packed: PackedScene = load(path)
		var actor: Node3D = packed.instantiate()
		stage.world.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		var box: AABB = await _sample(actor,player,"idle",0)
		# Same deterministic normalization rule; never saved back into candidate.
		actor.scale *= 2.8/maxf(box.size.y,0.1)
		box = _bounds(actor)
		actor.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
		stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		stage.camera.size = 4.5
		stage.camera.position = Vector3(3,2.5,8)
		stage.camera.look_at(Vector3(0,1.35,0))
		stage.packed[row.species] = packed
		stage.identities[0] = row.species
		stage.actors[0] = actor
		var helper: Node = stage.material_response
		helper._process(0)
		assert(helper.copies[0]!=null)
		if OS.get_environment("CONTROL_REVIEW_PARENT_ORDER")=="1":
			helper.viewport.reparent(stage.viewport)
		helper._sync()
		var copy_player: AnimationPlayer = helper.copies[0].find_children("*","AnimationPlayer",true,false)[0]
		var record := {"species":row.species,"runtime_sha256":row.runtime_sha256,"samples":[],"motion":[]}
		for action in ["idle","special_attack","sleep","faint_start"]:
			for fraction in [0.0,0.5,1.0]:
				await _sample(actor,player,action,fraction)
				helper._sync()
				var name: String = row.species+"-"+action+"-"+str(fraction)
				await capture(stage,name+"-runtime")
				record.samples.append({"action":action,"fraction":fraction,"mode":"runtime","pose":mismatch(helper),"image":name+"-runtime.png"})
				# Reproduce old viewer: independently sample the disabled clone instead of copying poses.
				RenderingServer.frame_pre_draw.disconnect(helper._sync)
				await _sample(helper.copies[0],copy_player,action,fraction)
				await capture(stage,name+"-legacy")
				record.samples.append({"action":action,"fraction":fraction,"mode":"legacy","pose":mismatch(helper),"image":name+"-legacy.png"})
				RenderingServer.frame_pre_draw.connect(helper._sync)
				helper._sync()
		# Continuous native clips, deterministic 30Hz advances, actual runtime layer sync.
		for action in ["idle","special_attack","sleep","faint_start","faint_loop"]:
			player.stop()
			player.play(action)
			player.pause()
			player.seek(0,true)
			var count := int(ceil(player.get_animation(action).length*30))
			var bad_frames := 0
			var settled: Array = []
			for tick in count+1:
				player.advance(1.0/30.0 if tick>0 else 0)
				helper._sync()
				await RenderingServer.frame_post_draw
				if mismatch(helper).different>0:
					bad_frames+=1
				assert(stage.viewport.get_texture().get_image().save_png(output.path_join(row.species+"-motion-"+action+"-%04d.png"%tick))==OK)
				if tick in [0,count/4,count/2,count*3/4,count]:
					var first := stage.viewport.get_texture().get_image()
					var first_light: Image = helper.viewport.get_texture().get_image()
					assert(first_light.save_png(output.path_join(row.species+"-light-first-"+action+"-%04d.png"%tick))==OK)
					for wait_frame in 4:
						await process_frame
					await RenderingServer.frame_post_draw
					var stable := stage.viewport.get_texture().get_image()
					var stable_light: Image = helper.viewport.get_texture().get_image()
					assert(stable_light.save_png(output.path_join(row.species+"-light-settled-"+action+"-%04d.png"%tick))==OK)
					var changed := 0
					for y in stable.get_height():
						for x in stable.get_width():
							var a := first.get_pixel(x,y)
							var b := stable.get_pixel(x,y)
							if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>0.05:
								changed+=1
					assert(stable.save_png(output.path_join(row.species+"-settled-"+action+"-%04d.png"%tick))==OK)
					settled.append({"tick":tick,"pixels_changed_over_0_05":changed,"pose":mismatch(helper),"light_bytes_equal":first_light.get_data()==stable_light.get_data()})
					if OS.get_environment("CONTROL_REVIEW_EXPECT_CURRENT_FRAME")=="1":
						assert(first.get_data()==stable.get_data(),"Main pass sampled stale irradiance")
						assert(mismatch(helper).different==0,"Render-layer poses diverged")
			record.motion.append({"action":action,"rendered_frames":count+1,"mismatched_frames":bad_frames,"duration":player.get_animation(action).length,"settled_checks":settled})
		results.append(record)
		assert(FileAccess.get_sha256(path)==row.runtime_sha256)
		stage.free()
		print("CONTROL_DONE ",row.species)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	quit()
