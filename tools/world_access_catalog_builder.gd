extends RefCounted

class_name WorldAccessCatalogBuilder

const SCHEMA_VERSION := 2
const TILE_SIZE := 32.0
const AREA_TYPES: Array[String] = [
	"exterior",
	"interior",
	"route",
	"wilderness",
	"transition",
]


func build(scene_root := "res://scenes/overworld") -> Dictionary:
	var scene_paths: Array[String] = []
	_collect_scene_paths(scene_root, scene_paths)
	scene_paths.sort()

	var areas: Dictionary = {}
	var records_by_scene_path: Dictionary = {}
	var errors: Array[String] = []
	for scene_path in scene_paths:
		if scene_path.contains("/reusable_interiors/"):
			continue
		var record := _load_scene_record(scene_path)
		if not bool(record.get("success", false)):
			var error := str(record.get("error", "")).strip_edges()
			if not error.is_empty():
				errors.append(error)
			continue
		var map_id := str(record.get("mapId", "")).strip_edges()
		if areas.has(map_id):
			errors.append("Duplicate map id %s in %s." % [map_id, scene_path])
			continue
		areas[map_id] = record.get("area", {})
		records_by_scene_path[scene_path] = record

	var transitions: Dictionary = {}
	for source_scene_path: String in records_by_scene_path:
		var source_record: Dictionary = records_by_scene_path[source_scene_path]
		for exit_value: Variant in source_record.get("exits", []):
			if not exit_value is Dictionary:
				continue
			var exit_record := exit_value as Dictionary
			var target_scene_path := _canonical_scene_path(
				str(exit_record.get("targetScenePath", ""))
			)
			if target_scene_path.is_empty():
				continue
			var target_record_value: Variant = records_by_scene_path.get(target_scene_path, {})
			if not target_record_value is Dictionary or (target_record_value as Dictionary).is_empty():
				errors.append(
					"%s targets unregistered map scene %s."
					% [str(exit_record.get("nodePath", source_scene_path)), target_scene_path]
				)
				continue
			var target_record := target_record_value as Dictionary
			var spawn_marker := str(exit_record.get("targetSpawnName", "")).strip_edges()
			var spawn_value: Variant = (target_record.get("spawns", {}) as Dictionary).get(
				spawn_marker,
				null
			)
			if not spawn_value is Vector2:
				errors.append(
					"%s targets missing spawn %s in %s."
					% [str(exit_record.get("nodePath", source_scene_path)), spawn_marker, target_scene_path]
				)
				continue

			var transition_id := str(exit_record.get("transitionId", "")).strip_edges()
			if transition_id.is_empty():
				transition_id = "%s__%s" % [
					str(source_record.get("mapId", "")),
					str(exit_record.get("nodeName", "")).to_snake_case(),
				]
			if transitions.has(transition_id):
				errors.append("Duplicate transition id %s." % transition_id)
				continue

			var target_area: Dictionary = target_record.get("area", {})
			var spawn_position := spawn_value as Vector2
			transitions[transition_id] = {
				"sourceMapId": str(source_record.get("mapId", "")),
				"destinationAreaId": str(target_record.get("mapId", "")),
				"destination": {
					"mapId": str(target_record.get("mapId", "")),
					"mapScenePath": target_scene_path,
					"mapSceneAliases": target_area.get("sceneAliases", []),
					"position": {
						"x": spawn_position.x,
						"y": spawn_position.y,
					},
					"facingDirection": str(
						exit_record.get("transitionFacingDirection", "down")
					),
					"spawnMarker": spawn_marker,
				},
			}

	if not errors.is_empty():
		return {
			"success": false,
			"errors": errors,
			"catalog": {},
		}
	return {
		"success": true,
		"errors": [],
		"catalog": {
			"schemaVersion": SCHEMA_VERSION,
			"areas": _sorted_dictionary(areas),
			"transitions": _sorted_dictionary(transitions),
		},
	}


