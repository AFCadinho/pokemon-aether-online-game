extends SceneTree

const EXPECTED := {
	"Magnemite": "magnemite",
	"Voltorb": "voltorb",
	"Pikachu": "pikachu",
	"Magneton": "magneton",
	"Electabuzz": "electabuzz",
	"Spearow": "spearow",
	"Raticate": "raticate",
	"Quagsire": "quagsire",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/overworld/kanto/interiors/power_plant.tscn") as PackedScene
	_check(packed != null, "Power Plant scene loads")
	if packed == null:
		quit(1)
		return
	var map := packed.instantiate()
	var pokemon_root := map.get_node_or_null("Entities/Pokemon")
	var collision := map.get_node_or_null("Tiles/Collision") as TileMapLayer
	_check(pokemon_root != null, "Power Plant has an ambient Pokémon group")
	_check(collision != null, "Power Plant exposes collision data")
	var occupied: Dictionary = {}
	for node_name: String in EXPECTED:
		var pokemon := pokemon_root.get_node_or_null(node_name) as Node2D if pokemon_root != null else null
		_check(pokemon != null, "%s is present" % node_name)
		if pokemon == null or collision == null:
			continue
		_check(str(pokemon.get("species_id")) == EXPECTED[node_name], "%s has the expected species" % node_name)
		_check(not str(pokemon.get("overworld_pokemon_id")).is_empty(), "%s has a metadata id" % node_name)
		_check(FollowerSpriteService.get_sprite_frames(EXPECTED[node_name], false) != null, "%s has a follower sprite" % node_name)
		var cell := collision.local_to_map(collision.to_local(pokemon.global_position))
		_check(collision.get_cell_source_id(cell) == -1, "%s stands on a walkable tile" % node_name)
		_check(not occupied.has(cell), "%s does not overlap another Pokémon" % node_name)
		occupied[cell] = true
		var visual := map.get_node_or_null("Visual")
		if visual != null:
			for node: Node in visual.find_children("*", "TileMapLayer", true, false):
				var layer := node as TileMapLayer
				if layer.name == "Ground":
					continue
				var visual_cell := layer.local_to_map(layer.to_local(pokemon.global_position))
				_check(layer.get_cell_source_id(visual_cell) == -1, "%s avoids decor in %s" % [node_name, layer.name])
	map.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
