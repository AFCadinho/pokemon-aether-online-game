extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const JENNY_TEXTURE := "res://assets/npcs/classes/officer_jenny.png"
const JENNY_FRAMES := "res://assets/npcs/classes/officer_jenny_frames.tres"

const WATER_POKEMON := {
	"Entities/Pokemon/WaterPokemon/Gyarados": "pace_horizontal",
	"Entities/Pokemon/WaterPokemon/Goldeen": "pace_horizontal",
	"Entities/Pokemon/WaterPokemon/Poliwag": "pace_vertical",
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
	_check(collision != null, "Cerulean exposes collision for population placement")
	_check(water != null, "Cerulean exposes semantic water for swimming Pokemon")

	_check_officer_jenny(city)
	_check_growlithe(city)
	_check_water_pokemon(city, collision, water)
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


func _check_practice_battle(city: Node, collision: TileMapLayer) -> void:
	var lila := city.get_node_or_null("Entities/NPCs/AceTrainerLila") as Node2D
	var bram := city.get_node_or_null("Entities/NPCs/AceTrainerBram") as Node2D
	var display := city.get_node_or_null("Entities/Pokemon/BattleDisplay") as Node2D
	var pikachu := city.get_node_or_null("Entities/Pokemon/BattleDisplay/Pikachu") as Node2D
	var eevee := city.get_node_or_null("Entities/Pokemon/BattleDisplay/Eevee") as Node2D
	_check(lila != null and bram != null, "Two Trainers face each other on the practice platform")
	_check(display != null and display.get_script() != null, "Practice Pokemon use the battle movement controller")
	_check(pikachu != null and eevee != null, "Both practice Trainers have a Pokemon")
	if lila == null or bram == null or display == null or pikachu == null or eevee == null:
		return
	_check(float(display.get("lunge_distance")) > 0.0, "Practice Pokemon lunge toward and retreat from each other")
	_check(lila.global_position.x < pikachu.global_position.x, "Lila stands behind Pikachu")
	_check(bram.global_position.x > eevee.global_position.x, "Bram stands behind Eevee")
	_check(pikachu.global_position.x < eevee.global_position.x, "Practice Pokemon face across the platform")
	if collision != null:
		for character: Node2D in [lila, bram, pikachu, eevee]:
			var cell := collision.local_to_map(collision.to_local(character.global_position))
			_check(collision.get_cell_source_id(cell) == -1, "%s stands on the open platform" % character.name)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error(message)
