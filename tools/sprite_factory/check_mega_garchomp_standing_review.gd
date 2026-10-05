extends SceneTree
## Retained-source check: completed channels preserve the approved visible poses.
const Standing = preload("res://scripts/battle/animations/mega_garchomp_standing.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var count := 0
	for shiny in [false,true]:
		var suffix := "-shiny" if shiny else ""
		var identity := "garchomp-mega@shiny" if shiny else "garchomp-mega"
		var original := "res://.tmp/mega-native-rest-v1/garchompmega/runtime/garchompmega"+suffix+".scn"
		assert(FileAccess.get_sha256(original)==Standing.DATA.data.models[identity])
		var reviewed := "res://.tmp/mega-garchomp-posture-v1/candidates/garchompmega"+suffix+".scn"
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.tmp/mega-garchomp-posture-v1/candidates/catalog.json"))
		assert(FileAccess.get_sha256(reviewed)==catalog.entries[int(shiny)].runtime_sha256)
		var a: Node3D = load(original).instantiate()
		var b: Node3D = load(reviewed).instantiate()
		root.add_child(a)
		root.add_child(b)
		var ap: AnimationPlayer = a.find_children("*","AnimationPlayer",true,false)[0]
		var bp: AnimationPlayer = b.find_children("*","AnimationPlayer",true,false)[0]
		var ask: Skeleton3D = a.find_children("*","Skeleton3D",true,false)[0]
		var bsk: Skeleton3D = b.find_children("*","Skeleton3D",true,false)[0]
		assert(Standing.apply(ap,identity,FileAccess.get_sha256(original)))
		for action in ap.get_animation_list():
			for fraction in [0.0,0.25,0.5,0.75,0.99]:
				ap.stop()
				bp.stop()
				ask.reset_bone_poses()
				bsk.reset_bone_poses()
				ap.play(action,0)
				bp.play(action,0)
				ap.seek(ap.get_animation(action).length*fraction,true)
				bp.seek(bp.get_animation(action).length*fraction,true)
				for bone in ask.get_bone_count():
					assert(ask.get_bone_pose(bone).is_equal_approx(bsk.get_bone_pose(bone)),action+" "+ask.get_bone_name(bone))
				count+=1
		a.free()
		b.free()
	print("MEGA_GARCHOMP_REVIEW_PARITY_OK poses=",count)
	quit()
