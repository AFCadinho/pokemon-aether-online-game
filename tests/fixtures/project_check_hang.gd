extends SceneTree

func _init() -> void:
	# Deliberately leave the process running to exercise the parent watchdog.
	print("intentional hung check fixture")
