extends SceneTree

const WildEncounterTransitionScript := preload("res://scripts/ui/wild_encounter_transition.gd")

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var transition := WildEncounterTransitionScript.new() as WildEncounterTransition
	root.add_child(transition)
	await process_frame
	_check_true(transition.size.x > 0.0 and transition.size.y > 0.0, "encounter transition fills the viewport")

	transition.begin()
	_check_true(transition.visible, "encounter transition becomes visible immediately")
	_check_true(transition.is_processing(), "encounter transition animates while covering")

	await transition.wait_until_covered()
	_check_true(transition.cover_progress >= 0.999, "encounter transition reaches full cover")

	await transition.reveal()
	_check_true(not transition.visible, "encounter transition hides after reveal")
	_check_true(not transition.is_processing(), "encounter transition stops animating after reveal")
	_check_true(transition.cover_progress <= 0.001, "encounter transition fully clears after reveal")

	transition.queue_free()
	quit(1 if failed else 0)


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
