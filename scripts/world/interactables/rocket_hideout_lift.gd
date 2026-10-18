extends WorldInteractable

signal floor_selected(index: int)

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")

@export var destination_floors := PackedStringArray(["B1F", "B2F", "B4F"])
@export var destination_exits: Array[NodePath] = []
var current_floor := ""
var _menu_layer: CanvasLayer
var _input_owner := StringName("rocket_elevator_panel_%s" % get_instance_id())


func _ready() -> void:
	display_name = LocalizationManager.text("ui.rocket_hideout.lift.title")
	super._ready()


func interact_with_player(player: Node2D) -> void:
	if current_floor not in destination_floors or destination_floors.size() != destination_exits.size():
		push_error("Rocket Hideout lift has incomplete destinations.")
		return
	var selected := await _show_floor_selection()
	if selected < 0 or selected >= destination_exits.size() or not is_instance_valid(player):
		return
	var exit_node := get_node_or_null(destination_exits[selected])
	if exit_node == null or not exit_node.has_method("_on_body_entered"):
		push_error("Rocket Hideout lift destination is missing its authorized MapExit.")
		return
	# Finish WorldInteractable's interaction and release its input lock before
	# MapExit starts the usual server-authorized map replacement.
	exit_node.call_deferred("_on_body_entered", player)


func _show_floor_selection() -> int:
	var layer := CanvasLayer.new()
	layer.name = "RocketHideoutLiftMenu"
	layer.layer = 120
	_menu_layer = layer
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	var choice := OptionButton.new()
	choice.name = "Floors"
	for floor_name: String in destination_floors:
		choice.add_item(floor_name)
		var index := choice.item_count - 1
		if floor_name == current_floor:
			choice.set_item_text(index, LocalizationManager.text("ui.rocket_hideout.lift.current_floor", {"floor": floor_name}))
			choice.set_item_disabled(index, true)
	for index in choice.item_count:
		if not choice.is_item_disabled(index):
			choice.select(index)
			break
	choice.custom_minimum_size = Vector2(0, 42)
	dialog.add_custom_control(choice)
	dialog.style_option_button(choice)
	dialog.configure(
		LocalizationManager.text("ui.rocket_hideout.lift.title"),
		LocalizationManager.text("ui.rocket_hideout.lift.prompt") + "\n" + LocalizationManager.text("ui.rocket_hideout.lift.current_floor", {"floor": current_floor}),
		LocalizationManager.text("common.continue"),
		LocalizationManager.text("common.cancel")
	)
	dialog.confirmed.connect(func(): floor_selected.emit(choice.selected), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): floor_selected.emit(-1), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(500, 290))
	var selected: int = await floor_selected
	layer.queue_free()
	_menu_layer = null
	return selected


func _lock_overworld_input() -> void:
	GameState.acquire_overworld_input_lock(_input_owner)


func _unlock_overworld_input() -> void:
	GameState.release_overworld_input_lock(_input_owner)


func _exit_tree() -> void:
	if is_instance_valid(_menu_layer):
		floor_selected.emit(-1)
	_unlock_overworld_input()
	if is_instance_valid(_menu_layer):
		_menu_layer.queue_free()
