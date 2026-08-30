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
	"Guild1ArenaSpawn": Vector2(1456, 176),
	"Guild2ArenaSpawn": Vector2(1072, 4816),
}
const EXPECTED_EXIT_PORTALS := {
	"BlueStagingExitPortal": Vector2(1472, 96),
	"RedStagingExitPortal": Vector2(1056, 4736),
	"Guild1JailExitPortal": Vector2(2240, 2368),
	"Guild2JailExitPortal": Vector2(2240, 2624),
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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
	var barrier := duel.get_node_or_null("StartBarrier") as Node2D
	_check(barrier != null, "Duel exposes its temporary center barrier")
	_check(
		barrier != null and barrier.position == Vector2(1280, 2560),
		"Duel barrier divides the north and south halves"
	)
	var barrier_collision := duel.get_node_or_null(
		"StartBarrier/BarrierBody/CollisionShape2D"
	) as CollisionShape2D
	var barrier_shape := barrier_collision.shape as RectangleShape2D if barrier_collision != null else null
	_check(
		barrier_shape != null and barrier_shape.size == Vector2(2560, 48),
		"Duel barrier collision spans the complete map width"
	)
	_check(duel.get_node_or_null("ArenaHud") != null, "Duel owns its dedicated match HUD")
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
	for portal_name: String in EXPECTED_EXIT_PORTALS:
		var portal := duel.get_node_or_null("Entities/Interactables/%s" % portal_name) as Node2D
		_check(portal != null, "Duel exposes %s" % portal_name)
		if portal == null:
			continue
		_check(portal.position == EXPECTED_EXIT_PORTALS[portal_name], "%s is at its editable arena location" % portal_name)
		_check(str(portal.get("mode_id")) == "guild_duel", "%s uses Guild Duel mode" % portal_name)
		_check(str(portal.get("portal_action")) == "exit", "%s is an arena exit" % portal_name)
		_check(bool(portal.get("entry_open")), "%s remains interactable throughout the Duel" % portal_name)
		_check(
			not portal.z_as_relative
			and portal.z_index == clampi(floori(portal.global_position.y), -4096, 4096),
			"%s renders on its world-depth layer instead of behind map artwork" % portal_name
		)
		var sprite := portal.get_node_or_null("PortalSprite") as Sprite2D
		_check(
			sprite != null and sprite.texture.resource_path.ends_with("clash_portal_red.png"),
			"%s reuses the red lobby portal art" % portal_name
		)
		var tile := Vector2i(floori(portal.position.x / 32.0), floori(portal.position.y / 32.0))
		_check(
			_has_walkable_portal_approach(collision, tile),
			"%s has a walkable approach through the edited collision" % portal_name
		)
	var duel_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_duel.gd")
	_check(
		duel_source.contains("load_aether_clash_arena_state"),
		"Duel refreshes its server-authoritative arena state"
	)
	_check(
		duel_source.contains("func can_launch_projectile"),
		"Duel exposes its active phase for the later projectile system"
	)
	duel.queue_free()
	quit(1 if failed else 0)


func _has_walkable_portal_approach(collision: TileMapLayer, portal_tile: Vector2i) -> bool:
	if collision == null:
		return false
	# The portal itself blocks movement, so its center may intentionally sit on
	# a solid map tile. Its interaction area extends over the nearby approach.
	for y_offset: int in range(-2, 3):
		for x_offset: int in range(-2, 3):
			if collision.get_cell_source_id(portal_tile + Vector2i(x_offset, y_offset)) == -1:
				return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
