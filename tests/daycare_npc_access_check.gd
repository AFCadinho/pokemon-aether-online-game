extends SceneTree

class CounterPlayer extends CharacterBody2D:
	var last_direction := Vector2.UP

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	var localization := root.get_node("LocalizationManager")
	var original_locale: String = localization.get("current_locale")
	var original_metadata := root.get_node("NpcMetadataService")
	root.remove_child(original_metadata)
	var metadata = load("res://tests/support/fake_npc_metadata_service.gd").new()
	metadata.name = "NpcMetadataService"
	root.add_child(metadata)
	var map = load("res://scenes/overworld/kanto/routes/route5/daycare.tscn").instantiate()
	var merchant = map.get_node("Entities/NPCs/WingMerchant")
	var researcher = map.get_node("Entities/NPCs/AetherResearcher")
	var npcs: Array = [merchant, researcher]
	for npc: Node in npcs:
		npc.get_parent().remove_child(npc)
		npc.owner = null
		root.add_child(npc)
		npc.set_process(false)
		_check(npc.nameplate.visible and not npc.nameplate_label.text.is_empty(), "Nameplate visible on spawn: " + str(npc.name))
	_check(metadata.fetch_count == 0, "Names available before any network metadata request")
	_check(researcher.portrait_id == "showdown_hexmaniac_gen6" and researcher.mugshot != null, "Aether Keeper has an assigned mystical portrait instead of Oak")
	_check(researcher.mugshot.resource_path.ends_with("hexmaniac-gen6.png"), "Keeper dialogue uses the matching portrait texture")
	_check(researcher.npc_sprite_frames.resource_path.ends_with("hex_maniac_frames.tres"), "Keeper uses mystical overworld frames")
	_check(merchant.portrait_id == "showdown_pokemonbreeder_gen4" and merchant.mugshot != null, "Wing Merchant also has a matching portrait instead of Oak")
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.call("set_locale", locale)
		for npc: Node in npcs:
			_check(npc.nameplate.visible and npc.nameplate_label.text == localization.call("text", npc.localized_display_name_key), "Immediate translated name: " + locale + "/" + str(npc.name))
	merchant._apply_npc_metadata({"name": "Catalog name"})
	_check(merchant.nameplate_label.text == "Catalog name", "Server metadata can replace the fallback name")
	localization.call("set_locale", "en")
	_check(merchant.nameplate_label.text == "Wing Merchant", "Locale change restores fallback before new metadata")
	var clerk = load("res://scenes/npcs/market_attendant_npc.tscn").instantiate()
	clerk.display_name = "Custom Clerk"
	clerk.localized_display_name_key = "ui.aethering.merchant"
	root.add_child(clerk)
	clerk.set_process(false)
	clerk._apply_npc_metadata({"name": "Server Clerk"})
	clerk._on_locale_changed("en")
	_check(clerk.nameplate_label.text == "Custom Clerk", "Explicit custom scene names retain their override")
	var front: Vector2 = merchant.position + Vector2(0, 64)
	var collision: TileMapLayer = map.get_node("Tiles/Collision")
	_check(collision.get_cell_source_id(Vector2i(front / 32)) == -1, "Counter front is a walkable floor tile")
	_check(collision.get_cell_source_id(Vector2i((front - Vector2(0, 32)) / 32)) != -1, "Counter blocks the adjacent tile")
	var player := CounterPlayer.new()
	player.name = "Player"
	player.position = front
	# Use the actual player detection shape, keeping the fixture independent of movement/login.
	var player_scene = load("res://scenes/player.tscn").instantiate()
	var detection: CollisionShape2D = player_scene.get_node("DetectionShape").duplicate()
	player.add_child(detection)
	player_scene.free()
	root.add_child(player)
	for _frame in range(5):
		await physics_frame
	_check(merchant.interaction_area.overlaps_body(player), "Real physics detects player across the counter")
	_check(merchant.player_nearby and merchant.nearby_player == player, "Counter player is registered for interaction")
	_check(merchant._is_player_facing_npc(player), "Facing the seller across the counter is accepted")
	await process_frame
	Input.action_press("interact")
	_check(merchant._can_start_manual_interaction(), "Interaction action can start the seller dialogue")
	Input.action_release("interact")
	player.last_direction = Vector2.DOWN
	_check(not merchant._is_player_facing_npc(player), "Facing away cannot interact")
	player.position += Vector2(0, 32)
	player.last_direction = Vector2.UP
	_check(not merchant._is_player_facing_npc(player), "Three tiles away exceeds manual interaction reach")
	metadata.release_fetch.emit()
	await process_frame
	for npc: Node in npcs:
		npc._on_interaction_area_body_exited(player)
		_check(npc.nameplate.visible, "Nameplate stays visible after leaving: " + str(npc.name))
	player.free()
	clerk.free()
	for npc: Node in npcs:
		npc.free()
	map.free()
	root.remove_child(metadata)
	metadata.free()
	root.add_child(original_metadata)
	localization.call("set_locale", original_locale)
	print("DAYCARE NPC ACCESS failures: ", failures)
	quit(1 if failures else 0)
