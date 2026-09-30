extends RefCounted
## Preserve native curves, explicitly restore omitted transform channels per clip.
var failure := ""
var inserted := 0

func apply(actor: Node) -> bool:
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		failure = "Expected one native animation player"
		return false
	var player: AnimationPlayer = players[0]
	var origin := player.get_node(player.root_node)
	var defaults := {}
	for name in player.get_animation_list():
		if name == "RESET": continue
		var animation := player.get_animation(name)
		for track in animation.get_track_count():
			var kind := animation.track_get_type(track)
			if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]: continue
			var path := animation.track_get_path(track)
			var key := str(kind) + "|" + str(path)
			if defaults.has(key): continue
			var node := origin.get_node_or_null(NodePath(path.get_concatenated_names()))
			var value: Variant
			if node is Skeleton3D and path.get_subname_count() == 1:
				var bone: int = node.find_bone(str(path.get_subname(0)))
				if bone < 0:
					failure = "Unknown native bone channel: " + str(path)
					return false
				value = node.get_bone_pose_position(bone) if kind == Animation.TYPE_POSITION_3D else (node.get_bone_pose_rotation(bone) if kind == Animation.TYPE_ROTATION_3D else node.get_bone_pose_scale(bone))
			elif node is Node3D and path.get_subname_count() == 0:
				value = node.position if kind == Animation.TYPE_POSITION_3D else (node.quaternion if kind == Animation.TYPE_ROTATION_3D else node.scale)
			else:
				failure = "Unsupported native transform binding: " + str(path)
				return false
			defaults[key] = {"kind": kind, "path": path, "value": value}
	for name in player.get_animation_list():
		if name == "RESET": continue
		var animation := player.get_animation(name)
		var present := {}
		for track in animation.get_track_count():
			present[str(animation.track_get_type(track)) + "|" + str(animation.track_get_path(track))] = true
		for key in defaults:
			if present.has(key): continue
			var spec: Dictionary = defaults[key]
			var track := animation.add_track(spec.kind)
			animation.track_set_path(track, spec.path)
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			animation.track_insert_key(track, 0, spec.value)
			animation.track_insert_key(track, animation.length, spec.value)
			inserted += 1
	actor.set_meta("pokeaether_complete_pose_channels", inserted)
	return true
