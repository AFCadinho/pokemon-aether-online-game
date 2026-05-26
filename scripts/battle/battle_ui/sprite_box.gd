extends Control

@export var default_is_double_battle := false

@onready var single_container: Control = $SingleBattleContainer
@onready var double_container: Control = $DoubleBattleContainer

@onready var single_sprite: AnimatedSprite2D = $SingleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var double_sprite_1: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var double_sprite_2: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2

func _ready() -> void:
	set_battle_type(default_is_double_battle)

func set_battle_type(is_double_battle: bool) -> void:
	single_container.visible = not is_double_battle
	double_container.visible = is_double_battle

func _load_sprite_frames(species: String, side: String) -> SpriteFrames:
	var folder := "res://assets/sprites/pokemon/%s/%s" % [side, species.to_lower()]
	
	if not DirAccess.dir_exists_absolute(folder):
		push_error("Pokemon sprite folder is not found: " + folder)
		return null
		
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("Could not open sprite folder: " + folder)
		return null
		
	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and file_name.begins_with("frame_"):
			frame_files.append(file_name)

		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	frame_files.sort()
	
	if frame_files.is_empty():
		push_error("No sprite frames found in: " + folder)
		return null
		
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.set_animation_speed("idle", 3.0)
	
	for frame_file in frame_files:
		var texture := load(folder + "/" + frame_file)
		
		if texture != null:
			sprite_frames.add_frame("idle", texture)
			
	return sprite_frames
	
func set_single_pokemon(pokemon: Pokemon, side: String) -> void:
	set_battle_type(false)
	
	var frames := _load_sprite_frames(pokemon.species, side)
	
	if frames == null:
		return
	
	single_sprite.sprite_frames = frames
	single_sprite.animation = "idle"
	single_sprite.play()
	
func set_double_pokemon(pokemon_1: Pokemon, pokemon_2: Pokemon, side: String) -> void:
	set_battle_type(true)

	var frames_1 := _load_sprite_frames(pokemon_1.species, side)
	var frames_2 := _load_sprite_frames(pokemon_2.species, side)

	if frames_1 != null:
		double_sprite_1.sprite_frames = frames_1
		double_sprite_1.animation = "idle"
		double_sprite_1.play()

	if frames_2 != null:
		double_sprite_2.sprite_frames = frames_2
		double_sprite_2.animation = "idle"
		double_sprite_2.play()
