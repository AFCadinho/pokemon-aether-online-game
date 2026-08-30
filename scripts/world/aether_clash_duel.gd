extends "res://scripts/world/map_metadata.gd"


const INSTANCE_MAP_PREFIX := "aether_clash_duel:"


func configure_aether_clash_instance(instance_map_id: String) -> void:
	var normalized_id := instance_map_id.strip_edges()
	if not normalized_id.begins_with(INSTANCE_MAP_PREFIX):
		return
	map_id = normalized_id
	location_id = normalized_id

