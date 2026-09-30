extends SceneTree
## Offline conversion only: preserve meshes/materials/native animation tracks.
## Never perform GLTF import on the interactive battle thread.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var output := OS.get_environment("POKEAETHER_3D_RUNTIME_OUTPUT").simplify_path()
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		printerr("OUTPUT_ERROR: POKEAETHER_3D_RUNTIME_OUTPUT must name a NEW absolute directory")
		quit(2)
		return
	var diagnostics := []
	var validator := ProjectSettings.globalize_path("res://tools/sprite_factory/validate_battle_3d_report.py")
	if OS.execute("python3", PackedStringArray([validator, path]), diagnostics, true) != 0:
		printerr("PREFLIGHT_FAILED: ", "\n".join(diagnostics))
		quit(2)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array or data.is_empty():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		printerr("OUTPUT_ERROR: cannot create output directory")
		quit(2)
		return
	var result := []
	for entry: Dictionary in data:
		var prepared := _convert(entry, output)
		if not prepared.is_empty():
			result.append(prepared)
	if result.size() != data.size():
		errors.append("Runtime conversion did not produce every requested model")
	if not errors.is_empty():
		_write_json(output.path_join("conversion-errors.json"), errors)
		printerr("CONVERSION_FAILED: ", "\n".join(errors), "\nPartial scenes retained; no catalog published")
		quit(1)
		return
	var temporary := output.path_join("report.json.pending")
	var target := output.path_join("report.json")
	var code := _write_json(temporary, result)
	if code == OK:
		code = DirAccess.rename_absolute(temporary, target)
	if code != OK:
		printerr("PUBLISH_ERROR: ", error_string(code))
		quit(1)
		return
	print("PREPARED_REPORT ", target, " models=", result.size())
	quit()

var errors: Array[String] = []

func _signature(node: Node) -> Array:
	var result := [node.get_class(), str(node.name)]
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			result.append([node.mesh.surface_get_array_len(surface), node.mesh.surface_get_array_index_len(surface)])
	if node is AnimationPlayer:
		for action in node.get_animation_list():
			var animation: Animation = node.get_animation(action)
			var tracks := []
			for track in animation.get_track_count():
				tracks.append([animation.track_get_type(track), str(animation.track_get_path(track)), animation.track_get_key_count(track)])
			result.append([str(action), animation.length, animation.loop_mode, tracks])
	for child in node.get_children():
		result.append(_signature(child))
	return result

func _inspect(node: Node, species: String, players: Array) -> int:
	var surfaces := 0
	if node is AnimationPlayer:
		players.append(node)
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			surfaces += 1
			if node.mesh.surface_get_array_len(surface) <= 0:
				errors.append(species + ": empty mesh surface")
			if not node.get_active_material(surface) is StandardMaterial3D:
				errors.append(species + ": unsupported or missing material: " + str(node.name))
	for child in node.get_children():
		surfaces += _inspect(child, species, players)
	return surfaces

