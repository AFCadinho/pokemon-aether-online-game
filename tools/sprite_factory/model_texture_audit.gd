extends RefCounted
## Offline only: inspect CPU images under the headless dummy renderer.
## No GPU readback/hashing is introduced into battle loading.
var visited := {}
var textures: Array[Dictionary] = []
var pool := {}
var rewritten := {}
var replacements := 0
var texture_branches := {}

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	assert(context.start(HashingContext.HASH_SHA256) == OK)
	assert(context.update(bytes) == OK)
	return context.finish().hex_encode()

static func image_signature(image: Image) -> String:
	assert(image != null and not image.is_empty())
	return str([image.get_width(), image.get_height(), image.get_format(), image.get_mipmap_count()]) + ":" + digest(image.get_data())

static func storage_properties(resource: Resource) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in resource.get_property_list():
		# Paths and editor subresource labels change on save. Preserve everything
		# else, including names, metadata, material parameters and animations.
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name not in ["resource_path", "resource_scene_unique_id"]:
			names.append(property.name)
	names.sort()
	return names

static func signature(value: Variant, memo: Dictionary = {}, stack: Dictionary = {}) -> String:
	if value is NodePath:
		# Use stable semantic components rather than binary NodePath encoding.
		return digest(("NodePath:" + str(value.is_absolute()) + ":" + str(value)).to_utf8_buffer())
	if value is Resource:
		var id: int = value.get_instance_id()
		if memo.has(id):
			return memo[id]
		assert(not stack.has(id), "Cyclic resource graph requires a different audit")
		stack[id] = true
		var parts := PackedStringArray([value.get_class()])
		if value is Image:
			parts.append(image_signature(value))
		elif value is PackedScene:
			# PackedScene rebuilds its interned variant table on assignment/save.
			# Check node values, not transient indices into that table.
			var state: SceneState = value.get_state()
			assert(state.get_base_scene_state() == null)
			var nodes: Array = []
			for index in state.get_node_count():
				var properties := {}
				for property_index in state.get_node_property_count(index):
					properties[state.get_node_property_name(index, property_index)] = state.get_node_property_value(index, property_index)
				nodes.append([state.get_node_path(index), state.get_node_path(index, true),
					state.get_node_owner_path(index), state.get_node_name(index), state.get_node_type(index),
					state.get_node_index(index), state.get_node_groups(index), state.get_node_instance(index),
					state.get_node_instance_placeholder(index), state.is_node_instance_placeholder(index), properties])
			var connections: Array = []
			for index in state.get_connection_count():
				connections.append([state.get_connection_source(index), state.get_connection_target(index),
					state.get_connection_signal(index), state.get_connection_method(index), state.get_connection_flags(index),
					state.get_connection_binds(index), state.get_connection_unbinds(index)])
			parts.append(signature([nodes, connections, value.get("_bundled").get("editable_instances", [])], memo, stack))
			for name in storage_properties(value):
				if name != "_bundled":
					parts.append(name + ":" + signature(value.get(name), memo, stack))
		elif value is ImageTexture:
			parts.append(image_signature(value.get_image()))
			for name in storage_properties(value):
				if name != "image":
					parts.append(name + ":" + signature(value.get(name), memo, stack))
		else:
			for name in storage_properties(value):
				parts.append(name + ":" + signature(value.get(name), memo, stack))
		stack.erase(id)
		memo[id] = digest("\n".join(parts).to_utf8_buffer())
		return memo[id]
	if value is Array:
		var parts := PackedStringArray(["Array", str(value.get_typed_builtin()), str(value.get_typed_class_name())])
		for item in value:
			parts.append(signature(item, memo, stack))
		return digest("\n".join(parts).to_utf8_buffer())
	if value is Dictionary:
		var parts := PackedStringArray(["Dictionary"])
		for key in value:
			parts.append(signature(key, memo, stack) + ":" + signature(value[key], memo, stack))
		parts.sort()
		return digest("\n".join(parts).to_utf8_buffer())
	return digest(var_to_bytes(value))

func inspect(value: Variant, owner: String = "") -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if visited.has(id):
			return # Count distinct objects, not repeated material references.
		visited[id] = true
		if value is Texture2D:
			var image: Image = value.get_image()
			assert(image != null and not image.is_empty())
			textures.append({"class": value.get_class(), "name": value.resource_name,
				"owner": owner, "image_signature": image_signature(image),
				"texture_signature": signature(value), "bytes": image.get_data_size(),
				"width": image.get_width(), "height": image.get_height(),
				"format": image.get_format(), "mipmaps": image.get_mipmap_count(),
				"shareable": value is ImageTexture and not value.resource_local_to_scene})
			return
		for name in storage_properties(value):
			inspect(value.get(name), owner + "/" + value.get_class() + "." + name)
	elif value is Array:
		for item in value:
			inspect(item, owner)
	elif value is Dictionary:
		for key in value:
			inspect(value[key], owner + "/" + str(key))

func summary() -> Dictionary:
	var images := {}
	var strict := {}
	var total := 0
	var image_duplicate := 0
	var strict_duplicate := 0
	for row in textures:
		total += int(row.bytes)
		if images.has(row.image_signature):
			image_duplicate += int(row.bytes)
		images[row.image_signature] = true
		if row.shareable:
			if strict.has(row.texture_signature):
				strict_duplicate += int(row.bytes)
			strict[row.texture_signature] = true
	return {"texture_objects": textures.size(), "image_bytes": total,
		"identical_image_duplicate_bytes": image_duplicate,
		"strict_shareable_duplicate_bytes": strict_duplicate}

func contains_texture(value: Variant) -> bool:
	if value is Texture2D:
		return true
	if value is Resource:
		var id: int = value.get_instance_id()
		if texture_branches.has(id):
			return texture_branches[id]
		texture_branches[id] = false
		for name in storage_properties(value):
			if contains_texture(value.get(name)):
				texture_branches[id] = true
		return texture_branches[id]
	if value is Array:
		for item in value:
			if contains_texture(item):
				return true
	elif value is Dictionary:
		for item in value.values():
			if contains_texture(item):
				return true
	return false

func share(value: Variant) -> Variant:
	if not contains_texture(value):
		return value # Do not reassign geometry/animation storage properties.
	if value is Resource:
		var id: int = value.get_instance_id()
		if rewritten.has(id):
			return rewritten[id]
		if value is Texture2D:
			if value is ImageTexture and not value.resource_local_to_scene:
				var key := signature(value)
				if pool.has(key):
					replacements += 1
					rewritten[id] = pool[key]
					return pool[key]
				pool[key] = value
			rewritten[id] = value
			return value
		rewritten[id] = value
		for name in storage_properties(value):
			var original: Variant = value.get(name)
			if original is Resource or original is Array or original is Dictionary:
				var replacement: Variant = share(original)
				# Set only changed references. Reassigning e.g. ArrayMesh._surfaces
				# can rebuild geometry even if that geometry was not touched.
				if replacement != original:
					value.set(name, replacement)
		return value
	if value is Array:
		var result: Array = value.duplicate()
		for index in result.size():
			result[index] = share(result[index])
		return result
	if value is Dictionary:
		var result: Dictionary = value.duplicate()
		for key in result:
			result[key] = share(result[key])
		return result
	return value
