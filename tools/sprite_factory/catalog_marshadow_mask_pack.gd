extends SceneTree
## Offline review conversion: embed source-sampled textures in ordinary native
## AnimationPlayer tracks. No custom runtime shader or sidecar texture loading.
var failure := ""

func _init() -> void:
	_run.call_deferred()

func _reject(message: String) -> bool:
	failure = message
	return false

func _native_signature(actor: Node, added: Array) -> PackedByteArray:
	var data := []
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var surfaces := []
		for surface in mesh.mesh.get_surface_count():
			surfaces.append(mesh.mesh.surface_get_arrays(surface))
		data.append([str(mesh.name), surfaces])
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	for name in player.get_animation_list():
		var animation := player.get_animation(name)
		var tracks := []
		for track in animation.get_track_count():
			if animation.track_get_path(track) in added:
				continue
			var keys := []
			for key in animation.track_get_key_count(track):
				keys.append([animation.track_get_key_time(track, key), animation.track_get_key_value(track, key), animation.track_get_key_transition(track, key)])
			tracks.append([animation.track_get_type(track), animation.track_get_path(track), animation.track_get_interpolation_type(track), keys])
		data.append([str(name), animation.length, animation.loop_mode, tracks])
	return JSON.stringify(data, "", false, true).sha256_buffer()

func _apply(actor: Node, bindings: Array, added: Array) -> bool:
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		return _reject("Expected one animation player")
	var player: AnimationPlayer = players[0]
	if not player.has_animation("RESET"):
		return _reject("Expected existing RESET")
	var animation_root := player.get_node(player.root_node)
	var used := {}
	for spec: Dictionary in bindings:
		var matches := []
		for node: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if str(node.name) == spec.mesh:
				matches.append(node)
		if matches.size() != 1 or used.has(spec.mesh) or spec.material != "body_a":
			return _reject("Ambiguous mesh or material")
		used[spec.mesh] = true
		var mesh: MeshInstance3D = matches[0]
		var surfaces := []
		for surface in mesh.mesh.get_surface_count():
			if mesh.get_active_material(surface).resource_name == spec.material:
				surfaces.append(surface)
		if surfaces.size() != 1:
			return _reject("Expected a single body_a surface")
		var textures := []
		for frame: Dictionary in spec.frames:
			if not str(frame.path).is_absolute_path() or FileAccess.get_sha256(frame.path) != frame.sha256:
				return _reject("Texture provenance mismatch")
			var image := Image.load_from_file(frame.path)
			if image == null or image.is_empty():
				return _reject("Missing texture")
			image.generate_mipmaps()
			var texture := ImageTexture.create_from_image(image)
			texture.set_meta("source_sha256", frame.sha256)
			textures.append(texture)
		var surface: int = surfaces[0]
		var original := mesh.get_active_material(surface)
		if not original is StandardMaterial3D or original.next_pass != null:
			return _reject("Expected ordinary source PBR material")
		var material := original.duplicate() as StandardMaterial3D
		material.resource_local_to_scene = true
		mesh.set_surface_override_material(surface, material)
		var path := NodePath(str(animation_root.get_path_to(mesh)) + ":surface_material_override/" + str(surface) + ":albedo_texture")
		if path in added:
			return _reject("Duplicate material binding")
		added.append(path)
		if spec.clips.size() != player.get_animation_list().size()-1:
			return _reject("Incomplete clip coverage")
		for action in player.get_animation_list():
			var clip: Dictionary = spec.clips.get("idle" if action == "RESET" else str(action), {})
			var animation := player.get_animation(action)
			if clip.is_empty() or (action != "RESET" and (absf(animation.length-float(clip.duration)) > 0.00001 or (animation.loop_mode == Animation.LOOP_LINEAR) != clip.loop)):
				return _reject("Material clip clock mismatch")
			for old in animation.get_track_count():
				if animation.track_get_path(old) == path:
					return _reject("Existing material track would be replaced")
			var keys: Array = [clip.keys[0]] if action == "RESET" else clip.keys
			if keys.is_empty() or keys[0][0] != 0:
				return _reject("Material clip must start at zero")
			var index := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(index, path)
			animation.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
			animation.track_set_interpolation_type(index, Animation.INTERPOLATION_NEAREST)
			var previous := -1.0
			for key: Array in keys:
				var time := float(key[0])
				var texture_index := int(key[1])
				if not is_finite(time) or time <= previous or time > animation.length+0.00001 or key[1] != texture_index or texture_index < 0 or texture_index >= textures.size():
					return _reject("Invalid material frame key")
				animation.track_insert_key(index, time, textures[texture_index])
				previous = time
			if action == "idle":
				material.albedo_texture = textures[int(keys[0][1])]
	return true

