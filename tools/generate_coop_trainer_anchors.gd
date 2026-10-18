extends SceneTree

var failed := false

# Export scene-owned entry anchors. Runtime admission never accepts client positions.
func _initialize() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var entries: Dictionary = {}
	for map_id: String in world.areas:
		var path: String = world.areas[map_id].get("scenePath", "")
		if path.is_empty():
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			quit(1)
			return
		var scene := packed.instantiate()
		_collect(scene, map_id, path, entries)
		scene.free()
	if failed:
		quit(1)
		return
	var output := "res://generated/coop_trainer_anchors.json"
	var generated_text := JSON.stringify({"schemaVersion": 1, "entries": entries}, "\t", true) + "\n"
	if _check_only():
		if FileAccess.get_file_as_string(output) != generated_text:
			push_error("Co-op trainer anchors are stale. Regenerate after changing world NPCs.")
			quit(1)
			return
		print("Co-op trainer anchors are current.")
		quit(0)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(generated_text)
	file.close()
	print("Exported %d NPC anchors." % entries.size())
	quit(0)

func _collect(node: Node, map_id: String, path: String, entries: Dictionary) -> void:
	for property: Dictionary in node.get_property_list():
		if property.name == "interaction_id" and not str(node.get("interaction_id")).is_empty():
			var parent := node.get_parent()
			while parent != null and not parent is Node2D:
				parent = parent.get_parent()
			if parent is Node2D:
				var point: Vector2 = parent.global_position
				entries["interaction:" + str(node.get("interaction_id"))] = {"mapId": map_id,
					"scenePath": path, "trainerId": "", "position": {"x": point.x, "y": point.y}, "radius": _trigger_radius(parent)}
	if node is Node2D:
		var properties: Dictionary = {}
		for property: Dictionary in node.get_property_list():
			properties[property.name] = true
		var npc_id := str(node.get("npc_id")) if properties.has("npc_id") else ""
		var trainer_id := str(node.get("trainer_id")) if properties.has("trainer_id") else ""
		if not npc_id.is_empty() or not trainer_id.is_empty():
			var key := npc_id if not npc_id.is_empty() else trainer_id
			var point: Vector2 = node.global_position
			var sight := float(node.get("sight_range_tiles")) if properties.has("sight_range_tiles") else 0.0
			var radius := maxf(80.0, sight * 32.0 + 16.0)
			if properties.has("challenge_width_tiles"):
				var half_width := ceilf((float(node.get("challenge_width_tiles")) - 1.0) / 2.0)
				radius = maxf(radius, Vector2(half_width, sight).length() * 32.0 + 16.0)
			var entry := {"mapId": map_id, "scenePath": path, "trainerId": trainer_id,
				"position": {"x": point.x, "y": point.y}, "radius": radius}
			if entries.has(key):
				push_error("Duplicate NPC anchor: " + key)
				failed = true
			entries[key] = entry
	for child: Node in node.get_children():
		_collect(child, map_id, path, entries)

func _trigger_radius(parent: Node2D) -> float:
	var radius := 80.0
	if parent is Area2D:
		for child: Node in parent.get_children():
			if child is CollisionShape2D and not child.disabled:
				var shape: Shape2D = child.shape
				if shape is RectangleShape2D:
					radius = maxf(radius, shape.size.length() / 2.0 + 16.0)
				elif shape is CircleShape2D:
					radius = maxf(radius, shape.radius + 16.0)
	return radius

func _check_only() -> bool:
	return "--check" in OS.get_cmdline_user_args()
