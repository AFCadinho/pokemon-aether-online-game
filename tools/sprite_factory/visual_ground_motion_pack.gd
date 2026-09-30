extends RefCounted
## Offline visual root offsets: keep native bone curves and gameplay root intact.
var failure := ""

func apply(actor: Node3D, manifest: Dictionary, glb_hash: String) -> Node3D:
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or manifest.get("review_required") != true or not manifest.get("clips") is Dictionary:
		failure = "Invalid visual grounding manifest"
		return null
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		failure = "Visual grounding needs one AnimationPlayer"
		return null
	var player: AnimationPlayer = players[0]
	var actions := []
	for action in player.get_animation_list():
		if action == "RESET": continue
		actions.append(str(action))
		var animation := player.get_animation(action)
		if not manifest.clips.has(str(action)):
			failure = "Missing visual grounding clip"
			return null
		var spec: Dictionary = manifest.clips[str(action)]
		if not spec.get("keys") is Array or spec["keys"].is_empty() or not is_equal_approx(float(spec.get("duration", -1)), animation.length) or spec.get("loop") != (animation.loop_mode == Animation.LOOP_LINEAR):
			failure = "Visual grounding clip clock mismatch"
			return null
		var last := -1.0
		for key in spec["keys"]:
			if not key is Array or key.size() != 2 or not is_finite(float(key[0])) or not is_finite(float(key[1])) or key[0] <= last or key[0] < 0 or key[0] > animation.length + 0.00001 or (last < 0 and key[0] != 0):
				failure = "Invalid visual grounding key"
				return null
			last = float(key[0])
	if actions.size() != manifest.clips.size():
		failure = "Unexpected visual grounding clip"
		return null
	var root := Node3D.new()
	root.name = "ModelRoot"
	var visual := Node3D.new()
	visual.name = "VisualGroundOffset"
	root.add_child(visual)
	visual.add_child(actor)
	visual.owner = root
	actor.owner = root
	for child in actor.find_children("*", "Node", true, false): child.owner = root
	for key in actor.get_meta_list(): root.set_meta(key, actor.get_meta(key))
	var origin := player.get_node(player.root_node)
	var path := origin.get_path_to(visual)
	for action in player.get_animation_list():
		var animation := player.get_animation(action)
		var index := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(index, path)
		animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
		var keys: Array = [[0.0, 0.0]] if action == "RESET" else manifest.clips[str(action)]["keys"]
		for key in keys: animation.track_insert_key(index, float(key[0]), Vector3(0, float(key[1]), 0))
	root.set_meta("pokeaether_visual_ground_motion", 1)
	return root
