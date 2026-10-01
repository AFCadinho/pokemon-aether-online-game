extends SceneTree
## Run with --main-pack to exercise shipped resources, including imported GLBs.
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(2))
	_check(FileAccess.file_exists("res://assets/models/battle/ss_anne_audience/LICENSE.txt"), "CC0 licence is packaged")
	var script = load("res://scripts/battle/arenas/maps/ss_anne/arena.gd")
	if script == null:
		_check(false, "SS Anne arena script loads")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	var builder = script.new(world)
	var arena: Node3D = builder.build()
	world.add_child(arena)
	var audience := arena.get_node("DeckAudience")
	_check(audience.get_child_count() == 6, "six passengers are present")
	for spectator in audience.get_children():
		_check(spectator.has_node("Character/CharacterArmature/Skeleton3D"), "imported character skeleton loads")
		for animation_name in ["Wave", "Idle_Neutral"]:
			_check(spectator.animation_player.has_animation(animation_name), "packed animation " + animation_name)
		spectator.elapsed = 0.0
		spectator._process(0.5)
		_check(spectator.animation_player.current_animation == "Wave", "wave plays")
		spectator._process(4.0)
		_check(spectator.animation_player.current_animation == "Idle_Neutral", "idle plays")
	world.free()
	if not failed:
		print("SS_ANNE_PACKED_RUNTIME_CHECK_OK")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