func _convert(entry: Dictionary, output: String) -> Dictionary:
	var species: String = entry.species
	var placement := preload("res://scripts/battle/battle_ui/model_placement.gd").resolve(entry, {}, "")
	if placement.is_empty():
		errors.append(species + ": invalid placement metadata")
		return {}
	var before := errors.size()
	var glb_hash := FileAccess.get_sha256(entry.path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var code := document.append_from_file(entry.path, state)
	if code != OK:
		errors.append(species + ": GLTF import failed: " + error_string(code))
		return {}
	var node := document.generate_scene(state, 60)
	if node == null:
		errors.append(species + ": no generated scene")
		return {}
	var players := []
	if _inspect(node, species, players) == 0:
		errors.append(species + ": no mesh surfaces")
	if players.size() != 1:
		errors.append(species + ": expected exactly one AnimationPlayer")
	else:
		var player: AnimationPlayer = players[0]
		for action: String in entry.action_timing:
			if not player.has_animation(action):
				errors.append(species + ": missing animation clip " + action)
				continue
			var animation := player.get_animation(action)
			if animation.get_track_count() == 0:
				errors.append(species + ": empty animation clip " + action)
			var spec: Dictionary = entry.action_timing[action]
			animation.length = float(spec.frames) / 60.0
			animation.loop_mode = Animation.LOOP_LINEAR if spec.loop else Animation.LOOP_NONE
	if FileAccess.get_sha256(entry.path) != glb_hash:
		errors.append(species + ": GLB changed during conversion")
	if errors.size() != before:
		node.free()
		return {}
	if entry.get("complete_pose_channels", false):
		var completion := preload("complete_pose_channels.gd").new()
		if not completion.apply(node):
			errors.append(species + ": pose channel completion failed: " + completion.failure)
			node.free()
			return {}
	if entry.has("visibility"):
		var visibility := preload("visibility_pack.gd").new()
		if not entry.visibility is Dictionary or not visibility.apply(node, entry.visibility, glb_hash):
			errors.append(species + ": visibility binding failed: " + visibility.failure)
			node.free()
			return {}
	if entry.has("transparent_diagnostic"):
		var transparency := preload("catalog_transparency_pack.gd").new()
		if not entry.transparent_diagnostic is Dictionary or not transparency.apply(node, entry.transparent_diagnostic, glb_hash):
			errors.append(species + ": transparency binding failed: " + transparency.failure)
			node.free()
			return {}
	if entry.has("material_effects"):
		var effect := preload("material_effect_pack.gd").new()
		if not entry.material_effects is Dictionary or not effect.apply(node, entry.material_effects, glb_hash):
			errors.append("Effect binding failed: " + effect.failure)
			node.free()
			return {}
	if entry.has("material_response"):
		var response := preload("material_response_pack.gd").new()
		if not entry.material_response is Dictionary or not response.apply(node, entry.material_response, glb_hash):
			errors.append(species + ": " + response.failure)
			node.free()
			return {}
	if entry.has("eye_motion"):
		var eye_motion := preload("eye_motion_pack.gd").new()
		if entry.has("material_response") or not eye_motion.apply(node, entry.eye_motion, glb_hash):
			errors.append(species + ": eye motion binding failed: " + eye_motion.failure)
			node.free()
			return {}
	if entry.has("led_eyes"):
		var led := preload("led_eye_pack.gd").new()
		if not entry.led_eyes is Dictionary or not led.apply(node, entry.led_eyes, glb_hash):
			errors.append(species + ": LED binding failed: " + led.failure)
			node.free()
			return {}
	if entry.has("visual_ground_motion"):
		var visual_ground := preload("visual_ground_motion_pack.gd").new()
		var wrapped := visual_ground.apply(node, entry.visual_ground_motion, glb_hash)
		if wrapped == null:
			errors.append(species + ": visual grounding failed: " + visual_ground.failure)
			node.free()
			return {}
		node = wrapped
	var packed := PackedScene.new()
	var signature := _signature(node)
	code = packed.pack(node)
	var target := output.path_join(species + ".scn")
	if code == OK:
		code = ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS)
	node.free()
	if code != OK:
		errors.append(species + ": scene save failed: " + error_string(code))
		return {}
	var check := ResourceLoader.load(target, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if check == null:
		errors.append(species + ": saved scene cannot be reloaded")
		return {}
	var verified := check.instantiate()
	if verified == null:
		errors.append(species + ": saved scene cannot be instantiated")
		return {}
	if _signature(verified) != signature:
		errors.append(species + ": scene structure, mesh counts or animation tracks changed on reload")
		verified.free()
		return {}
	if entry.has("material_response") and (verified.get_meta("pokeaether_material_response", 0) != 1 or not preload("res://scripts/battle/battle_ui/material_response.gd").supported_actor(verified)):
		errors.append(species + ": response lost on reload")
		verified.free()
		return {}
	if entry.has("transparent_diagnostic") and verified.get_meta("pokeaether_transparency_diagnostic", 0) != 1:
		errors.append(species + ": transparency binding lost on reload")
		verified.free()
		return {}
	if entry.has("eye_motion") and verified.get_meta("pokeaether_eye_motion", 0) != 1:
		errors.append(species + ": eye motion lost on reload")
		verified.free()
		return {}
	if entry.has("led_eyes") and verified.get_meta("pokeaether_led_eyes", 0) != 1:
		errors.append(species + ": LED eyes lost on reload")
		verified.free()
		return {}
	if entry.has("visual_ground_motion") and verified.get_meta("pokeaether_visual_ground_motion", 0) != 1:
		errors.append(species + ": visual grounding lost on reload")
		verified.free()
		return {}
	verified.free()
	var prepared := entry.duplicate(true)
	prepared.runtime_path = target
	prepared.runtime_schema = 1
	prepared.placement = {"scale": placement.scale, "yaw_degrees": placement.yaw_degrees}
	prepared.provenance_schema = 1
	prepared.glb_sha256 = glb_hash
	prepared.runtime_sha256 = FileAccess.get_sha256(target)
	prepared.converter_version = 2
	prepared.godot_version = Engine.get_version_info().string
	return prepared

func _write_json(path: String, value: Variant) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	file.flush()
	var code := file.get_error()
	file.close()
	return code
