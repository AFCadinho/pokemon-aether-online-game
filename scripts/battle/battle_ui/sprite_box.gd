extends Control

@export var default_is_double_battle := false

const IDLE_ANIMATION := "idle"
const DEFAULT_SHEET_FRAME_SIZE := Vector2i(48, 57)
const MIN_SHEET_FRAME_SIZE := Vector2i(16, 16)
const MAX_SHEET_FRAME_SIZE := Vector2i(256, 256)
const FRAME_ANIMATION_SPEED := 3.0
const SHEET_ANIMATION_SPEED := 10.0
const BATTLE_SPRITE_SCALE := Vector2(2, 2)
const BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER := 0.85
const BATTLE_SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR
const BATTLE_SPRITE_STYLE_ORDER: Array[String] = ["legacy_showdown", "showdown", "gen5"]
const PIXEL_SPRITE_STYLE_ORDER: Array[String] = ["gen5", "legacy_showdown", "showdown"]
const HOME_SPRITE_RENDER_SCALE := 2.0
const ATTACK_TWEEN_OFFSET := Vector2(28, -6)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.18, 0.18, 1.0)
const DAMAGE_IMPACT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HEAL_FLASH_COLOR := Color(0.45, 1.0, 0.55, 1.0)
const STAT_RAISE_FLASH_COLOR := Color(0.38, 1.0, 0.48, 1.0)
const STAT_RAISE_SECONDARY_COLOR := Color(0.72, 1.0, 0.86, 1.0)
const STAT_DROP_FLASH_COLOR := Color(1.0, 0.22, 0.42, 1.0)
const STAT_DROP_SECONDARY_COLOR := Color(0.62, 0.35, 0.95, 1.0)
const STAT_STAGE_PANEL_GAP := 8.0
const FAINT_TWEEN_OFFSET := Vector2(0, 34)
const SPRITE_HOVER_PADDING := Vector2(8, 8)

@onready var single_container: Control = $SingleBattleContainer
@onready var double_container: Control = $DoubleBattleContainer

@onready var single_sprite_slot: Control = $SingleBattleContainer/SpriteSlot
@onready var single_sprite: AnimatedSprite2D = $SingleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var single_stat_stage_panel: Control = get_node_or_null("SingleBattleContainer/SpriteSlot/StatStagePanel") as Control
@onready var double_sprite_1: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite
@onready var double_sprite_2: AnimatedSprite2D = $DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2

var active_tween: Tween
var base_sprite_positions: Dictionary = {}
var sprite_target_scales: Dictionary = {}
var sprite_frames_render_scales: Dictionary = {}

func _ready() -> void:
	_set_sprite_filter(single_sprite)
	_set_sprite_filter(double_sprite_1)
	_set_sprite_filter(double_sprite_2)
	_cache_base_sprite_positions()
	set_battle_type(default_is_double_battle)
	clear_stat_stages()
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
	sprite.texture_filter = BATTLE_SPRITE_TEXTURE_FILTER
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
	_update_stat_stage_panel_positions()

func _snap_sprite_to_pixel_grid(sprite: AnimatedSprite2D) -> void:
	sprite.scale = _get_sprite_target_scale(sprite)

func reset_battle_pose() -> void:
	_stop_active_tween()
	for sprite in _get_all_sprites():
		_reset_sprite_pose(sprite)
	_update_stat_stage_panel_positions()

