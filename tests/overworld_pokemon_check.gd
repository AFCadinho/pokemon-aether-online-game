extends SceneTree

const OVERWORLD_POKEMON_SCRIPT := "res://scripts/world/npcs/overworld_pokemon.gd"
const OVERWORLD_POKEMON_SCENE := "res://scenes/npcs/overworld_pokemon.tscn"
const OVERWORLD_POKEMON_METADATA_SERVICE_SCRIPT := "res://scripts/services/overworld_pokemon_metadata_service.gd"
const PROJECT_CONFIG := "res://project.godot"
const MAP_CHARACTER_BLOCKING_SCRIPT := "res://scripts/world/map_character_blocking.gd"
const ROUTE_1_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const VIRIDIAN_CITY_SCENE := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"

var failed := false


func _init() -> void:
	_check_metadata_service()
	_check_overworld_pokemon_script()
	_check_overworld_pokemon_scene()
	_check_pokemon_blocking_container()
	_check_route_1_example_placement()
	_check_town_placements()

	quit(1 if failed else 0)


func _check_metadata_service() -> void:
	var project_text := _read_text(PROJECT_CONFIG)
	_check_true(project_text.contains("OverworldPokemonMetadataService=\"*res://scripts/services/overworld_pokemon_metadata_service.gd\""), "OverworldPokemonMetadataService is autoloaded")

	var text := _read_text(OVERWORLD_POKEMON_METADATA_SERVICE_SCRIPT)
	_check_true(text.contains("func get_overworld_pokemon_metadata(overworld_pokemon_id: String) -> Dictionary:"), "OverworldPokemonMetadataService exposes fetch API")
	_check_true(text.contains("OVERWORLD_POKEMON_METADATA_ENDPOINT := \"/overworld-pokemon/%s\""), "OverworldPokemonMetadataService uses backend endpoint")
	_check_true(text.contains("pokemon_metadata[\"speciesId\"]"), "OverworldPokemonMetadataService normalizes speciesId")
	_check_true(text.contains("pokemon_metadata[\"dialogueId\"]"), "OverworldPokemonMetadataService normalizes dialogueId")


func _check_overworld_pokemon_script() -> void:
	var text := _read_text(OVERWORLD_POKEMON_SCRIPT)
	_check_true(text.contains("extends BaseNPC"), "OverworldPokemon extends BaseNPC")
	_check_true(text.contains("class_name OverworldPokemon"), "OverworldPokemon class exists")
	_check_true(text.contains("@export var overworld_pokemon_id := \"\""), "OverworldPokemon exports overworld_pokemon_id")
	_check_true(text.contains("@export var species_id := \"\""), "OverworldPokemon exports species_id")
	_check_true(text.contains("@export var level := 5"), "OverworldPokemon exports level")
	_check_true(text.contains("@export var auto_resolve_follower_sprite := true"), "OverworldPokemon auto-resolves follower sprites")
	_check_true(text.contains("OverworldPokemonMetadataService.get_overworld_pokemon_metadata(overworld_pokemon_id)"), "OverworldPokemon loads backend metadata")
	_check_true(text.contains("NpcDialogueService.resolve_lines("), "OverworldPokemon resolves backend dialogue centrally")
	_check_true(text.contains("FollowerSpriteService.get_sprite_frames(resolved_species_id, false)"), "OverworldPokemon uses follower sprite animations")
	_check_true(text.contains("sprite.sprite_frames = follower_sprite_frames"), "OverworldPokemon applies resolved follower sprite frames")
	_check_true(text.contains("sprite.animation != animation_name or not sprite.is_playing()"), "OverworldPokemon does not restart active walk loops")
	_check_true(text.contains("_should_keep_walk_animation_after_step(direction)"), "OverworldPokemon keeps walk loops between continuous steps")
	_check_true(text.contains("HOME_ICON_DIR := \"res://assets/sprites/pokemon/pokemon_home\""), "OverworldPokemon knows HOME icon directory")
	_check_true(text.contains("func _load_home_icon(raw_species_id: String) -> Texture2D:"), "OverworldPokemon can resolve HOME icons")
	_check_true(text.contains("await _process_base_npc()"), "OverworldPokemon reuses BaseNPC movement")
	_check_true(text.contains("\"%s cries out!\" % _get_pokemon_display_name()"), "OverworldPokemon derives fallback cry text from Pokemon name")


func _check_overworld_pokemon_scene() -> void:
	var text := _read_text(OVERWORLD_POKEMON_SCENE)
	_check_true(text.contains("res://scripts/world/npcs/overworld_pokemon.gd"), "OverworldPokemon scene uses script")
	_check_true(text.contains("assets/followers/LILLIPUP.png"), "OverworldPokemon scene has placeholder Pokemon sprite")
	_check_true(text.contains("species_id = \"lillipup\""), "OverworldPokemon scene defines species_id")
	_check_true(text.contains("npc_sprite_frames = SubResource"), "OverworldPokemon scene defines sprite frames")


func _check_pokemon_blocking_container() -> void:
	var text := _read_text(MAP_CHARACTER_BLOCKING_SCRIPT)
	_check_true(text.contains("\"Entities/Pokemon\""), "MapCharacterBlocking includes Pokemon container")


func _check_route_1_example_placement() -> void:
	var text := _read_text(ROUTE_1_SCENE)
	_check_true(text.contains("res://scenes/npcs/overworld_pokemon.tscn"), "Route 1 references OverworldPokemon scene")
	_check_true(text.contains("parent=\"Entities/Pokemon\""), "Route 1 places OverworldPokemon under Entities/Pokemon")
	_check_true(text.contains("overworld_pokemon_id = \"kanto_route_1_lillipup_1\""), "Route 1 Lillipup uses backend metadata id")
	_check_true(text.contains("overworld_pokemon_id = \"kanto_route_1_pidgey_1\""), "Route 1 Pidgey uses backend metadata id")
	_check_true(text.contains("species_id = \"pidgey\""), "Route 1 Pidgey overrides species_id")

func _check_town_placements() -> void:
	var pallet_town_text := _read_text(PALLET_TOWN_SCENE)
	_check_true(
		pallet_town_text.contains('overworld_pokemon_id = "kanto_pallet_town_horsea_1"'),
		"Pallet Town places its Horsea metadata id"
	)
	_check_true(
		pallet_town_text.contains('overworld_pokemon_id = "kanto_pallet_town_pikachu_1"'),
		"Pallet Town places its Pikachu metadata id"
	)

	var viridian_city_text := _read_text(VIRIDIAN_CITY_SCENE)
	_check_true(
		not viridian_city_text.contains('overworld_pokemon_id = "kanto_pallet_town_'),
		"Viridian City does not reuse Pallet Town overworld Pokemon ids"
	)


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
