extends GridContainer

class_name PartyGrid

signal party_selected(slot: int)
signal pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2)
signal pokemon_unhovered
signal party_changed(party: Array)

var input_disabled := false
var selection_enabled := false
var hover_enabled := false
var empty_slots_visible := false
var intrinsic_disabled_by_slot: Dictionary = {}
var current_party_data: Array = []
var trainer_groups_enabled := false
var trainer_group_style: StyleBoxFlat

func set_trainer_groups_enabled(enabled: bool) -> void:
	trainer_groups_enabled = enabled
	if enabled:
		trainer_group_style = StyleBoxFlat.new()
		trainer_group_style.bg_color = Color("#111e30e6")
		trainer_group_style.border_color = Color("#456582")
		trainer_group_style.set_border_width_all(1)
		trainer_group_style.set_corner_radius_all(8)
		custom_minimum_size = Vector2(56, 392)
	else:
		custom_minimum_size = Vector2.ZERO
	queue_sort()
	queue_redraw()

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or not trainer_groups_enabled:
		return
	# Keep the six direct children and their original visual-slot indices so
	# party updates, hover cards and Trainer callouts retain their ownership.
	for index in range(mini(6, get_child_count())):
		var slot := get_child(index) as Control
		if slot != null:
			fit_child_in_rect(slot, Rect2(2, (index / 3) * 202 + 24 + (index % 3) * 55, 52, 52))
	queue_redraw()

func _draw() -> void:
	if not trainer_groups_enabled or trainer_group_style == null:
		return
	var font := get_theme_default_font()
	for group in range(2):
		var top := group * 202.0
		draw_style_box(trainer_group_style, Rect2(0, top, 56, 190))
		draw_string(font, Vector2(2, top + 17), "P%d" % (group + 1), HORIZONTAL_ALIGNMENT_CENTER, 52, 12, Color("#b7d4ed"))

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

		if idx < party.size() and party[idx] != null:
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


func set_empty_slots_visible(is_visible: bool) -> void:
	empty_slots_visible = is_visible
	for slot: Node in get_children():
		if slot.has_method("set_empty_visible"):
			slot.call("set_empty_visible", empty_slots_visible)

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

func set_hover_enabled(is_enabled: bool) -> void:
	hover_enabled = is_enabled
	_apply_interaction_state()

func is_selection_enabled() -> bool:
	return selection_enabled and not input_disabled

func is_slot_selectable(slot: int) -> bool:
	if not is_selection_enabled():
		return false
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
			button.disabled = input_disabled or ((not selection_enabled) and not hover_enabled) or intrinsically_disabled

func _on_party_selected(slot: int) -> void:
	if input_disabled or not selection_enabled:
		return

	party_selected.emit(slot)

func _on_pokemon_hovered(pokemon_data: Dictionary, slot_rect: Rect2) -> void:
	pokemon_hovered.emit(pokemon_data, slot_rect)

func _on_pokemon_unhovered() -> void:
	pokemon_unhovered.emit()
