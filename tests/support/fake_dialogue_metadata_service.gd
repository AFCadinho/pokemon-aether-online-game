extends "res://scripts/services/dialogue_metadata_service.gd"

signal release_fetch

var fetch_count := 0


func _fetch_dialogue_metadata(dialogue_id: String, _locale: String) -> Dictionary:
	fetch_count += 1
	await release_fetch
	return {
		"success": true,
		"metadata": {
			"dialogue_id": dialogue_id,
			"speaker_name": "Test NPC",
			"dialogue_lines": ["Hello."],
		},
	}
