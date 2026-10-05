extends RefCounted
## Realtime move presentation only. No sprite catalogs, gameplay mutations or
## damage application. Future 3D move effects belong here, inside play_move's
## awaited lifetime, and must be released by cancel (including camera overrides).
var generation := 0
var started: Dictionary = {}
var recovery: Dictionary = {}
var effects: Array[Node] = []

func begin_attack(presenter: Node, actor: String, move: String) -> void:
	if not is_instance_valid(presenter) or not presenter.handles(actor):
		return
	started[actor] = move
	if presenter.has_method("start_move_action"):
		presenter.start_move_action(actor, move)
	else:
		presenter.start_action(actor, presenter.attack_action_for(move, actor))

func play_move(presenter: Node, move: String, actor: String, _target: String, options: Dictionary, audio: Node = null, effect: Node = null) -> void:
	var owned_generation := generation
	if is_instance_valid(effect): effects.append(effect)
	if not is_instance_valid(presenter):
		return
	if presenter.handles(actor):
		if not started.has(actor) or started[actor] != move:
			begin_attack(presenter, actor, move)
		var pilot: Dictionary = options.get("native_timing", {})
		if bool(options.get("stop_at_impact", false)) and str(options.get("result", "")).is_empty() and not pilot.is_empty() and presenter.handles(_target):
			await presenter.wait_action_until(actor, float(pilot.impact_frame))
			if owned_generation != generation or not presenter.active:
				return
			recovery = {"actor": actor, "target": _target}
			started.erase(actor)
			return
		await presenter.wait_action(actor)
	while owned_generation == generation and is_instance_valid(effect) and not effect.done:
		await presenter.get_tree().process_frame
	effects = effects.filter(func(live): return is_instance_valid(live) and not live.done)
	# Model-only routes pass no move audio. Optional future native-effect audio
	# stays inside this boundary; pilot recovery joins the ordered damage event.
	while owned_generation == generation and is_instance_valid(audio) and not audio.done:
		await audio.get_tree().process_frame
	if owned_generation != generation or not is_instance_valid(presenter) or not presenter.active:
		return
	started.erase(actor)
	# No sprite dodge in a 3D scene. Preserve the event renderer's miss beat
	# even until a native 3D dodge/effect is available.
	if str(options.get("result", "")).strip_edges().to_lower() == "miss":
		var callback: Callable = options.get("on_dodge_started", Callable())
		if callback.is_valid():
			await callback.call()

func play_effect(_presenter: Node, _effect: String, _target: String) -> void:
	# Unsupported 3D effects intentionally have no visual, never a 2D fallback.
	pass

func cancel() -> void:
	generation += 1
	for effect: Node in effects:
		if is_instance_valid(effect): effect.cancel()
	effects.clear()
	started.clear()
	recovery.clear()

func has_impact_damage(target: String = "") -> bool:
	return not recovery.is_empty() and (target.is_empty() or target.strip_edges().to_lower() == str(recovery.target).strip_edges().to_lower())

func finish_recovery(presenter: Node, target: String = "") -> void:
	if not has_impact_damage(target):
		return
	var actor := str(recovery.actor)
	var owned_generation := generation
	if is_instance_valid(presenter):
		await presenter.wait_action(actor)
	while owned_generation == generation and is_instance_valid(presenter) and not effects.is_empty():
		effects = effects.filter(func(effect): return is_instance_valid(effect) and not effect.done)
		if not effects.is_empty(): await presenter.get_tree().process_frame
	if owned_generation == generation:
		recovery.clear()
