extends Node

const GUIDE_SCENE := "res://scenes/npcs/aether_clash_guide_npc.tscn"
const GUIDE_SCRIPT := "res://scripts/world/npcs/aether_clash_guide_npc.gd"
const LOBBY_SCENE := "res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"
const TOPIC_MENU_SCRIPT := "res://scripts/ui/mentor_topic_menu.gd"
const TILE_SIZE := 32

var failed := false


func _ready() -> void:
	await _run()


func _run() -> void:
	var guide_packed := load(GUIDE_SCENE) as PackedScene
	_check(guide_packed != null, "Aether Clash guide scene loads")
	if guide_packed == null:
		get_tree().quit(1)
		return
	var guide := guide_packed.instantiate()
	add_child(guide)
	await get_tree().process_frame
	var guide_script := guide.get_script() as Script
	var guide_constants := guide_script.get_script_constant_map() if guide_script != null else {}
	var mode_guides := guide_constants.get("MODE_GUIDES", {}) as Dictionary
	var root_topics := guide_constants.get("ROOT_TOPICS", []) as Array
	_check(
		guide_script != null and guide_script.resource_path == GUIDE_SCRIPT,
		"Guide uses its dedicated scalable dialogue controller"
	)
	_check(str(guide.get("display_name")) == "Clash Coordinator", "Guide has a clear lobby role")
	_check(guide.get("npc_sprite_frames") != null, "Guide has an overworld appearance")
	_check(str(guide.get("portrait_id")) == "showdown_acetrainerf_gen6", "Guide has a matching dialogue portrait")
	_check(guide.get("mugshot") != null, "Guide resolves its dialogue portrait from the shared catalog")
	_check(mode_guides.has("guild_duel"), "Guide owns a Guild Duel section")
	_check(mode_guides.has("battle_royale"), "Guide is already structured for Battle Royale")
	_check(root_topics.size() >= 6, "Guide exposes concise categorized questions")
	_check(
		not bool(guide.call("_prefetches_dialogue_metadata_on_approach"))
		and not bool(guide.call("_loads_pickpocket_profile_from_npc_metadata")),
		"Local guide dialogue and thieving behavior never request server NPC metadata"
	)
	var nearby_player := Node2D.new()
	nearby_player.name = "Player"
	add_child(nearby_player)
	guide.set("player_nearby", true)
	guide.set("nearby_player", nearby_player)
	await guide.call("_prefetch_nearby_npc_content")
	_check(
		not bool(guide.get("npc_metadata_loaded"))
		and not bool(guide.get("npc_metadata_load_failed")),
		"Approaching the guide skips the NPC metadata request entirely"
	)
	nearby_player.queue_free()
	var localized_topics: Array = guide.call("_localized_topics", root_topics)
	_check(
		localized_topics.size() == root_topics.size()
		and not str((localized_topics[0] as Dictionary).get("label", "")).begins_with("npc."),
		"Guide resolves localized menu labels at interaction time"
	)
	guide.queue_free()

	var lobby_packed := load(LOBBY_SCENE) as PackedScene
	_check(lobby_packed != null, "Aether Clash Lobby still loads with its guide")
	if lobby_packed == null:
		get_tree().quit(1)
		return
	var lobby := lobby_packed.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var placed_guide := lobby.get_node_or_null("Entities/NPCs/ClashCoordinator") as Node2D
	_check(placed_guide != null, "Lobby places the Clash Coordinator")
	if placed_guide != null:
		_check(placed_guide.position == Vector2(784, 1360), "Guide stays beside the main route instead of crowding the portals")
		_check(
			posmod(int(placed_guide.position.x), TILE_SIZE) == 16
			and posmod(int(placed_guide.position.y), TILE_SIZE) == 16,
			"Guide placement is centered on a map tile"
		)
		var duel_portal := lobby.get_node_or_null("Entities/Interactables/GuildDuelPortal") as Node2D
		var royale_portal := lobby.get_node_or_null("Entities/Interactables/BattleRoyalePortal") as Node2D
		_check(
			duel_portal != null
			and royale_portal != null
			and placed_guide.position.distance_to(duel_portal.position) > 500.0
			and placed_guide.position.distance_to(royale_portal.position) > 500.0,
			"Guide leaves generous space around both portals"
		)
		var collision := lobby.get_node_or_null("Collision") as TileMapLayer
		var guide_tile := Vector2i(
			int(placed_guide.position.x) / TILE_SIZE,
			int(placed_guide.position.y) / TILE_SIZE
		)
		_check(
			collision != null and collision.get_cell_source_id(guide_tile) == -1,
			"Guide stands on a walkable lobby tile"
		)
		var reachable := false
		if collision != null:
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if collision.get_cell_source_id(guide_tile + direction) == -1:
					reachable = true
					break
		_check(reachable, "Players can reach the guide from an adjacent tile")
	lobby.queue_free()

	var guide_source := FileAccess.get_file_as_string(GUIDE_SCRIPT)
	_check(
		guide_source.contains("const MODE_GUIDES")
		and guide_source.contains("func _show_mode_guide(mode_id: String)"),
		"Additional Aether Clash variants can reuse the mode guide flow"
	)
	_check(
		guide_source.contains("MENTOR_TOPIC_MENU")
		and guide_source.contains("await menu.choose_topic("),
		"Guide uses the established themed question menu"
	)
	_check(
		guide_source.contains("\t\t2,\n\t\ttrue\n\t)")
		and guide_source.contains("\t\t\t2,\n\t\t\ttrue\n\t\t)"),
		"Root and mode questions request the compact two-column layout"
	)
	var topic_menu_script := load(TOPIC_MENU_SCRIPT) as GDScript
	var topic_menu := topic_menu_script.new() as CanvasLayer if topic_menu_script != null else null
	_check(topic_menu != null, "Shared mentor topic menu still loads")
	if topic_menu != null:
		add_child(topic_menu)
		topic_menu.call(
			"_build_menu",
			"Aether Clash",
			"What would you like to know?",
			localized_topics,
			"CLASH GUIDE",
			"Close",
			2,
			true
		)
		await get_tree().process_frame
		var topic_grid := topic_menu.find_child("TopicGrid", true, false) as GridContainer
		var topic_panel := topic_menu.find_child("TopicPanel", true, false) as PanelContainer
		_check(topic_grid != null and topic_grid.columns == 2, "Compact guide questions render in two columns")
		_check(topic_grid != null and topic_grid.get_child_count() == root_topics.size(), "Compact grid contains every guide question")
		_check(topic_panel != null and topic_panel.size.y < 360.0, "Compact guide menu leaves most of the screen visible")
		if topic_grid != null and topic_grid.get_child_count() > 0:
			var first_button := topic_grid.get_child(0) as Button
			_check(first_button != null and first_button.custom_minimum_size.y == 38.0, "Compact guide buttons use the reduced height")
		topic_menu.queue_free()
	var key_pattern := RegEx.new()
	key_pattern.compile('"(npc\\.aether_clash_guide\\.[^"]+)"')
	var required_keys: Dictionary = {}
	for key_match: RegExMatch in key_pattern.search_all(guide_source):
		required_keys[key_match.get_string(1)] = true
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		var catalog := parsed as Dictionary if parsed is Dictionary else {}
		var missing_keys: Array[String] = []
		for key_value: Variant in required_keys.keys():
			var key := str(key_value)
			if not catalog.has(key) or str(catalog.get(key, "")).strip_edges().is_empty():
				missing_keys.append(key)
		_check(
			missing_keys.is_empty(),
			"%s contains every localized Clash Coordinator line" % locale
		)
	get_tree().quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
