extends SceneTree
const Quality := preload("res://scripts/services/battle_quality_policy.gd")
const Pool := preload("res://scripts/battle/arenas/shared/environment_pool.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	assert(OS.has_feature("pc") and not OS.has_feature("android"))
	assert(Quality.dimensions(Vector2i(3840,2160), "medium") == Vector2i(2880,1620))
	assert(Quality.dimensions(Vector2i(2160,3840), "low") == Vector2i(1080,1920))
	assert(Quality.dimensions(Vector2i(3840,2160), "medium", true) == Vector2i(1280,720))
	assert(Quality.dimensions(Vector2i.ZERO, "low") == Vector2i(2,2))
	assert(Quality.validate_fps(60.5) == 0 and Quality.validate_fps("60") == 0 and Quality.validate_fps(120) == 120)
	var settings := root.get_node("SettingsManager")
	var existed := FileAccess.file_exists(settings.SETTINGS_PATH)
	var saved := FileAccess.get_file_as_string(settings.SETTINGS_PATH) if existed else ""
	var android_before: String = settings.android_quality_preset
	var android_fps_before: int = settings.android_fps_limit
	var menu: Control = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	assert(menu.desktop_quality_options != null and menu.desktop_fps_options != null and menu.android_quality_options == null)
	menu._apply_settings_to_controls()
	menu.desktop_quality_options.select(0)
	menu.desktop_quality_options.item_selected.emit(0)
	menu.desktop_fps_options.select(2)
	menu.desktop_fps_options.item_selected.emit(2)
	settings.load_settings()
	assert(settings.get_battle_quality_preset() == "low" and Engine.max_fps == 60)
	assert(settings.android_quality_preset == android_before and settings.android_fps_limit == android_fps_before)
	var pool := Pool.prepare(root, "", Vector2i(1920,1080), "cave")
	while not pool.ready_for_battle and not pool.failed: await process_frame
	assert(pool.ready_for_battle and pool.quality_preset == "low")
	for data in pool.passes:
		assert(data.viewport.size == Vector2i(960,540) and data.viewport.msaa_3d == Viewport.MSAA_DISABLED)
		_no_shadows(data.world)
	var owner := Control.new()
	root.add_child(owner)
	# A borrowed arena remains intact until the current battle releases it.
	pool.borrower = weakref(owner)
	settings.set_desktop_battle_quality_preset("high")
	assert(pool.discard_requested and not pool.is_queued_for_deletion() and pool.quality_preset == "low")
	assert(Pool.prepare(root, "", Vector2i(1920,1080), "cave") == null)
	owner.free()
	pool.free()
	pool = Pool.prepare(root, "", Vector2i(1920,1080), "cave")
	while not pool.ready_for_battle and not pool.failed: await process_frame
	assert(pool.ready_for_battle and pool.quality_preset == "high")
	for data in pool.passes:
		assert(data.viewport.size == Vector2i(1920,1080) and data.viewport.msaa_3d == Viewport.MSAA_2X)
	pool.free()
	menu.free()
	if existed:
		var file := FileAccess.open(settings.SETTINGS_PATH, FileAccess.WRITE)
		file.store_string(saved)
		file.close()
	else: DirAccess.remove_absolute(settings.SETTINGS_PATH)
	settings.load_settings()
	print("DESKTOP_BATTLE_QUALITY_OK persisted_ui independent_android borrowed_arena next_battle both_passes")
	quit()
func _no_shadows(node: Node) -> void:
	if node is Light3D: assert(not node.shadow_enabled)
	for child in node.get_children(): _no_shadows(child)
