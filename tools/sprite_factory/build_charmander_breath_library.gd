extends SceneTree
## Rig-checked start + one native loop + end. No mesh/material tracks are shipped.
## Arguments: SOURCE_GLB APPROVED_NORMAL_SCN OUTPUT_RES
const TYPES := [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
const TARGET_SHA := "23805df764f17e7e8df8851d9c7caf8d40ddaa49efb15262d7534ad4b2084b45"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3 and FileAccess.get_sha256(args[0]) == "2901cf04993bc24fd8d382c70a4f8c239b2c2ac45c8a3fbda784143987d01e79" and FileAccess.get_sha256(args[1]) == TARGET_SHA)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(args[0], state) == OK)
	var source := document.generate_scene(state)
	var target: Node = load(args[1]).instantiate()
	var skeleton: Skeleton3D = target.find_children("*", "Skeleton3D", true, false)[0]
	var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	assert(skeleton.get_bone_count() == source_skeleton.get_bone_count())
	for bone in skeleton.get_bone_count():
		assert(skeleton.get_bone_name(bone) == source_skeleton.get_bone_name(bone))
		assert(skeleton.get_bone_parent(bone) == source_skeleton.get_bone_parent(bone))
		assert(skeleton.get_bone_rest(bone).is_equal_approx(source_skeleton.get_bone_rest(bone)))
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var target_player: AnimationPlayer = target.find_children("*", "AnimationPlayer", true, false)[0]
	var path := player.get_node(player.root_node).get_path_to(source_skeleton)
	assert(path == target_player.get_node(target_player.root_node).get_path_to(skeleton))
	var combined := Animation.new()
	combined.length = 138.0 / 60.0
	var parts := ["breath_start", "breath_loop", "breath_end"]
	var durations := [40, 38, 60]
	for bone in skeleton.get_bone_count():
		var bone_path := NodePath(str(path) + ":" + skeleton.get_bone_name(bone))
		var rest := skeleton.get_bone_rest(bone)
		var defaults := [rest.origin, rest.basis.get_rotation_quaternion(), rest.basis.get_scale()]
		for type in TYPES:
			var track := combined.add_track(type)
			combined.track_set_path(track, bone_path)
			var offset := 0
			for part in parts.size():
				var clip := player.get_animation(parts[part])
				assert(is_equal_approx(clip.length, durations[part] / 60.0))
				var source_track := clip.find_track(bone_path, type)
				for frame in durations[part] + (1 if part == parts.size()-1 else 0):
					var value: Variant = defaults[TYPES.find(type)]
					if source_track >= 0:
						match type:
							Animation.TYPE_POSITION_3D: value = clip.position_track_interpolate(source_track, frame/60.0)
							Animation.TYPE_ROTATION_3D: value = clip.rotation_track_interpolate(source_track, frame/60.0)
							Animation.TYPE_SCALE_3D: value = clip.scale_track_interpolate(source_track, frame/60.0)
					# Native parts expect a short transition at their boundary.
					# Blend four native frames without extending the attack clock.
					if part > 0 and frame < 4:
						var previous := player.get_animation(parts[part-1])
						var previous_track := previous.find_track(bone_path, type)
						var from: Variant = defaults[TYPES.find(type)]
						if previous_track >= 0:
							match type:
								Animation.TYPE_POSITION_3D: from = previous.position_track_interpolate(previous_track, previous.length)
								Animation.TYPE_ROTATION_3D: from = previous.rotation_track_interpolate(previous_track, previous.length)
								Animation.TYPE_SCALE_3D: from = previous.scale_track_interpolate(previous_track, previous.length)
						value = from.slerp(value, frame / 4.0) if type == Animation.TYPE_ROTATION_3D else from.lerp(value, frame / 4.0)
					combined.track_insert_key(track, (offset + frame)/60.0, value)
				offset += durations[part]
	var library := AnimationLibrary.new()
	assert(library.add_animation("special_attack_2", combined) == OK)
	assert(ResourceSaver.save(library, args[2], ResourceSaver.FLAG_COMPRESS) == OK)
	print("CHARMANDER_BREATH_LIBRARY_OK bones=", skeleton.get_bone_count(), " frames=138 sha256=", FileAccess.get_sha256(args[2]))
	source.free()
	target.free()
	quit()
