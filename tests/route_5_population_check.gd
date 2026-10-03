extends SceneTree

const EXPECTED_POKEMON := {
	"MountainPokemon/Geodude": ["kanto_route_5_mountain_geodude_1", "geodude", Vector2(448, 704)],
	"MountainPokemon/Onix": ["kanto_route_5_mountain_onix_1", "onix", Vector2(704, 736)],
	"DaycareGardenPokemon/Oddish": ["kanto_route_5_daycare_garden_oddish_1", "oddish", Vector2(256, 1024)],
	"DaycareGardenPokemon/Bellsprout": ["kanto_route_5_daycare_garden_bellsprout_1", "bellsprout", Vector2(384, 1056)],
	"RoutePokemon/Pidgey": ["kanto_route_5_pidgey_1", "pidgey", Vector2(384, 752)],
	"RoutePokemon/Meowth": ["kanto_route_5_meowth_1", "meowth", Vector2(992, 1296)],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_5.tscn") as PackedScene).instantiate()
	root.add_child(route)
	await process_frame
	var collision := route.get_node("Tiles/Collision") as TileMapLayer
	var grass := route.get_node("Tiles/TallGrass") as TileMapLayer
	for relative_path: String in EXPECTED_POKEMON:
		var expected: Array = EXPECTED_POKEMON[relative_path]
		var pokemon := route.get_node_or_null("Entities/Pokemon/" + relative_path) as Node2D
		_check(pokemon != null, "%s exists" % relative_path)
		if pokemon == null:
			continue
		_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s has its metadata ID" % relative_path)
		_check(str(pokemon.get("species_id")) == expected[1], "%s has its species" % relative_path)
		_check(pokemon.position == expected[2], "%s is at the intended placement" % relative_path)
		var cell := collision.local_to_map(pokemon.position)
		_check(collision.get_cell_source_id(cell) < 0, "%s stands on walkable ground" % relative_path)
		_check(grass.get_cell_source_id(cell) < 0, "%s stands outside encounter grass" % relative_path)
		for offset in [-1, 1]:
			var patrol_cell := cell + Vector2i(offset, 0)
			_check(collision.get_cell_source_id(patrol_cell) < 0, "%s can complete its one-tile patrol" % relative_path)
	_check(route.get_node_or_null("Entities/NPCs/HikerMilo") != null, "Hiker Milo is present")
	_check(route.get_node_or_null("Entities/NPCs/CamperLena") != null, "Camper Lena is present")
	_check(str(route.get_node("Entities/NPCs/HikerMilo").get("npc_id")) == "kanto_route_5_hiker_milo", "Hiker Milo has a dialogue metadata ID")
	_check(str(route.get_node("Entities/NPCs/CamperLena").get("npc_id")) == "kanto_route_5_camper_lena", "Camper Lena has a dialogue metadata ID")
	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
