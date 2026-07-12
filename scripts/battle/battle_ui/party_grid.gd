extends GridContainer

class_name PartyGrid

signal party_selected(slot: int)
signal pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2)
signal pokemon_unhovered
signal party_changed(party: Array)

var input_disabled := false
var selection_enabled := false
var intrinsic_disabled_by_slot: Dictionary = {}
var current_party_data: Array = []

static func should_allow_selection(
	battle_mode_active: bool,
	selection_context_active: bool,
	input_is_locked: bool,
	battle_is_finished: bool
) -> bool:
	return battle_mode_active and selection_context_active and not input_is_locked and not battle_is_finished

func _ready() -> void:
	for idx in range(get_child_count()):
		var slot := get_child(idx)
		if slot.has_signal("selected"):
			slot.selected.connect(_on_party_selected.bind(idx + 1))
		if slot.has_signal("pokemon_hovered"):
			slot.pokemon_hovered.connect(_on_pokemon_hovered)
		if slot.has_signal("pokemon_unhovered"):
			slot.pokemon_unhovered.connect(_on_pokemon_unhovered)
	_capture_intrinsic_disabled_states()
	_apply_interaction_state()

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
		elif slot.has_method("set_empty"):
			slot.set_empty()

	_capture_intrinsic_disabled_states()
	_apply_interaction_state()
	party_changed.emit(current_party_data.duplicate(true))

func clear_party() -> void:
	current_party_data.clear()
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()
	_capture_intrinsic_disabled_states()
	_apply_interaction_state()
	party_changed.emit([])

func get_pokemon_data_for_visual_slot(slot: int) -> Dictionary:
	var index := slot - 1
	if index < 0 or index >= current_party_data.size():
		return {}

	var pokemon_value: Variant = current_party_data[index]
	if pokemon_value is Dictionary:
		return (pokemon_value as Dictionary).duplicate(true)

	return {}

func set_input_disabled(is_disabled: bool) -> void:
	input_disabled = is_disabled
	_apply_interaction_state()

func set_selection_enabled(is_enabled: bool) -> void:
	selection_enabled = is_enabled
	_apply_interaction_state()

func is_selection_enabled() -> bool:
	return selection_enabled and not input_disabled

func is_slot_selectable(slot: int) -> bool:
	var index := slot - 1
	if index < 0 or index >= get_child_count():
		return false
	var button := get_child(index) as Button
	return button != null and not button.disabled

func focus_first_selectable() -> void:
	for slot: Node in get_children():
		var button := slot as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return

func _capture_intrinsic_disabled_states() -> void:
	intrinsic_disabled_by_slot.clear()
	for slot in get_children():
		if slot is Button:
			var button: Button = slot as Button
			var key := str(button.get_path())
			intrinsic_disabled_by_slot[key] = button.disabled

func _apply_interaction_state() -> void:
	for slot in get_children():
		if slot is Button:
			var button: Button = slot as Button
			var key := str(button.get_path())
			var intrinsically_disabled := bool(intrinsic_disabled_by_slot.get(key, true))
			button.disabled = input_disabled or not selection_enabled or intrinsically_disabled

func _on_party_selected(slot: int) -> void:
	if input_disabled or not selection_enabled:
		return

	party_selected.emit(slot)

func _on_pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2) -> void:
	pokemon_hovered.emit(pokemon_data, slot_rect)

func _on_pokemon_unhovered() -> void:
	pokemon_unhovered.emit()
