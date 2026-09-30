extends SceneTree
## Offline exact scene geometry/skin/animation parity; materials are excluded.
func _init() -> void:
	var source := OS.get_environment("POKEAETHER_RUNTIME_PAIR_REPORT")
	var output := OS.get_environment("POKEAETHER_RUNTIME_PAIR_PARITY_OUTPUT")
	assert(source.is_absolute_path() and output.is_absolute_path() and not FileAccess.file_exists(output))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(source))
	var pairs := {}
	for row in rows:
		assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
		assert(not pairs.has(row.species))
		pairs[row.species] = row
	var proofs := []
	for identity in pairs:
		if "@" in identity:continue
		assert(pairs.has(identity + "@shiny"))
		var normal: Node = load(pairs[identity].runtime_path).instantiate()
		var shiny: Node = load(pairs[identity + "@shiny"].runtime_path).instantiate()
		var a := _structure(normal)
		var b := _structure(shiny)
		assert(a == b, "Scene geometry/animation differs: " + identity)
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(var_to_bytes(a))
		proofs.append({"species": identity, "normal_runtime_sha256": pairs[identity].runtime_sha256,
			"shiny_runtime_sha256": pairs[identity + "@shiny"].runtime_sha256,
			"geometry_animation_sha256": hashing.finish().hex_encode()})
		normal.free()
		shiny.free()
		print("RUNTIME_PAIR_PARITY_OK ", identity)
	assert(proofs.size() * 2 == rows.size())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,
		"report_sha256":FileAccess.get_sha256(source),"scope":"exact node transforms, mesh arrays, skins, bone rests and poses, animation tracks and keys; materials excluded",
		"pairs":proofs},"  "))
	quit()
func _structure(node: Node) -> Dictionary:
	var data := {"type": node.get_class(), "children": []}
	if node is Node3D:data.transform = node.transform
	if node is Skeleton3D:
		data.bones = []
		for i in node.get_bone_count():data.bones.append([node.get_bone_name(i),node.get_bone_parent(i),node.get_bone_rest(i),node.get_bone_pose(i)])
	if node is MeshInstance3D:
		data.visible = node.visible
		data.skeleton = node.skeleton
		data.surfaces = []
		for i in node.mesh.get_surface_count():data.surfaces.append([node.mesh.surface_get_primitive_type(i),node.mesh.surface_get_arrays(i)])
		data.skin = []
		if node.skin:
			for i in node.skin.get_bind_count():data.skin.append([node.skin.get_bind_name(i),node.skin.get_bind_bone(i),node.skin.get_bind_pose(i)])
	if node is AnimationPlayer:
		data.animations = {}
		for name in node.get_animation_list():
			var animation: Animation = node.get_animation(name)
			var tracks := []
			for i in animation.get_track_count():
				var keys := []
				for j in animation.track_get_key_count(i):keys.append([animation.track_get_key_time(i,j),animation.track_get_key_value(i,j),animation.track_get_key_transition(i,j)])
				tracks.append([animation.track_get_type(i),animation.track_get_path(i),animation.track_is_enabled(i),animation.track_get_interpolation_type(i),animation.track_get_interpolation_loop_wrap(i),keys])
			data.animations[name]=[animation.length,animation.loop_mode,tracks]
	for child in node.get_children():data.children.append([child.name,_structure(child)])
	return data
