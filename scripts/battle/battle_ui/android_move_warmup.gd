extends RefCounted
## Bounded hidden VFX samples on the actual battle world. No actor clocks,
## camera overrides, audio, battle commands or recorded move identities.
const Move = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const LIMIT := 8
const BUDGET_MS := 1500
const COMMON := ["tackle", "flamethrower", "thunderbolt"]
var retained := {}
var busy := false
var generation := 0

static func allows(android: bool, experimental: bool, mobile: bool, local_trial := false) -> bool:
	return android and experimental and mobile and local_trial

static func selected_moves(available: Array) -> Array[String]:
	var result: Array[String] = []
	# Own currently available moves take priority; the small common set covers
	# the physical, flame and electric paths measured on the phone.
	for value in available + COMMON:
		var name := str(value.get("id", value.get("name", value.get("move", "")))) if value is Dictionary else str(value)
		var key := Move.move_key(name)
		if Move.supports(key) and not key in result: result.append(key)
		if result.size() == LIMIT: break
	return result

func clear() -> void:
	generation += 1
	for effect in retained.values():
		if is_instance_valid(effect): effect.cancel()
	retained.clear()
	busy = false

func prepare(stage: Control, available: Array = []) -> Dictionary:
	var metrics := {"elapsed_ms": 0, "effects": 0, "reused": 0, "bounded": false}
	if busy or not is_instance_valid(stage.world) or not is_instance_valid(stage.camera) or not stage.active:
		return metrics
	busy = true
	for key in retained.keys():
		if not is_instance_valid(retained[key]): retained.erase(key)
	var owned := generation
	var started := Time.get_ticks_msec()
	var before: Array = stage._blocking_pipelines()
	var points := {"source": Vector3(-1, 1, 0), "target": Vector3(1, 1, 0), "radius": 0.8,
		"actor_center": Vector3(-1, 1, 0), "actor_radius": 0.8, "actor_ground": Vector3(-1, 0.05, 0),
		"target_ground": Vector3(1, 0.05, 0), "field": {"center": Vector3(0, 0.05, 0), "radius": 5.8}}
	for key in selected_moves(available):
		if owned != generation or not is_instance_valid(stage) or not stage.is_inside_tree() or stage.preparation_cancelled or stage.preparation_failed or not stage.active:
			break
		if Time.get_ticks_msec() - started >= BUDGET_MS:
			metrics.bounded = true
			break
		if retained.has(key) and is_instance_valid(retained[key]):
			metrics.reused += 1
			continue
		if retained.size() == LIMIT: break
		var effect: Node3D = stage.new_move_effect(key)
		effect.visible = false
		# Tag before adding, so the material-response pass never copies VFX.
		effect.set_meta("battle_field_visual", true)
		stage.world.add_child(effect)
		effect.view_camera = stage.camera
		var seconds := maxf(Move.presentation_seconds(key), 1.0)
		var sample := {"seconds": 0.0}
		var timing := {"frames": seconds * 60.0, "launch_frame": seconds * 12.0, "impact_frame": seconds * 36.0}
		effect.start(key, timing, {"show_impact": true}, func(): return sample.seconds,
			func(): return points, func(): return true)
		effect.set_process(false)
		retained[key] = effect
		# Geometry and shaders are created lazily by charge, flight and impact.
		# These samples only drive the hidden VFX, never a Pokémon animation.
		for fraction in [0.08, 0.32, 0.55, 0.63, 0.85]:
			if owned != generation or not is_instance_valid(stage) or not stage.is_inside_tree() or stage.preparation_cancelled or not is_instance_valid(effect): break
			sample.seconds = seconds * fraction
			effect._process(0.0)
			await stage.get_tree().process_frame
			if Time.get_ticks_msec() - started >= BUDGET_MS:
				metrics.bounded = true
				break
		metrics.effects += 1
	metrics.elapsed_ms = Time.get_ticks_msec() - started
	var after: Array = stage._blocking_pipelines() if is_instance_valid(stage) and stage.is_inside_tree() else before.duplicate()
	for index in after.size(): after[index] -= before[index]
	metrics["pipelines"] = after
	if owned == generation: busy = false
	return metrics
