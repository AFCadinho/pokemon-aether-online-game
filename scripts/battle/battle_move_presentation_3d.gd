extends RefCounted
## Realtime move presentation only. No sprite catalogs, gameplay mutations or
## damage application. Future 3D move effects belong here, inside play_move's
## awaited lifetime, and must be released by cancel (including camera overrides).
var generation := 0
var started: Dictionary = {}

func begin_attack(presenter: Node, actor: String, move: String) -> void:
	if not is_instance_valid(presenter) or not presenter.handles(actor):
		return
	started[actor] = move
	presenter.start_action(actor, presenter.attack_action_for(move))

func play_move(presenter: Node, move: String, actor: String, _target: String, options: Dictionary) -> void:
	var owned_generation := generation
	if not is_instance_valid(presenter):
		return
	if presenter.handles(actor):
		if not started.has(actor) or started[actor] != move:
			begin_attack(presenter, actor, move)
		await presenter.wait_action(actor)
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
	started.clear()
