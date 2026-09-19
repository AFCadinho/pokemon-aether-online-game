extends SceneTree
const PacksPanel := preload("res://scripts/content_packs_panel.gd")
const Store := preload("res://scripts/content_pack_store.gd")
var failed := false

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func run() -> void:
	var manager := root.get_node("LauncherLocalization")
	manager.set_locale("nl")
	var directory := "user://mods-panel-check-" + str(Time.get_ticks_usec())
	var store := Store.new(directory)
	DirAccess.make_dir_recursive_absolute(store.root.path_join("sample"))
	var file := FileAccess.open(store.root.path_join("sample/mod.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format_version": 1, "id": "sample", "name": "Voorbeeldpack", "version": "1.0", "author": "PokeAether", "assets": {"cries": {"pikachu": {"file": "pikachu.ogg"}}}}))
	file.close()
	var panel := PacksPanel.new()
	panel.store = store
	root.add_child(panel)
	panel.setup(manager.text)
	check(panel.tabs.get_tab_title(0) == "Ontdekken", "discover localized")
	check(panel.tabs.get_tab_title(1) == "Geïnstalleerd", "installed localized")
	check(panel.rows.get_child_count() == 1, "installed pack shown")
	var toggle := panel.rows.get_child(0).get_child(0) as CheckBox
	check(toggle != null and not toggle.button_pressed, "pack initially disabled")
	toggle.button_pressed = true
	await process_frame
	check(store.enabled_ids() == ["sample"], "toggle persists selection")
	panel.popup_centered()
	await process_frame
	check(panel.size.y <= 600, "dialog fits within launcher height")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot := panel.get_texture().get_image()
		var output := OS.get_environment("POKEAETHER_TEST_LOG_DIR").path_join("content-packs-panel.png")
		check(screenshot.save_png(output) == OK, "save visual review image")
	panel.hide()
	panel.queue_free()
	await process_frame
	DirAccess.remove_absolute(store.root.path_join("sample/mod.json"))
	DirAccess.remove_absolute(store.root.path_join("sample"))
	DirAccess.remove_absolute(store.root.path_join("enabled.json"))
	DirAccess.remove_absolute(store.root)
	print("Content packs panel: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
