@tool
extends BaseNPC

class_name OverworldPokemon

@export var overworld_pokemon_id := ""
@export var species_id := ""
@export var level := 5
@export var auto_resolve_home_icon := true
@export var auto_resolve_follower_sprite := true
@export var cry_dialogue_lines: Array[String] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		_ready_base_npc()
		return
	if display_name.strip_edges().is_empty():
		display_name = _format_species_display_name(species_id)
	_apply_follower_sprite_frames()
	_ready_base_npc()
	_resolve_home_mugshot()
	Callable(self, "_load_overworld_pokemon_metadata_if_needed").call_deferred()


func _process(_delta: float) -> void:
	await _process_base_npc()


func _play_walk_animation(direction: Vector2) -> void:
	var animation_name := _get_walk_animation_name(direction)
	if animation_name == "" or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return

	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)


func _set_idle_frame(direction: Vector2) -> void:
	if is_npc_moving and _should_keep_walk_animation_after_step(direction):
		facing_direction = _get_cardinal_direction(direction)
		return

	super._set_idle_frame(direction)


func interact_with_player(_player: Node2D) -> void:
	await _load_overworld_pokemon_metadata_if_needed()
	if not dialogue_id.strip_edges().is_empty():
		var dialogue_lines: Array[String] = await NpcDialogueService.resolve_lines(
			dialogue_id,
			cry_dialogue_lines,
			"OverworldPokemon"
		)
		if not dialogue_lines.is_empty():
			await show_dialogue(dialogue_lines)
			return

	var lines := cry_dialogue_lines
	if lines.is_empty():
		lines = [
			"%s cries out!" % _get_pokemon_display_name(),
		]
	await show_dialogue(lines)


func _format_species_display_name(raw_species_id: String) -> String:
	var normalized_species_id := raw_species_id.strip_edges()
	if normalized_species_id.is_empty():
		return "Pokemon"

	var words := normalized_species_id.replace("-", "_").split("_", false)
	for index: int in range(words.size()):
		words[index] = words[index].capitalize()

	return " ".join(words)


func _load_overworld_pokemon_metadata_if_needed() -> Dictionary:
	if overworld_pokemon_id.strip_edges().is_empty():
		return {
			"success": true,
			"metadata": {},
		}

	var response: Dictionary = await OverworldPokemonMetadataService.get_overworld_pokemon_metadata(overworld_pokemon_id)
	if not response.get("success", false):
		push_warning("OverworldPokemon: metadata failed for %s: %s" % [
			overworld_pokemon_id,
			str(response.get("error", "Unknown API error")),
		])
		return response

	_apply_overworld_pokemon_metadata(response.get("metadata", {}))
	return response


func _apply_overworld_pokemon_metadata(metadata: Dictionary) -> void:
	var metadata_species_id := str(metadata.get("speciesId", metadata.get("species_id", ""))).strip_edges()
	if not metadata_species_id.is_empty():
		species_id = metadata_species_id

	var metadata_level := int(metadata.get("level", level))
	if metadata_level > 0:
		level = metadata_level

	var metadata_dialogue_id := str(metadata.get("dialogueId", metadata.get("dialogue_id", ""))).strip_edges()
	if not metadata_dialogue_id.is_empty():
		dialogue_id = metadata_dialogue_id

	var metadata_name := str(metadata.get("name", metadata.get("displayName", metadata.get("display_name", "")))).strip_edges()
	if not metadata_name.is_empty():
		display_name = metadata_name
	elif display_name.strip_edges().is_empty():
		display_name = _format_species_display_name(species_id)
	_sync_nameplate()

	_resolve_home_mugshot()
	_apply_follower_sprite_frames()


func _get_pokemon_display_name() -> String:
	var pokemon_name := display_name.strip_edges()
	if pokemon_name.is_empty():
		pokemon_name = _format_species_display_name(species_id)
	return pokemon_name


func _resolve_home_mugshot() -> void:
	if not auto_resolve_home_icon:
		return

	var home_icon := PokemonAssets.load_home_sprite(species_id)
	if home_icon == null:
		home_icon = PokemonAssets.load_unknown_icon()
	mugshot = home_icon


func _apply_follower_sprite_frames() -> void:
	if not auto_resolve_follower_sprite:
		return

	var resolved_species_id := species_id.strip_edges()
	if resolved_species_id.is_empty():
		return

	var follower_sprite_frames := FollowerSpriteService.get_sprite_frames(resolved_species_id, false)
	if follower_sprite_frames == null:
		return

	npc_sprite_frames = follower_sprite_frames
	if sprite == null:
		return

	sprite.sprite_frames = follower_sprite_frames
	_set_idle_frame(_get_cardinal_direction(facing_direction))


func _should_keep_walk_animation_after_step(direction: Vector2) -> bool:
	if movement_behavior == "idle":
		return false
	if movement_wait_seconds > 0.0:
		return false

	var cardinal_direction := _get_cardinal_direction(direction)
	if cardinal_direction == Vector2.ZERO:
		return false

	var next_offset := movement_current_offset_tiles + movement_direction_sign
	if abs(next_offset) > maxi(movement_tiles, 1):
		return false

	var current_tile := _to_tile(get_feet_position())
	var next_tile := current_tile + Vector2i(int(cardinal_direction.x), int(cardinal_direction.y))
	return _can_npc_move_to(_tile_to_world(next_tile))
