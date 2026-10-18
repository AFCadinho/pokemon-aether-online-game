extends SceneTree

const LOBBY_SCENE := "res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(LOBBY_SCENE) as PackedScene
	_check(packed != null, "Aether Clash Lobby scene loads")
	if packed == null:
		quit(1)
		return

	var lobby := packed.instantiate()
	root.add_child(lobby)
	await process_frame
	_check(lobby.has_method("get_map_id"), "Lobby exposes overworld map metadata")
	_check(lobby.call("get_map_id") == "aether_clash_lobby", "Lobby has its canonical map id")
	_check(
		lobby.call("get_world_access_area_type") == "exterior",
		"Lobby follows the configured outdoor zoom"
	)
	_check(
		lobby.call("get_music_track_id") == "login.lugia_theme_lofi",
		"Lobby reuses the login-screen music"
	)
	_check(lobby.call("get_lighting_profile") == "outdoor", "Lobby follows the outdoor day/night cycle")
	_check(lobby.call("get_weather_profile") == "disabled", "Lobby always keeps clear magical weather")
	_check(lobby.get_node_or_null("Lobby") != null, "Lobby includes the imported visual")
	var arrival := lobby.get_node_or_null("Spawns/GuildArrival") as Marker2D
	_check(arrival != null, "Lobby has a Guild arrival marker")
	_check(
		arrival != null
		and posmod(int(arrival.position.x), 32) == 16
		and posmod(int(arrival.position.y), 32) == 16,
		"Guild arrival marker is centered on a map tile"
	)
	for vendor_name: String in ["BattlePointVendor", "EvolutionItemVendor", "ZCrystalVendor", "MegaStoneVendor"]:
		_check(not lobby.has_node("Entities/NPCs/" + vendor_name), "Vendor moved to Celadon: " + vendor_name)
	for rental: Array in [["TeamRentalNPC", "team", "Team Rental", Vector2(944, 176)], ["PokemonRentalNPC", "pokemon", "Pokémon Rental", Vector2(1008, 176)]]:
		var vendor := lobby.get_node_or_null("Entities/NPCs/" + str(rental[0]))
		_check(vendor != null, "Rental vendor remains in lobby: " + str(rental[0]))
		if vendor == null:
			continue
		_check(vendor.rental_kind == rental[1] and vendor.display_name == rental[2] and vendor.position == rental[3], "Rental type, name and server position: " + str(rental[0]))
		var shape := vendor.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
		_check(vendor.facing_direction == Vector2.DOWN and vendor.manual_interaction_reach_tiles == 3 and shape.position == Vector2.ZERO and shape.shape is RectangleShape2D and shape.shape.size == Vector2(96, 192) and vendor.get_node("InteractionArea").position == Vector2(0, 64), "Rental interaction reaches across the lobby counter: " + str(rental[0]))
	var night_lights := lobby.get_node_or_null("NightLights")
	_check(night_lights != null, "Lobby owns a hand-maintained night-light layer")
	_check(night_lights != null and night_lights.get_child_count() == 22, "Lobby lanterns and portals have night lights")
	var guild_portal := lobby.get_node_or_null("Entities/Interactables/GuildDuelPortal")
	var royale_portal := lobby.get_node_or_null("Entities/Interactables/BattleRoyalePortal")
	_check(guild_portal != null and guild_portal.position == Vector2(864, 624), "Guild duel portal fills the west portal bay")
	_check(royale_portal != null and royale_portal.position == Vector2(1088, 624), "Battle Royale portal fills the east portal bay")
	_check(guild_portal != null and guild_portal.get("mode_id") == "guild_duel", "West portal represents Guild vs Guild")
	_check(royale_portal != null and royale_portal.get("mode_id") == "battle_royale", "East portal represents Battle Royale")
	var red_portal_sprite := guild_portal.get_node_or_null("PortalSprite") as Sprite2D if guild_portal != null else null
	_check(
		red_portal_sprite != null
		and red_portal_sprite.texture.resource_path.ends_with("clash_portal_red.png"),
		"Guild vs Guild uses the red portal art"
	)
	var purple_portal_sprite := royale_portal.get_node_or_null("PortalSprite") as Sprite2D if royale_portal != null else null
	_check(
		purple_portal_sprite != null
		and purple_portal_sprite.texture.resource_path.ends_with("clash_portal_purple.png"),
		"Battle Royale keeps the purple portal art"
	)
	var lobby_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_lobby.gd")
	var save_index := lobby_source.find('world.call("save_current_player_state_now")')
	var enter_index := lobby_source.find('guild_service.call("enter_aether_clash_portal", challenge_id)')
	var effect_index := lobby_source.find('world.call("play_authorized_teleport_departure_effect")')
	_check(
		save_index >= 0 and enter_index > save_index and effect_index > enter_index,
		"portal entry saves position and waits for server authorization before its teleport effect"
	)
	_check(
		lobby_source.contains("AETHER_CONFIRMATION_DIALOG_SCENE.instantiate()"),
		"multi-session portal selection uses the themed Aether modal"
	)
	var collision := lobby.get_node_or_null("Tiles/Collision") as TileMapLayer
	_check(collision != null and not collision.get_used_cells().is_empty(), "Lobby includes gameplay collision")
	for tile: Vector2i in [Vector2i(29, 5), Vector2i(31, 5), Vector2i(29, 7), Vector2i(31, 7), Vector2i(29, 8), Vector2i(31, 8)]:
		_check(collision.get_cell_source_id(tile) == -1, "Rental counter approach remains walkable: " + str(tile))
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(29, 50)) == -1,
		"Guild arrival tile is walkable"
	)
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(49, 29)) == -1,
		"Battle Point vendor placement tile is available"
	)
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(41, 29)) == -1,
		"Z-Crystal Seller placement tile is available"
	)
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(45, 29)) == -1,
		"Mega Stone Seller placement tile is available"
	)
	for tile: Vector2i in [Vector2i(37, 29), Vector2i(36, 29), Vector2i(35, 29), Vector2i(37, 30)]:
		_check(collision.get_cell_source_id(tile) == -1, "Evolution Item Seller placement or approach tile is walkable: " + str(tile))
	lobby.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
