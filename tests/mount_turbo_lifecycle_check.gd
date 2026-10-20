extends SceneTree

const TurboEffect := preload("res://scripts/world/mount_turbo_effect.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for facing: String in ["down", "left", "right", "up"]:
		for delayed: bool in [false, true]:
			await _check_transfer(facing, delayed)
	print("Mount turbo lifecycle: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_transfer(facing: String, delayed: bool) -> void:
	var old_map := Node2D.new()
	var new_map := Node2D.new()
	root.add_child(old_map)
	root.add_child(new_map)
	var actor := Node2D.new()
	old_map.add_child(actor)
	var mount := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	for direction: String in ["down", "left", "right", "up"]:
		frames.add_animation("walk_" + direction)
		frames.add_animation("idle_" + direction)
	mount.sprite_frames = frames
	mount.animation = "walk_" + facing
	actor.add_child(mount)
	var foreground := Node2D.new()
	actor.add_child(foreground)
	var effect := TurboEffect.new()
	foreground.add_child(effect)
	effect.configure({"movementEffect": "zekrom_turbo"}, mount)
	effect.sync_frame(mount)
	effect.advance(0.2)
	var jet := effect.jet
	var sparks := effect.sparks
	_check(effect.active and sparks.emitting, "turbo starts before transfer")

	old_map.remove_child(actor)
	old_map.free()
	if delayed:
		await process_frame
		await process_frame
	new_map.add_child(actor)
	await process_frame
	var intact := is_instance_valid(jet) and is_instance_valid(sparks)
	_check(intact, "transfer retains turbine and sparks: %s delayed=%s" % [facing, delayed])
	if intact:
		_check(effect.jet == jet and not jet.is_queued_for_deletion(), "transfer reuses its live turbine")
		mount.animation = "idle_" + facing
		effect.sync_frame(mount)
		_check(not effect.active and not sparks.emitting and not jet.visible, "arrival clears old exhaust")
		for direction: String in ["down", "left", "right", "up"]:
			mount.animation = "walk_" + direction
			effect.sync_frame(mount)
			effect.advance(0.2)
			_check(effect.active and jet.visible and sparks.emitting, "turbo resumes after transfer")
			_check(jet.get_parent() == (mount if direction == "down" else foreground), "exhaust preserves directional layering")
			_check(jet.show_behind_parent == (direction == "down"), "front body still occludes jet")
		# The jet is outside the effect subtree; deleting its owner must clean it.
		if delayed:
			effect.queue_free()
		else:
			effect.free()
		await process_frame
		_check(not is_instance_valid(jet) and not is_instance_valid(sparks), "deleting effect removes sibling jet and sparks")
	# Whole-avatar teardown also works when the jet is under either sibling.
	var replacement := TurboEffect.new()
	foreground.add_child(replacement)
	replacement.configure({"movementEffect": "zekrom_turbo"}, mount)
	mount.animation = "walk_" + facing
	replacement.sync_frame(mount)
	var final_jet := replacement.jet
	var final_sparks := replacement.sparks
	new_map.free()
	await process_frame
	_check(not is_instance_valid(final_jet) and not is_instance_valid(final_sparks), "avatar teardown frees every effect layer")


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
