extends SceneTree

const DIALOG_SCENE := "res://scenes/interface/aether_confirmation_dialog.tscn"
const KEEPER_SCRIPT := "res://scripts/world/npcs/transit_keeper_npc.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var keeper_source := FileAccess.get_file_as_string(KEEPER_SCRIPT)
	_check(
		keeper_source.contains('dialog_layer.name = "AethernetBrowserDialogLayer"')
		and keeper_source.contains("current_scene.add_child(dialog_layer)")
		and keeper_source.contains("dialog_layer.add_child(dialog)"),
		"browser notice is hosted by a screen-space CanvasLayer"
	)

	var world := Node2D.new()
	world.position = Vector2(800.0, 500.0)
	world.scale = Vector2(3.0, 3.0)
	root.add_child(world)
	var dialog_layer := CanvasLayer.new()
	world.add_child(dialog_layer)
	var packed := load(DIALOG_SCENE) as PackedScene
	var dialog := packed.instantiate() as AetherConfirmationDialog
	dialog_layer.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 250))
	await process_frame
	await process_frame

	var panel := dialog.get_node("Center/Panel") as PanelContainer
	_check(
		dialog.size.is_equal_approx(root.get_visible_rect().size),
		"browser notice fills the viewport instead of inheriting the world transform"
	)
	_check(
		panel.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()),
		"browser notice remains centered above a transformed world"
	)
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
