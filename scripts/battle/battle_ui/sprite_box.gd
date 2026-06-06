extends Control

@export var default_is_double_battle := false

const IDLE_ANIMATION := "idle"
const DEFAULT_SHEET_FRAME_SIZE := Vector2i(48, 57)
const MIN_SHEET_FRAME_SIZE := Vector2i(16, 16)
const MAX_SHEET_FRAME_SIZE := Vector2i(256, 256)
const FRAME_ANIMATION_SPEED := 3.0
const SHEET_ANIMATION_SPEED := 10.0
const BATTLE_SPRITE_SCALE := Vector2(2, 2)
const ATTACK_TWEEN_OFFSET := Vector2(28, -6)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const HEAL_FLASH_COLOR := Color(0.45, 1.0, 0.55, 1.0)
const STAT_RAISE_FLASH_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const STAT_DROP_FLASH_COLOR := Color(0.8, 0.45, 1.0, 1.0)
const FAINT_TWEEN_OFFSET := Vector2(0, 34)
const SPRITE_HOVER_PADDING := Vector2(8, 8)

@onready var single_container: Control = $SingleBattleContainer
@onready var double_container: Control = $DoubleBattleContainer

@onready var single_sprite_slot: Control = $SingleBattleContainer/SpriteSlot
@onready var single_sprite: AnimatedSprite2D = $SingleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var double_sprite_1: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var double_sprite_2: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2

var active_tween: Tween
var base_sprite_positions: Dictionary = {}

func _ready() -> void:
	_set_sprite_filter(single_sprite)
	_set_sprite_filter(double_sprite_1)
	_set_sprite_filter(double_sprite_2)
	_cache_base_sprite_positions()
	set_battle_type(default_is_double_battle)
	_snap_all_sprites_to_pixel_grid.call_deferred()

func set_battle_type(is_double_battle: bool) -> void:
	single_container.visible = not is_double_battle
	double_container.visible = is_double_battle

func get_single_sprite_slot() -> Control:
	return single_sprite_slot

func is_mouse_over_single_sprite(mouse_position: Vector2) -> bool:
	return get_single_sprite_hover_rect().has_point(mouse_position)

func get_single_sprite_hover_rect() -> Rect2:
	return _get_sprite_hover_rect(single_sprite)

func _set_sprite_filter(sprite: AnimatedSprite2D) -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = BATTLE_SPRITE_SCALE

func _get_sprite_hover_rect(sprite: AnimatedSprite2D) -> Rect2:
	var texture: Texture2D = _get_current_sprite_texture(sprite)
	var frame_size: Vector2 = Vector2(DEFAULT_SHEET_FRAME_SIZE)
	if texture != null:
		frame_size = texture.get_size()

	var sprite_scale := Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
	var hitbox_size: Vector2 = frame_size * sprite_scale
	var hitbox_position: Vector2 = sprite.global_position - (hitbox_size * 0.5) - SPRITE_HOVER_PADDING
	return Rect2(hitbox_position, hitbox_size + (SPRITE_HOVER_PADDING * 2.0))

func _get_current_sprite_texture(sprite: AnimatedSprite2D) -> Texture2D:
	if sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null

	var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
	if frame_count <= 0:
		return null

	var frame_index: int = min(max(sprite.frame, 0), frame_count - 1)
	return sprite.sprite_frames.get_frame_texture(sprite.animation, frame_index)

func _cache_base_sprite_positions() -> void:
	for sprite in _get_all_sprites():
		base_sprite_positions[_get_sprite_key(sprite)] = sprite.position

func _get_all_sprites() -> Array[AnimatedSprite2D]:
	return [
		single_sprite,
		double_sprite_1,
		double_sprite_2,
	]

func _get_visible_sprites() -> Array[AnimatedSprite2D]:
	var sprites: Array[AnimatedSprite2D] = []
	for sprite in _get_all_sprites():
		if sprite.visible and sprite.is_visible_in_tree():
			sprites.append(sprite)

	return sprites

func _get_sprite_key(sprite: AnimatedSprite2D) -> String:
	return str(sprite.get_path())

func _snap_all_sprites_to_pixel_grid() -> void:
	_snap_sprite_to_pixel_grid(single_sprite)
	_snap_sprite_to_pixel_grid(double_sprite_1)
	_snap_sprite_to_pixel_grid(double_sprite_2)

func _snap_sprite_to_pixel_grid(sprite: AnimatedSprite2D) -> void:
	sprite.scale = BATTLE_SPRITE_SCALE
	sprite.global_position = sprite.global_position.round()

func reset_battle_pose() -> void:
	_stop_active_tween()
	for sprite in _get_all_sprites():
		_reset_sprite_pose(sprite)

