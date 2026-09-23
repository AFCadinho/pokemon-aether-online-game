extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/launcher.tscn") as PackedScene
	if packed_scene == null:
		push_error("Launcher scene could not be loaded")
		quit(1)
		return

	var launcher := packed_scene.instantiate()
	root.add_child(launcher)
	await process_frame

	var support_button := launcher.get_node_or_null(
		"Shell/MainSplit/Content/ContentLayout/NewsCard/NewsMargin/NewsLayout/SupportButton"
	) as Button
	if support_button == null or launcher.get("support_button") != support_button:
		push_error("Launcher support button is missing from the live scene")
		launcher.free()
		quit(1)
		return
	if launcher.find_child("CreditsButton", true, false) != null:
		push_error("Launcher still shows the removed Credits button")
		launcher.free()
		quit(1)
		return

	launcher.free()
	await process_frame
	print("PASS launcher startup_check")
	quit(0)
