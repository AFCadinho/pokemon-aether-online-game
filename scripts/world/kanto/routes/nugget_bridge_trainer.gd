@tool
extends TrainerNPC

class_name NuggetBridgeTrainer

func walk_to_player(_body: Node2D) -> void:
	# Bridge challengers hold their reviewed positions when they spot a player.
	_set_idle_frame(_get_cardinal_direction(facing_direction))
