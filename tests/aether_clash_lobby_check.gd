extends SceneTree

const LOBBY_SCENE := "res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"

var failed := false


func _init() -> void:
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
	var battle_point_vendor := lobby.get_node_or_null("Entities/NPCs/BattlePointVendor")
	_check(battle_point_vendor != null, "Lobby places the Battle Point vendor")
	_check(
		battle_point_vendor != null
		and battle_point_vendor.position == Vector2(1584, 944),
		"Battle Point vendor uses the updated lobby market location"
	)
	var lobby_scene_source := FileAccess.get_file_as_string(LOBBY_SCENE)
	_check(
		lobby_scene_source.contains("res://scenes/npcs/battle_point_vendor_npc.tscn")
		and lobby_scene_source.contains('[node name="BattlePointVendor"'),
		"Lobby placement instantiates the reusable Battle Point vendor scene"
	)
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
	var collision := lobby.get_node_or_null("Collision") as TileMapLayer
	_check(collision != null and not collision.get_used_cells().is_empty(), "Lobby includes gameplay collision")
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(29, 50)) == -1,
		"Guild arrival tile is walkable"
	)
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(49, 29)) == -1,
		"Battle Point vendor placement tile is available"
	)
	lobby.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
