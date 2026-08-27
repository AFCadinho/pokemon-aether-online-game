extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const CERULEAN_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const GARY_SCRIPT := "res://scripts/world/kanto/routes/route_24_gary.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_SCENE)
	var cerulean_source := FileAccess.get_file_as_string(CERULEAN_SCENE)
	var script_text := FileAccess.get_file_as_string(GARY_SCRIPT)
	_check(
		not route_source.contains('[node name="GaryOak"'),
		"Gary is no longer placed on the Route 24 placeholder map"
	)
	_check(
		cerulean_source.contains('[node name="GaryOak" parent="Entities/NPCs" instance=ExtResource("21_trainer")]')
			and cerulean_source.contains("position = Vector2(1808, 720)"),
		"Gary waits at the Cerulean entrance to Nugget Bridge"
	)
	_check(
		cerulean_source.contains("sight_range_tiles = 3")
			and cerulean_source.contains("facing_direction = Vector2(0, 1)")
			and script_text.contains("challenge_width_tiles := 6"),
		"Gary guards the complete bridge entrance toward the Cerulean approach"
	)
	_check(
		cerulean_source.contains('npc_id = "kanto_route_24_gary_oak"')
			and not cerulean_source.contains("required_quest_id"),
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
		script_text.contains("_won_in_current_map_visit")
			and script_text.contains("queue_free()")
			and script_text.contains("trainer_progress_state != STATE_FIRST_ENCOUNTER"),
		"Gary disappears on map reload after defeat"
	)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
