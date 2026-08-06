extends RefCounted

class_name WorldAccessCatalogBuilder

const SCHEMA_VERSION := 3
const TILE_SIZE := 32.0
const STAFF_TELEPORT_OVERRIDES_PATH := "res://tools/staff_teleport_overrides.json"
const VIRTUAL_AREA_OVERRIDES_PATH := "res://tools/world_access_virtual_areas.json"
const AREA_TYPES: Array[String] = [
	"exterior",
	"interior",
	"route",
	"wilderness",
	"transition",
]
const FACING_DIRECTIONS: Array[String] = ["up", "down", "left", "right"]


func build(
	scene_root := "res://scenes/overworld",
	staff_teleport_overrides_path := STAFF_TELEPORT_OVERRIDES_PATH
) -> Dictionary:
	var overrides_result := _load_staff_teleport_overrides(staff_teleport_overrides_path)
	if not bool(overrides_result.get("success", false)):
		return {
			"success": false,
			"errors": [str(overrides_result.get("error", ""))],
			"catalog": {},
		}
	var staff_teleport_overrides: Dictionary = overrides_result.get("overrides", {})
	var virtual_result := _load_virtual_areas(VIRTUAL_AREA_OVERRIDES_PATH)
	if not bool(virtual_result.get("success", false)):
		return {"success": false, "errors": [str(virtual_result.get("error", ""))], "catalog": {}}
	var scene_paths: Array[String] = []
	_collect_scene_paths(scene_root, scene_paths)
	scene_paths.sort()

	var areas: Dictionary = {}
	var records_by_scene_path: Dictionary = {}
	var errors: Array[String] = []
	for scene_path in scene_paths:
		if scene_path.contains("/reusable_interiors/"):
			continue
		var record := _load_scene_record(scene_path, staff_teleport_overrides)
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
	for virtual_area_value: Variant in virtual_result.get("areas", []):
		if not virtual_area_value is Dictionary:
			continue
		var virtual_area := virtual_area_value as Dictionary
		var virtual_id := str(virtual_area.get("areaId", "")).strip_edges()
		if virtual_id.is_empty() or areas.has(virtual_id):
			errors.append("Duplicate or empty virtual area id %s." % virtual_id)
			continue
		areas[virtual_id] = virtual_area.get("definition", {})

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
			var destination := {
				"mapId": str(target_record.get("mapId", "")),
				"mapScenePath": target_scene_path,
				"mapSceneAliases": target_area.get("sceneAliases", []),
				"position": {
					"x": spawn_position.x,
					"y": spawn_position.y,
				},
				"spawnMarker": spawn_marker,
			}
			var facing_override := str(
				exit_record.get("transitionFacingDirection", "")
			).strip_edges()
			if not facing_override.is_empty():
				destination["facingDirection"] = facing_override
			transitions[transition_id] = {
				"sourceMapId": str(source_record.get("mapId", "")),
				"destinationAreaId": str(target_record.get("mapId", "")),
				"destination": destination,
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


func _load_scene_record(scene_path: String, staff_teleport_overrides: Dictionary) -> Dictionary:
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
	var maps_value: Variant = staff_teleport_overrides.get("maps", {})
	var map_overrides: Dictionary = maps_value if maps_value is Dictionary else {}
	var map_override_value: Variant = map_overrides.get(map_id, {})
	var map_override: Dictionary = map_override_value if map_override_value is Dictionary else {}
	display_name = str(map_override.get("label", display_name)).strip_edges()
	region_name = str(map_override.get("regionName", region_name)).strip_edges()
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
	var spawn_points: Dictionary = {}
	var point_overrides_value: Variant = map_override.get("points", {})
	var point_overrides: Dictionary = (
		point_overrides_value if point_overrides_value is Dictionary else {}
	)
	var spawns_root := root.get_node_or_null("Spawns")
	if spawns_root != null:
		for child: Node in spawns_root.get_children():
			if child is Node2D:
				var spawn_name := str(child.name)
				var spawn_position := (child as Node2D).position
				spawns[spawn_name] = spawn_position
				var default_point_id := spawn_name.to_snake_case()
				var point_override_value: Variant = point_overrides.get(default_point_id, {})
				var point_override: Dictionary = (
					point_override_value if point_override_value is Dictionary else {}
				)
				var point_id := str(point_override.get("id", default_point_id)).strip_edges()
				if point_id.is_empty():
					root.free()
					return {
						"success": false,
						"error": "%s has an empty staff teleport point id." % scene_path,
					}
				if spawn_points.has(point_id):
					root.free()
					return {
						"success": false,
						"error": "%s has duplicate staff teleport point id %s."
							% [scene_path, point_id],
					}
				var facing_direction := str(
					point_override.get("facingDirection", "down")
				).strip_edges().to_lower()
				if facing_direction not in FACING_DIRECTIONS:
					root.free()
					return {
						"success": false,
						"error": "%s point %s has invalid facing direction."
							% [scene_path, point_id],
					}
				spawn_points[point_id] = {
					"label": str(point_override.get("label", _spawn_point_label(point_id))),
					"spawnMarker": spawn_name,
					"tile": {
						"x": roundi((spawn_position.x - (TILE_SIZE / 2.0)) / TILE_SIZE),
						"y": roundi((spawn_position.y - (TILE_SIZE / 2.0)) / TILE_SIZE),
					},
					"facingDirection": facing_direction,
					"safeForStaffTeleport": true,
				}

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
			var transition_facing_direction := str(
				_property_value(child, "transition_facing_direction", "")
			).strip_edges().to_lower()
			if target_scene_path.is_empty() and target_spawn_name.is_empty():
				continue
			if target_scene_path.is_empty() or target_spawn_name.is_empty():
				root.free()
				return {
					"success": false,
					"error": "%s has an incomplete map exit." % str(child.get_path()),
				}
			if (
				not transition_facing_direction.is_empty()
				and transition_facing_direction not in FACING_DIRECTIONS
			):
				root.free()
				return {
					"success": false,
					"error": "%s has an invalid transition facing direction." % str(child.get_path()),
				}
			exits.append({
				"nodeName": str(child.name),
				"nodePath": "%s:Exits/%s" % [scene_path, str(child.name)],
				"targetScenePath": target_scene_path,
				"targetSpawnName": target_spawn_name,
				"transitionId": str(_property_value(child, "transition_id", "")),
				"transitionFacingDirection": transition_facing_direction,
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
		"spawnPoints": _sorted_dictionary(spawn_points),
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


func _load_staff_teleport_overrides(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {
			"success": false,
			"error": "Could not read staff teleport overrides from %s." % path,
		}
	var parsed_value: Variant = JSON.parse_string(source)
	if not parsed_value is Dictionary:
		return {
			"success": false,
			"error": "Staff teleport overrides are invalid JSON: %s." % path,
		}
	return {"success": true, "overrides": parsed_value as Dictionary}


func _load_virtual_areas(path: String) -> Dictionary:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		return {"success": false, "error": "Could not read virtual area overrides from %s." % path}
	var parsed_value: Variant = JSON.parse_string(source)
	if not parsed_value is Dictionary:
		return {"success": false, "error": "Virtual area overrides are invalid JSON: %s." % path}
	var areas_value: Variant = (parsed_value as Dictionary).get("areas", [])
	if not areas_value is Array:
		return {"success": false, "error": "Virtual area overrides must contain an areas array."}
	var result: Array[Dictionary] = []
	for value: Variant in areas_value:
		if not value is Dictionary:
			return {"success": false, "error": "Virtual area override is not an object."}
		var entry := value as Dictionary
		var area_id := str(entry.get("areaId", "")).strip_edges()
		var definition_value: Variant = entry.get("definition", {})
		if area_id.is_empty() or not definition_value is Dictionary:
			return {"success": false, "error": "Virtual area override has an invalid id or definition."}
		var definition := (definition_value as Dictionary).duplicate(true)
		definition["accessOnly"] = true
		definition["scenePath"] = ""
		definition["sceneAliases"] = []
		definition["spawnPoints"] = {}
		result.append({"areaId": area_id, "definition": definition})
	return {"success": true, "areas": result}


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


func _spawn_point_label(point_id: String) -> String:
	var semantic_id := point_id.strip_edges().to_lower()
	for prefix: String in ["from_", "to_"]:
		if semantic_id.begins_with(prefix):
			semantic_id = semantic_id.trim_prefix(prefix)
			break
	var label := _humanize_id(semantic_id)
	var replacements := {
		"Pokecenter": "Pokémon Center",
		"Players House": "Player's House",
		"Rivals House": "Rival's House",
		"Npc": "NPC",
	}
	for source: String in replacements:
		label = label.replace(source, str(replacements[source]))
	return label
