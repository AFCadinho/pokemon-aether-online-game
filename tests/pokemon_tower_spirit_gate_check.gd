extends SceneTree

const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"
const Blockers := preload("res://scripts/world/map_character_blocking.gd")

class FakeFloorMask extends Node2D:
	var active_floor: StringName = &"floor_6"
	func show_floor(value: StringName) -> void:
		active_floor = value

class FakeDialogueBox extends Node:
	signal dialogue_finished
	var turns: Array[Dictionary] = []
	func start_dialogue(lines: Array[String], speaker: String, portrait: Texture2D = null, portrait_visible := false) -> void:
		turns.append({"lines": lines, "speaker": speaker, "portrait": portrait, "portrait_visible": portrait_visible})
		dialogue_finished.emit.call_deferred()

var failed := false
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var auth := root.get_node("AuthService")
	var inventory := root.get_node("InventoryService")
	var save := root.get_node("PlayerSave")
	var state := root.get_node("GameState")
	var old_user: Dictionary = auth.current_user.duplicate(true)
	var old_items: Array = inventory.cached_inventory_items.duplicate(true)
	var old_owner: int = inventory.cached_inventory_user_id
	var old_name: String = save.player_name
	var old_position: Vector2 = state.player_position
	var old_has_position: bool = state.has_player_position
	auth.current_user = {"id": 8001}
	inventory.cached_inventory_user_id = 8001
	inventory.cached_inventory_items = []
	save.player_name = "Spirit Tester"
	var tower := (load(TOWER) as PackedScene).instantiate()
	var placed_gate := tower.get_node("Entities/Interactables/RestlessSpirit")
	var placed_stair := tower.get_node("FloorTransitions/Floor6To7")
	_check(placed_gate.position == placed_stair.position + Vector2(32, 0), "Spirit blocks the tile one step before the 6F stair")
	_check(placed_stair.get_node(placed_stair.passage_gate_path) == placed_gate, "The stair independently checks the spirit gate")
	_check(placed_gate.find_children("*", "Sprite2D", true, false).is_empty() and placed_gate.find_children("*", "AnimatedSprite2D", true, false).is_empty(), "Spirit has no visible Pokémon artwork")
	var source_position: Vector2 = placed_gate.position
	var destination: Vector2 = tower.get_node("Spawns/Floor7From6").position
	tower.free()

	# Exercise the production stair and ghost dialogue without starting a live map's NPC requests.
	var world := Node.new()
	root.add_child(world)
	current_scene = world
	var holder := Node.new()
	holder.name = "DialogueBox"
	world.add_child(holder)
	var box := FakeDialogueBox.new()
	box.name = "Box"
	holder.add_child(box)
	var map := Node2D.new()
	map.name = "Map"
	world.add_child(map)
	var actors := Node2D.new()
	actors.name = "Entities"
	map.add_child(actors)
	var interactables := Node2D.new()
	interactables.name = "Interactables"
	actors.add_child(interactables)
	var gate := load("res://scripts/world/interactables/pokemon_tower_spirit_gate.gd").new() as Node2D
	gate.name = "RestlessSpirit"
	gate.position = source_position
	interactables.add_child(gate)
	_check(Blockers.is_position_blocked_by_character(map, gate.global_position), "The invisible spirit blocks ordinary player movement")
	_check(not gate.blocks_world_position(gate.global_position + Vector2(32, 0)), "The approach tile remains free")
	var player := Node2D.new()
	player.name = "Player"
	player.position = source_position + Vector2(32, 0)
	actors.add_child(player)
	var stairs := Node2D.new()
	stairs.name = "FloorTransitions"
	map.add_child(stairs)
	var stair := load("res://scripts/world/internal_floor_transition.gd").new() as Area2D
	stair.name = "Floor6To7"
	stair.passage_gate_path = ^"../../Entities/Interactables/RestlessSpirit"
	stair.destination_marker_path = ^"../../Spawns/Floor7From6"
	stair.target_floor = &"floor_7"
	stair.cooldown_seconds = 0.0
	stairs.add_child(stair)
	var mask := FakeFloorMask.new()
	mask.name = "FloorVisibilityMask"
	map.add_child(mask)
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	map.add_child(spawns)
	var landing := Marker2D.new()
	landing.name = "Floor7From6"
	landing.position = destination
	spawns.add_child(landing)
	var start: Vector2 = player.position
	await stair._on_body_entered(player)
	_check(player.position == start and mask.active_floor == &"floor_6", "Approaching the trigger from another direction cannot bypass the missing Scope")
	inventory.cached_inventory_items = [{"itemId": "silph-scope", "quantity": 0}, {"itemId": "old-rod", "quantity": 1}]
	_check(not gate.is_passage_open(), "A different item or a zero-quantity Scope does not unlock 7F")

	var dialogue_service := root.get_node("DialogueMetadataService")
	var locale: String = dialogue_service.call("_get_http_locale")
	var cached_keys: Array[String] = []
	for entry: Dictionary in [
		{"id": "kanto_pokemon_tower_spirit_warning", "speakerName": "???", "lines": ["Go away…"]},
		{"id": "kanto_pokemon_tower_player_scope_needed", "speakerRole": "player", "lines": ["I need a device that can reveal this spirit."]},
	]:
		entry["dialogueId"] = entry.id
		var key: String = dialogue_service.call("_get_cache_key", locale, entry.id)
		cached_keys.append(key)
		dialogue_service.dialogue_metadata_cache[key] = {"success": true, "metadata": entry}
	var old_input: bool = state.input_locked
	await gate.interact_with_player(player)
	_check(box.turns.size() == 2, "Spirit and player each speak without advancing the main quest")
	if box.turns.size() == 2:
		_check(box.turns[0].speaker == "???" and not box.turns[0].portrait_visible, "The unseen spirit speaks without revealing its identity or portrait")
		_check(box.turns[1].speaker == "Spirit Tester" and box.turns[1].portrait != null, "The player's response uses their own name and portrait")
	_check(state.input_locked == old_input, "The dialogue restores input")
	inventory.cached_inventory_items = [{"itemId": "silph-scope", "quantity": 1}]
	_check(gate.is_passage_open() and not gate.blocks_world_position(gate.global_position), "Owning the Scope unlocks both the tile and stair")
	await stair._on_body_entered(player)
	_check(player.position == destination and mask.active_floor == &"floor_7", "The unlocked stair moves the player to 7F")
	inventory.cached_inventory_items = []
	_check(not gate.is_passage_open(), "Removing the Scope closes the gate immediately")
	for key in cached_keys:
		dialogue_service.dialogue_metadata_cache.erase(key)
	auth.current_user = old_user
	inventory.cached_inventory_items = old_items
	inventory.cached_inventory_user_id = old_owner
	save.player_name = old_name
	state.player_position = old_position
	state.has_player_position = old_has_position
	world.queue_free()
	print("pokemon_tower_spirit_gate_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func _check(value: bool, label: String) -> void:
	if value:
		print("PASS ", label)
	else:
		failed = true
		push_error(label)