func play_attack_tween(offset: Vector2 = ATTACK_TWEEN_OFFSET) -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		active_tween.tween_property(sprite, "position", base_position + offset, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.12).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_damage_tween() -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		active_tween.tween_property(sprite, "modulate", DAMAGE_FLASH_COLOR, 0.04)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.08).set_delay(0.04)
		active_tween.tween_property(sprite, "position", base_position + Vector2(-8, 0), 0.04)
		active_tween.tween_property(sprite, "position", base_position + Vector2(8, 0), 0.04).set_delay(0.04)
		active_tween.tween_property(sprite, "position", base_position, 0.05).set_delay(0.08)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_heal_tween() -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		active_tween.tween_property(sprite, "modulate", HEAL_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.14).set_delay(0.08)
		active_tween.tween_property(sprite, "scale", BATTLE_SPRITE_SCALE * 1.06, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", BATTLE_SPRITE_SCALE, 0.14).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_stat_raise_tween() -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		active_tween.tween_property(sprite, "modulate", STAT_RAISE_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16).set_delay(0.08)
		active_tween.tween_property(sprite, "position", base_position + Vector2(0, -10), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.14).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_stat_drop_tween() -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		active_tween.tween_property(sprite, "modulate", STAT_DROP_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16).set_delay(0.08)
		active_tween.tween_property(sprite, "position", base_position + Vector2(0, 8), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.14).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_faint_tween() -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		active_tween.tween_property(sprite, "position", base_position + FAINT_TWEEN_OFFSET, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		active_tween.tween_property(sprite, "modulate:a", 0.0, 0.28)

	await active_tween.finished

func _stop_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = null

func _reset_sprites_pose(sprites: Array[AnimatedSprite2D]) -> void:
	for sprite in sprites:
		_reset_sprite_pose(sprite)

func _reset_sprite_pose(sprite: AnimatedSprite2D) -> void:
	sprite.position = _get_base_sprite_position(sprite)
	sprite.scale = BATTLE_SPRITE_SCALE
	sprite.modulate = Color.WHITE

func _get_base_sprite_position(sprite: AnimatedSprite2D) -> Vector2:
	var base_position_value: Variant = base_sprite_positions.get(_get_sprite_key(sprite), sprite.position)
	if base_position_value is Vector2:
		return base_position_value

	return sprite.position

func _load_sprite_frames(species: String, side: String, is_shiny: bool = false) -> SpriteFrames:
	for sprite_root in _get_sprite_asset_roots(side, is_shiny):
		for asset_id in _get_species_asset_id_candidates(species):
			var sheet_metadata_path := "res://assets/sprites/pokemon/%s/%s/animation.json" % [sprite_root, asset_id]
			var metadata_frames := _load_sprite_frames_from_sheet_metadata(sheet_metadata_path, sprite_root, species)
			if metadata_frames != null:
				return metadata_frames

			var folder := "res://assets/sprites/pokemon/%s/%s" % [sprite_root, asset_id]
			var folder_frames := _load_sprite_frames_from_folder(folder)
			if folder_frames != null:
				return folder_frames

			var sheet_path := "res://assets/sprites/pokemon/%s/%s.png" % [sprite_root, asset_id]
			var sheet_frames := _load_sprite_frames_from_sheet(sheet_path)
			if sheet_frames != null:
				return sheet_frames

	push_error("Pokemon sprite assets are not found for %s/%s" % [side, species])
	return null

func _get_sprite_asset_roots(side: String, is_shiny: bool) -> Array[String]:
	var roots: Array[String] = []
	if is_shiny:
		roots.append("shiny_%s" % side)

	roots.append(side)
	return roots

func _get_species_asset_id_candidates(species: String) -> Array[String]:
	var asset_id: String = _normalize_species_asset_id(species)
	var candidates: Array[String] = [asset_id]
	var compact_asset_id: String = asset_id.replace("-", "")
	if compact_asset_id != asset_id:
		candidates.append(compact_asset_id)

	return candidates

func _normalize_species_asset_id(species: String) -> String:
	var asset_id := species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")
	if asset_id.begins_with("tapu-"):
		asset_id = asset_id.replace("tapu-", "tapu")

	return asset_id

func _load_sprite_frames_from_folder(folder: String) -> SpriteFrames:
	if not DirAccess.dir_exists_absolute(folder):
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

	var timing := _load_frame_timing(folder, frame_files.size())
	var sprite_frames := _create_idle_sprite_frames(timing["speed"])
	for index in frame_files.size():
		var frame_file := frame_files[index]
		var texture := load(folder + "/" + frame_file)
		if texture != null:
			sprite_frames.add_frame(IDLE_ANIMATION, texture, timing["durations"][index])

	return sprite_frames

func _load_frame_timing(folder: String, frame_count: int) -> Dictionary:
	var metadata_path := folder + "/animation.json"
	var timing := {
		"speed": FRAME_ANIMATION_SPEED,
		"durations": [],
	}

	if not FileAccess.file_exists(metadata_path):
		timing["durations"] = _default_frame_durations(frame_count)
		return timing

	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		timing["durations"] = _default_frame_durations(frame_count)
		return timing

	var parsed = JSON.parse_string(metadata_file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		timing["durations"] = _default_frame_durations(frame_count)
		return timing

	timing["speed"] = float(parsed.get("speed", FRAME_ANIMATION_SPEED))
	var durations: Array[float] = []
	for duration in parsed.get("durations", []):
		durations.append(float(duration))

	while durations.size() < frame_count:
		durations.append(1.0)

	timing["durations"] = durations
	return timing

func _default_frame_durations(frame_count: int) -> Array[float]:
	var durations: Array[float] = []
	for _index in frame_count:
		durations.append(1.0)

	return durations

func _load_sprite_frames_from_sheet_metadata(metadata_path: String, side: String, species: String) -> SpriteFrames:
	if not FileAccess.file_exists(metadata_path):
		return null

	var metadata_file := FileAccess.open(metadata_path, FileAccess.READ)
	if metadata_file == null:
		push_error("Could not open Pokemon spritesheet metadata: " + metadata_path)
		return null

	var metadata = JSON.parse_string(metadata_file.get_as_text())
	if typeof(metadata) != TYPE_DICTIONARY:
		push_error("Invalid Pokemon spritesheet metadata: " + metadata_path)
		return null

	var image_name := str(metadata.get("image", "sheet.png"))
	var sheet_path := metadata_path.get_base_dir() + "/" + image_name
	var sheet_texture := load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_error("Could not load Pokemon spritesheet from metadata: " + sheet_path)
		return null

	var sheet_image := sheet_texture.get_image()
	if sheet_image == null:
		push_error("Could not read Pokemon spritesheet image: " + sheet_path)
		return null

	var frames = metadata.get("frames", [])
	if typeof(frames) != TYPE_ARRAY or frames.is_empty():
		push_error("Pokemon spritesheet metadata has no frames: " + metadata_path)
		return null

	var sprite_frames := _create_idle_sprite_frames(float(metadata.get("speed", 1.0)))
	for frame in frames:
		if typeof(frame) != TYPE_DICTIONARY:
			continue

		var region := Rect2i(
			int(frame.get("x", 0)),
			int(frame.get("y", 0)),
			int(frame.get("w", metadata.get("frame_width", 0))),
			int(frame.get("h", metadata.get("frame_height", 0)))
		)
		if region.size.x <= 0 or region.size.y <= 0:
			continue

		var frame_texture := ImageTexture.create_from_image(sheet_image.get_region(region))
		sprite_frames.add_frame(IDLE_ANIMATION, frame_texture, float(frame.get("duration", 1.0)))

	if sprite_frames.get_frame_count(IDLE_ANIMATION) == 0:
		push_error("Pokemon spritesheet metadata produced no frames: " + metadata_path)
		return null

	return sprite_frames

func _load_sprite_frames_from_sheet(sheet_path: String) -> SpriteFrames:
	if not ResourceLoader.exists(sheet_path):
		return null

	var sheet_texture := load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_error("Could not load Pokemon spritesheet: " + sheet_path)
		return null

	var sheet_size := Vector2i(sheet_texture.get_width(), sheet_texture.get_height())
	var sheet_image := sheet_texture.get_image()
	if sheet_image == null:
		push_error("Could not read Pokemon spritesheet image: " + sheet_path)
		return null

	var frame_size := _guess_sheet_frame_size(sheet_size, sheet_image)
	if frame_size == Vector2i.ZERO:
		push_error("Could not detect spritesheet frame size: " + sheet_path)
		return null

	var sprite_frames := _create_idle_sprite_frames(SHEET_ANIMATION_SPEED)
	var columns := sheet_size.x / frame_size.x
	var rows := sheet_size.y / frame_size.y
	var idle_regions: Array[Rect2i] = []

	for row in rows:
		var row_regions: Array[Rect2i] = []
		for column in columns:
			var region := Rect2i(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
			if _is_region_empty(sheet_image, region):
				continue

			row_regions.append(region)

		if not row_regions.is_empty():
			idle_regions = row_regions
			break

	for region in idle_regions:
		var frame_texture := ImageTexture.create_from_image(sheet_image.get_region(region))
		sprite_frames.add_frame(IDLE_ANIMATION, frame_texture)

	if sprite_frames.get_frame_count(IDLE_ANIMATION) == 0:
		push_error("No visible sprite frames found in spritesheet: " + sheet_path)
		return null

	return sprite_frames

func _create_idle_sprite_frames(animation_speed: float) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(IDLE_ANIMATION)
	sprite_frames.set_animation_loop(IDLE_ANIMATION, true)
	sprite_frames.set_animation_speed(IDLE_ANIMATION, animation_speed)
	return sprite_frames

func _guess_sheet_frame_size(sheet_size: Vector2i, sheet_image: Image) -> Vector2i:
	if sheet_image == null:
		if sheet_size.x % DEFAULT_SHEET_FRAME_SIZE.x == 0 and sheet_size.y % DEFAULT_SHEET_FRAME_SIZE.y == 0:
			return DEFAULT_SHEET_FRAME_SIZE

	var best_frame_size := Vector2i.ZERO
	var best_score := 999999

	for frame_width in _get_divisors(sheet_size.x):
		if frame_width < MIN_SHEET_FRAME_SIZE.x or frame_width > MAX_SHEET_FRAME_SIZE.x:
			continue

		for frame_height in _get_divisors(sheet_size.y):
			if frame_height < MIN_SHEET_FRAME_SIZE.y or frame_height > MAX_SHEET_FRAME_SIZE.y:
				continue

			var frame_count := (sheet_size.x / frame_width) * (sheet_size.y / frame_height)
			if frame_count < 2 or frame_count > 160:
				continue

			var edge_pixels := _count_edge_pixels(sheet_image, Vector2i(frame_width, frame_height))
			var default_distance: int = abs(frame_width - DEFAULT_SHEET_FRAME_SIZE.x) + abs(frame_height - DEFAULT_SHEET_FRAME_SIZE.y)
			var score: int = edge_pixels * 10 + default_distance * 100
			if score < best_score:
				best_score = score
				best_frame_size = Vector2i(frame_width, frame_height)

	return best_frame_size

func _get_divisors(value: int) -> Array[int]:
	var divisors: Array[int] = []
	for number in range(1, value + 1):
		if value % number == 0:
			divisors.append(number)

	return divisors

func _count_edge_pixels(image: Image, frame_size: Vector2i) -> int:
	var edge_pixels := 0
	var columns := image.get_width() / frame_size.x
	var rows := image.get_height() / frame_size.y

	for row in rows:
		for column in columns:
			var region := Rect2i(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
			for y in range(region.position.y, region.end.y):
				if image.get_pixel(region.position.x, y).a > 0.0:
					edge_pixels += 1
				if image.get_pixel(region.end.x - 1, y).a > 0.0:
					edge_pixels += 1

			for x in range(region.position.x, region.end.x):
				if image.get_pixel(x, region.position.y).a > 0.0:
					edge_pixels += 1
				if image.get_pixel(x, region.end.y - 1).a > 0.0:
					edge_pixels += 1

	return edge_pixels

func _is_region_empty(image: Image, region: Rect2i) -> bool:
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 0.0:
				return false

	return true

func set_single_pokemon(pokemon: Pokemon, side: String) -> void:
	set_single_pokemon_species(pokemon.species, side, pokemon.shiny)

func set_double_pokemon(pokemon_1: Pokemon, pokemon_2: Pokemon, side: String) -> void:
	set_battle_type(true)

	var frames_1 := _load_sprite_frames(pokemon_1.species, side, pokemon_1.shiny)
	var frames_2 := _load_sprite_frames(pokemon_2.species, side, pokemon_2.shiny)

	double_sprite_1.visible = true
	_reset_sprite_pose(double_sprite_1)
	if frames_1 != null:
		double_sprite_1.sprite_frames = frames_1
		double_sprite_1.animation = IDLE_ANIMATION
		double_sprite_1.frame = 0
		_snap_sprite_to_pixel_grid(double_sprite_1)
		double_sprite_1.play()

	double_sprite_2.visible = true
	_reset_sprite_pose(double_sprite_2)
	if frames_2 != null:
		double_sprite_2.sprite_frames = frames_2
		double_sprite_2.animation = IDLE_ANIMATION
		double_sprite_2.frame = 0
		_snap_sprite_to_pixel_grid(double_sprite_2)
		double_sprite_2.play()

func set_single_pokemon_species(species: String, side: String, is_shiny: bool = false) -> void:
	set_battle_type(false)
	
	single_sprite.visible = true
	_reset_sprite_pose(single_sprite)
	var frames := _load_sprite_frames(species, side, is_shiny)
	if frames == null:
		return
		
	single_sprite.sprite_frames = frames
	single_sprite.animation = IDLE_ANIMATION
	single_sprite.frame = 0
	_snap_sprite_to_pixel_grid(single_sprite)
	single_sprite.play()
