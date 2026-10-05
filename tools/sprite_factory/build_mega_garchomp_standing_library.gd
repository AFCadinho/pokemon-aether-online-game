extends SceneTree
## Build only skeletal animation data from the pinned native bank-00 motion carrier.
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

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var provenance: Dictionary = preload("res://resources/battle/model_animations/mega_garchomp_standing.json").data
	assert(FileAccess.get_sha256(args[0]) == provenance.source_glb_sha256)
	assert(FileAccess.get_sha256(args[1]) == provenance.models["garchomp-mega"])
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
	for action: String in provenance.animations:
		var clip := complete_clip(player.get_animation(action), skeleton, path)
		clip.loop_mode = Animation.LOOP_LINEAR if provenance.animations[action].loop else Animation.LOOP_NONE
		assert(is_equal_approx(clip.length, provenance.animations[action].duration))
		# The reviewed scenes only had static visibility=true outside the skeleton.
		# Assert those defaults; ship no tracks that modify meshes or materials.
		var old := old_player.get_animation(action)
		for t in old.get_track_count():
			if old.track_get_type(t) in TYPES: continue
			assert(old.track_get_type(t) == Animation.TYPE_VALUE)
			assert(str(old.track_get_path(t)).ends_with(":visible"))
			assert(old.track_get_key_count(t) == 1 and old.track_get_key_value(t,0) == true)
			var mesh_path := NodePath(str(old.track_get_path(t)).trim_suffix(":visible"))
			assert(old_player.get_node(old_player.root_node).get_node(mesh_path).visible)
		assert(library.add_animation(action,clip) == OK)
	assert(ResourceSaver.save(library,args[2],ResourceSaver.FLAG_COMPRESS) == OK)
	print("MEGA_GARCHOMP_STANDING_LIBRARY_BUILT ", FileAccess.get_sha256(args[2]))
	source.free()
	target.free()
	quit()
