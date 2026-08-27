extends WorldInteractable

class_name CeruleanMountainReturn

@export var destination_position := Vector2(432, 1520)


func _ready() -> void:
	interactable_kind = "trail_marker"
	display_name = LocalizationManager.text("npc.cerulean_mountain_guide.return_name")
	blocks_movement = false
	requires_facing = false
	interaction_shape_size = Vector2(80, 80)
	super._ready()


func interact_with_player(_player: Node2D) -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not world.has_method("relocate_player_within_current_map"):
		await show_dialogue([LocalizationManager.text("npc.cerulean_mountain_guide.travel_failed")])
		return
	var result: Dictionary = await world.call("relocate_player_within_current_map", destination_position)
	if not bool(result.get("success", false)):
		await GameErrorDialogService.show_response(result, "backend.error.rock_smash_unavailable")
