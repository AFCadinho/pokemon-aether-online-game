extends WorldInteractable

@export var opens_with_first_switch := false

var animation_time := 0.0
@onready var puzzle: Node = get_node("../../..")


func _ready() -> void:
	super._ready()
	puzzle.puzzle_changed.connect(_refresh_state)
	_refresh_state()


func _process(delta: float) -> void:
	super._process(delta)
	if blocks_movement:
		animation_time += delta
		queue_redraw()


func _can_start_manual_interaction() -> bool:
	return blocks_movement and super._can_start_manual_interaction()


func interact_with_player(_player: Node2D) -> void:
	if blocks_movement:
		var lines: Array[String] = [LocalizationManager.text("world.vermilion_gym.puzzle.barrier_closed")]
		await show_dialogue(lines, LocalizationManager.text("world.vermilion_gym.puzzle.barrier"))


func _refresh_state() -> void:
	blocks_movement = not (puzzle.puzzle_solved or (opens_with_first_switch and puzzle.first_switch_active))
	visible = blocks_movement
	queue_redraw()


func _draw() -> void:
	if not blocks_movement:
		return
	# Connect the existing emitters, with a faint field and flickering arcs.
	draw_rect(Rect2(-96, -12, 192, 24), Color(0.25, 0.65, 1.0, 0.12))
	for arc in range(2):
		var points := PackedVector2Array()
		for step in range(17):
			var x := -96.0 + step * 12.0
			var y := (-4.0 if arc == 0 else 4.0)
			if step > 0 and step < 16:
				y += sin(step * 2.7 + floor(animation_time * 12.0) * 1.9 + arc) * 6.0
			points.append(Vector2(x, y))
		draw_polyline(points, Color(0.2, 0.6, 1.0, 0.25), 9.0, true)
		draw_polyline(points, Color("62caff"), 3.0, true)
		draw_polyline(points, Color("e8fbff"), 1.0, true)
