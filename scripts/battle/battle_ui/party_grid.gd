extends GridContainer

class_name PartyGrid

func set_party(party: Array) -> void:
	var slots: Array[Node] = get_children()
	
	for idx in range(slots.size()):
		var slot: Node = slots[idx]
		
		if idx < party.size() and slot.has_method("set_pokemon"):
			slot.set_pokemon(party[idx])
		elif slot.has_method("set_empty"):
			slot.set_empty()
			
func clear_party() -> void:
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()
		
