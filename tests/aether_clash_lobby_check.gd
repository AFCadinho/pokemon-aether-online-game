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
	var night_lights := lobby.get_node_or_null("NightLights")
	_check(night_lights != null, "Lobby owns a hand-maintained night-light layer")
	_check(night_lights != null and night_lights.get_child_count() == 22, "Lobby lanterns and portals have night lights")
	var purple_portal := lobby.get_node_or_null("Entities/Interactables/PurpleClashPortal")
	var red_portal := lobby.get_node_or_null("Entities/Interactables/RedClashPortal")
	_check(purple_portal != null and purple_portal.position == Vector2(864, 624), "Purple portal fills the west portal bay")
	_check(red_portal != null and red_portal.position == Vector2(1088, 624), "Red portal fills the east portal bay")
	_check(purple_portal != null and purple_portal.get("team_id") == "purple", "West portal represents purple")
	_check(red_portal != null and red_portal.get("team_id") == "red", "East portal represents red")
	var red_portal_sprite := red_portal.get_node_or_null("PortalSprite") as Sprite2D if red_portal != null else null
	_check(
		red_portal_sprite != null
		and red_portal_sprite.texture.resource_path.ends_with("clash_portal_red.png"),
		"East portal uses the red portal art"
	)
	var collision := lobby.get_node_or_null("Collision") as TileMapLayer
	_check(collision != null and not collision.get_used_cells().is_empty(), "Lobby includes gameplay collision")
	_check(
		collision != null and collision.get_cell_source_id(Vector2i(29, 50)) == -1,
		"Guild arrival tile is walkable"
	)
	lobby.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
