extends RefCounted
## Reorder opaque cutout instances without changing geometry or attributes.
static func ordered(original: MultiMesh, local_camera: Vector3) -> MultiMesh:
	# Copy attributes through the resource API; a renderer buffer may not yet
	# exist during preparation (and is unavailable with the dummy renderer).
	var copy := MultiMesh.new()
	copy.transform_format = original.transform_format
	copy.use_colors = original.use_colors
	copy.use_custom_data = original.use_custom_data
	copy.mesh = original.mesh
	copy.instance_count = original.instance_count
	copy.visible_instance_count = original.visible_instance_count
	copy.custom_aabb = original.custom_aabb
	var count := original.instance_count if original.visible_instance_count < 0 else mini(original.instance_count, original.visible_instance_count)
	var rows: Array = []
	for index in count:
		var transform := original.get_instance_transform(index)
		rows.append([index, transform, transform.origin.distance_squared_to(local_camera)])
	rows.sort_custom(func(a, b): return a[2] < b[2] if a[2] != b[2] else a[0] < b[0])
	for index in original.instance_count:
		var source_index: int = rows[index][0] if index < count else index
		copy.set_instance_transform(index, original.get_instance_transform(source_index))
		if original.use_colors: copy.set_instance_color(index, original.get_instance_color(source_index))
		if original.use_custom_data: copy.set_instance_custom_data(index, original.get_instance_custom_data(source_index))
	return copy
