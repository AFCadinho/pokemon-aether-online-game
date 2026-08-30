extends Node2D


const ZONE_SIZE := Vector2(224.0, 224.0)
const NORTH_COLOR := Color("f4c34fff")
const SOUTH_COLOR := Color("70b7ffff")

var phase := "entry_open"
var pulse_elapsed := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 48
	queue_redraw()


func _process(delta: float) -> void:
	pulse_elapsed += delta
	queue_redraw()


func set_phase(next_phase: String) -> void:
	phase = next_phase
	queue_redraw()


func get_zone_rect(side: String) -> Rect2:
	var spawn := _spawn_for_side(side)
	if spawn == null:
		return Rect2()
	return Rect2(spawn.position - ZONE_SIZE * 0.5, ZONE_SIZE)


func get_arena_exit_point(side: String) -> Vector2:
	var spawn := _spawn_for_side(side)
	if spawn == null:
		return Vector2.ZERO
	var direction := Vector2.DOWN if side == "challenger" else Vector2.UP
	return spawn.position + direction * (ZONE_SIZE.y * 0.5 + 16.0)


func _draw() -> void:
	for side: String in ["challenger", "challenged"]:
		var zone := get_zone_rect(side)
		if zone.size == Vector2.ZERO:
			continue
		var color := NORTH_COLOR if side == "challenger" else SOUTH_COLOR
		var pulse := (sin(pulse_elapsed * 3.0) + 1.0) * 0.5
		var fill_alpha := 0.11 + pulse * 0.035
		if phase in ["roster_locked", "active", "finishing"]:
			fill_alpha = 0.075 + pulse * 0.025
		draw_rect(zone, Color(color, fill_alpha), true)
		draw_rect(zone, Color(color, 0.72), false, 3.0)
		var inset := zone.grow(-7.0)
		draw_rect(inset, Color(color, 0.28), false, 1.0)


func _spawn_for_side(side: String) -> Marker2D:
	var spawn_name := "Guild1ArenaSpawn" if side == "challenger" else "Guild2ArenaSpawn"
	return get_parent().get_node_or_null("Spawns/%s" % spawn_name) as Marker2D
