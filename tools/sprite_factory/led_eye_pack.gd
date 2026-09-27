extends RefCounted
const SHADER = preload("res://scripts/battle/battle_ui/material_led_eye.gdshader")
var failure := ""
func reject(reason: String) -> bool:
	failure = reason
	return false
func _texture(spec: Dictionary) -> Texture2D:
	if not str(spec.get("path", "")).is_absolute_path() or FileAccess.get_sha256(str(spec.path)) != spec.get("sha256", ""):
		return null
	var image := Image.load_from_file(spec.path)
	if image == null or image.is_empty():return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
func apply(actor: Node, manifest: Dictionary, glb_hash: String) -> bool:
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or manifest.get("review_required") != true or not manifest.get("materials") is Array:
		return reject("Invalid LED manifest")
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:return reject("LED animation requires one player")
	var player: AnimationPlayer = players[0]
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:return reject("Missing LED animation root")
	var seen := {}
	for spec: Dictionary in manifest.materials:
		if seen.has(spec.material) or not spec.get("clips") is Dictionary or not spec.get("textures") is Dictionary or not spec.get("color") is Array or spec.color.size() != 4 or not spec.get("grid") is Array or spec.grid.size() != 2:
			return reject("Invalid LED material")
		seen[spec.material] = false
		for v in spec.color + spec.grid:
			if not (v is int or v is float) or not is_finite(float(v)) or v < 0:return reject("Nonfinite LED settings")
		if spec.grid[0] < 1 or spec.grid[1] < 1 or spec.grid[0] != floor(spec.grid[0]) or spec.grid[1] != floor(spec.grid[1]):return reject("Invalid LED grid")
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface)
				if original == null or original.resource_name != spec.material:continue
				var material := ShaderMaterial.new()
				material.shader = Shader.new()
				material.shader.code = SHADER.code
				material.resource_name = spec.material
				material.resource_local_to_scene = true
				material.set_shader_parameter("tint", Vector4(spec.color[0], spec.color[1], spec.color[2], spec.color[3]))
				material.set_shader_parameter("grid", Vector2(spec.grid[0], spec.grid[1]))
				for mapping in [["OpacityMap", "mask_tex"], ["OpacityMap1", "iris_tex"]]:
					if not spec.textures.get(mapping[0]) is Dictionary:return reject("Missing LED mask")
					var texture := _texture(spec.textures[mapping[0]])
					if texture == null:return reject("LED texture hash mismatch")
					material.set_shader_parameter(mapping[1], texture)
				mesh.set_surface_override_material(surface, material)
				seen[spec.material] = true
				var parameters := {"UVScaleOffset":"uv_transform", "UVScaleOffset1":"iris_transform", "FlipBookFrame":"frame", "EmissionIntensity":"intensity", "LayerMaskScale1":"iris_weight"}
				for action in player.get_animation_list():
					if action == "RESET":continue
					if not spec.clips.get(action) is Dictionary:return reject("Missing LED action")
					var clip: Dictionary = spec.clips[action]
					var animation := player.get_animation(action)
					if absf(float(clip.get("duration", -1)) - animation.length) > 0.0001 or clip.get("loop") != (animation.loop_mode != Animation.LOOP_NONE) or not clip.get("parameters") is Dictionary or clip.parameters.size() != parameters.size():return reject("LED clock/coverage mismatch")
					for source: String in parameters:
						var keys: Variant = clip.parameters.get(source)
						if not keys is Array or keys.is_empty():return reject("Missing LED keys")
						var path := NodePath(str(animation_root.get_path_to(mesh)) + ":surface_material_override/" + str(surface) + ":shader_parameter/" + parameters[source])
						for existing in animation.get_track_count():
							if animation.track_get_path(existing) == path:return reject("Duplicate LED animation target")
						var track := animation.add_track(Animation.TYPE_VALUE)
						animation.track_set_path(track, path)
						animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST if source == "FlipBookFrame" else Animation.INTERPOLATION_LINEAR)
						if source == "FlipBookFrame":animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
						var previous := -1.0
						for key: Variant in keys:
							if not key is Array or key.size() != 2 or not (key[0] is int or key[0] is float) or not is_finite(float(key[0])) or key[0] <= previous or key[0] > animation.length + 0.0001:return reject("Invalid LED key time")
							previous = key[0]
							var value: Variant = key[1]
							if source.begins_with("UV"):
								if not value is Array or value.size() != 4:return reject("Invalid LED UV")
								for v: Variant in value:
									if not (v is int or v is float) or not is_finite(float(v)):return reject("Nonfinite LED UV")
								if value[0] <= 0 or value[1] <= 0:return reject("Invalid LED scale")
								value = Vector4(value[0],value[1],value[2],value[3])
							elif not (value is int or value is float) or not is_finite(float(value)) or value < 0:return reject("Invalid LED scalar")
							elif source == "FlipBookFrame" and (value != floor(value) or value >= spec.grid[0] * spec.grid[1]):return reject("Invalid LED atlas frame")
							animation.track_insert_key(track, key[0], value)
						if keys[0][0] != 0:return reject("LED keys must start at zero")
						if action == "idle":
							var initial: Variant = animation.track_get_key_value(track, 0)
							material.set_shader_parameter(parameters[source], initial)
							if not player.has_animation("RESET"):
								player.get_animation_library("").add_animation("RESET", Animation.new())
							var reset := player.get_animation("RESET")
							var reset_track := reset.add_track(Animation.TYPE_VALUE)
							reset.track_set_path(reset_track, path)
							reset.track_insert_key(reset_track, 0.0, initial)
	for used in seen.values():
		if not used:return reject("LED material not found")
	actor.set_meta("pokeaether_led_eyes", 1)
	return true
