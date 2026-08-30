extends SceneTree


const DUEL_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"
const EXPECTED_SPAWNS := [
	"Guild1ArenaSpawn",
	"Guild2ArenaSpawn",
	"Guild1JailSpawn",
	"Guild2JailSpawn",
	"SpectatorJailSpawn",
]
const EXPECTED_ARENA_SPAWN_POSITIONS := {
	"Guild1ArenaSpawn": Vector2(400, 2544),
	"Guild2ArenaSpawn": Vector2(1488, 2544),
}

var failed := false


func _init() -> void:
	var packed := load(DUEL_SCENE) as PackedScene
	_check(packed != null, "Aether Clash duel runtime scene loads")
	if packed == null:
		quit(1)
		return
	var duel := packed.instantiate()
	root.add_child(duel)
	_check(duel.call("get_map_id") == "aether_clash_duel", "Duel exposes its canonical catalog map id")
	duel.call("configure_aether_clash_instance", "aether_clash_duel:test-session")
	_check(
		duel.call("get_map_id") == "aether_clash_duel:test-session",
		"Duel applies an isolated runtime match id"
	)
	var collision := duel.find_child("Collision", true, false) as TileMapLayer
	_check(collision != null, "Duel exposes collision for portal arrivals")
	var distinct_positions := {}
	for spawn_name: String in EXPECTED_SPAWNS:
		var spawn := duel.get_node_or_null("Spawns/%s" % spawn_name) as Marker2D
		_check(spawn != null, "Duel exposes %s" % spawn_name)
		if spawn == null:
			continue
		if EXPECTED_ARENA_SPAWN_POSITIONS.has(spawn_name):
			_check(
				spawn.position == EXPECTED_ARENA_SPAWN_POSITIONS[spawn_name],
				"%s stands before its Guild-side arena portal" % spawn_name
			)
		var tile := Vector2i(floori(spawn.position.x / 32.0), floori(spawn.position.y / 32.0))
		_check(
			collision != null and collision.get_cell_source_id(tile) == -1,
			"%s is on a walkable tile" % spawn_name
		)
		if spawn_name != "SpectatorJailSpawn":
			distinct_positions[spawn.position] = true
	_check(distinct_positions.size() == 4, "Both teams have distinct arena and jail arrivals")
	duel.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