func _verify_motion(actor: Node, bindings: Array, added: Array) -> bool:
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	var animation_root := player.get_node(player.root_node)
	for index in bindings.size():
		var spec: Dictionary = bindings[index]
		var path: NodePath = added[index]
		var mesh: MeshInstance3D = animation_root.get_node(NodePath(path.get_concatenated_names()))
		var material := mesh.get_surface_override_material(0) as StandardMaterial3D
		if material == null or not material.resource_local_to_scene:
			return _reject("Missing local embedded material")
		for action in player.get_animation_list():
			var clip: Dictionary = spec.clips["idle" if action == "RESET" else str(action)]
			var keys: Array = [clip.keys[0]] if action == "RESET" else clip.keys
			var animation := player.get_animation(action)
			var track := animation.find_track(path, Animation.TYPE_VALUE)
			if track < 0 or animation.track_get_key_count(track) != keys.size():
				return _reject("Embedded material keys missing")
			for key_index in keys.size():
				var key: Array = keys[key_index]
				var expected: String = spec.frames[int(key[1])].sha256
				var texture: Texture2D = animation.track_get_key_value(track, key_index)
				if texture == null or texture.get_meta("source_sha256", "") != expected or absf(animation.track_get_key_time(track, key_index)-float(key[0])) > 0.00001:
					return _reject("Embedded texture or clock changed")
			# Check actual AnimationPlayer material application, including reset
			# after attacks. Loop endpoints wrap, so probe only within the clip.
			for fraction in [0.0, 0.5, 0.99]:
				var time: float = animation.length * fraction
				var expected_index := int(keys[0][1])
				for key: Array in keys:
					if float(key[0]) <= time:
						expected_index = int(key[1])
				player.play(action)
				player.seek(time, true)
				if material.albedo_texture.get_meta("source_sha256", "") != spec.frames[expected_index].sha256:
					return _reject("AnimationPlayer did not apply source texture")
		player.play("idle")
		player.seek(0, true)
		if material.albedo_texture.get_meta("source_sha256", "") != spec.frames[int(spec.clips.idle.keys[0][1])].sha256:
			return _reject("Idle did not restore resting mask")
	player.stop()
	return true

func _run() -> void:
	var manifest_path := OS.get_environment("POKEAETHER_MASK_MANIFEST")
	var output := OS.get_environment("POKEAETHER_MASK_OUTPUT")
	if not manifest_path.is_absolute_path() or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		printerr("Expected manifest and new absolute output directory")
		quit(2)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if manifest.get("schema") != 1 or manifest.get("review_required") != true or manifest.variants.size() != 2:
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var report := []
	for row: Dictionary in manifest.variants:
		if FileAccess.get_sha256(row.runtime_path) != row.runtime_sha256:
			printerr("Source scene hash mismatch")
			quit(1)
			return
		var actor: Node3D = (ResourceLoader.load(row.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		var added := []
		var before := _native_signature(actor, added)
		if not _apply(actor, row.bindings, added) or _native_signature(actor, added) != before:
			printerr("Material conversion failed: ", failure)
			quit(1)
			return
		var packed := PackedScene.new()
		var path := output.path_join("marshadow-" + row.variant + ".scn")
		if packed.pack(actor) != OK or ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) != OK:
			quit(1)
			return
		actor.free()
		var reloaded: Node3D = (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		if _native_signature(reloaded, added) != before:
			printerr("Native geometry or motion changed on reload")
			quit(1)
			return
		root.add_child(reloaded)
		if not _verify_motion(reloaded, row.bindings, added):
			printerr("Material playback verification failed: ", failure)
			quit(1)
			return
		reloaded.free()
		var result := row.duplicate(true)
		result.erase("bindings")
		result["source_runtime_sha256"] = row.runtime_sha256
		result["runtime_path"] = path
		result["runtime_sha256"] = FileAccess.get_sha256(path)
		result["runtime_approved"] = false
		result["mask_motion_manifest"] = manifest_path
		result["mask_motion_manifest_sha256"] = FileAccess.get_sha256(manifest_path)
		result["native_geometry_motion_preserved"] = true
		result["embedded_texture_keys_and_playback_verified"] = true
		report.append(result)
		print("MASK_MOTION_PACKED ", row.variant, " native geometry/motion unchanged")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit()
