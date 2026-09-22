extends SceneTree

var failures := 0

class ObservedCursorManager extends "res://scripts/services/cursor_theme_manager.gd":
	var textures: Array[WeakRef] = []
	func _scaled_cursor(source: Texture2D) -> ImageTexture:
		var texture := super._scaled_cursor(source)
		textures.append(weakref(texture))
		return texture


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := ObservedCursorManager.new()
	root.add_child(manager)
	var initial := manager.textures.duplicate()
	_check(initial.size() == 6, "All six cursor shapes receive generated textures")
	if DisplayServer.get_name() != "headless":
		_check(initial.all(func(ref: WeakRef): return ref.get_ref() != null),
			"Input holds all six current cursor textures")
	manager.set_cursor_scale(50)
	_check(initial.all(func(ref: WeakRef): return ref.get_ref() == null),
		"Changing scale releases the replaced cursor textures")
	var current := manager.textures.slice(6)
	_check(current.size() == 6, "Scale change regenerates all six cursor shapes")
	manager.queue_free()
	await process_frame
	await process_frame
	_check(current.all(func(ref: WeakRef): return ref.get_ref() == null),
		"Leaving the tree releases cursor textures before renderer shutdown")
	root.get_node("CursorThemeManager").apply_cursor_theme()
	quit(1 if failures else 0)


func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
