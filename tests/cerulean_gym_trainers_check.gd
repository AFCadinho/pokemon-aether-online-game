extends SceneTree

const GYM_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn"
const PortraitCatalogScript := preload("res://scripts/services/trainer_portrait_catalog.gd")

const TRAINERS := {
	"Entities/NPCs/SwimmerLuis": {
		"trainer_id": "kanto_cerulean_city_gym_swimmer_luis",
		"definition_id": "trainer_class_swimmer_m",
		"position": Vector2(624, 496),
		"facing": Vector2.RIGHT,
		"sight_range": 5,
		"terrain": "water",
		"portrait": "showdown_swimmer_gen6",
	},
	"Entities/NPCs/PicnickerDiana": {
		"trainer_id": "kanto_cerulean_city_gym_picnicker_diana",
		"definition_id": "trainer_class_picnicker",
		"position": Vector2(560, 656),
		"facing": Vector2.LEFT,
		"sight_range": 5,
		"terrain": "land",
		"portrait": "showdown_picnicker_gen6",
	},
	"Entities/NPCs/SwimmerBriana": {
		"trainer_id": "kanto_cerulean_city_gym_swimmer_briana",
		"definition_id": "trainer_class_swimmer_f",
		"position": Vector2(432, 880),
		"facing": Vector2.RIGHT,
		"sight_range": 3,
		"terrain": "water",
		"portrait": "showdown_swimmerf_gen6",
	},
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gym: Node = load(GYM_SCENE).instantiate()
	root.add_child(gym)
	await process_frame
	var collision := gym.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := gym.find_map_tilemap_layer("Water") as TileMapLayer
	_check(collision != null, "Cerulean Gym exposes its collision layer")
	_check(water != null, "Cerulean Gym exposes its water layer")
	var catalog := PortraitCatalogScript.new()
	root.add_child(catalog)
	for node_path: String in TRAINERS:
		var expected: Dictionary = TRAINERS[node_path]
		var trainer := gym.get_node_or_null(node_path)
		_check(trainer != null, "%s is placed in Cerulean Gym" % node_path)
		if trainer == null:
			continue
		_check(str(trainer.get("trainer_id")) == expected.trainer_id, "%s uses its registered battle" % node_path)
		_check(str(trainer.get("npc_id")) == expected.trainer_id, "%s keeps a stable NPC identity" % node_path)
		_check(str(trainer.get("npc_definition_id")) == expected.definition_id, "%s uses the matching Trainer class" % node_path)
		_check(trainer.position == expected.position, "%s stands on its intended tile" % node_path)
		_check(trainer.get("facing_direction") == expected.facing, "%s faces the approaching player" % node_path)
		_check(
			int(trainer.get("sight_range_tiles")) == expected.sight_range,
			"%s uses its designed sight range" % node_path
		)
		_check(str(trainer.get("battle_environment_id")) == "water", "%s battles in the water arena" % node_path)
		if collision != null and water != null:
			var cell := collision.local_to_map(trainer.position)
			var is_water_bound: bool = expected.terrain == "water"
			_check(
				water.get_cell_source_id(cell) >= 0 if is_water_bound else water.get_cell_source_id(cell) < 0,
				"%s occupies its intended terrain" % node_path
			)
			if not is_water_bound:
				_check(collision.get_cell_source_id(cell) < 0, "%s occupies a walkable tile" % node_path)
			var direction := Vector2i(expected.facing)
			var reachable_sight_cell := Vector2i(-1, -1)
			for distance: int in range(1, expected.sight_range + 1):
				var sight_cell := cell + direction * distance
				if collision.get_cell_source_id(sight_cell) < 0 and water.get_cell_source_id(sight_cell) < 0:
					reachable_sight_cell = sight_cell
					break
			_check(reachable_sight_cell != Vector2i(-1, -1), "%s can spot a player on land" % node_path)
			if is_water_bound:
				_check(
					trainer.get_script().resource_path == "res://scripts/world/npcs/water_bound_trainer.gd",
					"%s uses water-bound trainer logic" % node_path
				)
				var original_position: Vector2 = trainer.global_position
				var mock_player := Node2D.new()
				gym.add_child(mock_player)
				mock_player.global_position = collision.to_global(collision.map_to_local(reachable_sight_cell))
				trainer.walk_to_player(mock_player)
				_check(trainer.global_position == original_position, "%s never leaves the water to approach a player" % node_path)
				mock_player.queue_free()
		_check(
			catalog.resolve_portrait_id("", expected.trainer_id, expected.definition_id) == expected.portrait,
			"%s resolves the matching battle portrait" % node_path
		)
	catalog.queue_free()
	gym.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
