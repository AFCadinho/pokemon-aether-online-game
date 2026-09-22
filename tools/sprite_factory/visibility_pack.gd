extends RefCounted
## Offline bake into native AnimationPlayer tracks. No runtime sidecar clock.
var failure := ""

func reject(message: String) -> bool:
	failure = message
	return false

func apply(actor: Node, manifest: Dictionary, glb_hash: String) -> bool:
	failure = ""
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or glb_hash.length() != 64 or not glb_hash.is_valid_hex_number(false) or not manifest.get("clips") is Dictionary:
		return reject("Invalid visibility manifest or GLB hash")
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		return reject("Visibility requires one unambiguous animation player")
	var player: AnimationPlayer = players[0]
	if not player.has_animation_library(""):
		return reject("Unsupported visibility animation library")
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return reject("Missing visibility animation root")
	var meshes := {}
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		if meshes.has(str(mesh.name)):
			return reject("Duplicate visibility mesh name")
		meshes[str(mesh.name)] = mesh
	var actions: Array = []
	for action in player.get_animation_list():
		if action != "RESET": actions.append(str(action))
	if actions.size() != manifest.clips.size() or not manifest.clips.has("idle"):
		return reject("Visibility clip coverage mismatch")
	# Validate every binding and key before modifying any animation.
	var plans := []
	for action: String in actions:
		var clip: Variant = manifest.clips.get(action)
		var animation := player.get_animation(action)
		if not clip is Dictionary or not clip.get("tracks") is Array or not clip.get("loop") is bool:
			return reject("Invalid visibility clip")
		var duration: Variant = clip.get("duration")
		if not (duration is int or duration is float) or not is_finite(float(duration)) or duration <= 0 or absf(float(duration)-animation.length) > 0.00001 or clip.loop != (animation.loop_mode == Animation.LOOP_LINEAR):
			return reject("Visibility clip clock mismatch")
		if not clip.get("source_sha256") is String or clip.source_sha256.length() != 64 or not clip.source_sha256.is_valid_hex_number(false):
			return reject("Invalid visibility source hash")
		var seen := {}
		for track: Variant in clip.tracks:
			if not track is Dictionary or not track.get("mesh") is String or not meshes.has(track.mesh) or seen.has(track.mesh) or track.get("source_target") != track.mesh + "_shape" or not track.get("keys") is Array or track.keys.is_empty():
				return reject("Invalid or unresolved visibility target")
			seen[track.mesh] = true
			var path := NodePath(str(animation_root.get_path_to(meshes[track.mesh])) + ":visible")
			for index in animation.get_track_count():
				if animation.track_get_path(index) == path:
					return reject("Existing visibility track would be overwritten")
			var previous := -1.0
			for key: Variant in track.keys:
				if not key is Array or key.size() != 2 or not (key[0] is int or key[0] is float) or not is_finite(float(key[0])) or not key[1] is bool or key[0] < 0 or key[0] > duration or key[0] <= previous or (previous < 0 and key[0] != 0):
					return reject("Invalid visibility key sequence")
				previous = float(key[0])
			plans.append([animation, path, track.keys, meshes[track.mesh], action])
		if seen.size() != meshes.size():
			return reject("Incomplete visibility mesh coverage")
	var reset: Animation = player.get_animation("RESET") if player.has_animation("RESET") else Animation.new()
	for plan in plans:
		if plan[4] != "idle": continue
		for index in reset.get_track_count():
			if reset.track_get_path(index) == plan[1]:
				return reject("Existing RESET visibility would be overwritten")
	if not player.has_animation("RESET"):
		player.get_animation_library("").add_animation("RESET", reset)
	for plan in plans:
		add_track(plan[0], plan[1], plan[2])
		if plan[4] == "idle":
			add_track(reset, plan[1], [plan[2][0]])
			plan[3].visible = plan[2][0][1]
	actor.set_meta("pokeaether_visibility", 1)
	return true

func add_track(animation: Animation, path: NodePath, keys: Array) -> void:
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, path)
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	for key in keys:
		animation.track_insert_key(index, float(key[0]), key[1])