func clear_pokemon() -> void:
	_stop_active_tween()
	set_battle_type(false)
	clear_stat_stages()
	for sprite in _get_all_sprites():
		_reset_sprite_pose(sprite)
		sprite.visible = false

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
		active_tween.tween_property(sprite, "modulate", DAMAGE_IMPACT_COLOR, 0.03)
		active_tween.tween_property(sprite, "modulate", DAMAGE_FLASH_COLOR, 0.05).set_delay(0.03)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.08).set_delay(0.08)
		active_tween.tween_property(sprite, "position", base_position + Vector2(-12, 0), 0.035)
		active_tween.tween_property(sprite, "position", base_position + Vector2(10, 0), 0.04).set_delay(0.035)
		active_tween.tween_property(sprite, "position", base_position + Vector2(-5, 0), 0.035).set_delay(0.075)
		active_tween.tween_property(sprite, "position", base_position, 0.05).set_delay(0.11)

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
		var target_scale: Vector2 = _get_sprite_target_scale(sprite)
		active_tween.tween_property(sprite, "modulate", HEAL_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.14).set_delay(0.08)
		active_tween.tween_property(sprite, "scale", target_scale * 1.06, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", target_scale, 0.14).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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
		var target_scale: Vector2 = _get_sprite_target_scale(sprite)
		active_tween.tween_property(sprite, "modulate", STAT_RAISE_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", STAT_RAISE_SECONDARY_COLOR, 0.08).set_delay(0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.14).set_delay(0.16)
		active_tween.tween_property(sprite, "position", base_position + Vector2(0, -14), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.16).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		active_tween.tween_property(sprite, "scale", target_scale * 1.12, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", target_scale, 0.18).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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
		var target_scale: Vector2 = _get_sprite_target_scale(sprite)
		active_tween.tween_property(sprite, "modulate", STAT_DROP_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", STAT_DROP_SECONDARY_COLOR, 0.08).set_delay(0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16).set_delay(0.16)
		active_tween.tween_property(sprite, "position", base_position + Vector2(0, 12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.18).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		active_tween.tween_property(sprite, "scale", target_scale * 0.9, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", target_scale, 0.2).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	_update_stat_stage_panel_positions()

func _reset_sprite_pose(sprite: AnimatedSprite2D) -> void:
	sprite.position = _get_base_sprite_position(sprite)
	sprite.scale = _get_sprite_target_scale(sprite)
	sprite.modulate = Color.WHITE

func _get_base_sprite_position(sprite: AnimatedSprite2D) -> Vector2:
	var base_position_value: Variant = base_sprite_positions.get(_get_sprite_key(sprite), sprite.position)
	if base_position_value is Vector2:
		return base_position_value

	return sprite.position

func _set_sprite_target_scale_from_frames(sprite: AnimatedSprite2D, sprite_frames: SpriteFrames) -> void:
	var render_scale: float = _get_sprite_frames_render_scale(sprite_frames)
	if render_scale <= 0.0:
		sprite_target_scales[_get_sprite_key(sprite)] = BATTLE_SPRITE_SCALE
		return

	sprite_target_scales[_get_sprite_key(sprite)] = (BATTLE_SPRITE_SCALE / render_scale) * BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER

func _get_sprite_target_scale(sprite: AnimatedSprite2D) -> Vector2:
	var target_scale_value: Variant = sprite_target_scales.get(_get_sprite_key(sprite), BATTLE_SPRITE_SCALE)
	if target_scale_value is Vector2:
		return target_scale_value

	return BATTLE_SPRITE_SCALE

func _set_sprite_frames_render_scale(sprite_frames: SpriteFrames, render_scale: float) -> void:
	sprite_frames_render_scales[_get_sprite_frames_key(sprite_frames)] = max(render_scale, 1.0)

func _get_sprite_frames_render_scale(sprite_frames: SpriteFrames) -> float:
	var render_scale_value: Variant = sprite_frames_render_scales.get(_get_sprite_frames_key(sprite_frames), 1.0)
	if render_scale_value is float:
		return render_scale_value
	if render_scale_value is int:
		return float(render_scale_value)

	return 1.0

func _get_sprite_frames_key(sprite_frames: SpriteFrames) -> String:
	if sprite_frames == null:
		return ""

	return str(sprite_frames.get_instance_id())

func _load_sprite_frames(species: String, side: String, is_shiny: bool = false) -> SpriteFrames:
	for sprite_root in _get_sprite_asset_roots(side, is_shiny):
		for asset_id in _get_species_asset_id_candidates(species):
			for sheet_metadata_path in PokemonAssets.build_pokemon_sprite_path("%s/%s/animation.json" % [sprite_root, asset_id]):
				var metadata_frames := _load_sprite_frames_from_sheet_metadata(sheet_metadata_path, sprite_root, species)
				if metadata_frames != null:
					return metadata_frames

			for folder in PokemonAssets.build_pokemon_sprite_path("%s/%s" % [sprite_root, asset_id]):
				var folder_frames := _load_sprite_frames_from_folder(folder)
				if folder_frames != null:
					return folder_frames

			for sheet_path in PokemonAssets.build_pokemon_sprite_path("%s/%s.png" % [sprite_root, asset_id]):
				var sheet_frames := _load_sprite_frames_from_sheet(sheet_path)
				if sheet_frames != null:
					return sheet_frames

	var home_frames := _load_sprite_frames_from_home_sprite(species, is_shiny)
	if home_frames != null:
		return home_frames

	push_error("Pokemon sprite assets are not found for %s/%s" % [side, species])
	return null

func _get_sprite_asset_roots(side: String, is_shiny: bool) -> Array[String]:
	var roots: Array[String] = []
	var style_order: Array[String] = BATTLE_SPRITE_STYLE_ORDER
	if (
		SettingsManager.sprite_style == SettingsManager.SPRITE_STYLE_GEN5_ANIMATED
		and SettingsManager.is_gen5_animated_sprites_installed()
	):
		style_order = PIXEL_SPRITE_STYLE_ORDER

	for style in style_order:
		roots.append_array(_get_sprite_asset_roots_for_style(style, side, is_shiny))

	return roots

func _get_sprite_asset_roots_for_style(style: String, side: String, is_shiny: bool) -> Array[String]:
	var roots: Array[String] = []
	var side_folder: String = _get_sprite_side_folder(side, is_shiny)

	match style:
		"showdown":
			roots.append("showdown/%s" % side_folder)
		"gen5":
			roots.append("gen5/%s" % side_folder)
		"legacy_showdown":
			roots.append(side_folder)

	return roots

func _get_sprite_side_folder(side: String, is_shiny: bool) -> String:
	if is_shiny:
		return "shiny_%s" % side

	return side

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
		var texture := PokemonAssets.load_texture(folder + "/" + frame_file)
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
	var sheet_texture := PokemonAssets.load_texture(sheet_path)
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

	_set_sprite_frames_render_scale(sprite_frames, _get_metadata_render_scale(metadata, side))
	return sprite_frames

func _get_metadata_render_scale(metadata: Dictionary, side: String) -> float:
	if metadata.has("render_scale"):
		return max(float(metadata.get("render_scale", 1.0)), 1.0)
	if metadata.has("scale"):
		return max(float(metadata.get("scale", 1.0)), 1.0)

	var frame_width := float(metadata.get("frame_width", 0.0))
	var frame_height := float(metadata.get("frame_height", 0.0))
	var is_front_sprite := side == "front" or side == "shiny_front"
	if is_front_sprite and max(frame_width, frame_height) >= 160.0:
		return 2.0

	return 1.0

func _load_sprite_frames_from_sheet(sheet_path: String) -> SpriteFrames:
	if sheet_path.begins_with("res://") and not ResourceLoader.exists(sheet_path):
		return null
	if not sheet_path.begins_with("res://") and not FileAccess.file_exists(sheet_path):
		return null

	var sheet_texture := PokemonAssets.load_texture(sheet_path)
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

func _load_sprite_frames_from_home_sprite(species: String, is_shiny: bool) -> SpriteFrames:
	var texture: Texture2D = PokemonAssets.load_home_sprite(species, is_shiny)
	if texture == null:
		return null

	var sprite_frames := _create_idle_sprite_frames(1.0)
	sprite_frames.add_frame(IDLE_ANIMATION, texture)
	_set_sprite_frames_render_scale(sprite_frames, HOME_SPRITE_RENDER_SCALE)
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
	double_sprite_1.visible = false
	double_sprite_2.visible = false

	var frames_1 := _load_sprite_frames(pokemon_1.species, side, pokemon_1.shiny)
	var frames_2 := _load_sprite_frames(pokemon_2.species, side, pokemon_2.shiny)

	_reset_sprite_pose(double_sprite_1)
	if frames_1 != null:
		double_sprite_1.sprite_frames = frames_1
		double_sprite_1.animation = IDLE_ANIMATION
		double_sprite_1.frame = 0
		_set_sprite_target_scale_from_frames(double_sprite_1, frames_1)
		_snap_sprite_to_pixel_grid(double_sprite_1)
		double_sprite_1.visible = true
		_apply_sprite_playback_mode(double_sprite_1)

	_reset_sprite_pose(double_sprite_2)
	if frames_2 != null:
		double_sprite_2.sprite_frames = frames_2
		double_sprite_2.animation = IDLE_ANIMATION
		double_sprite_2.frame = 0
		_set_sprite_target_scale_from_frames(double_sprite_2, frames_2)
		_snap_sprite_to_pixel_grid(double_sprite_2)
		double_sprite_2.visible = true
		_apply_sprite_playback_mode(double_sprite_2)

func set_single_pokemon_species(species: String, side: String, is_shiny: bool = false) -> void:
	set_battle_type(false)
	
	single_sprite.visible = false
	_reset_sprite_pose(single_sprite)
	var frames := _load_sprite_frames(species, side, is_shiny)
	if frames == null:
		return
		
	single_sprite.sprite_frames = frames
	single_sprite.animation = IDLE_ANIMATION
	single_sprite.frame = 0
	_set_sprite_target_scale_from_frames(single_sprite, frames)
	_snap_sprite_to_pixel_grid(single_sprite)
	single_sprite.visible = true
	_apply_sprite_playback_mode(single_sprite)
	_position_stat_stage_panel(single_sprite, single_stat_stage_panel)

func _apply_sprite_playback_mode(sprite: AnimatedSprite2D) -> void:
	if SettingsManager.sprite_style == SettingsManager.SPRITE_STYLE_STATIC:
		sprite.stop()
		sprite.frame = 0
		return

	sprite.play()

func set_stat_stages(stages: Dictionary) -> void:
	if single_stat_stage_panel != null and single_stat_stage_panel.has_method("set_stat_stages"):
		single_stat_stage_panel.call("set_stat_stages", stages)

	_position_stat_stage_panel(single_sprite, single_stat_stage_panel)

func set_stat_stage_badges(badges: Array) -> void:
	if single_stat_stage_panel != null and single_stat_stage_panel.has_method("set_badges"):
		single_stat_stage_panel.call("set_badges", badges)

	_position_stat_stage_panel(single_sprite, single_stat_stage_panel)

func clear_stat_stages() -> void:
	if single_stat_stage_panel == null:
		return

	if single_stat_stage_panel.has_method("clear"):
		single_stat_stage_panel.call("clear")
	else:
		single_stat_stage_panel.visible = false

func _update_stat_stage_panel_positions() -> void:
	_position_stat_stage_panel(single_sprite, single_stat_stage_panel)

func _position_stat_stage_panel(sprite: AnimatedSprite2D, panel: Control) -> void:
	if sprite == null or panel == null:
		return
	if not sprite.visible:
		panel.visible = false
		return
	if panel.get_child_count() == 0:
		return

	panel.reset_size()
	var panel_size: Vector2 = panel.size
	var sprite_size: Vector2 = _get_sprite_display_size(sprite)
	var top_center: Vector2 = sprite.position - Vector2(0, sprite_size.y * 0.5)
	panel.position = top_center - Vector2(panel_size.x * 0.5, panel_size.y + STAT_STAGE_PANEL_GAP)

func _get_sprite_display_size(sprite: AnimatedSprite2D) -> Vector2:
	var texture: Texture2D = _get_current_sprite_texture(sprite)
	var frame_size: Vector2 = Vector2(DEFAULT_SHEET_FRAME_SIZE)
	if texture != null:
		frame_size = texture.get_size()

	return frame_size * Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
