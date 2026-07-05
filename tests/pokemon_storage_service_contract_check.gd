extends SceneTree

const StorageService := preload("res://scripts/services/pokemon_storage_service.gd")

var failed := false


func _init() -> void:
	_check_boxes_response_parsing()
	_check_storage_location_parsing()
	_check_move_payload_shape()
	_check_empty_party_target_uses_next_contiguous_slot()

	quit(1 if failed else 0)


func _check_boxes_response_parsing() -> void:
	var result := StorageService.parse_boxes_response({
		"success": true,
		"body": {
			"boxCount": 32,
			"slotsPerBox": 30,
			"boxes": [
				{
					"boxIndex": 0,
					"slots": [
						{
							"boxIndex": 0,
							"slotIndex": 2,
							"pokemon": {
								"id": 42,
								"pokemon": {"species": "Eevee", "level": 5},
							},
						},
					],
				},
			],
		},
	})

	_check_equal(result.get("success", false), true, "boxes parse success")
	_check_equal(result.get("boxCount", 0), 32, "box count")
	_check_equal(result.get("slotsPerBox", 0), 30, "slots per box")
	var boxes: Array = result.get("boxes", [])
	_check_equal(boxes.size(), 1, "box array size")
	var first_box: Dictionary = boxes[0]
	var slots: Array = first_box.get("slots", [])
	_check_equal(slots.size(), 1, "box slot array size")
	_check_equal(int((slots[0] as Dictionary).get("slotIndex", -1)), 2, "box slot index")


func _check_storage_location_parsing() -> void:
	var party_location := StorageService.normalize_storage_location({"type": "party", "partySlot": 3})
	_check_equal(party_location.get("type", ""), "party", "party location type")
	_check_equal(party_location.get("partySlot", -1), 3, "party location slot")

	var box_location := StorageService.normalize_storage_location({"type": "box", "boxIndex": 1, "slotIndex": 4})
	_check_equal(box_location.get("type", ""), "box", "box location type")
	_check_equal(box_location.get("boxIndex", -1), 1, "box location box")
	_check_equal(box_location.get("slotIndex", -1), 4, "box location slot")
	_check_equal(StorageService.storage_location_label(box_location), "Box 2 slot 5", "box location label")


func _check_move_payload_shape() -> void:
	var payload := StorageService.build_move_payload(
		42,
		StorageService.party_location(0),
		StorageService.box_location(2, 9)
	)
	_check_equal(payload.get("pokemonId", 0), 42, "move pokemon id")
	_check_equal((payload.get("source", {}) as Dictionary).get("type", ""), "party", "move source type")
	_check_equal((payload.get("source", {}) as Dictionary).get("partySlot", -1), 0, "move source slot")
	_check_equal((payload.get("target", {}) as Dictionary).get("type", ""), "box", "move target type")
	_check_equal((payload.get("target", {}) as Dictionary).get("boxIndex", -1), 2, "move target box")
	_check_equal((payload.get("target", {}) as Dictionary).get("slotIndex", -1), 9, "move target slot")


func _check_empty_party_target_uses_next_contiguous_slot() -> void:
	var target := StorageService.next_empty_party_location(2)
	var payload := StorageService.build_move_payload(
		42,
		StorageService.box_location(0, 0),
		target
	)
	_check_equal((payload.get("target", {}) as Dictionary).get("type", ""), "party", "empty party target type")
	_check_equal((payload.get("target", {}) as Dictionary).get("partySlot", -1), 2, "empty party target next slot")
	_check_equal(StorageService.next_empty_party_location(6).is_empty(), true, "full party has no empty target")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
