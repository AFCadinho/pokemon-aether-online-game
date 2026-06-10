extends Node2D

@export var encounter_area_id := "kanto_route_1"
@export_range(0.0, 1.0, 0.01) var grass_encounter_chance := 0.1

func _ready() -> void:
	await _load_encounter_area_metadata()

func get_wild_encounter_area_id() -> String:
	return encounter_area_id

func should_trigger_wild_encounter(encounter_type: String = "grass") -> bool:
	if encounter_type != "grass":
		return false

	return randf() <= grass_encounter_chance

func _load_encounter_area_metadata() -> void:
	var metadata := await _fetch_encounter_area_metadata()
	var encounter_types: Dictionary = metadata.get("encounterTypes", {})
	var grass_metadata: Dictionary = encounter_types.get("grass", {})
	grass_encounter_chance = clampf(float(grass_metadata.get("encounterChance", grass_encounter_chance)), 0.0, 1.0)

func _fetch_encounter_area_metadata() -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var url := "%s/encounters/areas/%s" % [base_url, encounter_area_id.uri_encode()]
	var error := request.request(url, PackedStringArray(["Accept: application/json"]))
	if error != OK:
		request.queue_free()
		return {}

	var result: Array = await request.request_completed
	request.queue_free()

	var response_code := int(result[1])
	if response_code < 200 or response_code >= 300:
		return {}

	var body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}

	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("area") and parsed_dictionary["area"] is Dictionary:
		return parsed_dictionary["area"]

	return parsed_dictionary

func is_position_blocked_by_character(world_position: Vector2) -> bool:
	var npcs: Node = get_node_or_null("Entities/NPCs")
	if npcs == null:
		return false
		
	for npc: Node in npcs.get_children():
		if npc.has_method("blocks_world_position"):
			if npc.blocks_world_position(world_position):
				return true
		
	return false 
