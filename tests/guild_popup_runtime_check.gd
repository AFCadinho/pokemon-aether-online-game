extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/interface/guild_popup.tscn") as PackedScene
	_check(packed != null, "guild popup scene loads at runtime")
	if packed == null:
		quit(1)
		return

	var popup := packed.instantiate() as GuildPopup
	root.add_child(popup)
	await process_frame
	popup.show_debug_preview()
	popup.open()
	await process_frame

	_check(popup.visible, "guild popup opens")
	_check(popup.size == GuildPopup.POPUP_SIZE, "guild popup uses the intended desktop size")
	var minimum_size := popup.get_combined_minimum_size()
	_check(
		minimum_size.x <= GuildPopup.POPUP_SIZE.x and minimum_size.y <= GuildPopup.POPUP_SIZE.y,
		"guild content fits inside its popup"
	)
	_check(popup.find_child("BrowseGuildsButton", true, false) != null, "browse action is present")
	_check(popup.find_child("CreateGuildButton", true, false) != null, "create action is present")
	_check(popup.find_child("GuildSearchInput", true, false) != null, "guild search is present")
	_check(popup.find_child("GuildRow_1", true, false) != null, "debug directory renders guild rows")
	_check(popup.find_child("GuildDetailPanel", true, false) != null, "guild information panel is present")

	popup.close()
	await process_frame
	_check(not popup.visible, "guild popup closes cleanly")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
