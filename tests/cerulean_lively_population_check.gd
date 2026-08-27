extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const JENNY_TEXTURE := "res://assets/npcs/classes/officer_jenny.png"
const JENNY_FRAMES := "res://assets/npcs/classes/officer_jenny_frames.tres"

const WATER_POKEMON := {
	"Entities/Pokemon/WaterPokemon/Gyarados": "pace_horizontal",
	"Entities/Pokemon/WaterPokemon/Goldeen": "pace_horizontal",
	"Entities/Pokemon/WaterPokemon/Poliwag": "pace_vertical",
}

const MOUNTAIN_POKEMON := {
	"Entities/Pokemon/MountainPokemon/Geodude": "geodude",
	"Entities/Pokemon/MountainPokemon/Nosepass": "nosepass",
	"Entities/Pokemon/MountainPokemon/Roggenrola": "roggenrola",
	"Entities/Pokemon/MountainPokemon/Larvitar": "larvitar",
	"Entities/Pokemon/MountainPokemon/Rockruff": "rockruff",
	"Entities/Pokemon/MountainPokemon/Rhyhorn": "rhyhorn",
}

const MOUNTAIN_MOVEMENT := {
	"Entities/Pokemon/MountainPokemon/Geodude": "pace_horizontal",
	"Entities/Pokemon/MountainPokemon/Nosepass": "pace_vertical",
	"Entities/Pokemon/MountainPokemon/Roggenrola": "pace_horizontal",
	"Entities/Pokemon/MountainPokemon/Larvitar": "pace_horizontal",
	"Entities/Pokemon/MountainPokemon/Rockruff": "pace_horizontal",
	"Entities/Pokemon/MountainPokemon/Rhyhorn": "pace_horizontal",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CITY_SCENE) as PackedScene
	_check(packed != null, "Cerulean City loads with its lively population")
	if packed == null:
		quit(1)
		return

	var city := packed.instantiate()
	city.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(city)
	var collision := city.get_node_or_null("Tiles/Collision") as TileMapLayer
	var water := city.get_node_or_null("Tiles/Water") as TileMapLayer
	var ground := city.get_node_or_null("CeruleanCityVisual/Ground") as TileMapLayer
	_check(collision != null, "Cerulean exposes collision for population placement")
	_check(water != null, "Cerulean exposes semantic water for swimming Pokemon")
	_check(ground != null, "Cerulean exposes Ground for mountain Pokemon movement")

	_check_officer_jenny(city)
	_check_growlithe(city)
	_check_water_pokemon(city, collision, water)
	_check_mountain_pokemon(city, collision, water, ground)
	_check_decorative_mountain_collision_override(city, collision)
	_check_practice_battle(city, collision)
	city.free()
	quit(1 if failed else 0)


