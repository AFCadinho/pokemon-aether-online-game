extends RefCounted
class_name MapEncounterProvider

const DEFAULT_ENCOUNTER_TYPE := "grass"
const FISHING_ENCOUNTER_TYPES := [&"old_rod", &"good_rod", &"super_rod"]
const ENCOUNTER_REGIONS_ROOT := "EncounterRegions"

const META_PLACEHOLDER_TYPE := "pao_placeholder_type"
const META_RESOURCE_ID := "pao_resource_id"
const META_PROPERTIES := "pao_properties"
const META_ENCOUNTER_AREA_ID := "pao_encounter_area_id"
const META_ENCOUNTER_TYPE := "pao_encounter_type"
const META_ENCOUNTER_CHANCE := "pao_encounter_chance"
const META_REGION_RECT := "pao_region_rect"


static func resolve_wild_encounter(current_map: Node, world_position: Vector2, encounter_type: String = DEFAULT_ENCOUNTER_TYPE) -> Dictionary:
	var requested_type := _normalize_encounter_type(encounter_type)
	if current_map == null:
		return _unavailable("missing_map", requested_type)

	var region := _find_encounter_region(current_map, world_position, requested_type)
	if region != null:
		return _resolve_region_encounter(current_map, region, requested_type)

	return _resolve_map_encounter(current_map, requested_type)


static func _resolve_region_encounter(current_map: Node, region: Node, requested_type: String) -> Dictionary:
	var resolved_type := _get_region_encounter_type(region, requested_type)
	var area_id := _get_region_encounter_area_id(region)
	if area_id == "":
		area_id = _get_map_encounter_area_id(current_map)
	if area_id == "":
		return _unavailable("missing_area_id", resolved_type)

	var chance := _get_region_encounter_chance(region)
	var use_map_trigger := false
	if chance < 0.0:
		if _is_fishing_encounter_type(resolved_type):
			chance = 1.0
		else:
			use_map_trigger = current_map.has_method("should_trigger_wild_encounter")
			if not use_map_trigger:
				chance = _get_map_encounter_chance(current_map, resolved_type)

	return {
		"available": true,
		"area_id": area_id,
		"encounter_type": resolved_type,
		"chance": chance,
		"use_map_trigger": use_map_trigger,
		"source": "region",
		"region_id": _get_meta_text(region, META_RESOURCE_ID),
	}


static func _resolve_map_encounter(current_map: Node, requested_type: String) -> Dictionary:
	var area_id := _get_map_encounter_area_id(current_map)
	if area_id == "":
		return _unavailable("missing_area_id", requested_type)

	var is_fishing_encounter := _is_fishing_encounter_type(requested_type)
	var use_map_trigger := not is_fishing_encounter and current_map.has_method("should_trigger_wild_encounter")
	return {
		"available": true,
		"area_id": area_id,
		"encounter_type": requested_type,
		"chance": 1.0 if is_fishing_encounter else _get_map_encounter_chance(current_map, requested_type),
		"use_map_trigger": use_map_trigger,
		"source": "map",
		"region_id": "",
	}


static func _is_fishing_encounter_type(encounter_type: String) -> bool:
	return StringName(_normalize_encounter_type(encounter_type)) in FISHING_ENCOUNTER_TYPES


static func _find_encounter_region(current_map: Node, world_position: Vector2, requested_type: String) -> Node:
	var regions_root := current_map.get_node_or_null(ENCOUNTER_REGIONS_ROOT)
	if regions_root == null:
		return null

	return _find_encounter_region_recursive(regions_root, world_position, requested_type)


static func _find_encounter_region_recursive(node: Node, world_position: Vector2, requested_type: String) -> Node:
	for child: Node in node.get_children():
		if _is_matching_encounter_region(child, world_position, requested_type):
			return child

		var nested_region := _find_encounter_region_recursive(child, world_position, requested_type)
		if nested_region != null:
			return nested_region

	return null


static func _is_matching_encounter_region(region: Node, world_position: Vector2, requested_type: String) -> bool:
	if not _is_encounter_region_node(region):
		return false

	var region_type := _get_region_encounter_type(region, requested_type)
	if region_type != requested_type:
		return false

	return _is_world_position_inside_region(region, world_position)


static func _is_encounter_region_node(node: Node) -> bool:
	if node.has_meta(META_PLACEHOLDER_TYPE) and str(node.get_meta(META_PLACEHOLDER_TYPE)) == "encounter_region":
		return true
	if node.has_meta(META_ENCOUNTER_AREA_ID) or node.has_meta(META_ENCOUNTER_TYPE) or node.has_meta(META_ENCOUNTER_CHANCE):
		return true

	var properties := _get_meta_dictionary(node, META_PROPERTIES)
	return properties.has("encounter_region_id") or properties.has("encounter_area_id") or properties.has("encounter_type")


