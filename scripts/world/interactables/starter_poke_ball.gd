extends WorldInteractable

class_name StarterPokeBall

@export var species_id := "bulbasaur"
@export var species_name := "Bulbasaur"
@export var selection_stand_offset := Vector2(0, 32)

@onready var visual: CanvasItem = get_node_or_null("Visual")

var claimed := false


func _ready() -> void:
	interactable_kind = "starter_poke_ball"
	display_name = LocalizationManager.text("ui.oaks_lab.starter_ball.name")
	super._ready()


func interact_with_player(_player: Node2D) -> void:
	if claimed:
		return
	await show_dialogue(
		[
			LocalizationManager.text(
				"ui.oaks_lab.starter_ball.inspect",
				{"pokemon": species_name}
			)
		],
		display_name
	)


func set_claimed(value: bool) -> void:
	claimed = value
	visible = not claimed
	set_process(not claimed)
	if interaction_area != null:
		interaction_area.monitoring = not claimed
		interaction_area.monitorable = not claimed


func get_selection_stand_position() -> Vector2:
	return global_position + selection_stand_offset


func matches_species(value: String) -> bool:
	return species_id == value.strip_edges().to_lower()
