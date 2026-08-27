extends SceneTree

const GYM_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn"
const PortraitCatalogScript := preload("res://scripts/services/trainer_portrait_catalog.gd")

const TRAINERS := {
	"Entities/NPCs/SwimmerLuis": {
		"trainer_id": "kanto_cerulean_city_gym_swimmer_luis",
		"definition_id": "trainer_class_swimmer_m",
		"position": Vector2(496, 1008),
		"facing": Vector2.DOWN,
		"portrait": "showdown_swimmer_gen6",
	},
	"Entities/NPCs/PicnickerDiana": {
		"trainer_id": "kanto_cerulean_city_gym_picnicker_diana",
		"definition_id": "trainer_class_picnicker",
		"position": Vector2(720, 592),
		"facing": Vector2.LEFT,
		"portrait": "showdown_picnicker_gen6",
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
		_check(trainer.position == expected.position, "%s stands on its intended bridge" % node_path)
		_check(trainer.get("facing_direction") == expected.facing, "%s faces the approaching player" % node_path)
		_check(int(trainer.get("sight_range_tiles")) == 5, "%s uses the standard five-tile sight range" % node_path)
		_check(str(trainer.get("battle_environment_id")) == "water", "%s battles in the water arena" % node_path)
		if collision != null:
			var cell := collision.local_to_map(trainer.position)
			_check(collision.get_cell_source_id(cell) < 0, "%s occupies a walkable bridge tile" % node_path)
			var direction := Vector2i(expected.facing)
			for distance: int in range(1, int(trainer.get("sight_range_tiles")) + 1):
				var sight_cell := cell + direction * distance
				_check(
					collision.get_cell_source_id(sight_cell) < 0,
					"%s has a clear collision-free sight line at tile %d" % [node_path, distance]
				)
				if water != null:
					_check(
						water.get_cell_source_id(sight_cell) < 0,
						"%s keeps its sight line on the bridge at tile %d" % [node_path, distance]
					)
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
