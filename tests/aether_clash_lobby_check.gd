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
	_check(lobby.get_node_or_null("Lobby") != null, "Lobby includes the imported visual")
	var arrival := lobby.get_node_or_null("Spawns/GuildArrival") as Marker2D
	_check(arrival != null, "Lobby has a Guild arrival marker")
	_check(arrival != null and arrival.position == Vector2(944, 1616), "Guild arrival uses the intended tile center")
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
