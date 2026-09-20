extends Node

class Presenter extends Node:
	signal released
	var active := true
	var playback_speed := 1.0
	var calls: Array = []
	var delayed := false
	func handles(ident: String) -> bool:
		return active and ident in ["p1", "p2"]
	func attack_action_for(move: String) -> String:
		return "physical_attack" if move == "Outrage" else "special_attack"
	func start_action(actor: String, action: String) -> void:
		calls.append([actor, action])
	func wait_action(_actor: String) -> void:
		if delayed:
			await released
	func cancel_actions() -> void:
		released.emit()

class Router extends BattleAnimationRouter:
	var legacy_reads := 0
	var legacy_plays := 0
	func _get_move_animation_config(_key: String) -> Dictionary:
		legacy_reads += 1
		return {"fixture":true}
	func _get_effect_animation_config(_key: String) -> Dictionary:
		legacy_reads += 1
		return {"fixture":true}
	func _play_animation_config(_config: Dictionary, _target: String = "", _reverse: bool = false, _actor: String = "", _move_target: String = "", _options: Dictionary = {}) -> void:
		legacy_plays += 1

var misses := 0
var completed := false
func _ready() -> void:
	_run.call_deferred()
func _miss() -> void:
	misses += 1
func _cancelled_move(router: Router) -> void:
	await router.play_move_animation("Outrage", "p1", "p2", {"result":"miss","on_dodge_started":_miss})
	completed = true
func _run() -> void:
	SettingsManager.battle_animations = true
	var router := Router.new()
	var presenter := Presenter.new()
	add_child(presenter)
	router.model_presenter = presenter
	await router.play_attack_tween_for_actor("p1", "Outrage")
	await router.play_move_animation("Outrage", "p1", "p2")
	assert(presenter.calls == [["p1", "physical_attack"]], "Start and move phases must not duplicate the attack")
	await router.play_move_animation("Flamethrower", "p2", "p1", {"result":"miss","on_dodge_started":_miss})
	assert(presenter.calls[-1] == ["p2", "special_attack"] and misses == 1)
	await router.play_move_animation("Unknown", "missing", "p2")
	await router.play_effect_animation("stat_up", "p1")
	await router.play_heal_tween_for_target("p1")
	await router.play_stat_change_tween_for_target("p1", 1)
	router.prewarm_move_animations(["Outrage"])
	router.prewarm_effect_animations(["stat_up"])
	assert(router.legacy_reads == 0 and router.legacy_plays == 0, "3D must never load or play sprite catalogs")
	presenter.delayed = true
	_cancelled_move(router)
	assert(not completed)
	router.cancel_render()
	await get_tree().process_frame
	assert(completed and misses == 1, "Cancellation must release waits and suppress stale miss callbacks")
	presenter.active = false
	await router.play_move_animation("Outrage", "p1", "p2")
	await router.play_effect_animation("stat_up", "p1")
	assert(router.legacy_reads == 2 and router.legacy_plays == 2, "Actual 2D fallback retains legacy effects")
	presenter.active = true
	SettingsManager.battle_animations = false
	await router.play_move_animation("Outrage", "p1", "p2", {"result":"miss","on_dodge_started":_miss})
	assert(misses == 2, "Animation preference must preserve the miss callback")
	router.cancel_render()
	presenter.queue_free()
	print("BATTLE_MOVE_PRESENTATION_ROUTES_OK")
	get_tree().quit()
