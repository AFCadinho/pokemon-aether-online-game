extends SceneTree
## Build a review-only pose correction on the exact approved normal/shiny scenes.
const ROOT := "res://.tmp/mega-garchomp-posture-v1/"
const SOURCE := ROOT + "ground/export/motion.glb"
const OLD := "res://.tmp/mega-native-rest-v1/"
const TYPES = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "ground/export/motion.json"))
	assert(FileAccess.get_sha256(SOURCE) == motion.glb_sha256)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(SOURCE, state) == OK)
	var source := document.generate_scene(state)
	var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var registry: Dictionary = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json").data
	var output := ProjectSettings.globalize_path(ROOT + "candidates")
	DirAccess.make_dir_recursive_absolute(output)
	var entries := []
	for shiny in [false, true]:
		var name := "garchompmega" + ("-shiny" if shiny else "")
		var identity := "garchomp-mega" + ("@shiny" if shiny else "")
		var original := OLD + "garchompmega/runtime/" + name + ".scn"
		assert(FileAccess.get_sha256(original) == registry.models[identity].sha256)
		var actor: Node3D = load(original).instantiate()
		var skeleton: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		assert(skeleton.get_bone_count() == source_skeleton.get_bone_count())
		for bone in skeleton.get_bone_count():
			assert(skeleton.get_bone_name(bone) == source_skeleton.get_bone_name(bone))
			assert(skeleton.get_bone_rest(bone).is_equal_approx(source_skeleton.get_bone_rest(bone)))
		var bone_path := player.get_node(player.root_node).get_path_to(skeleton)
		var source_bone_path := source_player.get_node(source_player.root_node).get_path_to(source_skeleton)
		assert(bone_path == source_bone_path)
		var library := AnimationLibrary.new()
		for action in motion.animations:
			var clip: Animation = source_player.get_animation(action).duplicate(true)
			for track in clip.get_track_count():
				assert(clip.track_get_type(track) in TYPES)
				assert(str(clip.track_get_path(track)).begins_with(str(bone_path) + ":"))
			clip.loop_mode = Animation.LOOP_LINEAR if motion.animations[action].loop else Animation.LOOP_NONE
			# Keep existing non-skeletal visibility/material tracks, scaled to the native clip duration.
			var old: Animation = player.get_animation(action)
			for track in old.get_track_count():
				if old.track_get_type(track) in TYPES:
					continue
				old.copy_track(track, clip)
				var added := clip.get_track_count()-1
				for key in clip.track_get_key_count(added):
					clip.track_set_key_time(added, key, clip.track_get_key_time(added,key)*clip.length/old.length)
			library.add_animation(action,clip)
		player.stop()
		player.remove_animation_library("")
		player.add_animation_library("",library)
		var packed := PackedScene.new()
		assert(packed.pack(actor) == OK)
		var destination := output.path_join(name+".scn")
		assert(ResourceSaver.save(packed,destination,ResourceSaver.FLAG_COMPRESS) == OK)
		entries.append({"species":name,"status":"exported_for_review","path":ProjectSettings.globalize_path(SOURCE),
			"glb_sha256":motion.glb_sha256,"runtime_path":destination,"runtime_sha256":FileAccess.get_sha256(destination),
			"animations":motion.animations,"review_poses":[["idle",0.0,"front"],["idle",0.5,"side"],["physical_attack",0.5,"front"],["special_attack",0.5,"front"],["sleep",0.5,"front"],["faint_start",1.0,"front"]]})
		RenderingServer.force_draw(false)
		actor.free()
	var file := FileAccess.open(output.path_join("catalog.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"entries":entries},"\t")+"\n")
	file.close()
	RenderingServer.force_draw(false)
	source.free()
	print("MEGA_GARCHOMP_POSTURE_CANDIDATES_OK variants=2 skeletons_equal=true")
	quit()
