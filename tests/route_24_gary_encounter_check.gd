extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const GARY_SCRIPT := "res://scripts/world/kanto/routes/route_24_gary.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_SCENE)
	var script_text := FileAccess.get_file_as_string(GARY_SCRIPT)
	_check(
		route_source.contains('[node name="GaryOak" parent="Entities/NPCs" instance=ExtResource("6_trainer")]')
			and route_source.contains("position = Vector2(320, 416)"),
		"Gary waits before Nugget Bridge"
	)
	_check(
		route_source.contains("sight_range_tiles = 3")
			and route_source.contains("facing_direction = Vector2(0, 1)"),
		"Gary starts a mandatory first encounter toward the Cerulean approach"
	)
	_check(
		route_source.contains('npc_id = "kanto_route_24_gary_oak"')
			and not route_source.contains("required_quest_id"),
		"Gary's battle has a stable identity and is independent from story progress"
	)
	_check(
		script_text.contains("PlayerPartyStateService.get_starter_options()")
			and script_text.contains('TRAINER_ID_PREFIX := "kanto_route_24_gary_"'),
		"Gary selects the Route 24 team matching his earlier starter"
	)
	_check(
		script_text.contains("func supports_trainer_rematches() -> bool:")
			and script_text.contains("return false"),
		"Gary's mandatory encounter is completed only once"
	)
	_check(
		script_text.contains("CLEARED_POSITION_OFFSET := Vector2(64, 0)")
			and script_text.contains("_move_clear_of_bridge()"),
		"Gary clears the bridge approach after defeat"
	)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
