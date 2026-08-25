extends "res://scripts/services/npc_metadata_service.gd"

signal release_fetch

var fetch_count := 0


func _fetch_npc_metadata(npc_id: String, _locale: String) -> Dictionary:
	fetch_count += 1
	await release_fetch
	return {
		"success": true,
		"metadata": {
			"id": npc_id,
			"name": "Test NPC",
			"dialogue_id": "test_dialogue",
		},
	}
