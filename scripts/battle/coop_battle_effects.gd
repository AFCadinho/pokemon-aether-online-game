extends Node

const Router := preload("res://scripts/battle/coop_animation_router.gd")
var routers: Dictionary = {}
var generation := 0
var active_pairs := 0


func cancel() -> void:
	generation += 1
	active_pairs = 0
	for router in routers.values():
		router.cancel_render()
	# Sounds are children of the owned presentation layer, never a global bus.
	for child in get_parent().get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.queue_free()


func _exit_tree() -> void:
	cancel()
	for router in routers.values():
		router.dispose()
	routers.clear()


func bind_pair(actor: String, target: String, cards: Dictionary, audible := true):
	if not cards.has(actor) or not cards.has(target): return null
	var key := actor + ":" + target
	if not routers.has(key): routers[key] = Router.new()
	var router = routers[key]
	var reversed := actor in ["p2", "p4"]
	var player_box: Node = cards[target].sprite if reversed else cards[actor].sprite
	var enemy_box: Node = cards[actor].sprite if reversed else cards[target].sprite
	router.setup(player_box, enemy_box, get_parent(), _allowed)
	router.audible = audible
	router.playback_speed = 1.5
	return router


func _allowed(_source: String, _details: Dictionary) -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


static func move_targets(event: Dictionary, batch: Array) -> Dictionary:
	var targets: Array = event.get("targets", []).duplicate()
	var primary := str(event.get("target", ""))
	if targets.is_empty() and not primary.is_empty(): targets.append(primary)
	var misses: Array = []
	for following: Dictionary in batch:
		if int(following.get("seq", 0)) <= int(event.get("seq", 0)): continue
		if following.get("kind") in ["move", "turn", "switch", "drag", "win", "tie"]: break
		if following.get("kind") == "-miss" and following.get("actor") == event.get("actor"):
			var target := str(following.get("target", ""))
			if not target.is_empty():
				if not targets.has(target): targets.append(target)
				if not misses.has(target): misses.append(target)
	if targets.is_empty(): targets.append(str(event.get("actor", "")))
	return {"targets": targets, "misses": misses}


func play_move(event: Dictionary, batch: Array, cards: Dictionary) -> void:
	if not SettingsManager.battle_animations: return
	var plan := move_targets(event, batch)
	var epoch := generation
	active_pairs = plan.targets.size()
	for index in plan.targets.size():
		var target := str(plan.targets[index])
		_play_pair(event, target, plan.misses.has(target), cards, index == 0, epoch)
	var tree := get_tree()
	var deadline := Time.get_ticks_msec() + 3500
	while epoch == generation and active_pairs > 0 and is_inside_tree():
		if Time.get_ticks_msec() >= deadline:
			cancel()
			break
		await tree.process_frame


func _play_pair(event: Dictionary, target: String, missed: bool, cards: Dictionary, audible: bool, epoch: int) -> void:
	var actor := str(event.get("actor", ""))
	var router = bind_pair(actor, target, cards, audible)
	if router != null:
		var source_alias := "p2" if actor in ["p2", "p4"] else "p1"
		var target_alias := source_alias if actor == target else "p1" if source_alias == "p2" else "p2"
		if router.has_move_animation(str(event.get("move", ""))):
			await router.play_move_animation(str(event.get("move", "")), source_alias, target_alias, {"result": "miss" if missed else "hit"})
		else:
			if audible: await router.play_attack_tween_for_actor(source_alias)
			if missed:
				await router.play_move_animation("", source_alias, target_alias, {"result": "miss"})
	if epoch == generation: active_pairs -= 1


func play_feedback(event: Dictionary, cards: Dictionary) -> void:
	if not SettingsManager.battle_animations: return
	var actor := str(event.get("actor", ""))
	var router = bind_pair(actor, actor, cards)
	if router == null: return
	var alias := "p2" if actor in ["p2", "p4"] else "p1"
	match str(event.get("kind", "")):
		"-damage":
			router.prewarm_common_battle_sounds()
			await router.play_damage_tween_for_target(alias)
		"-heal": await router.play_heal_presentation_for_target(alias)
		"faint": await router.play_faint_tween_for_target(alias)
		"-boost", "-unboost": await router.play_stat_change_presentation_for_target(alias, -1 if event.kind == "-unboost" else 1)
