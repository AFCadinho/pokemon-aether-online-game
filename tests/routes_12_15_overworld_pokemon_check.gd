extends SceneTree

const ROUTES := {
	"res://scenes/overworld/kanto/routes/kanto_route_12.tscn": {
		"Pidgey": ["kanto_route_12_pidgey_1", "pidgey", Vector2(336, 3184), "pace_horizontal", "grass"],
		"Venonat": ["kanto_route_12_venonat_1", "venonat", Vector2(368, 3568), "idle", "grass"],
		"Poliwag": ["kanto_route_12_poliwag_1", "poliwag", Vector2(848, 1104), "pace_horizontal", "water"],
		"Gloom": ["kanto_route_12_gloom_1", "gloom", Vector2(272, 3184), "idle", "grass"],
		"Pidgeotto": ["kanto_route_12_pidgeotto_1", "pidgeotto", Vector2(400, 3184), "idle", "grass"],
		"Bellsprout": ["kanto_route_12_bellsprout_1", "bellsprout", Vector2(240, 3568), "pace_horizontal", "grass"],
		"Weepinbell": ["kanto_route_12_weepinbell_1", "weepinbell", Vector2(304, 3568), "idle", "grass"],
		"Goldeen": ["kanto_route_12_goldeen_1", "goldeen", Vector2(1392, 592), "idle", "water"],
		"Horsea": ["kanto_route_12_horsea_1", "horsea", Vector2(1392, 2192), "idle", "water"],
		"Magikarp": ["kanto_route_12_magikarp_1", "magikarp", Vector2(1392, 3696), "idle", "water"],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_13.tscn": {
		"Oddish": ["kanto_route_13_oddish_1", "oddish", Vector2(976, 752), "pace_horizontal", "grass"],
		"Pidgeotto": ["kanto_route_13_pidgeotto_1", "pidgeotto", Vector2(2352, 176), "pace_horizontal", "grass"],
		"Quagsire": ["kanto_route_13_quagsire_1", "quagsire", Vector2(2896, 272), "pace_vertical", "water"],
		"Venonat": ["kanto_route_13_venonat_1", "venonat", Vector2(176, 464), "idle", "grass"],
		"Bellsprout": ["kanto_route_13_bellsprout_1", "bellsprout", Vector2(2416, 464), "idle", "grass"],
		"Tentacool": ["kanto_route_13_tentacool_1", "tentacool", Vector2(2832, 592), "idle", "water"],
		"Goldeen": ["kanto_route_13_goldeen_1", "goldeen", Vector2(2832, 1040), "idle", "water"],
		"Poliwag": ["kanto_route_13_poliwag_1", "poliwag", Vector2(1680, 1104), "idle", "water"],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_14.tscn": {
		"Pidgey": ["kanto_route_14_pidgey_1", "pidgey", Vector2(432, 208), "pace_horizontal", "grass"],
		"Hoppip": ["kanto_route_14_hoppip_1", "hoppip", Vector2(496, 304), "pace_vertical", "grass"],
		"Venonat": ["kanto_route_14_venonat_1", "venonat", Vector2(400, 400), "pace_vertical", "grass"],
		"Gloom": ["kanto_route_14_gloom_1", "gloom", Vector2(496, 400), "pace_vertical", "grass"],
		"Poliwag": ["kanto_route_14_poliwag_1", "poliwag", Vector2(1232, 464), "idle", "water"],
		"Goldeen": ["kanto_route_14_goldeen_1", "goldeen", Vector2(1232, 976), "idle", "water"],
		"Magikarp": ["kanto_route_14_magikarp_1", "magikarp", Vector2(1232, 1616), "idle", "water"],
		"Psyduck": ["kanto_route_14_psyduck_1", "psyduck", Vector2(1232, 2192), "idle", "water"],
	},
	"res://scenes/overworld/kanto/routes/kanto_route_15.tscn": {
		"Oddish": ["kanto_route_15_oddish_1", "oddish", Vector2(592, 624), "pace_vertical", "grass"],
		"Pidgeotto": ["kanto_route_15_pidgeotto_1", "pidgeotto", Vector2(1904, 720), "pace_horizontal", "grass"],
		"Venonat": ["kanto_route_15_venonat_1", "venonat", Vector2(2960, 432), "pace_vertical", "grass"],
		"Gloom": ["kanto_route_15_gloom_1", "gloom", Vector2(528, 592), "pace_horizontal", "grass"],
		"Pidgey": ["kanto_route_15_pidgey_1", "pidgey", Vector2(656, 656), "pace_vertical", "grass"],
		"Bellsprout": ["kanto_route_15_bellsprout_1", "bellsprout", Vector2(1776, 720), "pace_horizontal", "grass"],
		"Weepinbell": ["kanto_route_15_weepinbell_1", "weepinbell", Vector2(2064, 752), "pace_vertical", "grass"],
		"Venomoth": ["kanto_route_15_venomoth_1", "venomoth", Vector2(3088, 464), "pace_vertical", "grass"],
	},
}
var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ids := {}
	for scene_path: String in ROUTES:
		var route := (load(scene_path) as PackedScene).instantiate()
		var collision := route.get_node("Tiles/Collision") as TileMapLayer
		var grass := route.get_node("Tiles/TallGrass") as TileMapLayer
		var water := route.get_node_or_null("Tiles/Water") as TileMapLayer
		var pokemon_root := route.get_node("Entities/Pokemon")
		var route_expected: Dictionary = ROUTES[scene_path]
		_check(pokemon_root.get_child_count() == route_expected.size(), "%s has the expected overworld Pokemon" % scene_path.get_file())
		for node_name: String in route_expected:
			var expected: Array = route_expected[node_name]
			var pokemon := pokemon_root.get_node_or_null(node_name) as Node2D
			_check(pokemon != null, "%s has %s" % [scene_path.get_file(), node_name])
			if pokemon == null:
				continue
			var pokemon_id := str(pokemon.get("overworld_pokemon_id"))
			_check(pokemon_id == expected[0], "%s uses its registered overworld ID" % node_name)
			_check(not ids.has(pokemon_id), "%s ID is unique across routes" % node_name)
			ids[pokemon_id] = true
			_check(str(pokemon.get("species_id")) == expected[1], "%s uses the local wild species" % node_name)
			_check(pokemon.position == expected[2], "%s is on its authored habitat patch" % node_name)
			_check(str(pokemon.get("movement_behavior")) == expected[3], "%s patrols in its local direction" % node_name)
			_check(str(expected[3]) == "idle" or int(pokemon.get("movement_tiles")) == 1, "%s has the intended movement range" % node_name)
			_check(FollowerSpriteService.get_sprite_frames(expected[1], false) != null, "%s resolves an overworld follower sprite" % node_name)
			var cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			var axis := Vector2i.RIGHT if expected[3] == "pace_horizontal" else Vector2i.DOWN if expected[3] == "pace_vertical" else Vector2i.ZERO if expected[3] == "pace_vertical" else Vector2i.ZERO
			var habitat: TileMapLayer = grass if expected[4] == "grass" else water
			_check(habitat != null, "%s has a habitat tile layer" % node_name)
			if habitat == null:
				continue
			for offset in range(-1, 2):
				var patrol_cell: Vector2i = cell + axis * offset
				_check(collision.get_cell_source_id(patrol_cell) == -1, "%s patrol avoids blocked tiles" % node_name)
				_check(habitat.get_cell_source_id(patrol_cell) >= 0, "%s patrol stays in its local %s" % [node_name, expected[4]])
			for other in route.get_node("Entities/NPCs").get_children():
				var other_cell := collision.local_to_map(collision.to_local(other.global_position))
				_check(other_cell != cell, "%s does not overlap a route trainer" % node_name)
			for pickup in route.get_node("Entities/Interactables").get_children():
				var other_cell := collision.local_to_map(collision.to_local(pickup.global_position))
				_check(other_cell != cell, "%s does not overlap a pickup" % node_name)
		route.free()
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
