extends GridContainer

class_name MovesGrid

signal move_selected(slot: int)

var input_disabled := false
var previous_disabled_by_slot: Dictionary = {}

func _ready() -> void:
	var slots: Array[Node] = get_children()
	
	for idx in range(slots.size()):
		var slot: Node = slots[idx]
		if slot.has_signal("selected"):
			slot.selected.connect(_on_slot_selected.bind(idx + 1))

func set_moves(moves: Array) -> void:
	var slots: Array[Node] = get_children()
	
	for idx in range(slots.size()):
		var slot: Node = slots[idx]
		
		if idx < moves.size() and slot.has_method("set_move_data"):
			slot.set_move_data(moves[idx])
		elif slot.has_method("set_empty"):
			slot.set_empty()

	if input_disabled:
		_capture_current_disabled_states()
		_disable_current_buttons()

func clear_moves() -> void:
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()

func set_input_disabled(is_disabled: bool) -> void:
	if input_disabled == is_disabled:
		return

	input_disabled = is_disabled
	if is_disabled:
		_capture_current_disabled_states()
		_disable_current_buttons()
	else:
		_restore_previous_disabled_states()

func _capture_current_disabled_states() -> void:
	previous_disabled_by_slot.clear()
	for slot in get_children():
		if slot is Button:
			var button: Button = slot as Button
			var key := str(button.get_path())
			previous_disabled_by_slot[key] = button.disabled

func _disable_current_buttons() -> void:
	for slot in get_children():
		if slot is Button:
			var button: Button = slot as Button
			button.disabled = true

func _restore_previous_disabled_states() -> void:
	for slot in get_children():
		if slot is Button:
			var button: Button = slot as Button
			var key := str(button.get_path())
			button.disabled = bool(previous_disabled_by_slot.get(key, button.disabled))

	previous_disabled_by_slot.clear()
			
func _on_slot_selected(slot: int) -> void:
	if input_disabled:
		return

	move_selected.emit(slot)
