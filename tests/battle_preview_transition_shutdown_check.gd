extends SceneTree

var failures := 0
var completed := false
var drawn_frames := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.frame_post_draw.connect(func(): drawn_frames += 1)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var team: Array = []
	for species: String in ["Pikachu", "Bulbasaur", "Charmander", "Squirtle", "Eevee", "Snorlax"]:
		team.append({"species": species})
	battle.player_team_preview_layer.show_team(team, "player")
	battle.enemy_team_preview_layer.show_team(team, "enemy")
	var pokemon := Pokemon.new("Pikachu", 5)
	var held: WeakRef = weakref(pokemon)
	_hold_through_transition(pokemon, battle, drawn_frames)
	pokemon = null
	_check(not battle.player_team_preview_layer.visible and not battle.enemy_team_preview_layer.visible,
		"Transition clears both preview layers immediately")
	for _frame in range(10):
		await process_frame
	_check(completed, "Preview transition completes with the current display driver")
	_check(held.get_ref() == null, "Completed transition releases its held Pokemon")
	_check(not battle.player_team_preview_layer.visible and not battle.enemy_team_preview_layer.visible,
		"Preview layers stay cleared after the presentation barrier")
	battle.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)


func _hold_through_transition(pokemon: Pokemon, battle: Node, previous_drawn_frames: int) -> void:
	await battle._prepare_team_preview_lead_summon_transition()
	_check(pokemon != null, "Transition retains its Pokemon only while running")
	if DisplayServer.get_name() != "headless":
		_check(drawn_frames > previous_drawn_frames, "Rendered client retains the real post-draw barrier")
	completed = true


func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
