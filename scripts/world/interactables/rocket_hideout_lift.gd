extends WorldInteractable

signal floor_selected(index: int)

const CONFIRMATION := preload("res://scenes/interface/aether_confirmation_dialog.tscn")

@export var destination_floors: PackedStringArray = []
@export var destination_exits: Array[NodePath] = []


func _ready() -> void:
	display_name = LocalizationManager.text("ui.rocket_hideout.lift.title")
	super._ready()


func interact_with_player(player: Node2D) -> void:
	if destination_floors.is_empty() or destination_floors.size() != destination_exits.size():
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
	get_tree().current_scene.add_child(layer)
	var dialog := CONFIRMATION.instantiate() as AetherConfirmationDialog
	layer.add_child(dialog)
	var choice := OptionButton.new()
	choice.name = "Floors"
	for floor_name: String in destination_floors:
		choice.add_item(floor_name)
	choice.custom_minimum_size = Vector2(0, 42)
	dialog.add_custom_control(choice)
	dialog.style_option_button(choice)
	dialog.configure(
		LocalizationManager.text("ui.rocket_hideout.lift.title"),
		LocalizationManager.text("ui.rocket_hideout.lift.prompt"),
		LocalizationManager.text("common.continue"),
		LocalizationManager.text("common.cancel")
	)
	dialog.confirmed.connect(func(): floor_selected.emit(choice.selected), CONNECT_ONE_SHOT)
	dialog.canceled.connect(func(): floor_selected.emit(-1), CONNECT_ONE_SHOT)
	dialog.popup_centered(Vector2i(500, 290))
	var selected: int = await floor_selected
	layer.queue_free()
	return selected
