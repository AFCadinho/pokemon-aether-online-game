extends "res://tools/sprite_factory/measure_mega_garchomp_standing.gd"
## Sample skinned mesh bounds at 120 Hz for the existing reviewed placement.
## Arguments: APPROVED_NORMAL_SCN OUTPUT_JSON
func _run():
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2 and FileAccess.get_sha256(args[0]) == "23805df764f17e7e8df8851d9c7caf8d40ddaa49efb15262d7534ad4b2084b45")
	var actor: Node3D = load(args[0]).instantiate()
	root.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	var addon: AnimationLibrary = load("res://resources/battle/model_animations/charmander_breath.res")
	library.add_animation("special_attack_2", addon.get_animation("special_attack_2").duplicate(true))
	player.remove_animation_library("")
	player.add_animation_library("", library)
	player.play("special_attack_2")
	player.pause()
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var envelope := AABB()
	var minima: Array = []
	for sample in 277:
		player.seek(sample / 120.0, true)
		for skeleton: Skeleton3D in skeletons: skeleton.force_update_all_bone_transforms()
		await process_frame
		RenderingServer.force_draw(false)
		var box := bounds(meshes)
		minima.append(box.position.y)
		envelope = box if sample == 0 else envelope.merge(box)
	var offsets: Array = []
	for sample in 139:
		var low := INF
		for nearby in range(maxi(0, sample*2-2), mini(minima.size(), sample*2+3)):
			low = minf(low, minima[nearby])
		offsets.append(maxf(0, 0.03 - 0.02563108327584957 - low * 1.3982627641402978))
	var result := {"bounds":{"min":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"motion":{"duration":2.3,"intent":"clearance_only","offsets":offsets}}
	FileAccess.open(args[1], FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("CHARMANDER_BREATH_MEASURED min=",envelope.position.y," max=",envelope.end.y)
	quit()
