extends SceneTree

var failed := false

class PosePlayer extends Node2D:
	var style := "default"
	var styles: Array[String] = []

	func get_activity_style() -> String:
		return style

	func set_activity_style(value: String) -> void:
		style = value
		styles.append(value)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var runner := root.get_node("StorySequenceRunner")
	_check(bool(runner.validate_actions([{"type": "player_pose", "durationMs": 1800}]).success), "pose action is accepted")
	for duration in [0, -1, 10001, 0.5, true]:
		_check(not bool(runner.validate_actions([{"type": "player_pose", "durationMs": duration}]).success), "invalid pose duration is rejected")
	var player := PosePlayer.new()
	root.add_child(player)
	var result: Dictionary = await runner.run_sequence([{"type": "player_pose", "durationMs": 1}], player, player)
	_check(bool(result.success), "pose finishes successfully")
	_check(player.styles == ["pickpocket", "default"], "pose reuses thieving visuals and restores the prior style")
	var scene := load("res://scenes/overworld/kanto/towns/ss_anne/ss_anne_3f.tscn") as PackedScene
	var map := scene.instantiate()
	var rose := map.get_node("Entities/NPCs/PopulationTouristSana")
	_check(rose.display_name == "Rose" and rose.portrait_id == "showdown_beauty_gen6", "Rose has a Beauty portrait and her own name")
	_check(rose.get_node("TitanicPoseStoryHook").interaction_id == "kanto_ss_anne_titanic_pose", "Rose starts the server-owned pose interaction")
	map.free()
	player.free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
