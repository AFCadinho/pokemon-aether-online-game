extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	# Build the route graph from collision, so a bypass cannot silently appear.
	var components: Dictionary = {}
	var adjacency: Dictionary = {}
	for floor_name in ["1f", "b1f"]:
		var map: Node = load("res://scenes/overworld/kanto/caves/rock_tunnel/%s.tscn" % floor_name).instantiate()
		root.add_child(map)
		var collision: TileMapLayer = map.get_node("Tiles/Collision")
		var cells: Dictionary = {}
		var region := 0
		for spawn: Marker2D in map.get_node("Spawns").get_children():
			var start := collision.local_to_map(collision.to_local(spawn.global_position))
			if not cells.has(start):
				region += 1
				var queue: Array[Vector2i] = [start]
				cells[start] = region
				var index := 0
				while index < queue.size():
					var cell := queue[index]
					index += 1
					for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var next := cell + delta
						if not collision.get_used_rect().has_point(next) or cells.has(next) or collision.get_cell_source_id(next) >= 0:
							continue
						cells[next] = region
						queue.append(next)
			var component := "%s:%s" % [floor_name, cells[start]]
			components["%s/%s" % [floor_name, spawn.name]] = component
			adjacency[component] = []
		if floor_name == "1f":
			var visitor: Node2D = map.get_node("Entities/NPCs/FutureSelf")
			_check(not visitor._can_auto_challenge(), "Visitor does not challenge from line of sight")
			_check(not visitor.visible and not visitor.blocks_world_position(map.get_node("Spawns/FromB1FC").global_position), "Hidden visitor leaves the C spawn clear")
			_check(collision.get_cell_source_id(collision.local_to_map(visitor.position)) < 0, "Visitor starts on a walkable tile")
		map.free()
	var north: String = components["1f/FromRoute10North"]
	var south: String = components["1f/FromRoute10South"]
	for stair in ["A", "B", "D"]:
		_connect(adjacency, components["1f/FromB1F%s" % stair], components["b1f/From1F%s" % stair])
	_check(not _reachable(adjacency, north, south), "C staircase cannot be skipped on the north-to-south route")
	_connect(adjacency, components["1f/FromB1FC"], components["b1f/From1FC"])
	_check(_reachable(adjacency, north, south), "Completing the C staircase permits the cave route")
	var hud: Control = load("res://scenes/battle/pokemon_hud_panel.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	var label: Label = hud.active_info_rows[0].get_node("MarginContainer/VBoxContainer/TopRow/HBoxContainer/LevelLabel")
	hud.level_hidden = true
	hud.set_pokemon_data("Charizard", 40, 100, 100)
	_check(label.text.contains("???") and not label.text.contains("40"), "Enemy HUD masks the level")
	hud._on_locale_changed("nl")
	_check(label.text.contains("???"), "Locale refresh preserves the hidden level")
	_check(hud.active_info_rows[0].get_meta("battle_hud_data")["level"] == 40, "Masking preserves the actual battle level")
	hud.level_hidden = false
	hud.set_pokemon_data("Charizard", 40, 100, 100)
	_check(label.text.contains("40"), "Ordinary HUD still displays the level")
	var presenter: RefCounted = load("res://scripts/battle/battle_display_data_presenter.gd").new()
	presenter.opponent_levels_hidden = true
	var data := {"species": "Charizard", "level": 40}
	presenter.setup(load("res://scripts/battle/battle_state.gd").new())
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([data])
	_check(presenter.get_display_team_data("p2")[0].get("level_hidden", false), "Trainer team preview masks the level")
	var enemy: Dictionary = presenter.get_display_pokemon_data("p2", data)
	_check(enemy.get("level_hidden", false) and enemy.level == 40, "Enemy hover metadata masks display only")
	_check(not presenter.get_display_pokemon_data("p1", data).get("level_hidden", false), "Player hover keeps its level")
	var hover: Control = load("res://scripts/battle/battle_ui/party_hover_card.gd").new()
	_check(hover._get_name_and_level(enemy).contains("???"), "Enemy party hover displays question marks")
	var calc: Control = load("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd").new()
	calc.localization_manager = root.get_node("LocalizationManager")
	_check(calc._get_level_label(enemy, true).contains("???"), "Calculator masks the opponent level")
	_check(calc._get_level_label(data).contains("40"), "Calculator preserves ordinary level labels")
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	_check(battle_source.contains('trainer_data.get("_hide_pokemon_level", false)'), "Trainer setup consumes the masked-level policy")
	_check(battle_source.contains('enemy_hud_panel.level_hidden = false'), "New battle setup resets the masked-level policy")
	hover.free()
	calc.free()
	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)
func _connect(graph: Dictionary, a: String, b: String) -> void:
	graph[a].append(b)
	graph[b].append(a)
func _reachable(graph: Dictionary, start: String, target: String) -> bool:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if current == target:
			return true
		for neighbor: String in graph[current]:
			if not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return false
func _check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	failed = failed or not condition
