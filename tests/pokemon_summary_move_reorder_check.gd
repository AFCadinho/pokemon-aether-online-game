extends SceneTree

const MoveReorderSlotScript := preload("res://scripts/ui/pokemon_summary_move_reorder_slot.gd")
const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false
var received_reorder: Dictionary = {}
var received_hover: Dictionary = {}


func _init() -> void:
	var host := Control.new()
	root.add_child(host)

	var source: Control = MoveReorderSlotScript.new()
	source.call("configure", "interactive:owned:7", 7, 0, "flash", "Flash", true)
	source.size = Vector2(240, 50)
	host.add_child(source)

	var target: Control = MoveReorderSlotScript.new()
	target.call("configure", "interactive:owned:7", 7, 2, "fly", "Fly", true)
	target.size = Vector2(240, 50)
	target.position = Vector2(0, 60)
	target.connect("reorder_hovered", Callable(self, "_on_reorder_hovered"))
	target.connect("reorder_requested", Callable(self, "_on_reorder_requested"))
	host.add_child(target)
	await process_frame

	var payload_value: Variant = source.call("build_drag_payload")
	_check_true(payload_value is Dictionary, "enabled move row creates a drag dictionary")
	var payload: Dictionary = payload_value as Dictionary
	_check_equal(str(payload.get("kind", "")), "pokemon_summary_move_reorder", "drag payload uses the dedicated kind")
	_check_equal(int(payload.get("pokemonId", 0)), 7, "drag payload retains the owned Pokemon id")
	_check_equal(str(payload.get("moveId", "")), "flash", "drag payload retains the move id")

	_check_true(bool(target.call("_can_drop_data", Vector2(12, 8), payload)), "target accepts a move from the same Pokemon")
	_check_equal(str(received_hover.get("sourceMoveId", "")), "flash", "hover emits the dragged move id")
	_check_equal(str(received_hover.get("targetMoveId", "")), "fly", "hover emits the target move id for a live swap")
	target.call("_drop_data", Vector2(12, 8), payload)
	_check_equal(str(received_reorder.get("cardKey", "")), "interactive:owned:7", "drop retains the summary card context")
	_check_equal(int(received_reorder.get("pokemonId", 0)), 7, "drop retains the owned Pokemon id")
	_check_equal(str(received_reorder.get("sourceMoveId", "")), "flash", "drop commits the dragged move")

	var other_pokemon: Control = MoveReorderSlotScript.new()
	other_pokemon.call("configure", "interactive:owned:8", 8, 1, "cut", "Cut", true)
	other_pokemon.size = Vector2(240, 50)
	host.add_child(other_pokemon)
	await process_frame
	_check_true(not bool(other_pokemon.call("_can_drop_data", Vector2(12, 8), payload)), "moves cannot be dropped onto another Pokemon")

	var disabled_slot: Control = MoveReorderSlotScript.new()
	disabled_slot.call("configure", "readonly:owned:7", 7, 0, "flash", "Flash", false)
	_check_true((disabled_slot.call("build_drag_payload") as Dictionary).is_empty(), "read-only rows cannot start a reorder drag")

	_check_source_contracts()
	host.queue_free()
	disabled_slot.queue_free()
	quit(1 if failed else 0)


func _on_reorder_hovered(card_key: String, pokemon_id: int, source_move_id: String, target_move_id: String) -> void:
	received_hover = {
		"cardKey": card_key,
		"pokemonId": pokemon_id,
		"sourceMoveId": source_move_id,
		"targetMoveId": target_move_id,
	}


func _on_reorder_requested(card_key: String, pokemon_id: int, source_move_id: String) -> void:
	received_reorder = {
		"cardKey": card_key,
		"pokemonId": pokemon_id,
		"sourceMoveId": source_move_id,
	}


func _check_source_contracts() -> void:
	var service_source := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	var ui_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check_true(service_source.contains('/game/pokemon/%s/moves/reorder'), "party service calls the reorder endpoint")
	_check_true(service_source.contains('JSON.stringify({"moveIds": normalized_move_ids})'), "party service sends the complete ordered move ids")
	_check_true(service_source.contains("_apply_party_response(result)"), "successful reorder responses refresh the authoritative party")
	var slot_source := FileAccess.get_file_as_string("res://scripts/ui/pokemon_summary_move_reorder_slot.gd")
	_check_true(slot_source.contains("duplicate() as Control"), "drag preview duplicates the complete move slot")
	_check_true(slot_source.contains("preview.top_level = true"), "drag preview is detached from parent draw ordering")
	_check_true(slot_source.contains("preview.z_index = RenderingServer.CANVAS_ITEM_Z_MAX"), "drag preview renders above the summary card")
	_check_true(ui_source.contains("preview_moves[target_index] = preview_moves[source_index]"), "hovering another move performs a live visual swap")
	_check_true(ui_source.contains("pokemon_summary_content_stack.move_child"), "live reorder moves the actual summary slots")
	_check_true(ui_source.contains("rollback_pokemon.moves = original_moves"), "failed persistence restores the previous move order")
	_check_true(ui_source.contains("_cancel_pokemon_summary_move_reorder"), "dropping outside the move list restores the visual order")
	_check_true(ui_source.contains("_is_world_battle_active() or pokemon_summary_move_reorder_drag_states.has"), "move order changes are blocked during battle")
	_check_true(ui_source.contains("pokemon_summary_move_reorder_pending"), "duplicate reorder requests are guarded")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
