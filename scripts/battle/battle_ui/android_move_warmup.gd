extends RefCounted
## Bounded VFX samples on the actual battle world. No actor clocks,
## camera overrides, audio, battle commands or recorded move identities.
const Move = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const LIMIT := 8
const BUDGET_MS := 1500
# Only these paths have a checked reset contract. Other moves keep the ordinary factory.
const REUSABLE := ["flamethrower", "thunderbolt", "rockslide", "dracometeor", "tackle"]
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

func take(move: String) -> Node3D:
	var key := Move.move_key(move)
	if busy or not retained.has(key): return null
	var effect: Node3D = retained[key]
	if not is_instance_valid(effect):
		retained.erase(key)
		return null
	if not effect.has_meta("android_prepared_cast"): return null
	retained.erase(key) # Single use: ownership now belongs to the ordinary cast.
	return effect

func _valid(stage: Control, owned: int) -> bool:
	return owned == generation and is_instance_valid(stage) and stage.is_inside_tree() and not stage.preparation_cancelled and not stage.preparation_failed and stage.active

func prepare(stage: Control, available: Array = [], mode := "legacy") -> Dictionary:
	var metrics := {"mode": mode, "elapsed_ms": 0, "effects": 0, "reused": 0, "bounded": false, "samples": [], "complete_keys": []}
	if mode not in ["legacy", "hidden", "covered"]: return metrics
	if busy or not is_instance_valid(stage.world) or not is_instance_valid(stage.camera) or not stage.active:
		return metrics
	busy = true
	for key in retained.keys():
		if not is_instance_valid(retained[key]): retained.erase(key)
	var tree := stage.get_tree()
	var owned := generation
	var started := Time.get_ticks_msec()
	var before: Array = stage._blocking_pipelines()
	var points := {"source": Vector3(-1, 1, 0), "target": Vector3(1, 1, 0), "radius": 0.8,
		"actor_center": Vector3(-1, 1, 0), "actor_radius": 0.8, "actor_ground": Vector3(-1, 0.05, 0),
		"target_ground": Vector3(1, 0.05, 0), "field": {"center": Vector3(0, 0.05, 0), "radius": 5.8}}
	for key in selected_moves(available):
		if not _valid(stage, owned): break
		if mode != "legacy" and key not in REUSABLE: continue
		if Time.get_ticks_msec() - started >= BUDGET_MS:
			metrics.bounded = true
			break
		if retained.has(key) and is_instance_valid(retained[key]):
			metrics.reused += 1
			continue
		if retained.size() == LIMIT: break
		var setup_tick := Time.get_ticks_usec()
		var effect: Node3D = stage.new_move_effect(key)
		effect.visible = mode == "covered"
		# Tag before adding, so the material-response pass never copies VFX.
		effect.set_meta("battle_field_visual", true)
		stage.world.add_child(effect)
		effect.view_camera = stage.camera
		var seconds := maxf(Move.presentation_seconds(key), 1.0)
		var sample := {"seconds": 0.0}
		var timing := {"frames": seconds * 60.0, "launch_frame": seconds * 12.0, "impact_frame": seconds * 36.0}
		var anchors := points.duplicate(true)
		if mode != "legacy" and stage.handles("p1") and stage.handles("p2"):
			timing = stage.move_timing(key, "p1")
			if timing.is_empty() or float(timing.get("frames", 0)) <= 0:
				effect.cancel()
				continue
			anchors = stage._move_anchors("p1", "p2", key)
			seconds = float(timing.frames) / 60.0
		effect.start(key, timing, {"show_impact": true}, func(): return sample.seconds,
			func(): return anchors, func(): return true)
		effect.set_process(false)
		retained[key] = effect
		var setup_ms := (Time.get_ticks_usec() - setup_tick) / 1000.0
		# Sample actual charge/flight/impact variants. Covered samples must draw
		# in the same viewport/pass that will later display the real cast.
		var fractions: Array = [0.08, 0.32, 0.55, 0.63, 0.85]
		if mode != "legacy":
			fractions += [0.46, 0.72, 0.94, minf(.97, effect.launch / seconds + .01), minf(.97, effect.impact / seconds + .01)]
			fractions.sort()
		var complete := true
		var active_samples := 0
		var drawn_samples := 0
		var max_sample_ms := 0.0
		for fraction in fractions:
			if not _valid(stage, owned) or not is_instance_valid(effect):
				complete = false
				break
			sample.seconds = seconds * fraction
			var tick := Time.get_ticks_usec()
			effect._process(0.0)
			max_sample_ms = maxf(max_sample_ms, (Time.get_ticks_usec() - tick) / 1000.0)
			if effect.cursor > 0: active_samples += 1
			await tree.process_frame
			if mode == "covered" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				if _valid(stage, owned) and is_instance_valid(effect) and effect.is_visible_in_tree() and effect.cursor > 0:
					drawn_samples += 1
			if Time.get_ticks_msec() - started >= BUDGET_MS:
				metrics.bounded = true
				complete = false
				break
		if not _valid(stage, owned): break
		if not complete or not is_instance_valid(effect) or effect.done:
			retained.erase(key)
			if is_instance_valid(effect): effect.cancel()
			continue
		metrics.effects += 1
		metrics.complete_keys.append(key)
		metrics.samples.append({"key": key, "instance": effect.get_instance_id(), "active_samples": active_samples,
			"drawn_samples": drawn_samples, "setup_ms": setup_ms, "max_sample_ms": max_sample_ms, "pieces": effect.pieces.size()})
		if mode != "legacy":
			effect.reset_prepared_cast()
			effect.set_meta("android_prepared_cast", key)
	metrics.elapsed_ms = Time.get_ticks_msec() - started
	var after: Array = stage._blocking_pipelines() if is_instance_valid(stage) and stage.is_inside_tree() else before.duplicate()
	for index in after.size(): after[index] -= before[index]
	metrics["pipelines"] = after
	if owned == generation: busy = false
	return metrics
