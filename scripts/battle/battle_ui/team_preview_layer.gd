extends Node2D

const IDLE_ANIMATION := "idle"
const PREVIEW_SPRITE_SCALE := Vector2(1.35, 1.35)
const BATTLE_SPRITE_LOADER := preload("res://scripts/battle/battle_ui/sprite_box.gd")

var sprite_loader := BATTLE_SPRITE_LOADER.new()
var slot_sprites: Array[AnimatedSprite2D] = []
var team_is_shown := false


func _ready() -> void:
	_cache_slot_sprites()
	# The battle controller can populate this layer immediately after mounting
	# the Battle scene, before this child receives its ready notification. Do
	# not erase that already-built Team Preview here; doing so left one client
	# with an empty overview depending on frame timing.
	if not team_is_shown:
		clear()


func show_team(team_data: Array, side: String) -> void:
	_cache_slot_sprites()
	clear()

	for index in range(min(team_data.size(), slot_sprites.size())):
		var pokemon_value: Variant = team_data[index]
		if not (pokemon_value is Dictionary):
			continue

		_show_pokemon_in_slot(slot_sprites[index], pokemon_value as Dictionary, side)

	team_is_shown = true
	visible = true


func clear() -> void:
	# Hide the owner before clearing individual sprites. This prevents a cached
	# SubViewport frame or a late lead transition from drawing preview Pokemon
	# underneath the Pokeball summon.
	team_is_shown = false
	visible = false
	_cache_slot_sprites()
	for sprite in slot_sprites:
		sprite.stop()
		sprite.visible = false
		sprite.sprite_frames = null


func _cache_slot_sprites() -> void:
	if not slot_sprites.is_empty():
		return

	for slot_index in range(1, 7):
		var sprite := get_node_or_null("Slot%s/AnimatedSprite2D" % slot_index) as AnimatedSprite2D
		if sprite == null:
			continue

		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		slot_sprites.append(sprite)


func _show_pokemon_in_slot(sprite: AnimatedSprite2D, pokemon_data: Dictionary, side: String) -> void:
	var species := _get_species_from_data(pokemon_data)
	if species == "":
		return

	var frames: SpriteFrames = sprite_loader.call(
		"_load_sprite_frames",
		species,
		side,
		_get_shiny_from_data(pokemon_data)
	)
	if frames == null:
		return

	sprite.sprite_frames = frames
	sprite.animation = IDLE_ANIMATION
	sprite.frame = 0
	sprite.scale = _get_preview_scale_for_frames(frames)
	sprite.visible = true
	sprite.play()


func _get_preview_scale_for_frames(frames: SpriteFrames) -> Vector2:
	var render_scale := 1.0
	if sprite_loader.has_method("_get_sprite_frames_render_scale"):
		render_scale = float(sprite_loader.call("_get_sprite_frames_render_scale", frames))

	var display_scale_multiplier := 1.0
	if sprite_loader.has_method("_get_sprite_frames_display_scale_multiplier"):
		display_scale_multiplier = float(sprite_loader.call("_get_sprite_frames_display_scale_multiplier", frames))

	return (PREVIEW_SPRITE_SCALE / max(render_scale, 1.0)) * display_scale_multiplier


func _get_species_from_data(pokemon_data: Dictionary) -> String:
	var display_species := str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var species := str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return ""


func _get_shiny_from_data(pokemon_data: Dictionary) -> bool:
	for key in ["shiny", "isShiny", "is_shiny"]:
		if not pokemon_data.has(key):
			continue

		var value: Variant = pokemon_data.get(key)
		if value is bool:
			return bool(value)

		var text_value := str(value).strip_edges().to_lower()
		if text_value == "true" or text_value == "1" or text_value == "yes":
			return true

	return false
