extends BaseNPC

class_name DialogueNPC


func _ready() -> void:
	_ready_base_npc()


func _process(_delta: float) -> void:
	await _process_base_npc()
