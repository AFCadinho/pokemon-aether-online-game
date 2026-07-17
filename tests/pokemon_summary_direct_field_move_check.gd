extends SceneTree

var failed := false


func _init() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/services/field_move_service.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var slot_source := FileAccess.get_file_as_string("res://scripts/ui/pokemon_summary_move_reorder_slot.gd")
	_check_true(service_source.contains('"flash": {'), "Flash is exposed as a direct overworld move")
	_check_true(service_source.contains("func can_use_direct_field_move"), "direct moves receive exact source validation")
	_check_true(service_source.contains('world.call("use_direct_field_move"'), "direct moves are dispatched to the active overworld")
	_check_true(ui_source.contains("OVERWORLD_MOVE_ACTION_ICON"), "summary cards use the compact overworld action icon")
	_check_true(ui_source.contains("FieldMoveService.use_direct_field_move(move_id, pokemon_id)"), "summary actions use the shared field move service")
	_check_true(slot_source.contains('"hotbarEligible": direct_action_enabled'), "summary move drag data advertises hotbar eligibility")
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
