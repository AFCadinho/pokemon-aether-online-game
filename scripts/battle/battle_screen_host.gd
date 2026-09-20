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
var chat_bridge: Node
var loading_label: Label
var fallback_button: Button

func _ready() -> void:
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stack.position = Vector2(-260,-55)
	stack.size = Vector2(520,110)
	$Cover.add_child(stack)
	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_label.custom_minimum_size = Vector2(520,60)
	loading_label.text = "Preparing battle…"
	stack.add_child(loading_label)
	fallback_button = Button.new()
	fallback_button.text = "Continue this battle in 2.5D"
	fallback_button.hide()
	stack.add_child(fallback_button)
	fallback_button.pressed.connect(_reveal_cover)

func _process(_delta: float) -> void:
	if released or not is_instance_valid(battle) or not $Cover.visible:
		return
	var presenter = battle.animation_router.model_presenter
	if is_instance_valid(presenter) and not presenter.preparation_failed:
		loading_label.text = "Preparing battle…\n" + presenter.preparation_phase

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
	if get_node("/root/SettingsManager").battle_ui_layout == "immersive":
		preload("res://scripts/battle/battle_ui/immersive_layout.gd").apply(battle)
	$Content.add_child(battle)
	resized.connect(_fit_battle)
	_fit_battle()
	if battle.has_meta("immersive_battle_ui") and is_instance_valid(overlay) and overlay.has_node("Control/ChatPanel") and overlay.has_node("Control/ChatTabsPanel"):
		chat_bridge = preload("res://scripts/battle/battle_ui/battle_chat_bridge.gd").new()
		add_child(chat_bridge)
		chat_bridge.setup(overlay,self)
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
	if presenter != null and presenter.preparation_failed:
		loading_label.text = presenter.reason + "\nYou can continue this battle in 2.5D."
		fallback_button.show()
		return
	_reveal_cover()

func _reveal_cover() -> void:
	if released or reveal_tween != null:
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
	if is_instance_valid(chat_bridge):
		chat_bridge.release()
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
