extends PanelContainer

class_name PokemonSummaryMoveReorderSlot

signal reorder_drag_started(card_key: String, pokemon_id: int, source_move_id: String)
signal reorder_hovered(card_key: String, pokemon_id: int, source_move_id: String, target_move_id: String)
signal reorder_requested(card_key: String, pokemon_id: int, source_move_id: String)
signal reorder_drag_finished(card_key: String, pokemon_id: int, source_move_id: String, successful: bool)
signal direct_action_requested(card_key: String, pokemon_id: int, move_id: String)

const DRAG_KIND := "pokemon_summary_move_reorder"

var card_key := ""
var pokemon_id := 0
var move_index := -1
var move_id := ""
var move_name := "Move"
var reorder_enabled := false
var direct_action_enabled := false
var _drag_active := false
var _last_hovered_source_move_id := ""


func configure(
	configured_card_key: String,
	configured_pokemon_id: int,
	configured_move_index: int,
	configured_move_id: String,
	configured_move_name: String,
	configured_reorder_enabled: bool,
	configured_direct_action_enabled := false
) -> void:
	card_key = configured_card_key
	pokemon_id = configured_pokemon_id
	move_index = configured_move_index
	move_id = configured_move_id
	move_name = configured_move_name
	reorder_enabled = configured_reorder_enabled
	direct_action_enabled = configured_direct_action_enabled
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG if reorder_enabled else Control.CURSOR_ARROW


func update_visual_index(updated_index: int) -> void:
	move_index = updated_index
	var number_label := find_child("MoveNumberLabel", true, false) as Label
	if number_label != null:
		number_label.text = str(move_index + 1)


func build_drag_payload() -> Dictionary:
	if not reorder_enabled or pokemon_id <= 0 or move_index < 0 or move_id == "":
		return {}
	return {
		"kind": DRAG_KIND,
		"cardKey": card_key,
		"pokemonId": pokemon_id,
		"sourceIndex": move_index,
		"moveId": move_id,
		"moveName": move_name,
		"hotbarEligible": direct_action_enabled,
	}


func request_direct_action() -> void:
	if not direct_action_enabled or pokemon_id <= 0 or move_id == "":
		return
	direct_action_requested.emit(card_key, pokemon_id, move_id)


func _get_drag_data(_position: Vector2) -> Variant:
	var payload: Dictionary = build_drag_payload()
	if payload.is_empty():
		return null

	_drag_active = true
	modulate = Color(1, 1, 1, 0.28)
	set_drag_preview(_create_full_slot_drag_preview())
	reorder_drag_started.emit(card_key, pokemon_id, move_id)
	return payload


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not _matches_drag_payload(data):
		_last_hovered_source_move_id = ""
		return false

	var payload: Dictionary = data as Dictionary
	var source_move_id: String = str(payload.get("moveId", ""))
	if source_move_id != move_id and source_move_id != _last_hovered_source_move_id:
		_last_hovered_source_move_id = source_move_id
		reorder_hovered.emit(card_key, pokemon_id, source_move_id, move_id)
	return true


func _drop_data(_position: Vector2, data: Variant) -> void:
	if not _matches_drag_payload(data):
		return
	var payload: Dictionary = data as Dictionary
	reorder_requested.emit(
		str(payload.get("cardKey", "")),
		int(payload.get("pokemonId", 0)),
		str(payload.get("moveId", ""))
	)


func _matches_drag_payload(data: Variant) -> bool:
	if not reorder_enabled or not (data is Dictionary):
		return false
	var payload: Dictionary = data as Dictionary
	return (
		str(payload.get("kind", "")) == DRAG_KIND
		and str(payload.get("cardKey", "")) == card_key
		and int(payload.get("pokemonId", 0)) == pokemon_id
		and str(payload.get("moveId", "")) != ""
	)


func _create_full_slot_drag_preview() -> Control:
	var preview := duplicate() as Control
	if preview == null:
		preview = PanelContainer.new()
	preview.custom_minimum_size = size
	preview.size = size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 0.96)
	preview.top_level = true
	preview.z_as_relative = false
	preview.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_set_mouse_filter_recursive(preview)
	return preview


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_last_hovered_source_move_id = ""
	if what != NOTIFICATION_DRAG_END or not _drag_active:
		return
	_drag_active = false
	modulate = Color.WHITE
	var successful := false
	if get_viewport() != null:
		successful = get_viewport().gui_is_drag_successful()
	reorder_drag_finished.emit(card_key, pokemon_id, move_id, successful)