func _check_officer_jenny(city: Node) -> void:
	var jenny := city.get_node_or_null("Entities/NPCs/OfficerJenny")
	_check(jenny != null, "Cerulean places Officer Jenny")
	if jenny == null:
		return
	_check(str(jenny.get("display_name")) == "Officer Jenny", "Officer Jenny uses her canonical name")
	var frames := jenny.get("npc_sprite_frames") as SpriteFrames
	_check(frames != null and frames.resource_path == JENNY_FRAMES, "Officer Jenny uses the supplied sprite sheet")
	_check(jenny.get("mugshot") != null, "Officer Jenny uses her custom sprite in dialogue")
	if frames != null:
		for animation_name: StringName in [&"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
			_check(frames.has_animation(animation_name), "Officer Jenny has %s" % animation_name)
			_check(frames.get_frame_count(animation_name) == 4, "Officer Jenny %s keeps four frames" % animation_name)
	var texture := load(JENNY_TEXTURE) as Texture2D
	_check(texture != null and texture.get_width() == 256 and texture.get_height() == 256, "Officer Jenny keeps the 256px sprite grid")


func _check_growlithe(city: Node) -> void:
	var growlithe := city.get_node_or_null("Entities/Pokemon/Growlithe")
	_check(growlithe != null, "Growlithe replaces Squirtle beside Officer Jenny")
	if growlithe == null:
		return
	_check(str(growlithe.get("species_id")) == "growlithe", "Officer Jenny companion is Growlithe")
	_check(
		str(growlithe.get("overworld_pokemon_id")) == "kanto_cerulean_city_growlithe_1",
		"Growlithe uses its registered content ID"
	)


func _check_water_pokemon(city: Node, collision: TileMapLayer, water: TileMapLayer) -> void:
	for node_path_value: Variant in WATER_POKEMON:
		var node_path := str(node_path_value)
		var pokemon := city.get_node_or_null(node_path) as Node2D
		_check(pokemon != null, "Cerulean places %s in the water" % node_path.get_file())
		if pokemon == null or collision == null or water == null:
			continue
		_check(
			str(pokemon.get("movement_behavior")) == str(WATER_POKEMON[node_path_value]),
			"%s moves through the water" % node_path.get_file()
		)
		var movement_tiles := int(pokemon.get("movement_tiles"))
		var axis := Vector2.RIGHT if str(pokemon.get("movement_behavior")) == "pace_horizontal" else Vector2.DOWN
		for offset_tiles: int in [-movement_tiles, 0, movement_tiles]:
			var sample_position := pokemon.global_position + axis * 32.0 * offset_tiles
			var water_cell := water.local_to_map(water.to_local(sample_position))
			var collision_cell := collision.local_to_map(collision.to_local(sample_position))
			_check(water.get_cell_source_id(water_cell) != -1, "%s movement stays on water" % node_path.get_file())
			_check(collision.get_cell_source_id(collision_cell) == -1, "%s movement avoids collision" % node_path.get_file())
	var gyarados := city.get_node_or_null("Entities/Pokemon/WaterPokemon/Gyarados") as Node2D
	_check(gyarados != null and gyarados.scale.x > 1.0, "Gyarados is visually prominent")


func _check_mountain_pokemon(
	city: Node,
	collision: TileMapLayer,
	water: TileMapLayer,
	ground: TileMapLayer
) -> void:
	var reachable_tiles := _collect_walkable_tiles(city, collision, water)
	var mountain_foreground := city.get_node_or_null("CeruleanCityVisual/ObjectsTop") as CanvasItem
	_check(mountain_foreground != null, "Cerulean exposes its mountain foreground layer")
	for node_path_value: Variant in MOUNTAIN_POKEMON:
		var node_path := str(node_path_value)
		var pokemon := city.get_node_or_null(node_path) as Node2D
		_check(pokemon != null, "Cerulean places %s on the mountains" % node_path.get_file())
		if pokemon == null:
			continue
		_check(
			str(pokemon.get("species_id")) == str(MOUNTAIN_POKEMON[node_path_value]),
			"%s uses its intended Rock-type species" % node_path.get_file()
		)
		_check(pokemon.get("npc_sprite_frames") != null, "%s resolves its overworld follower sprite" % node_path.get_file())
		var movement_behavior := str(pokemon.get("movement_behavior"))
		_check(
			movement_behavior == str(MOUNTAIN_MOVEMENT[node_path_value]),
			"%s patrols along its intended mountain axis" % node_path.get_file()
		)
		_check(int(pokemon.get("movement_tiles")) == 1, "%s keeps a short mountain patrol" % node_path.get_file())
		_check(float(pokemon.get("movement_speed_pixels")) > 0.0, "%s moves at a visible speed" % node_path.get_file())
		_check(
			bool(pokemon.get("ambient_movement_ignores_map_collision")),
			"%s can move over decorative mountain collision" % node_path.get_file()
		)
		if ground != null and water != null:
			var movement_axis := Vector2.RIGHT if movement_behavior == "pace_horizontal" else Vector2.DOWN
			for offset_tiles: int in [-1, 0, 1]:
				var sample_position := pokemon.global_position + movement_axis * 32.0 * offset_tiles
				var ground_cell := ground.local_to_map(ground.to_local(sample_position))
				var water_cell := water.local_to_map(water.to_local(sample_position))
				_check(
					ground.get_cell_source_id(ground_cell) != -1,
					"%s patrol stays on Ground" % node_path.get_file()
				)
				_check(
					water.get_cell_source_id(water_cell) == -1,
					"%s patrol stays out of water" % node_path.get_file()
				)
		if mountain_foreground != null:
			_check(
				pokemon.z_index > mountain_foreground.z_index,
				"%s renders above the mountain foreground" % node_path.get_file()
			)
		if collision != null:
			var cell := collision.local_to_map(collision.to_local(pokemon.global_position))
			_check(not reachable_tiles.has(cell), "%s stays beyond the player's walkable area" % node_path.get_file())


func _collect_walkable_tiles(city: Node, collision: TileMapLayer, water: TileMapLayer) -> Dictionary:
	var reachable := {}
	if collision == null or water == null:
		return reachable
	var spawn := city.get_node_or_null("Spawns/FromPokemonCenter") as Node2D
	if spawn == null:
		return reachable
	var frontier: Array[Vector2i] = [collision.local_to_map(collision.to_local(spawn.global_position))]
	var map_bounds := Rect2i(Vector2i.ZERO, Vector2i(75, 70))
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		if reachable.has(cell) or not map_bounds.has_point(cell):
			continue
		if collision.get_cell_source_id(cell) != -1 or water.get_cell_source_id(cell) != -1:
			continue
		reachable[cell] = true
		frontier.append(cell + Vector2i.LEFT)
		frontier.append(cell + Vector2i.RIGHT)
		frontier.append(cell + Vector2i.UP)
		frontier.append(cell + Vector2i.DOWN)
	return reachable


func _check_decorative_mountain_collision_override(city: Node, collision: TileMapLayer) -> void:
	var geodude := city.get_node_or_null("Entities/Pokemon/MountainPokemon/Geodude") as Node2D
	var game_state := root.get_node_or_null("GameState")
	if geodude == null or collision == null or game_state == null:
		return
	var previous_map: Node = game_state.get("current_map") as Node
	game_state.set("current_map", city)
	var target_position := geodude.global_position + Vector2.RIGHT * 32.0
	var target_cell := collision.local_to_map(collision.to_local(target_position))
	_check(collision.get_cell_source_id(target_cell) != -1, "Geodude patrol crosses decorative mountain collision")
	geodude.set("ambient_movement_ignores_map_collision", false)
	_check(not bool(geodude.call("_can_npc_move_to", target_position)), "Mountain collision blocks a normal actor")
	geodude.set("ambient_movement_ignores_map_collision", true)
	_check(
		bool(geodude.call("_can_npc_move_to", target_position)),
		"Decorative mountain movement bypasses its collision mask"
	)
	game_state.set("current_map", previous_map)


func _check_practice_battle(city: Node, collision: TileMapLayer) -> void:
	var lila := city.get_node_or_null("Entities/NPCs/AceTrainerLila") as Node2D
	var bram := city.get_node_or_null("Entities/NPCs/AceTrainerBram") as Node2D
	var display := city.get_node_or_null("Entities/Pokemon/BattleDisplay") as Node2D
	var onix := city.get_node_or_null("Entities/Pokemon/BattleDisplay/Onix") as Node2D
	var pikachu := city.get_node_or_null("Entities/Pokemon/BattleDisplay/Pikachu") as Node2D
	_check(lila != null and bram != null, "Two Trainers face each other on the practice platform")
	_check(display != null and display.get_script() != null, "Practice Pokemon use the battle movement controller")
	_check(onix != null and pikachu != null, "Both practice Trainers have a Pokemon")
	if lila == null or bram == null or display == null or onix == null or pikachu == null:
		return
	_check(float(display.get("lunge_distance")) > 0.0, "Practice Pokemon lunge toward and retreat from each other")
	_check(str(onix.get("species_id")) == "onix", "Lila battles with Onix")
	_check(str(pikachu.get("species_id")) == "pikachu", "Bram battles with Pikachu")
	_check(lila.global_position.x < onix.global_position.x, "Lila stands behind Onix")
	_check(bram.global_position.x > pikachu.global_position.x, "Bram stands behind Pikachu")
	_check(onix.global_position.x < pikachu.global_position.x, "Practice Pokemon face across the platform")
	if collision != null:
		for character: Node2D in [lila, bram, onix, pikachu]:
			var cell := collision.local_to_map(collision.to_local(character.global_position))
			_check(collision.get_cell_source_id(cell) == -1, "%s stands on the open platform" % character.name)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error(message)
