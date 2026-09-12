extends Node


class RevealWorld extends "res://scripts/world/world.gd":
	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _exit_tree() -> void:
		pass


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Both reveal tweens finish in one slow frame. The first tween's finished
	# signal has already fired when the overlay resumes its caller, even though
	# that tween can remain valid until the tween processing pass completes.
	Engine.max_fps = 2
	# Attach after tree entry: this unit only needs the reveal method, not the
	# full overworld scene's onready nodes or its startup network requests.
	var world: Variant = Node2D.new()
	add_child(world)
	world.set_script(RevealWorld)
	var battle := Control.new()
	world.add_child(battle)
	world.battle_instance = battle
	var overlay := WildEncounterTransition.new()
	world.add_child(overlay)
	world.wild_encounter_transition = overlay
	overlay.visible = true
	overlay.cover_progress = 1.0
	get_tree().create_timer(5.0).timeout.connect(func():
		push_error("Battle reveal waited on an already completed tween")
		get_tree().quit(1)
	)
	await world._reveal_prepared_wild_battle()
	if overlay.visible or not is_equal_approx(battle.modulate.a, 1.0):
		push_error("Battle reveal did not finish visibly")
		get_tree().quit(1)
		return
	world.free()
	print("battle_reveal_completion_check: PASS")
	get_tree().quit(0)
