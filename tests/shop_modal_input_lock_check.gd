extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := root.get_node("GameState")
	state.clear_world_runtime_state()
	var overlay = load("res://scripts/ui/ui_overlay.gd").new()
	var host := Control.new()
	root.add_child(host)
	overlay.root_control = host
	var player = load("res://scripts/world/player.gd").new()
	var npc = load("res://scripts/world/npcs/base_npc.gd").new()
	npc.player_nearby = true
	npc.nearby_player = player
	npc.story_visibility_active = true
	# Use the real popup opening path and reproduce the NPC-to-shop handoff.
	for market_id: String in ["standard_pokemart", "evolution_item_shop", "mega_stone_shop", "z_crystal_shop", "battle_point_exchange"]:
		for mode: String in (["player_buys", "player_sells"] if market_id == "standard_pokemart" else ["player_buys"]):
			state.lock_overworld_input()
			overlay.open_market({"id": market_id, "items": []}, mode)
			state.unlock_overworld_input()
			_check(state.is_overworld_input_locked(), market_id + ": " + mode + " survives NPC completion")
			_check(state.is_overworld_input_locked() and not player._can_accept_movement_input(), "open shop rejects movement input")
			Input.action_press("interact")
			_check(state.is_overworld_input_locked() and not npc._can_start_manual_interaction(), "open shop rejects another NPC interaction")
			Input.action_release("interact")
			_check(not state.is_ui_input_locked(), "shop controls remain usable")
			overlay._hide_market_popup()
			_check(not state.is_overworld_input_locked(), "closing the shop restores overworld input")

	# Other storefronts all activate through the same panel tracker.
	var second_panel := PanelContainer.new()
	host.add_child(second_panel)
	for storefront: String in ["Gift Store", "Guild shop", "Aether Exchange", "Aether Atelier"]:
		state.lock_overworld_input()
		overlay._activate_ui_panel(second_panel)
		state.unlock_overworld_input()
		_check(state.is_overworld_input_locked(), storefront + " survives an unrelated interaction unlock")
		second_panel.hide()
		_check(not state.is_overworld_input_locked(), storefront + " releases on hide")
		second_panel.show()

	overlay.open_market({"items": []})
	overlay._activate_ui_panel(second_panel)
	overlay._hide_market_popup()
	_check(state.is_overworld_input_locked(), "closing one of two windows retains the modal lock")
	state.acquire_overworld_input_lock(&"story_sequence")
	second_panel.hide()
	_check(state.is_overworld_input_locked(), "closing the last window preserves a story lock")
	state.release_overworld_input_lock(&"story_sequence")
	_check(not state.is_overworld_input_locked(), "story owner releases its own lock")
	second_panel.show()
	overlay._activate_ui_panel(second_panel)
	second_panel.free()
	_check(not state.is_overworld_input_locked(), "destroying an open panel releases its modal lock")

	var staff_panel := PanelContainer.new()
	host.add_child(staff_panel)
	overlay.staff_teleport_popup = staff_panel
	overlay._activate_ui_panel(staff_panel)
	_check(overlay._can_ignore_staff_teleporter_overworld_lock(), "staff teleporter may bypass only its own window lock")
	state.acquire_overworld_input_lock(&"story_sequence")
	_check(not overlay._can_ignore_staff_teleporter_overworld_lock(), "staff teleporter cannot bypass another scoped lock")
	state.release_overworld_input_lock(&"story_sequence")
	overlay._exit_tree()
	_check(not state.is_overworld_input_locked(), "overlay teardown releases its modal lock")
	staff_panel.hide()

	player.free()
	npc.free()
	host.free()
	overlay.free()
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
