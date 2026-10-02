extends TrainerNPC

# Exercise sensor physics without starting metadata or progression requests.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
