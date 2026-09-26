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
var entry_transition: WildEncounterTransition
var battle_unhandled_input_before_settings := true
var battle_settings_menu: PanelContainer
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var settings_center: CenterContainer = $SettingsOverlay/CenterContainer

func _ready() -> void:
	if not OS.has_feature("mobile"):
		_ensure_battle_settings_menu()
	entry_transition = WildEncounterTransition.new()
	entry_transition.name = "EntryTransition"
	$Cover.add_child(entry_transition)
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


func _ensure_battle_settings_menu() -> void:
	if battle_settings_menu != null:
		return
	var settings_scene := load("res://scenes/interface/settings/settings_menu.tscn") as PackedScene
	if settings_scene != null:
		battle_settings_menu = settings_scene.instantiate() as PanelContainer
		battle_settings_menu.name = "BattleSettingsMenu"
		battle_settings_menu.hide()
		settings_center.add_child(battle_settings_menu)
	if battle_settings_menu != null and battle_settings_menu.has_signal("closed"):
		battle_settings_menu.closed.connect(_on_battle_settings_closed)

func _input(event: InputEvent) -> void:
	if released or not is_instance_valid(battle) or $Cover.visible:
		return
	if battle_settings_menu != null and battle_settings_menu.visible:
		# The menu owns Escape while open, including cancelling key binding
		# capture and closing its confirmation dialogs before the menu itself.
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	if battle.has_method("_close_visible_battle_drawer") and battle.call("_close_visible_battle_drawer"):
		get_viewport().set_input_as_handled()
		return
	_open_battle_settings()
	get_viewport().set_input_as_handled()

func _open_battle_settings() -> void:
	_ensure_battle_settings_menu()
	if battle_settings_menu == null:
		return
	settings_overlay.show()
	if battle_settings_menu.has_method("open"):
		battle_settings_menu.call("open", "game")
	else:
		battle_settings_menu.show()
	if is_instance_valid(battle):
		battle_unhandled_input_before_settings = battle.is_processing_unhandled_input()
		battle.set_process_unhandled_input(false)

func _on_battle_settings_closed() -> void:
	settings_overlay.hide()
	if is_instance_valid(battle):
		battle.set_process_unhandled_input(battle_unhandled_input_before_settings)

func _process(_delta: float) -> void:
	if released or not is_instance_valid(battle) or not $Cover.visible:
		return
	var presenter = battle.animation_router.model_presenter
	if is_instance_valid(presenter) and not presenter.preparation_failed:
		loading_label.text = "Preparing battle…\n" + presenter.preparation_phase

func prewarm_mobile_immersive_battle(instance: Control) -> void:
	# Build the Android battle controls while the world is open. Keep the whole
	# tree dormant until mount() takes ownership of the active encounter.
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	battle = instance
	battle.set_meta("dedicated_battle_screen", true)
	preload("res://scripts/battle/battle_ui/immersive_layout.gd").apply(battle)
	$Content.add_child(battle)

func mount(instance: Control, overworld_overlay: CanvasLayer = null, transition_style := WildEncounterTransition.STYLE_WILD, force_immersive := false) -> void:
	var already_prepared := battle == instance and instance.get_parent() == $Content
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	entry_transition.transition_style = transition_style
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
	battle.set_meta("battle_screen_preparing", true)
	if not already_prepared and (force_immersive or get_node("/root/SettingsManager").battle_ui_layout == "immersive"):
		preload("res://scripts/battle/battle_ui/immersive_layout.gd").apply(battle)
	if not already_prepared:
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
	# Keep the opaque loading cover until preparation succeeds (or the player
	# explicitly chooses fallback). Then open the same shutters/bands as 2D.
	loading_label.get_parent().hide()
	entry_transition.cover_progress = 1.0
	entry_transition.show()
	entry_transition.set_process(true)
	$Cover.color.a = 0.0
	reveal_tween = create_tween()
	reveal_tween.tween_property(entry_transition, "cover_progress", 0.0, WildEncounterTransition.REVEAL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await reveal_tween.finished
	if not released:
		entry_transition.hide()
		entry_transition.set_process(false)
		$Cover.hide()
		if is_instance_valid(battle):
			battle.remove_meta("battle_screen_preparing")

func release() -> void:
	if released:
		return
	released = true
	if is_instance_valid(chat_bridge):
		chat_bridge.release()
	settings_overlay.hide()
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
