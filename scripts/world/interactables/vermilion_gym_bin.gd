extends WorldInteractable

@export var bin_coordinates := Vector2i.ZERO

@onready var puzzle: Node = get_node("../../..")


func _ready() -> void:
	super._ready()
	puzzle.puzzle_changed.connect(queue_redraw)


func interact_with_player(_player: Node2D) -> void:
	var result: String = puzzle.activate_bin(bin_coordinates)
	var lines: Array[String] = [LocalizationManager.text("world.vermilion_gym.puzzle." + result)]
	await show_dialogue(lines, LocalizationManager.text("world.vermilion_gym.puzzle.bin"))


func _draw() -> void:
	if puzzle == null:
		return
	var is_first: bool = bin_coordinates == puzzle.first_switch and puzzle.first_switch_active
	var is_second: bool = bin_coordinates == puzzle.second_switch and puzzle.puzzle_solved
	if is_first or is_second:
		# A small lit switch on the bin's front keeps the found position readable.
		draw_rect(Rect2(-5, -5, 10, 6), Color("173b38"))
		draw_rect(Rect2(-3, -4, 6, 3), Color("88ffb3"))
