extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	# An empty scene isolates startup/shutdown allocations from the co-op UI.
	print("PASS empty render lifecycle baseline")
	quit()
