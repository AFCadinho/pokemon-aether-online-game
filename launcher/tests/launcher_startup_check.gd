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
		"Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/SupportButton"
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
	var server_card := launcher.get_node(
		"Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/ServerCard"
	) as Control
	var discord_button := launcher.get_node(
		"Shell/MainSplit/Sidebar/SidebarMargin/SidebarLayout/SocialSection/SocialRow/DiscordButton"
	) as Button
	if (
		discord_button.get_global_rect().end.x > support_button.get_global_rect().position.x
		or support_button.get_global_rect().end.x > server_card.get_global_rect().end.x
		or support_button.get_global_rect().end.y > server_card.get_global_rect().position.y
		or server_card.get_global_rect().end.y > root.get_visible_rect().end.y
	):
		push_error("Launcher support link crowds the sidebar at the default window size")
		launcher.free()
		quit(1)
		return

	launcher.free()
	await process_frame
	print("PASS launcher startup_check")
	quit(0)
