extends SceneTree

const ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const SOUND_PATH := "res://assets/battles/animations/common/damage/normaldamage.ogg"
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var router_script = load(ROUTER_PATH)
	var first = router_script.new()
	var second = router_script.new()
	first._request_threaded_resource(SOUND_PATH)
	first._request_threaded_resource(SOUND_PATH)
	second._request_threaded_resource(SOUND_PATH)
	_check(first.threaded_resource_requests.size() == 1, "Duplicate local prewarm retains only one request")
	first.release_threaded_resource_requests()
	_check(ResourceLoader.load_threaded_get_status(SOUND_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"Collecting one router does not steal another router's load token")
	second.release_threaded_resource_requests()
	_check(ResourceLoader.load_threaded_get_status(SOUND_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"Both load owners collect their tokens exactly once")
	_check(first._get_cached_resource(SOUND_PATH) == first.resource_cache[SOUND_PATH],
		"Completed prewarm is reused from the resource cache")
	first._request_threaded_resource(SOUND_PATH)
	_check(first.threaded_resource_requests.is_empty(), "Cached prewarm does not start another threaded request")
	first.clear_move_animation_cache()
	first._request_threaded_resource(SOUND_PATH)
	first.clear_move_animation_cache()
	_check(first.resource_cache.is_empty() and first.threaded_resource_requests.is_empty(),
		"Clearing the cache also collects pending unused requests")
	_check(ResourceLoader.load_threaded_get_status(SOUND_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"Cache reset leaves no orphaned load token")
	first = null
	second = null
	var abandoned = router_script.new()
	abandoned._request_threaded_resource(SOUND_PATH)
	abandoned = null
	_check(ResourceLoader.load_threaded_get_status(SOUND_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"Router destruction collects even a never-played in-progress request")
	var player_save = root.get_node("PlayerSave")
	player_save.replace_party_from_state([{"species": "Pikachu", "level": 5}])
	var settings = root.get_node("SettingsManager")
	var old_animations: bool = settings.battle_animations
	settings.battle_animations = true
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	battle._prepare_battle_setup(1, player_save.party[0], null, &"pvp_stadium")
	_check(not battle.animation_router.threaded_resource_requests.is_empty(), "Real battle preparation starts unused effect prewarming")
	var deadline := Time.get_ticks_msec() + 5000
	while not battle.animation_router.threaded_resource_requests.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(battle.animation_router.threaded_resource_requests.is_empty(), "Battle frames collect finished prewarms without playing their animations")
	_check(not battle.animation_router.resource_cache.is_empty(), "Frame collection keeps warmed resources ready for playback")
	battle.queue_free()
	player_save.party.clear()
	settings.battle_animations = old_animations
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
