extends Control
## Presentation-only scene boundary. World retains authority/input locks/networking.
## Never pauses the SceneTree or saves/restores a stale map/player transform.

var battle: Control
var overlay: CanvasLayer
var overlay_was_visible := false
var saved_input: Array[Dictionary] = []
var released := false
var generation := 0
var reveal_tween: Tween

func mount(instance: Control, overworld_overlay: CanvasLayer = null) -> void:
	battle = instance
	overlay = overworld_overlay
	if is_instance_valid(overlay):
		overlay_was_visible = overlay.visible
		overlay.hide()
		_suspend_ui_input(overlay)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()
	battle.set_meta("dedicated_battle_screen", true)
	$Content.add_child(battle)
	resized.connect(_fit_battle)
	_fit_battle()
	_reveal_when_prepared.call_deferred(generation)

func _suspend_ui_input(node: Node) -> void:
	saved_input.append({"node": weakref(node), "input": node.is_processing_input(),
		"unhandled": node.is_processing_unhandled_input(),
		"key": node.is_processing_unhandled_key_input(),
		"shortcut": node.is_processing_shortcut_input()})
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	node.set_process_shortcut_input(false)
	for child in node.get_children():
		_suspend_ui_input(child)

func _fit_battle() -> void:
	if not is_instance_valid(battle):
		return
	# Preserve the HUD's design coordinates; expand its logical canvas for wide
	# displays, instead of stretching Pokémon or cropping controls on small ones.
	var design := Vector2(1500, 780)
	var factor := minf(size.x / design.x, size.y / design.y)
	if factor <= 0.0:
		return
	battle.position = Vector2.ZERO
	battle.size = size / factor
	battle.scale = Vector2.ONE * factor

func _reveal_when_prepared(token: int) -> void:
	if released or not is_instance_valid(battle):
		return
	var presenter := battle.get_node_or_null("%BattleStage/ExperimentalBattle3D")
	if presenter != null:
		await presenter.await_prepared(true)
	if released or token != generation or not is_inside_tree():
		return
	reveal_tween = create_tween()
	reveal_tween.tween_property($Cover, "modulate:a", 0.0, 0.2)
	await reveal_tween.finished
	if not released:
		$Cover.hide()

func release() -> void:
	if released:
		return
	released = true
	generation += 1
	if is_instance_valid(battle):
		var presenter := battle.get_node_or_null("%BattleStage/ExperimentalBattle3D")
		if presenter != null:
			presenter.cancel_preparation()
	if reveal_tween != null:
		reveal_tween.kill()
	# Restore UI immediately, exactly once, before any new screen can acquire it.
	# World alone restores player input, including blackout/teleport exceptions.
	for state in saved_input:
		var node: Node = state.node.get_ref()
		if is_instance_valid(node):
			node.set_process_input(state.input)
			node.set_process_unhandled_input(state.unhandled)
			node.set_process_unhandled_key_input(state.key)
			node.set_process_shortcut_input(state.shortcut)
	saved_input.clear()
	if is_instance_valid(overlay):
		overlay.visible = overlay_was_visible
	overlay = null
	battle = null

func _exit_tree() -> void:
	release()
