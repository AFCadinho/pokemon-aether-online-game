extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const CERULEAN_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const GARY_SCRIPT := "res://scripts/world/kanto/routes/route_24_gary.gd"
const RIVAL_SCRIPT := "res://scripts/world/npcs/rival_trainer_npc.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_source := FileAccess.get_file_as_string(ROUTE_SCENE)
	var cerulean_source := FileAccess.get_file_as_string(CERULEAN_SCENE)
	var script_text := FileAccess.get_file_as_string(GARY_SCRIPT)
	var rival_text := FileAccess.get_file_as_string(RIVAL_SCRIPT)
	var gary_start := cerulean_source.find('[node name="GaryOak"')
	var gary_end := cerulean_source.find("\n[node ", gary_start + 1)
	var gary_block := cerulean_source.substr(gary_start, gary_end - gary_start)
	_check(
		not route_source.contains('[node name="GaryOak"'),
		"Gary is no longer placed on the Route 24 placeholder map"
	)
	_check(
		cerulean_source.contains('[node name="GaryOak" parent="Entities/NPCs"')
			and cerulean_source.contains('instance=ExtResource("21_trainer")]')
			and cerulean_source.contains("position = Vector2(1808, 720)"),
		"Gary waits at the Cerulean entrance to Nugget Bridge"
	)
	_check(
		cerulean_source.contains("sight_range_tiles = 3")
			and script_text.contains("challenge_width_tiles := 6"),
		"Gary guards the complete bridge entrance toward the Cerulean approach"
	)
	_check(
		gary_block.contains('npc_id = "kanto_route_24_gary_oak"')
			and not gary_block.contains("required_quest_id"),
		"Gary's battle has a stable identity and is independent from story progress"
	)
	_check(
		rival_text.contains("PlayerPartyStateService.get_starter_options()")
			and script_text.contains('rival_encounter_id = "kanto_route_24_gary"'),
		"Gary selects the Route 24 team matching his earlier starter"
	)
	_check(
		script_text.contains('extends "res://scripts/world/npcs/rival_trainer_npc.gd"')
			and rival_text.contains('progress.get("rematchEligible", false)'),
		"Gary uses the shared controller and server-owned rematch policy"
	)
	_check(
		rival_text.contains("_won_in_current_map_visit")
			and rival_text.contains("queue_free()")
			and rival_text.contains("trainer_progress_state != STATE_FIRST_ENCOUNTER"),
		"Gary disappears on map reload after defeat"
	)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
