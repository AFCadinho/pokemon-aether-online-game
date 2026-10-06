extends "res://scripts/services/player_hotbar_service.gd"

func save_hotbar(slots: Array) -> Dictionary:
	await get_tree().process_frame
	cached_slots = slots.duplicate(true)
	hotbar_changed.emit(cached_slots)
	return {"success": true, "slots": cached_slots}