static func _is_world_position_inside_region(region: Node, world_position: Vector2) -> bool:
	var area := region as Area2D
	if area != null and _is_world_position_inside_area(area, world_position):
		return true

	if region.has_meta(META_REGION_RECT):
		var rect: Rect2 = region.get_meta(META_REGION_RECT)
		var parent_node := region.get_parent() as Node2D
		var local_position := parent_node.to_local(world_position) if parent_node != null else world_position
		return rect.has_point(local_position)

	return false


static func _is_world_position_inside_area(area: Area2D, world_position: Vector2) -> bool:
	for child: Node in area.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue
		if _is_world_position_inside_shape(collision_shape, world_position):
			return true

	return false


static func _is_world_position_inside_shape(collision_shape: CollisionShape2D, world_position: Vector2) -> bool:
	var local_position := collision_shape.to_local(world_position)
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		var half_size := rectangle.size * 0.5
		return absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y

	var circle := collision_shape.shape as CircleShape2D
	if circle != null:
		return local_position.length() <= circle.radius

	return false


static func _get_region_encounter_area_id(region: Node) -> String:
	var area_id := _get_meta_text(region, META_ENCOUNTER_AREA_ID)
	if area_id != "":
		return area_id

	return _get_property_text(region, "encounter_area_id")


static func _get_region_encounter_type(region: Node, fallback: String) -> String:
	var encounter_type := _get_meta_text(region, META_ENCOUNTER_TYPE)
	if encounter_type == "":
		encounter_type = _get_property_text(region, "encounter_type")
	if encounter_type == "":
		encounter_type = fallback
	return _normalize_encounter_type(encounter_type)


static func _get_region_encounter_chance(region: Node) -> float:
	if region.has_meta(META_ENCOUNTER_CHANCE):
		return _variant_to_float(region.get_meta(META_ENCOUNTER_CHANCE), -1.0)

	var properties := _get_meta_dictionary(region, META_PROPERTIES)
	if properties.has("encounter_chance"):
		return _variant_to_float(properties.get("encounter_chance"), -1.0)

	return -1.0


static func _get_map_encounter_area_id(current_map: Node) -> String:
	if current_map.has_method("get_wild_encounter_area_id"):
		var method_area_id := str(current_map.call("get_wild_encounter_area_id")).strip_edges()
		if method_area_id != "":
			return method_area_id

	var property_value: Variant = current_map.get("encounter_area_id")
	if property_value != null:
		var property_area_id := str(property_value).strip_edges()
		if property_area_id != "":
			return property_area_id

	var map_data: Variant = current_map.get("map_data")
	if map_data is Resource:
		var data_area_value: Variant = (map_data as Resource).get("encounter_area_id")
		if data_area_value != null:
			var data_area_id := str(data_area_value).strip_edges()
			if data_area_id != "":
				return data_area_id

	return ""


static func _get_map_encounter_chance(current_map: Node, encounter_type: String) -> float:
	if current_map.has_method("get_wild_encounter_chance"):
		return clampf(_variant_to_float(current_map.call("get_wild_encounter_chance", encounter_type), 0.0), 0.0, 1.0)

	var property_name := "%s_encounter_chance" % _normalize_encounter_type(encounter_type)
	var chance_value: Variant = current_map.get(property_name)
	if chance_value != null:
		return clampf(_variant_to_float(chance_value, 0.0), 0.0, 1.0)

	return 0.0


static func _get_property_text(node: Node, property_name: String) -> String:
	var properties := _get_meta_dictionary(node, META_PROPERTIES)
	return str(properties.get(property_name, "")).strip_edges()


static func _get_meta_text(node: Node, meta_name: String) -> String:
	if not node.has_meta(meta_name):
		return ""

	return str(node.get_meta(meta_name)).strip_edges()


static func _get_meta_dictionary(node: Node, meta_name: String) -> Dictionary:
	if not node.has_meta(meta_name):
		return {}

	var value: Variant = node.get_meta(meta_name)
	return value as Dictionary if value is Dictionary else {}


static func _variant_to_float(value: Variant, fallback: float) -> float:
	if value == null:
		return fallback
	if value is String and str(value).strip_edges() == "":
		return fallback

	return float(value)


static func _normalize_encounter_type(encounter_type: String) -> String:
	var normalized_type := encounter_type.strip_edges().to_lower()
	if normalized_type == "":
		return DEFAULT_ENCOUNTER_TYPE
	if normalized_type == "fishing" or normalized_type == "fish":
		return "old_rod"
	return normalized_type


static func _unavailable(reason: String, encounter_type: String) -> Dictionary:
	return {
		"available": false,
		"reason": reason,
		"area_id": "",
		"encounter_type": encounter_type,
		"chance": 0.0,
		"use_map_trigger": false,
		"source": "",
		"region_id": "",
	}
