extends GridContainer

class_name PartyGrid

signal party_selected(slot: int)
signal pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2)
signal pokemon_unhovered

var input_disabled := false
var previous_disabled_by_slot: Dictionary = {}
var current_party_data: Array = []

func _ready() -> void:
	for idx in range(get_child_count()):
		var slot := get_child(idx)
		if slot.has_signal("selected"):
			slot.selected.connect(_on_party_selected.bind(idx + 1))
		if slot.has_signal("pokemon_hovered"):
			slot.pokemon_hovered.connect(_on_pokemon_hovered)
		if slot.has_signal("pokemon_unhovered"):
			slot.pokemon_unhovered.connect(_on_pokemon_unhovered)

func set_party(party: Array) -> void:
	current_party_data = party.duplicate(true)
	var slots: Array[Node] = get_children()

	for idx in range(slots.size()):
		var slot: Node = slots[idx]

		if idx < party.size():
			var pokemon = party[idx]
			if pokemon is Dictionary and slot.has_method("set_pokemon_data"):
				slot.set_pokemon_data(pokemon)
			elif slot.has_method("set_pokemon"):
				slot.set_pokemon(pokemon)
		elif slot.has_method("set_empty"):
			slot.set_empty()

	if input_disabled:
		_capture_current_disabled_states()
		_disable_current_buttons()

func clear_party() -> void:
	current_party_data.clear()
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()

func get_pokemon_data_for_visual_slot(slot: int) -> Dictionary:
	var index := slot - 1
	if index < 0 or index >= current_party_data.size():
		return {}

	var pokemon_value: Variant = current_party_data[index]
	if pokemon_value is Dictionary:
		return (pokemon_value as Dictionary).duplicate(true)

	return {}

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

func _on_party_selected(slot: int) -> void:
	if input_disabled:
		return

	party_selected.emit(slot)

func _on_pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2) -> void:
	pokemon_hovered.emit(pokemon_data, slot_rect)

func _on_pokemon_unhovered() -> void:
	pokemon_unhovered.emit()
