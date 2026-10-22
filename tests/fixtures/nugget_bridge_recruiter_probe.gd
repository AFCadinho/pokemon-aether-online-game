extends NuggetBridgeRecruiter

# Exercise the real reward failure path without scene sensors or progress HTTP calls.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)
