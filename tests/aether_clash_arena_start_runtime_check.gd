extends SceneTree


const DUEL_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"
const OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	var original_locale := str(localization_manager.get("current_locale"))
	localization_manager.call("set_locale", "en")
	var packed := load(DUEL_SCENE) as PackedScene
	_check(packed != null, "Aether Clash duel start scene loads")
	if packed == null:
		quit(1)
		return
	var duel := packed.instantiate()
	root.add_child(duel)
	await process_frame

	var barrier = duel.get_node("StartBarrier")
	var collision := duel.get_node(
		"StartBarrier/BarrierBody/CollisionShape2D"
	) as CollisionShape2D
	var visual := duel.get_node("StartBarrier/BarrierVisual") as Node2D
	var hud = duel.get_node("ArenaHud")
	_check(not hud.visible, "Canonical staff preview keeps the match HUD hidden")
	_check(not barrier.is_barrier_raised(), "Canonical staff preview keeps the barrier lowered")

	duel.call("_apply_arena_state", _arena_payload("active", 4, 2))
	await physics_frame
	_check(hud.visible, "Receiving arena state opens the dedicated HUD")
	_check(not barrier.is_barrier_raised(), "Reconnect into an active Clash keeps the barrier down")
	_check(collision.disabled, "Reconnect into an active Clash keeps barrier collision disabled")
	_check(not visual.visible, "Reconnect skips an obsolete lowering animation")
	_check(hud.challenger_name_label.text == "North Stars", "HUD names the north Guild")
	_check(hud.challenged_name_label.text == "South Guard", "HUD names the south Guild")
	_check(hud.challenger_side_label.text == "BLUE SIDE", "HUD identifies the north Guild as Blue Side")
	_check(hud.challenged_side_label.text == "RED SIDE", "HUD identifies the south Guild as Red Side")
	_check(hud.challenger_count_label.text == "4", "HUD shows north active players")
	_check(hud.challenged_count_label.text == "2", "HUD shows south active players")
	_check(hud.countdown_label.text == "FIGHT!", "Active arena HUD shows the fight phase")

	duel.call("_apply_arena_state", _arena_payload("entry_open", 3, 5))
	await physics_frame
	_check(barrier.is_barrier_raised(), "Open entry window raises the center barrier")
	_check(not collision.disabled, "Open entry window blocks players at the center")
	_check(visual.visible, "Open entry window renders the Aether wall")
	_check(hud.challenger_count_label.text == "3", "Countdown HUD shows north arrivals")
	_check(hud.challenged_count_label.text == "5", "Countdown HUD shows south arrivals")
	_check(hud.countdown_label.text.contains(":"), "Countdown HUD shows synchronized time")
	_check(
		bool(duel.call(
			"is_world_barrier_step_blocked",
			Vector2(100, 2544),
			Vector2(100, 2576)
		)),
		"Raised barrier blocks a grid step between Guild halves"
	)
	_check(
		not bool(duel.call(
			"is_world_barrier_step_blocked",
			Vector2(100, 2544),
			Vector2(132, 2544)
		)),
		"Raised barrier still allows movement along a Guild half"
	)
	_check(
		not bool(duel.call(
			"is_world_barrier_step_blocked",
			Vector2(100, 2544),
			Vector2(100, 2512)
		)),
		"Player touching the barrier can move back toward their Guild side"
	)
	var game_state := root.get_node("GameState")
	var original_current_map: Variant = game_state.get("current_map")
	game_state.set("current_map", duel)
	var player_script := load("res://scripts/world/player.gd") as Script
	var player = player_script.new()
	_check(
		bool(player.call(
			"_is_world_barrier_step_blocked",
			Vector2(100, 2544),
			Vector2(100, 2576)
		)),
		"Player grid movement receives the raised map barrier"
	)
	player.free()
	game_state.set("current_map", original_current_map)

	duel.call("_apply_arena_state", _arena_payload("active", 3, 5))
	await physics_frame
	_check(collision.disabled, "Roster lock removes collision immediately")
	_check(not barrier.is_barrier_raised(), "Roster lock marks the barrier as lowered")
	await create_timer(0.8).timeout
	_check(not visual.visible, "Roster lock finishes the visual lowering animation")
	_check(bool(duel.call("is_clash_active")), "Controller exposes the active Clash phase")
	_check(bool(duel.call("can_launch_projectile")), "Active phase is ready for later projectiles")
	_check(
		not bool(duel.call(
			"is_world_barrier_step_blocked",
			Vector2(100, 2544),
			Vector2(100, 2576)
		)),
		"Lowered barrier allows movement between Guild halves"
	)

	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT)
	_check(
		overlay_source.contains('"location", not _is_in_aether_clash_duel()'),
		"Dedicated match HUD replaces the normal location panel in a duel"
	)
	var duel_source := FileAccess.get_file_as_string(
		"res://scripts/world/aether_clash_duel.gd"
	)
	_check(
		not duel_source.contains(": AetherClashStartBarrier")
		and not duel_source.contains(": AetherClashArenaHud"),
		"Duel controller does not depend on a pre-warmed global class cache"
	)
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	_check(
		player_source.contains("_is_world_barrier_step_blocked(global_position"),
		"Grid movement consults the map-owned Aether barrier"
	)

	localization_manager.call("set_locale", original_locale)
	duel.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _arena_payload(status: String, challenger_count: int, challenged_count: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"success": true,
		"serverNow": Time.get_datetime_string_from_unix_time(now, true) + "Z",
		"viewerRole": "participant",
		"viewerSide": "blue",
		"session": {
			"id": "runtime-test",
			"status": status,
			"entryClosesAt": Time.get_datetime_string_from_unix_time(now + 90, true) + "Z",
			"challengerGuild": {"id": 1, "name": "North Stars"},
			"challengedGuild": {"id": 2, "name": "South Guard"},
			"entryCounts": {
				"challenger": challenger_count,
				"challenged": challenged_count,
			},
			"participantCounts": {
				"challenger": challenger_count,
				"challenged": challenged_count,
			},
			"activeCounts": {
				"challenger": challenger_count,
				"challenged": challenged_count,
			},
		},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
