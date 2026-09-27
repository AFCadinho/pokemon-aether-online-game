extends RefCounted
## Embedded eye textures and AnimationPlayer UV properties; no runtime sidecars.
var failure := ""

func reject(message: String) -> bool:
	failure = message
	return false

func _uv(value: Array) -> Array:
	# glTF has already converted Blender UVs to the native top-origin convention.
	return [Vector3(value[0], value[1], 1.0), Vector3(value[2], value[3], 0.0)]

func _track(animation: Animation, path: NodePath, keys: Array, part: int) -> bool:
	for index in animation.get_track_count():
		if animation.track_get_path(index) == path:
			return reject("Eye animation would overwrite an existing track")
	var index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, path)
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		animation.track_insert_key(index, float(key[0]), _uv(key[1])[part])
	return true

func apply(actor: Node, manifest: Dictionary, glb_hash: String) -> bool:
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or manifest.get("review_required") != true or not manifest.get("materials") is Array or manifest.materials.is_empty():
		return reject("Invalid eye-motion manifest")
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	if players.size() != 1:
		return reject("Eye motion needs one AnimationPlayer")
	var player: AnimationPlayer = players[0]
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null:
		return reject("Missing eye animation root")
	var seen := {}
	for spec: Dictionary in manifest.materials:
		if seen.has(spec.material) or not spec.get("defaults") is Dictionary or not spec.get("clips") is Dictionary or not spec.get("lids") is Array:
			return reject("Invalid or duplicate eye material")
		seen[spec.material] = false
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface)
				if original.resource_name != spec.material:
					continue
				if not original is StandardMaterial3D or original.next_pass != null:
					return reject("Unsupported base eye material")
				seen[spec.material] = true
				var base := original.duplicate() as StandardMaterial3D
				base.resource_local_to_scene = true
				base.texture_repeat = spec.get("repeat_uv", false)
				mesh.set_surface_override_material(surface, base)
				var prefix := str(animation_root.get_path_to(mesh)) + ":surface_material_override/" + str(surface)
				var targets := {"UVScaleOffset": [base, prefix]}
				var previous: StandardMaterial3D = base
				for lid: Dictionary in spec.lids:
					if targets.has(lid.parameter) or lid.parameter not in ["UVScaleOffset3", "UVScaleOffset4"] or not str(lid.path).is_absolute_path() or FileAccess.get_sha256(lid.path) != lid.sha256:
						return reject("Invalid eye lid texture binding")
					var image := Image.load_from_file(lid.path)
					if image == null or image.is_empty():
						return reject("Missing eye lid image")
					image.generate_mipmaps()
					var material := StandardMaterial3D.new()
					material.resource_local_to_scene = true
					material.albedo_texture = ImageTexture.create_from_image(image)
					material.albedo_color = Color(lid.colour[0],lid.colour[1],lid.colour[2],lid.colour[3])
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
					material.texture_repeat = false
					material.cull_mode = base.cull_mode
					material.roughness = 1.0
					material.render_priority = spec.lids.find(lid) + 1
					previous.next_pass = material
					previous = material
					prefix += ":next_pass"
					targets[lid.parameter] = [material, prefix]
				if targets.size() != spec.defaults.size():
					return reject("Eye parameter coverage differs")
				for action in player.get_animation_list():
					if action == "RESET": continue
					if not spec.clips.has(str(action)):
						return reject("Incomplete eye clip coverage")
					var animation := player.get_animation(action)
					var clip: Dictionary = spec.clips[str(action)]
					if absf(float(clip.duration)-animation.length)>0.00001 or clip.loop != (animation.loop_mode == Animation.LOOP_LINEAR) or clip.parameters.size() != targets.size():
						return reject("Eye clip clock or parameter mismatch")
					for parameter: String in targets:
						if not clip.parameters.has(parameter): return reject("Missing eye parameter")
						var keys: Array = clip.parameters[parameter]
						var last := -1.0
						if keys.is_empty(): return reject("Empty eye keys")
						for key: Array in keys:
							if key.size()!=2 or key[0]<0 or key[0]>animation.length+0.00001 or key[0]<=last or (last<0 and key[0]!=0) or not key[1] is Array or key[1].size()!=4:
								return reject("Invalid eye key sequence")
							for value in key[1]:
								if not is_finite(float(value)): return reject("Non-finite eye UV")
							if key[1][0]<=0 or key[1][1]<=0: return reject("Invalid eye UV scale")
							last = float(key[0])
						for part in 2:
							var property_name := ":uv1_scale" if part==0 else ":uv1_offset"
							if not _track(animation, NodePath(targets[parameter][1]+property_name), keys, part): return false
							if action == "idle":
								targets[parameter][0].set("uv1_scale" if part==0 else "uv1_offset", _uv(keys[0][1])[part])
								if not player.has_animation("RESET"):
									player.get_animation_library("").add_animation("RESET",Animation.new())
								if not _track(player.get_animation("RESET"),NodePath(targets[parameter][1]+property_name),[keys[0]],part): return false
	for material in seen:
		if not seen[material]: return reject("Unbound eye material")
	actor.set_meta("pokeaether_eye_motion", 1)
	return true
