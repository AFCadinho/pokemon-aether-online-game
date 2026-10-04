extends SceneTree
## Build only skeletal animation data from the pinned Biochao source export.
## Usage: godot --headless --script ... -- SOURCE_GLB TARGET_APPROVED_SCN OUTPUT_RES
const TYPES = [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]

func complete_clip(original: Animation, skeleton: Skeleton3D, path: NodePath) -> Animation:
	var clip: Animation = original.duplicate(true)
	for track in clip.get_track_count():
		assert(clip.track_get_type(track) in TYPES)
		assert(str(clip.track_get_path(track)).begins_with(str(path) + ":"))
	for bone in skeleton.get_bone_count():
		var bone_path := NodePath(str(path) + ":" + skeleton.get_bone_name(bone))
		var rest := skeleton.get_bone_rest(bone)
		var values := [rest.origin, rest.basis.get_rotation_quaternion(), rest.basis.get_scale()]
		for type in TYPES:
			if clip.find_track(bone_path, type) >= 0:
				continue
			var track := clip.add_track(type)
			clip.track_set_path(track, bone_path)
			clip.track_insert_key(track, 0.0, values[TYPES.find(type)])
	return clip

func join(clips: Array) -> Animation:
	var result := Animation.new()
	var offset := 0.0
	for clip: Animation in clips:
		for t in clip.get_track_count():
			var path := clip.track_get_path(t)
			var type := clip.track_get_type(t)
			var target := result.find_track(path, type)
			if target < 0:
				target = result.add_track(type)
				result.track_set_path(target, path)
			for k in clip.track_get_key_count(t):
				result.track_insert_key(target, offset + clip.track_get_key_time(t,k), clip.track_get_key_value(t,k))
			# Hold constant channels until this segment ends, before the next one starts.
			var last: Variant
			match type:
				Animation.TYPE_POSITION_3D: last = clip.position_track_interpolate(t,clip.length)
				Animation.TYPE_ROTATION_3D: last = clip.rotation_track_interpolate(t,clip.length)
				Animation.TYPE_SCALE_3D: last = clip.scale_track_interpolate(t,clip.length)
			result.track_insert_key(target, offset + clip.length, last)
		offset += clip.length
	result.length = offset
	return result

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var provenance: Dictionary = preload("res://resources/battle/model_animations/gliscor_flight.json").data
	assert(FileAccess.get_sha256(args[0]) == provenance.source_glb_sha256)
	assert(FileAccess.get_sha256(args[1]) == provenance.models.gliscor)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(args[0], state) == OK)
	var source := document.generate_scene(state)
	var target := (load(args[1]) as PackedScene).instantiate()
	var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	var skeleton: Skeleton3D = target.find_children("*", "Skeleton3D", true, false)[0]
	assert(source_skeleton.get_bone_count() == skeleton.get_bone_count())
	for bone in skeleton.get_bone_count():
		assert(source_skeleton.get_bone_name(bone) == skeleton.get_bone_name(bone))
		assert(source_skeleton.get_bone_rest(bone).is_equal_approx(skeleton.get_bone_rest(bone)))
	var player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var old_player: AnimationPlayer = target.find_children("*", "AnimationPlayer", true, false)[0]
	var path := player.get_node(player.root_node).get_path_to(source_skeleton)
	assert(path == old_player.get_node(old_player.root_node).get_path_to(skeleton))
	var library := AnimationLibrary.new()
	for action in ["idle", "physical_attack", "damage", "faint_start", "faint_loop"]:
		var clip := complete_clip(player.get_animation(action), skeleton, path)
		clip.loop_mode = Animation.LOOP_LINEAR if action in ["idle", "faint_loop"] else Animation.LOOP_NONE
		assert(library.add_animation(action,clip) == OK)
	var special := join([complete_clip(player.get_animation("special_start"),skeleton,path), complete_clip(player.get_animation("special_loop"),skeleton,path), complete_clip(player.get_animation("special_end"),skeleton,path)])
	assert(library.add_animation("special_attack",special) == OK)
	# Keep the previously approved sleeping expression and skeletal pose.
	assert(library.add_animation("sleep",complete_clip(old_player.get_animation("sleep"),skeleton,path)) == OK)
	assert(ResourceSaver.save(library,args[2],ResourceSaver.FLAG_COMPRESS) == OK)
	print("GLISCOR_FLIGHT_LIBRARY_BUILT ", FileAccess.get_sha256(args[2]))
	source.free()
	target.free()
	quit()
