extends SceneTree
## Offline codec measurement. Never changes reviewed assets or client admission.
const Audit = preload("res://tools/sprite_factory/model_texture_audit.gd")
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const Geometry = preload("res://tools/sprite_factory/shared_geometry_collection.gd")
var seen_textures := {}
var inspected_textures := []

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("LOSSLESS_TEXTURE_ABORT ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := ErrorSink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	_run.call_deferred()

static func texture_state(texture: Texture2D) -> Dictionary:
	assert(texture is ImageTexture or texture is PortableCompressedTexture2D)
	var image := texture.get_image()
	assert(image != null and not image.is_empty())
	var metadata := {}
	for name: StringName in texture.get_meta_list():
		metadata[str(name)] = texture.get_meta(name)
	return {"image": Audit.image_signature(image), "size": texture.get_size(),
		"name": texture.resource_name, "local_to_scene": texture.resource_local_to_scene, "metadata": metadata}

static func mip_image(image: Image, level: int) -> Image:
	assert(level >= 0 and level <= image.get_mipmap_count() and not image.is_compressed())
	var start := image.get_mipmap_offset(level)
	var end := image.get_mipmap_offset(level + 1) if level < image.get_mipmap_count() else image.get_data_size()
	return Image.create_from_data(maxi(1, image.get_width() >> level), maxi(1, image.get_height() >> level),
		false, image.get_format(), image.get_data().slice(start, end))

static func normalized_signature(value: Variant, memo := {}, stack := {}) -> String:
	# The only normalized distinction is the storage class of a texture. Every
	# decoded mip, size, name, locality and metadata remains part of its key.
	if value is NodePath:
		return Audit.digest(("NodePath:" + str(value.is_absolute()) + ":" + str(value)).to_utf8_buffer())
	if value is Resource:
		var id: int = value.get_instance_id()
		if memo.has(id): return memo[id]
		assert(not stack.has(id), "Cyclic graph")
		stack[id] = true
		var parts := PackedStringArray([value.get_class()])
		if value is Texture2D:
			parts = PackedStringArray(["LosslessTexture2D", normalized_signature(texture_state(value), memo, stack)])
		elif value is Image:
			parts.append(Audit.image_signature(value))
		elif value is PackedScene:
			var state: SceneState = value.get_state()
			assert(state.get_base_scene_state() == null)
			var nodes := []
			for i in state.get_node_count():
				var properties := {}
				for p in state.get_node_property_count(i): properties[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
				nodes.append([state.get_node_path(i), state.get_node_path(i, true), state.get_node_owner_path(i), state.get_node_name(i),
					state.get_node_type(i), state.get_node_index(i), state.get_node_groups(i), state.get_node_instance(i), state.get_node_instance_placeholder(i), properties])
			var connections := []
			for i in state.get_connection_count():
				connections.append([state.get_connection_source(i), state.get_connection_target(i), state.get_connection_signal(i),
					state.get_connection_method(i), state.get_connection_flags(i), state.get_connection_binds(i), state.get_connection_unbinds(i)])
			parts.append(normalized_signature([nodes, connections, value.get("_bundled").get("editable_instances", [])], memo, stack))
			for name in Audit.storage_properties(value):
				if name != "_bundled": parts.append(name + ":" + normalized_signature(value.get(name), memo, stack))
		else:
			for name in Audit.storage_properties(value): parts.append(name + ":" + normalized_signature(value.get(name), memo, stack))
		stack.erase(id)
		memo[id] = Audit.digest("\n".join(parts).to_utf8_buffer())
		return memo[id]
	if value is Array:
		var parts := PackedStringArray(["Array", str(value.get_typed_builtin()), str(value.get_typed_class_name())])
		for item in value: parts.append(normalized_signature(item, memo, stack))
		return Audit.digest("\n".join(parts).to_utf8_buffer())
	if value is Dictionary:
		var parts := PackedStringArray(["Dictionary"])
		for key in value: parts.append(normalized_signature(key, memo, stack) + ":" + normalized_signature(value[key], memo, stack))
		parts.sort()
		return Audit.digest("\n".join(parts).to_utf8_buffer())
	return Audit.digest(var_to_bytes(value))

func motion(scene: PackedScene) -> Dictionary:
	var actor := scene.instantiate()
	root.add_child(actor)
	var players := actor.find_children("*", "AnimationPlayer", true, false)
	assert(players.size() == 1)
	var player: AnimationPlayer = players[0]
	var poses := {}
	for action in player.get_animation_list():
		for fraction in [0.0, 0.5, 0.999]:
			player.stop()
			for skeleton in actor.find_children("*", "Skeleton3D", true, false): skeleton.reset_bone_poses()
			player.play(action)
			player.pause()
			player.seek(player.get_animation(action).length * fraction, true)
			poses[str(action) + ":" + str(fraction)] = Geometry.pose_state(actor)
	Geometry.retire(actor)
	return poses

func encode_texture(texture: Texture2D, directory: String, relative: String) -> Dictionary:
	assert(texture is ImageTexture)
	var image := texture.get_image()
	var state := texture_state(texture)
	var row := {"path": relative, "image_signature": Audit.image_signature(image), "state_signature": normalized_signature(state),
		"width": image.get_width(), "height": image.get_height(), "format": image.get_format(), "mipmaps": image.get_mipmap_count(),
		"decoded_bytes": image.get_data_size(), "codecs": {}}
	# PNG/WebP are 8-bit codecs. Compressed or higher precision source images
	# remain untouched; no lossy conversion is made to force eligibility.
	if image.is_compressed() or image.get_format() > Image.FORMAT_RGBA8:
		row["hold"] = "source_format_outside_lossless_8bit_scope"
		return row
	if texture.get_size() != Vector2(image.get_width(), image.get_height()):
		row["hold"] = "non_native_texture_size_override"
		return row
	for codec in ["png", "webp"]:
		var header := PackedByteArray()
		header.resize(20)
		header.encode_u16(0, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		# Godot 4.6 PortableCompressedTexture2D::DataFormat: PNG=2, WebP=3.
		header.encode_u16(2, 2 if codec == "png" else 3)
		header.encode_u32(4, image.get_format())
		header.encode_u32(8, image.get_mipmap_count() + 1)
		header.encode_u32(12, image.get_width())
		header.encode_u32(16, image.get_height())
		var mips := []
		var exact := true
		var started := Time.get_ticks_usec()
		for level in image.get_mipmap_count() + 1:
			var original: Image = mip_image(image, level)
			var bytes: PackedByteArray = original.save_png_to_buffer() if codec == "png" else original.save_webp_to_buffer(false, 1.0)
			assert(not bytes.is_empty())
			var decoded := Image.new()
			assert((decoded.load_png_from_buffer(bytes) if codec == "png" else decoded.load_webp_from_buffer(bytes)) == OK)
			decoded.convert(original.get_format())
			var same := Audit.image_signature(decoded) == Audit.image_signature(original)
			exact = exact and same
			mips.append({"level": level, "width": original.get_width(), "height": original.get_height(), "encoded_bytes": bytes.size(),
				"source_sha256": Audit.digest(original.get_data()), "decoded_sha256": Audit.digest(decoded.get_data()), "exact": same})
			if codec == "png":
				# Native PNG resources require Godot's four-byte "PNG " wrapper;
				# load_png_from_buffer above intentionally checks the standard PNG.
				var wrapped := "PNG ".to_utf8_buffer()
				wrapped.append_array(bytes)
				bytes = wrapped
			var size := PackedByteArray()
			size.resize(4)
			size.encode_u32(0, bytes.size())
			header.append_array(size)
			header.append_array(bytes)
		var result := {"exact": exact, "mips": mips, "encode_usec": Time.get_ticks_usec() - started}
		if exact:
			var candidate := PortableCompressedTexture2D.new()
			candidate.keep_compressed_buffer = true
			candidate.call("_set_data", header)
			candidate.resource_name = texture.resource_name
			candidate.resource_local_to_scene = texture.resource_local_to_scene
			candidate.set_size_override(texture.get_size())
			for name in texture.get_meta_list(): candidate.set_meta(name, texture.get_meta(name))
			assert(texture_state(candidate) == state, "Portable texture decoded state changed")
			var path := directory.path_join(codec).path_join(relative)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			assert(ResourceSaver.save(candidate, path, ResourceSaver.FLAG_COMPRESS) == OK)
			assert(ResourceLoader.get_dependencies(path).is_empty())
			var persisted := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			assert(persisted != null and texture_state(persisted) == state, "Saved texture roundtrip changed pixels or mips")
			result["path"] = path
		row.codecs[codec] = result
	return row

func _run() -> void:
	assert(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility")
	ProjectSettings.set_setting("rendering/textures/webp_compression/compression_method", 6)
	ProjectSettings.set_setting("rendering/textures/webp_compression/lossless_compression_factor", 100.0)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3)
	var mode: String = args[0]
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var directory: String = args[2]
	assert(not FileAccess.file_exists(directory.path_join("report.json")))
	DirAccess.make_dir_recursive_absolute(directory)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	var asset: Dictionary = config.asset
	var checked := Pair.inspect(config.path, asset)
	assert(str(checked.error).is_empty(), str(checked.error))
	assert(Pair.mount_checked(config.path, asset, checked).is_empty())
	var rows := []
	for member: Dictionary in asset.pair_manifest.files:
		if not str(member.path).begins_with("textures/"): continue
		var texture := ResourceLoader.load(str(asset.pair_manifest.resource_root).path_join(member.path), "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		assert(texture != null)
		if mode == "encode":
			rows.append(encode_texture(texture, directory, member.path))
		else:
			rows.append({"path": member.path, "state_signature": normalized_signature(texture_state(texture))})
		await process_frame
	var models := []
	for appearance: Dictionary in asset.appearances:
		var path := str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path)
		assert(FileAccess.get_sha256(path) == appearance.runtime_sha256)
		var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null)
		models.append({"identity": appearance.runtime_identity, "signature": normalized_signature(scene), "motion": motion(scene)})
		await process_frame
		await process_frame
	var report := {"schema": 1, "complete": true, "prototype_only": true, "production_approved": false,
		"asset_id": asset.asset_id, "pack_sha256": asset.sha256, "input_sha256": FileAccess.get_sha256(args[1]),
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "textures": rows, "models": models}
	var file := FileAccess.open(directory.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report) + "\n")
	file.close()
	print("LOSSLESS_TEXTURE_ENGINE_OK ", mode, " ", asset.asset_id, " textures=", rows.size())
	quit()
