extends GridContainer

class_name PartyGrid

signal party_selected(slot: int)

func _ready() -> void:
	for idx in range(get_child_count()):
		var slot := get_child(idx)
		if slot.has_signal("selected"):
			slot.selected.connect(_on_party_selected.bind(idx + 1))

func set_party(party: Array) -> void:
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

func clear_party() -> void:
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()

func _on_party_selected(slot: int) -> void:
	party_selected.emit(slot)