func _load_scene_record(scene_path: String) -> Dictionary:
	var packed_value: Variant = load(scene_path)
	if not packed_value is PackedScene:
		return {"success": false, "error": "Could not load map scene %s." % scene_path}
	var root := (packed_value as PackedScene).instantiate()
	if root == null:
		return {"success": false, "error": "Could not instantiate map scene %s." % scene_path}

	var map_id := str(_property_value(root, "map_id", "")).strip_edges()
	if map_id.is_empty() and root.has_method("get_map_id"):
		map_id = str(root.call("get_map_id")).strip_edges()
	if map_id.is_empty():
		root.free()
		return {"success": false, "error": ""}

	var display_name := str(_property_value(root, "map_display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = _humanize_id(map_id)
	var region_name := str(_property_value(root, "map_region_name", "Kanto")).strip_edges()
	if region_name.is_empty():
		region_name = "Kanto"
	var location_group_id := str(
		_property_value(root, "world_access_group_id", "")
	).strip_edges()
	var location_group_label := str(
		_property_value(root, "world_access_group_label", "")
	).strip_edges()
	var area_type := str(
		_property_value(root, "world_access_area_type", "")
	).strip_edges()
	if location_group_id.is_empty() or location_group_label.is_empty():
		root.free()
		return {
			"success": false,
			"error": "%s has incomplete world access group metadata." % scene_path,
		}
	if area_type not in AREA_TYPES:
		root.free()
		return {
			"success": false,
			"error": "%s has invalid world access area type %s." % [scene_path, area_type],
		}

	var scene_aliases: Array[String] = []
	var resource_uid := ResourceLoader.get_resource_uid(scene_path)
	if resource_uid != ResourceUID.INVALID_ID:
		scene_aliases.append(ResourceUID.id_to_text(resource_uid))

	var spawns: Dictionary = {}
	var spawns_root := root.get_node_or_null("Spawns")
	if spawns_root != null:
		for child: Node in spawns_root.get_children():
			if child is Node2D:
				spawns[child.name] = (child as Node2D).position

	var exits: Array[Dictionary] = []
	var exits_root := root.get_node_or_null("Exits")
	if exits_root != null:
		for child: Node in exits_root.get_children():
			if not _has_property(child, "target_scene_path"):
				continue
			var target_scene_path := str(
				_property_value(child, "target_scene_path", "")
			).strip_edges()
			var target_spawn_name := str(
				_property_value(child, "target_spawn_name", "")
			).strip_edges()
			if target_scene_path.is_empty() and target_spawn_name.is_empty():
				continue
			if target_scene_path.is_empty() or target_spawn_name.is_empty():
				root.free()
				return {
					"success": false,
					"error": "%s has an incomplete map exit." % str(child.get_path()),
				}
			exits.append({
				"nodeName": str(child.name),
				"nodePath": "%s:Exits/%s" % [scene_path, str(child.name)],
				"targetScenePath": target_scene_path,
				"targetSpawnName": target_spawn_name,
				"transitionId": str(_property_value(child, "transition_id", "")),
				"transitionFacingDirection": str(
					_property_value(child, "transition_facing_direction", "down")
				),
			})

	var area := {
		"label": display_name,
		"regionName": region_name,
		"scenePath": scene_path,
		"sceneAliases": scene_aliases,
		"locationGroupId": location_group_id,
		"locationGroupLabel": location_group_label,
		"areaType": area_type,
		"defaultMode": "open",
	}
	var result := {
		"success": true,
		"mapId": map_id,
		"area": area,
		"spawns": spawns,
		"exits": exits,
	}
	root.free()
	return result


func _canonical_scene_path(scene_reference: String) -> String:
	var normalized := scene_reference.strip_edges()
	if normalized.is_empty():
		return ""
	var resource_value: Variant = load(normalized)
	if not resource_value is PackedScene:
		return normalized
	return str((resource_value as PackedScene).resource_path).strip_edges()


func _collect_scene_paths(directory_path: String, result: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name not in [".", ".."]:
			var entry_path := directory_path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_scene_paths(entry_path, result)
			elif entry_name.ends_with(".tscn"):
				result.append(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _property_value(object: Object, property_name: String, fallback: Variant) -> Variant:
	if not _has_property(object, property_name):
		return fallback
	return object.get(property_name)


func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys := source.keys()
	keys.sort()
	for key: Variant in keys:
		result[key] = source[key]
	return result


func _humanize_id(value: String) -> String:
	var words := value.replace("_", " ").split(" ", false)
	for index in range(words.size()):
		words[index] = words[index].capitalize()
	return " ".join(words)
