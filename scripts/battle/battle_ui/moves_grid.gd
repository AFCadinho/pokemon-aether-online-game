extends GridContainer

class_name MovesGrid

func set_moves(moves: Array) -> void:
	var slots: Array[Node] = get_children()
	
	for idx in range(slots.size()):
		var slot: Node = slots[idx]
		
		if idx < moves.size() and slot.has_method("set_move_data"):
			slot.set_move_data(moves[idx])
		elif slot.has_method("set_empty"):
			slot.set_empty()

func clear_moves() -> void:
	for slot: Node in get_children():
		if slot.has_method("set_empty"):
			slot.set_empty()
