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
const GEN5_BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER := 1.25
const BATTLE_SPRITE_TEXTURE_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR
const BATTLE_SPRITE_STYLE_ORDER: Array[String] = ["legacy_showdown", "showdown", "gen5"]
const PIXEL_SPRITE_STYLE_ORDER: Array[String] = ["gen5", "legacy_showdown", "showdown"]
const HOME_SPRITE_RENDER_SCALE := 2.0
const BATTLE_SPRITE_ASSET_ALIASES := {
	# Battle payloads use this form name, while the battle-sheet directory is
	# the base species. Without the alias the loader falls through to the HOME
	# icon, then gets refreshed to the real battle sprite by later state data.
	"mimikyu-disguised": ["mimikyu"],
	# Showdown's animated sprite pack omits the separator between Rock and Star.
	"pikachu-rock-star": ["pikachu-rockstar"],
}
const SPECIES_POSITION_OFFSETS := {
	"back:charizard": Vector2(-46, -10),
	"shiny_back:charizard": Vector2(-46, -10),
	"back:mimikyu": Vector2(0, 10),
	"back:mimikyu-busted": Vector2(0, 10),
	"shiny_back:mimikyu": Vector2(0, 10),
	"shiny_back:mimikyu-busted": Vector2(0, 10),
	"front:mimikyu": Vector2(0, 8),
	"front:mimikyu-busted": Vector2(0, 8),
	"shiny_front:mimikyu": Vector2(0, 8),
	"shiny_front:mimikyu-busted": Vector2(0, 8),
}
const ATTACK_TWEEN_OFFSET := Vector2(28, -6)
const DAMAGE_FLASH_COLOR := Color(1.0, 0.18, 0.18, 1.0)
const DAMAGE_IMPACT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HEAL_FLASH_COLOR := Color(0.45, 1.0, 0.55, 1.0)
const STAT_RAISE_FLASH_COLOR := Color(0.28, 0.82, 1.0, 1.0)
const STAT_RAISE_SECONDARY_COLOR := Color(0.7, 0.94, 1.0, 1.0)
const STAT_DROP_FLASH_COLOR := Color(1.0, 0.22, 0.42, 1.0)
const STAT_DROP_SECONDARY_COLOR := Color(0.62, 0.35, 0.95, 1.0)
const STAT_CHANGE_REFERENCE_SIZE := Vector2(450.0, 293.0)
const STAT_CHANGE_MIN_MOTION_SCALE := 0.6
const STAT_RAISE_TWEEN_OFFSET := Vector2(0.0, -10.0)
const STAT_DROP_TWEEN_OFFSET := Vector2(0.0, 8.0)
const STAT_RAISE_SCALE_MULTIPLIER := 1.07
const STAT_DROP_SCALE_MULTIPLIER := 0.94
const STAT_STAGE_PANEL_GAP := 8.0
const FAINT_TWEEN_OFFSET := Vector2(0, 34)
const SPRITE_HOVER_PADDING := Vector2(8, 8)
const SPRITE_ALPHA_BOUNDS_THRESHOLD := 0.02
const SUBSTITUTE_SHEET: Texture2D = preload("res://assets/battles/animations/substitute/PRAS- Substitute.png")
const SUBSTITUTE_CELL_SIZE := Vector2(192.0, 192.0)
const SUBSTITUTE_DISPLAY_SCALE := Vector2(2.0, 2.0)
const SUBSTITUTE_FRONT_REGION := Rect2(Vector2.ZERO, SUBSTITUTE_CELL_SIZE)
const SUBSTITUTE_BACK_REGION := Rect2(Vector2(SUBSTITUTE_CELL_SIZE.x, 0.0), SUBSTITUTE_CELL_SIZE)
const SUBSTITUTE_CROSSFADE_SECONDS := 0.14
const SUBSTITUTE_RETREAT_OFFSET := Vector2(18.0, 7.0)

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
var sprite_frames_display_scale_multipliers: Dictionary = {}
var sprite_frames_position_offsets: Dictionary = {}
var sprite_frames_anchors: Dictionary = {}
var sprite_frames_frame_sizes: Dictionary = {}
var sprite_frames_visual_bounds: Dictionary = {}
var sprite_frames_cache: Dictionary = {}
var current_single_species := ""
var current_single_side := ""
var current_single_is_shiny := false
var stat_stage_panel_anchor: Control
var substitute_sprite: Sprite2D
var substitute_tween: Tween
var substitute_active := false
var substitute_revealed_for_move := false

func _ready() -> void:
	_set_sprite_filter(single_sprite)
	_set_sprite_filter(double_sprite_1)
	_set_sprite_filter(double_sprite_2)
	_cache_base_sprite_positions()
	_create_substitute_sprite()
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
	var visual_rect := _get_sprite_visual_rect_global(sprite)
	return Rect2(visual_rect.position - SPRITE_HOVER_PADDING, visual_rect.size + (SPRITE_HOVER_PADDING * 2.0))

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

func set_battle_sprites_visible(is_visible: bool) -> Array:
	var changed_sprites: Array = []
	for sprite in _get_all_sprites():
		if sprite.visible != is_visible:
			changed_sprites.append(sprite)
			sprite.visible = is_visible
	return changed_sprites

func restore_battle_sprites_visibility(sprites: Array) -> void:
	for sprite_value: Variant in sprites:
		if sprite_value is AnimatedSprite2D:
			(sprite_value as AnimatedSprite2D).visible = true

func _get_sprite_key(sprite: AnimatedSprite2D) -> String:
	return str(sprite.get_path())

func _snap_all_sprites_to_pixel_grid() -> void:
	_snap_sprite_to_pixel_grid(single_sprite)
	_snap_sprite_to_pixel_grid(double_sprite_1)
	_snap_sprite_to_pixel_grid(double_sprite_2)
	_update_stat_stage_panel_positions()

func _snap_sprite_to_pixel_grid(sprite: AnimatedSprite2D) -> void:
	sprite.position = _get_base_sprite_position(sprite)
	sprite.scale = _get_sprite_target_scale(sprite)
	_apply_sprite_anchor(sprite)

func reset_battle_pose() -> void:
	_stop_active_tween()
	for sprite in _get_all_sprites():
		_reset_sprite_pose(sprite)
	_update_stat_stage_panel_positions()

func clear_pokemon() -> void:
	_stop_active_tween()
	clear_substitute_immediately()
	set_battle_type(false)
	clear_stat_stages()
	current_single_species = ""
	current_single_side = ""
	current_single_is_shiny = false
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

func set_substitute_active(is_active: bool, animate := true) -> void:
	if substitute_sprite == null:
		return
	if substitute_active == is_active and not substitute_revealed_for_move:
		_sync_substitute_idle_pose()
		return

	_stop_active_tween()
	_stop_substitute_tween()
	substitute_revealed_for_move = false
	var should_animate := animate and is_inside_tree() and single_sprite.visible
	if is_active:
		_reset_sprite_pose(single_sprite)
		substitute_active = true
		_sync_substitute_region()
		substitute_sprite.visible = true
		substitute_sprite.position = _get_substitute_idle_position()
		substitute_sprite.rotation = 0.0
		if not should_animate:
			substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
			substitute_sprite.modulate = Color.WHITE
			single_sprite.modulate = _with_alpha(single_sprite.modulate, 0.0)
			return

		substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE * 1.08
		substitute_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		substitute_tween = create_tween().set_parallel(true)
		substitute_tween.tween_property(single_sprite, "modulate:a", 0.0, SUBSTITUTE_CROSSFADE_SECONDS)
		substitute_tween.tween_property(substitute_sprite, "modulate:a", 1.0, SUBSTITUTE_CROSSFADE_SECONDS)
		substitute_tween.tween_property(substitute_sprite, "scale", SUBSTITUTE_DISPLAY_SCALE, SUBSTITUTE_CROSSFADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await substitute_tween.finished
		_sync_substitute_idle_pose()
		return

	substitute_active = false
	if not should_animate:
		substitute_sprite.visible = false
		substitute_sprite.modulate = Color.WHITE
		substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
		single_sprite.modulate = Color.WHITE
		return

	substitute_tween = create_tween().set_parallel(true)
	substitute_tween.tween_property(substitute_sprite, "modulate:a", 0.0, SUBSTITUTE_CROSSFADE_SECONDS)
	substitute_tween.tween_property(substitute_sprite, "scale", SUBSTITUTE_DISPLAY_SCALE * 0.82, SUBSTITUTE_CROSSFADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	substitute_tween.tween_property(single_sprite, "modulate:a", 1.0, SUBSTITUTE_CROSSFADE_SECONDS)
	await substitute_tween.finished
	substitute_sprite.visible = false
	substitute_sprite.modulate = Color.WHITE
	substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
	single_sprite.modulate = Color.WHITE

func reveal_pokemon_from_substitute_for_move() -> bool:
	if not substitute_active or substitute_sprite == null or not single_sprite.visible:
		return false

	_stop_active_tween()
	_stop_substitute_tween()
	_reset_sprite_pose(single_sprite)
	substitute_revealed_for_move = true
	var retreat_direction := -1.0 if current_single_side == "back" else 1.0
	var retreat_offset := Vector2(SUBSTITUTE_RETREAT_OFFSET.x * retreat_direction, SUBSTITUTE_RETREAT_OFFSET.y)
	substitute_sprite.visible = true
	substitute_sprite.position = _get_substitute_idle_position()
	substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
	substitute_sprite.modulate = Color.WHITE
	single_sprite.modulate = _with_alpha(single_sprite.modulate, 0.0)

	substitute_tween = create_tween().set_parallel(true)
	substitute_tween.tween_property(substitute_sprite, "position", _get_substitute_idle_position() + retreat_offset, SUBSTITUTE_CROSSFADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	substitute_tween.tween_property(substitute_sprite, "modulate:a", 0.0, SUBSTITUTE_CROSSFADE_SECONDS)
	substitute_tween.tween_property(substitute_sprite, "scale", SUBSTITUTE_DISPLAY_SCALE * 0.88, SUBSTITUTE_CROSSFADE_SECONDS)
	substitute_tween.tween_property(single_sprite, "modulate:a", 1.0, SUBSTITUTE_CROSSFADE_SECONDS)
	await substitute_tween.finished
	substitute_sprite.visible = false
	_reset_sprite_pose(single_sprite)
	return true

func restore_substitute_after_move() -> void:
	if not substitute_active or substitute_sprite == null:
		return

	_stop_active_tween()
	_stop_substitute_tween()
	_reset_sprite_pose(single_sprite)
	var retreat_direction := -1.0 if current_single_side == "back" else 1.0
	var retreat_offset := Vector2(SUBSTITUTE_RETREAT_OFFSET.x * retreat_direction, SUBSTITUTE_RETREAT_OFFSET.y)
	substitute_sprite.visible = true
	substitute_sprite.position = _get_substitute_idle_position() + retreat_offset
	substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE * 0.88
	substitute_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	single_sprite.modulate = Color.WHITE

	substitute_tween = create_tween().set_parallel(true)
	substitute_tween.tween_property(single_sprite, "modulate:a", 0.0, SUBSTITUTE_CROSSFADE_SECONDS)
	substitute_tween.tween_property(substitute_sprite, "position", _get_substitute_idle_position(), SUBSTITUTE_CROSSFADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	substitute_tween.tween_property(substitute_sprite, "modulate:a", 1.0, SUBSTITUTE_CROSSFADE_SECONDS)
	substitute_tween.tween_property(substitute_sprite, "scale", SUBSTITUTE_DISPLAY_SCALE, SUBSTITUTE_CROSSFADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await substitute_tween.finished
	substitute_revealed_for_move = false
	_sync_substitute_idle_pose()

func play_substitute_damage_tween() -> void:
	if not substitute_active or substitute_sprite == null or substitute_revealed_for_move:
		return

	_stop_substitute_tween()
	_sync_substitute_idle_pose()
	var base_position := _get_substitute_idle_position()
	substitute_tween = create_tween().set_parallel(true)
	substitute_tween.tween_property(substitute_sprite, "modulate", DAMAGE_IMPACT_COLOR, 0.03)
	substitute_tween.tween_property(substitute_sprite, "modulate", DAMAGE_FLASH_COLOR, 0.05).set_delay(0.03)
	substitute_tween.tween_property(substitute_sprite, "modulate", Color.WHITE, 0.08).set_delay(0.08)
	substitute_tween.tween_property(substitute_sprite, "position", base_position + Vector2(-10.0, 0.0), 0.035)
	substitute_tween.tween_property(substitute_sprite, "position", base_position + Vector2(9.0, 0.0), 0.04).set_delay(0.035)
	substitute_tween.tween_property(substitute_sprite, "position", base_position + Vector2(-4.0, 0.0), 0.035).set_delay(0.075)
	substitute_tween.tween_property(substitute_sprite, "position", base_position, 0.05).set_delay(0.11)
	await substitute_tween.finished
	_sync_substitute_idle_pose()

func clear_substitute_immediately() -> void:
	_stop_active_tween()
	_stop_substitute_tween()
	substitute_active = false
	substitute_revealed_for_move = false
	if substitute_sprite != null:
		substitute_sprite.visible = false
		substitute_sprite.position = _get_substitute_idle_position()
		substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
		substitute_sprite.rotation = 0.0
		substitute_sprite.modulate = Color.WHITE
	if single_sprite != null:
		single_sprite.modulate = Color.WHITE

func has_active_substitute() -> bool:
	return substitute_active

func play_move_actor_motion(motion_config: Dictionary = {}, motion_direction: Vector2 = Vector2.ONE) -> void:
	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	var points_value: Variant = motion_config.get("points", [])
	if not points_value is Array:
		return

	var points: Array = points_value as Array
	if points.is_empty():
		return

	var duration: float = max(float(motion_config.get("duration", 0.45)), 0.05)
	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		var target_scale: Vector2 = _get_sprite_target_scale(sprite)
		for point_value: Variant in points:
			if not point_value is Dictionary:
				continue

			var point: Dictionary = point_value as Dictionary
			var at: float = clamp(float(point.get("at", 0.0)), 0.0, 1.0)
			var delay: float = at * duration
			var offset: Vector2 = _read_motion_offset(point.get("offset", [0, 0]))
			offset *= motion_direction
			var rotation: float = deg_to_rad(float(point.get("rotation_degrees", 0.0)) * motion_direction.x)
			var scale_multiplier: float = max(float(point.get("scale", 1.0)), 0.1)
			var segment_duration: float = max(float(point.get("duration", 0.05)), 0.01)

			active_tween.tween_property(sprite, "position", base_position + offset, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			active_tween.tween_property(sprite, "rotation", rotation, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			active_tween.tween_property(sprite, "scale", target_scale * scale_multiplier, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if point.has("opacity"):
				var opacity: float = clampf(float(point.get("opacity", 1.0)), 0.0, 1.0)
				active_tween.tween_property(sprite, "modulate:a", opacity, segment_duration).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_damage_tween() -> void:
	if substitute_active and not substitute_revealed_for_move:
		await play_substitute_damage_tween()
		return

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


func play_hit_flash_tween(flash_config: Dictionary = {}) -> void:
	if substitute_active and not substitute_revealed_for_move:
		await _play_substitute_hit_flash_tween(flash_config)
		return

	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	var delay: float = maxf(float(flash_config.get("delay", 0.0)), 0.0)
	var flash_duration: float = maxf(float(flash_config.get("duration", 0.09)), 0.02)
	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		active_tween.tween_property(sprite, "modulate", DAMAGE_FLASH_COLOR, flash_duration * 0.36).set_delay(delay)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, flash_duration * 0.64).set_delay(delay + flash_duration * 0.36)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func play_shake_tween(shake_config: Dictionary = {}) -> void:
	if substitute_active and not substitute_revealed_for_move:
		await _play_substitute_shake_tween(shake_config)
		return

	var sprites := _get_visible_sprites()
	if sprites.is_empty():
		return

	var duration: float = maxf(float(shake_config.get("duration", 0.65)), 0.05)
	var interval: float = maxf(float(shake_config.get("interval", 0.045)), 0.01)
	var amplitude: float = maxf(float(shake_config.get("amplitude", 8.0)), 0.0)
	var vertical_scale: float = maxf(float(shake_config.get("vertical_scale", 0.35)), 0.0)
	var decay := bool(shake_config.get("decay", true))
	var delay: float = maxf(float(shake_config.get("delay", 0.0)), 0.0)
	var step_count: int = maxi(int(ceil(duration / interval)), 1)

	_stop_active_tween()
	_reset_sprites_pose(sprites)
	active_tween = create_tween()
	active_tween.set_parallel(true)

	for sprite in sprites:
		var base_position := _get_base_sprite_position(sprite)
		for step: int in range(step_count):
			var progress := float(step) / float(maxi(step_count - 1, 1))
			var step_amplitude := amplitude * (1.0 - progress if decay else 1.0)
			var direction := -1.0 if step % 2 == 0 else 1.0
			var vertical_direction := -1.0 if step % 4 < 2 else 1.0
			var offset := Vector2(
				roundf(step_amplitude * direction),
				roundf(step_amplitude * vertical_scale * vertical_direction)
			)
			active_tween.tween_property(sprite, "position", base_position + offset, interval).set_delay(delay + float(step) * interval).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		active_tween.tween_property(sprite, "position", base_position, interval).set_delay(delay + duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
		active_tween.tween_property(sprite, "modulate", HEAL_FLASH_COLOR, 0.1)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18).set_delay(0.1)
		active_tween.tween_property(sprite, "scale", target_scale * 1.025, 0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", target_scale, 0.17).set_delay(0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
		var motion_scale := _get_stat_change_motion_scale()
		var peak_scale_multiplier := _get_stat_change_scale_multiplier(STAT_RAISE_SCALE_MULTIPLIER, motion_scale)
		active_tween.tween_property(sprite, "modulate", STAT_RAISE_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", STAT_RAISE_SECONDARY_COLOR, 0.08).set_delay(0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.14).set_delay(0.16)
		active_tween.tween_property(sprite, "position", base_position + STAT_RAISE_TWEEN_OFFSET * motion_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.16).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		active_tween.tween_property(sprite, "scale", target_scale * peak_scale_multiplier, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		var motion_scale := _get_stat_change_motion_scale()
		var dip_scale_multiplier := _get_stat_change_scale_multiplier(STAT_DROP_SCALE_MULTIPLIER, motion_scale)
		active_tween.tween_property(sprite, "modulate", STAT_DROP_FLASH_COLOR, 0.08)
		active_tween.tween_property(sprite, "modulate", STAT_DROP_SECONDARY_COLOR, 0.08).set_delay(0.08)
		active_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16).set_delay(0.16)
		active_tween.tween_property(sprite, "position", base_position + STAT_DROP_TWEEN_OFFSET * motion_scale, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "position", base_position, 0.18).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		active_tween.tween_property(sprite, "scale", target_scale * dip_scale_multiplier, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(sprite, "scale", target_scale, 0.2).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await active_tween.finished
	_reset_sprites_pose(sprites)

func _get_stat_change_motion_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0

	var width_scale := size.x / STAT_CHANGE_REFERENCE_SIZE.x
	var height_scale := size.y / STAT_CHANGE_REFERENCE_SIZE.y
	return clampf(minf(width_scale, height_scale), STAT_CHANGE_MIN_MOTION_SCALE, 1.0)

func _get_stat_change_scale_multiplier(multiplier: float, motion_scale: float) -> float:
	return 1.0 + (multiplier - 1.0) * motion_scale

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
	clear_pokemon()

func _stop_active_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = null

func _create_substitute_sprite() -> void:
	substitute_sprite = Sprite2D.new()
	substitute_sprite.name = "SubstituteSprite"
	substitute_sprite.texture = SUBSTITUTE_SHEET
	substitute_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	substitute_sprite.region_enabled = true
	substitute_sprite.centered = true
	substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
	substitute_sprite.z_index = 12
	substitute_sprite.visible = false
	single_sprite_slot.add_child(substitute_sprite)
	_sync_substitute_region()
	_sync_substitute_idle_pose()

func _sync_substitute_region() -> void:
	if substitute_sprite == null:
		return
	substitute_sprite.region_rect = SUBSTITUTE_BACK_REGION if current_single_side == "back" else SUBSTITUTE_FRONT_REGION

func _sync_substitute_idle_pose() -> void:
	if substitute_sprite == null:
		return
	_sync_substitute_region()
	substitute_sprite.position = _get_substitute_idle_position()
	substitute_sprite.scale = SUBSTITUTE_DISPLAY_SCALE
	substitute_sprite.rotation = 0.0
	substitute_sprite.modulate = Color.WHITE
	substitute_sprite.visible = substitute_active and not substitute_revealed_for_move
	if single_sprite != null:
		single_sprite.modulate = _with_alpha(single_sprite.modulate, 0.0 if substitute_active and not substitute_revealed_for_move else 1.0)

func _get_substitute_idle_position() -> Vector2:
	if single_sprite == null:
		return Vector2.ZERO
	# The imported cells keep generous transparent margins. These offsets place
	# the visible doll's feet exactly on the Pokemon battle anchor.
	var battle_anchor := get_single_battle_anchor_in_node(single_sprite_slot)
	if battle_anchor == Vector2.ZERO:
		battle_anchor = _get_base_sprite_position(single_sprite)
	var horizontal_offset := -2.0 if current_single_side == "back" else 4.0
	return battle_anchor + Vector2(horizontal_offset, -52.0)

func _play_substitute_hit_flash_tween(flash_config: Dictionary = {}) -> void:
	if substitute_sprite == null:
		return
	var delay: float = maxf(float(flash_config.get("delay", 0.0)), 0.0)
	var flash_duration: float = maxf(float(flash_config.get("duration", 0.09)), 0.02)
	_stop_substitute_tween()
	_sync_substitute_idle_pose()
	substitute_tween = create_tween().set_parallel(true)
	substitute_tween.tween_property(substitute_sprite, "modulate", DAMAGE_FLASH_COLOR, flash_duration * 0.36).set_delay(delay)
	substitute_tween.tween_property(substitute_sprite, "modulate", Color.WHITE, flash_duration * 0.64).set_delay(delay + flash_duration * 0.36)
	await substitute_tween.finished
	_sync_substitute_idle_pose()

func _play_substitute_shake_tween(shake_config: Dictionary = {}) -> void:
	if substitute_sprite == null:
		return
	var duration: float = maxf(float(shake_config.get("duration", 0.65)), 0.05)
	var interval: float = maxf(float(shake_config.get("interval", 0.045)), 0.01)
	var amplitude: float = maxf(float(shake_config.get("amplitude", 8.0)), 0.0)
	var vertical_scale: float = maxf(float(shake_config.get("vertical_scale", 0.35)), 0.0)
	var decay := bool(shake_config.get("decay", true))
	var delay: float = maxf(float(shake_config.get("delay", 0.0)), 0.0)
	var step_count: int = maxi(int(ceil(duration / interval)), 1)
	var base_position := _get_substitute_idle_position()
	_stop_substitute_tween()
	_sync_substitute_idle_pose()
	substitute_tween = create_tween().set_parallel(true)
	for step: int in range(step_count):
		var progress := float(step) / float(maxi(step_count - 1, 1))
		var step_amplitude := amplitude * (1.0 - progress if decay else 1.0)
		var direction := -1.0 if step % 2 == 0 else 1.0
		var vertical_direction := -1.0 if step % 4 < 2 else 1.0
		var offset := Vector2(
			roundf(step_amplitude * direction),
			roundf(step_amplitude * vertical_scale * vertical_direction)
		)
		substitute_tween.tween_property(substitute_sprite, "position", base_position + offset, interval).set_delay(delay + float(step) * interval).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	substitute_tween.tween_property(substitute_sprite, "position", base_position, interval).set_delay(delay + duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await substitute_tween.finished
	_sync_substitute_idle_pose()

func _stop_substitute_tween() -> void:
	if substitute_tween != null and substitute_tween.is_valid():
		substitute_tween.kill()
	substitute_tween = null

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))

func _reset_sprites_pose(sprites: Array[AnimatedSprite2D]) -> void:
	for sprite in sprites:
		_reset_sprite_pose(sprite)
	_update_stat_stage_panel_positions()

func _reset_sprite_pose(sprite: AnimatedSprite2D) -> void:
	sprite.position = _get_base_sprite_position(sprite)
	sprite.scale = _get_sprite_target_scale(sprite)
	sprite.rotation = 0.0
	_apply_sprite_anchor(sprite)
	if sprite == single_sprite and substitute_active and not substitute_revealed_for_move:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	else:
		sprite.modulate = Color.WHITE

func _read_motion_offset(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array:
		var values := value as Array
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))

	return Vector2.ZERO

func _get_base_sprite_position(sprite: AnimatedSprite2D) -> Vector2:
	var base_position_value: Variant = base_sprite_positions.get(_get_sprite_key(sprite), sprite.position)
	if base_position_value is Vector2:
		var base_position := base_position_value as Vector2
		return base_position + _get_sprite_frames_position_offset(sprite.sprite_frames)

	return sprite.position + _get_sprite_frames_position_offset(sprite.sprite_frames)

func _set_sprite_target_scale_from_frames(sprite: AnimatedSprite2D, sprite_frames: SpriteFrames) -> void:
	var render_scale: float = _get_sprite_frames_render_scale(sprite_frames)
	if render_scale <= 0.0:
		sprite_target_scales[_get_sprite_key(sprite)] = BATTLE_SPRITE_SCALE
		return

	var display_scale_multiplier: float = BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER * _get_sprite_frames_display_scale_multiplier(sprite_frames)
	sprite_target_scales[_get_sprite_key(sprite)] = (BATTLE_SPRITE_SCALE / render_scale) * display_scale_multiplier

func _get_sprite_target_scale(sprite: AnimatedSprite2D) -> Vector2:
	var target_scale_value: Variant = sprite_target_scales.get(_get_sprite_key(sprite), BATTLE_SPRITE_SCALE)
	if target_scale_value is Vector2:
		return target_scale_value

	return BATTLE_SPRITE_SCALE

func _set_sprite_frames_render_scale(sprite_frames: SpriteFrames, render_scale: float) -> void:
	sprite_frames_render_scales[_get_sprite_frames_key(sprite_frames)] = max(render_scale, 1.0)

func _set_sprite_frames_display_scale_multiplier(sprite_frames: SpriteFrames, multiplier: float) -> void:
	sprite_frames_display_scale_multipliers[_get_sprite_frames_key(sprite_frames)] = max(multiplier, 1.0)

func _set_sprite_frames_position_offset(sprite_frames: SpriteFrames, position_offset: Vector2) -> void:
	sprite_frames_position_offsets[_get_sprite_frames_key(sprite_frames)] = position_offset

func _set_sprite_frames_anchor(sprite_frames: SpriteFrames, anchor: Vector2, frame_size: Vector2) -> void:
	var key := _get_sprite_frames_key(sprite_frames)
	sprite_frames_anchors[key] = anchor
	sprite_frames_frame_sizes[key] = frame_size

func _set_sprite_frames_frame_size(sprite_frames: SpriteFrames, frame_size: Vector2) -> void:
	sprite_frames_frame_sizes[_get_sprite_frames_key(sprite_frames)] = frame_size

func _set_sprite_frames_visual_bounds(sprite_frames: SpriteFrames, visual_bounds: Rect2) -> void:
	sprite_frames_visual_bounds[_get_sprite_frames_key(sprite_frames)] = visual_bounds

func _set_sprite_frames_auto_anchor(sprite_frames: SpriteFrames, frame_size: Vector2) -> void:
	if sprite_frames == null:
		return

	var visual_bounds := _calculate_sprite_frames_visual_bounds(sprite_frames, frame_size)
	_set_sprite_frames_visual_bounds(sprite_frames, visual_bounds)
	_set_sprite_frames_anchor(sprite_frames, _get_visual_bounds_horizontal_anchor(visual_bounds, frame_size), frame_size)

func _calculate_sprite_frames_visual_bounds(sprite_frames: SpriteFrames, frame_size: Vector2) -> Rect2:
	if sprite_frames == null or not sprite_frames.has_animation(IDLE_ANIMATION):
		return Rect2(Vector2.ZERO, frame_size)

	var frame_count: int = sprite_frames.get_frame_count(IDLE_ANIMATION)
	var merged_bounds := Rect2()
	var has_bounds := false
	for frame_index: int in range(frame_count):
		var texture := sprite_frames.get_frame_texture(IDLE_ANIMATION, frame_index)
		var bounds := _calculate_texture_alpha_bounds(texture)
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			continue

		if has_bounds:
			merged_bounds = merged_bounds.merge(bounds)
		else:
			merged_bounds = bounds
			has_bounds = true

	if not has_bounds:
		return Rect2(Vector2.ZERO, frame_size)

	return merged_bounds

func _calculate_texture_alpha_bounds(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()

	var image := texture.get_image()
	if image == null:
		return Rect2()

	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= SPRITE_ALPHA_BOUNDS_THRESHOLD:
				continue

			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2()

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x + 1, max_y - min_y + 1))

func _get_visual_bounds_horizontal_anchor(visual_bounds: Rect2, frame_size: Vector2) -> Vector2:
	if visual_bounds.size.x <= 0.0 or visual_bounds.size.y <= 0.0:
		return frame_size * 0.5

	return Vector2(visual_bounds.position.x + (visual_bounds.size.x * 0.5), frame_size.y * 0.5)

func _sprite_frames_has_anchor(sprite_frames: SpriteFrames) -> bool:
	return sprite_frames_anchors.has(_get_sprite_frames_key(sprite_frames))

func _get_sprite_frames_render_scale(sprite_frames: SpriteFrames) -> float:
	var render_scale_value: Variant = sprite_frames_render_scales.get(_get_sprite_frames_key(sprite_frames), 1.0)
	if render_scale_value is float:
		return render_scale_value
	if render_scale_value is int:
		return float(render_scale_value)

	return 1.0

func _get_sprite_frames_display_scale_multiplier(sprite_frames: SpriteFrames) -> float:
	var multiplier_value: Variant = sprite_frames_display_scale_multipliers.get(_get_sprite_frames_key(sprite_frames), 1.0)
	if multiplier_value is float:
		return multiplier_value
	if multiplier_value is int:
		return float(multiplier_value)

	return 1.0

func _get_sprite_frames_position_offset(sprite_frames: SpriteFrames) -> Vector2:
	var offset_value: Variant = sprite_frames_position_offsets.get(_get_sprite_frames_key(sprite_frames), Vector2.ZERO)
	if offset_value is Vector2:
		return offset_value

	return Vector2.ZERO

func _get_sprite_frames_anchor(sprite_frames: SpriteFrames) -> Vector2:
	var key := _get_sprite_frames_key(sprite_frames)
	var anchor_value: Variant = sprite_frames_anchors.get(key, Vector2.ZERO)
	if anchor_value is Vector2:
		return anchor_value

	var frame_size := _get_sprite_frames_frame_size(sprite_frames)
	return Vector2(frame_size.x * 0.5, frame_size.y)

func _get_sprite_frames_frame_size(sprite_frames: SpriteFrames) -> Vector2:
	var key := _get_sprite_frames_key(sprite_frames)
	var frame_size_value: Variant = sprite_frames_frame_sizes.get(key, Vector2.ZERO)
	if frame_size_value is Vector2:
		return frame_size_value

	if sprite_frames != null and sprite_frames.has_animation(IDLE_ANIMATION) and sprite_frames.get_frame_count(IDLE_ANIMATION) > 0:
		var texture := sprite_frames.get_frame_texture(IDLE_ANIMATION, 0)
		if texture != null:
			return texture.get_size()

	return Vector2(DEFAULT_SHEET_FRAME_SIZE)

func _get_sprite_frames_visual_bounds(sprite_frames: SpriteFrames) -> Rect2:
	var key := _get_sprite_frames_key(sprite_frames)
	var visual_bounds_value: Variant = sprite_frames_visual_bounds.get(key, Rect2())
	if visual_bounds_value is Rect2:
		var visual_bounds := visual_bounds_value as Rect2
		if visual_bounds.size.x > 0.0 and visual_bounds.size.y > 0.0:
			return visual_bounds

	var frame_size := _get_sprite_frames_frame_size(sprite_frames)
	return Rect2(Vector2.ZERO, frame_size)

func _apply_sprite_anchor(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if not sprite_frames_anchors.has(_get_sprite_frames_key(sprite.sprite_frames)):
		sprite.centered = true
		sprite.offset = Vector2.ZERO
		return

	var frame_size := _get_sprite_frames_frame_size(sprite.sprite_frames)
	var anchor := _get_sprite_frames_anchor(sprite.sprite_frames)
	sprite.centered = true
	sprite.offset = (frame_size * 0.5) - anchor

func get_single_battle_anchor_global_position() -> Vector2:
	return _get_sprite_battle_anchor_global_position(single_sprite)

func get_single_animation_anchor_global_position() -> Vector2:
	return _get_sprite_animation_anchor_global_position(single_sprite)

func _get_sprite_battle_anchor_global_position(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or not sprite.visible:
		return Vector2.ZERO

	var visual_rect := _get_sprite_visual_rect_global(sprite)
	var bottom_center := Vector2(
		visual_rect.position.x + (visual_rect.size.x * 0.5),
		visual_rect.position.y + visual_rect.size.y
	)
	return bottom_center

func _get_sprite_animation_anchor_global_position(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or not sprite.visible:
		return Vector2.ZERO

	var visual_rect := _get_sprite_visual_rect_global(sprite)
	return visual_rect.position + (visual_rect.size * 0.5)

func get_single_battle_anchor_in_node(target_node: CanvasItem) -> Vector2:
	if target_node == null:
		return Vector2.ZERO

	var global_anchor := get_single_battle_anchor_global_position()
	if global_anchor == Vector2.ZERO:
		return Vector2.ZERO

	return target_node.get_global_transform().affine_inverse() * global_anchor

func get_single_animation_anchor_in_node(target_node: CanvasItem) -> Vector2:
	if target_node == null:
		return Vector2.ZERO

	var global_anchor := get_single_animation_anchor_global_position()
	if global_anchor == Vector2.ZERO:
		return Vector2.ZERO

	return target_node.get_global_transform().affine_inverse() * global_anchor

func _get_sprite_frames_key(sprite_frames: SpriteFrames) -> String:
	if sprite_frames == null:
		return ""

	return str(sprite_frames.get_instance_id())

func prewarm_species(species: String, side: String, is_shiny: bool = false) -> void:
	if species.strip_edges() == "":
		return
	_load_sprite_frames(species, side, is_shiny)

func _load_sprite_frames(species: String, side: String, is_shiny: bool = false) -> SpriteFrames:
	var cache_key := "%s|%s|%s|%s" % [
		_normalize_species_asset_id(species),
		side.strip_edges().to_lower(),
		str(is_shiny),
		str(SettingsManager.sprite_style),
	]
	if sprite_frames_cache.has(cache_key):
		return sprite_frames_cache[cache_key] as SpriteFrames

	var frames := _load_sprite_frames_uncached(species, side, is_shiny)
	if frames != null:
		sprite_frames_cache[cache_key] = frames
	return frames

func _load_sprite_frames_uncached(species: String, side: String, is_shiny: bool = false) -> SpriteFrames:
	for sprite_root in _get_sprite_asset_roots(side, is_shiny):
		for asset_id in _get_species_asset_id_candidates(species):
			for sheet_metadata_path in PokemonAssets.build_pokemon_sprite_path("%s/%s/animation.json" % [sprite_root, asset_id]):
				var metadata_frames := _load_sprite_frames_from_sheet_metadata(sheet_metadata_path, sprite_root, species)
				if metadata_frames != null:
					_apply_sprite_source_display_scale(metadata_frames, sheet_metadata_path)
					_apply_species_position_offset(metadata_frames, species, side, is_shiny)
					return metadata_frames

			for folder in PokemonAssets.build_pokemon_sprite_path("%s/%s" % [sprite_root, asset_id]):
				var folder_frames := _load_sprite_frames_from_folder(folder)
				if folder_frames != null:
					_apply_sprite_source_display_scale(folder_frames, folder)
					_apply_species_position_offset(folder_frames, species, side, is_shiny)
					return folder_frames

			for sheet_path in PokemonAssets.build_pokemon_sprite_path("%s/%s.png" % [sprite_root, asset_id]):
				var sheet_frames := _load_sprite_frames_from_sheet(sheet_path)
				if sheet_frames != null:
					_apply_sprite_source_display_scale(sheet_frames, sheet_path)
					_apply_species_position_offset(sheet_frames, species, side, is_shiny)
					return sheet_frames

	var home_frames := _load_sprite_frames_from_home_sprite(species, is_shiny)
	if home_frames != null:
		_apply_species_position_offset(home_frames, species, side, is_shiny)
		return home_frames

	push_error("Pokemon sprite assets are not found for %s/%s" % [side, species])
	return null

func _apply_sprite_source_display_scale(sprite_frames: SpriteFrames, source_path: String) -> void:
	if _is_gen5_sprite_path(source_path):
		_set_sprite_frames_display_scale_multiplier(sprite_frames, GEN5_BATTLE_SPRITE_DISPLAY_SCALE_MULTIPLIER)

func _apply_species_position_offset(sprite_frames: SpriteFrames, species: String, side: String, is_shiny: bool) -> void:
	var side_key := _get_sprite_side_folder(side, is_shiny)
	var species_key := _normalize_species_asset_id(species)
	var offset_value: Variant = SPECIES_POSITION_OFFSETS.get("%s:%s" % [side_key, species_key], Vector2.ZERO)
	if offset_value is Vector2 and offset_value != Vector2.ZERO:
		var existing_offset := _get_sprite_frames_position_offset(sprite_frames)
		_set_sprite_frames_position_offset(sprite_frames, existing_offset + (offset_value as Vector2))

func _is_gen5_sprite_path(source_path: String) -> bool:
	var normalized_path := source_path.replace("\\", "/").to_lower()
	return normalized_path.contains("/gen5/")

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

	var aliases_value: Variant = BATTLE_SPRITE_ASSET_ALIASES.get(asset_id, [])
	if aliases_value is Array:
		for alias_value: Variant in aliases_value:
			var alias_id := _normalize_species_asset_id(str(alias_value))
			if alias_id != "" and not candidates.has(alias_id):
				candidates.append(alias_id)

	return candidates

func _normalize_species_asset_id(species: String) -> String:
	var asset_id := species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")
	if asset_id.begins_with("tapu-"):
		asset_id = asset_id.replace("tapu-", "tapu")

	return asset_id

func is_showing_species(species: String) -> bool:
	if double_container != null and double_container.visible:
		return true
	if single_sprite != null and not single_sprite.visible:
		return false
	if species.strip_edges() == "":
		return false
	if current_single_species.strip_edges() == "":
		return false

	return _normalize_species_asset_id(current_single_species) == _normalize_species_asset_id(species)

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
	var first_frame_size := Vector2.ZERO
	for index in frame_files.size():
		var frame_file := frame_files[index]
		var texture := PokemonAssets.load_texture(folder + "/" + frame_file)
		if texture != null:
			if first_frame_size == Vector2.ZERO:
				first_frame_size = texture.get_size()
			sprite_frames.add_frame(IDLE_ANIMATION, texture, timing["durations"][index])

	if first_frame_size != Vector2.ZERO:
		_set_sprite_frames_render_scale(sprite_frames, timing["render_scale"])
		_set_sprite_frames_auto_anchor(sprite_frames, first_frame_size)

	return sprite_frames

func _load_frame_timing(folder: String, frame_count: int) -> Dictionary:
	var metadata_path := folder + "/animation.json"
	var timing := {
		"speed": FRAME_ANIMATION_SPEED,
		"durations": [],
		"render_scale": 1.0,
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
	timing["render_scale"] = max(float(parsed.get("render_scale", 1.0)), 1.0)
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
	var metadata_frame_size := Vector2(
		float(metadata.get("frame_width", 0.0)),
		float(metadata.get("frame_height", 0.0))
	)
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

	if metadata_frame_size.x <= 0.0 or metadata_frame_size.y <= 0.0:
		metadata_frame_size = _get_sprite_frames_frame_size(sprite_frames)

	_set_sprite_frames_render_scale(sprite_frames, _get_metadata_render_scale(metadata, side))
	_set_sprite_frames_visual_bounds(sprite_frames, _calculate_sprite_frames_visual_bounds(sprite_frames, metadata_frame_size))
	if metadata.has("position_offset"):
		_set_sprite_frames_position_offset(sprite_frames, _get_metadata_position_offset(metadata))
	if _metadata_has_anchor(metadata):
		_set_sprite_frames_anchor(sprite_frames, _get_metadata_anchor(metadata, metadata_frame_size), metadata_frame_size)
	else:
		_set_sprite_frames_auto_anchor(sprite_frames, metadata_frame_size)
	return sprite_frames

func _metadata_has_anchor(metadata: Dictionary) -> bool:
	return metadata.has("anchor")

func _get_metadata_anchor(metadata: Dictionary, frame_size: Vector2) -> Vector2:
	var anchor_value: Variant = metadata.get("anchor", {})
	if anchor_value is Dictionary:
		var anchor_dictionary := anchor_value as Dictionary
		return Vector2(
			float(anchor_dictionary.get("x", frame_size.x * 0.5)),
			float(anchor_dictionary.get("y", frame_size.y))
		)
	if anchor_value is Array:
		var anchor_array := anchor_value as Array
		if anchor_array.size() >= 2:
			return Vector2(float(anchor_array[0]), float(anchor_array[1]))

	return Vector2(frame_size.x * 0.5, frame_size.y)

func _get_metadata_position_offset(metadata: Dictionary) -> Vector2:
	var offset_value: Variant = metadata.get("position_offset", {})
	if offset_value is Dictionary:
		var offset_dictionary := offset_value as Dictionary
		return Vector2(
			float(offset_dictionary.get("x", 0.0)),
			float(offset_dictionary.get("y", 0.0))
		)
	if offset_value is Array:
		var offset_array := offset_value as Array
		if offset_array.size() >= 2:
			return Vector2(float(offset_array[0]), float(offset_array[1]))

	return Vector2.ZERO

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

	_set_sprite_frames_auto_anchor(sprite_frames, Vector2(frame_size))
	return sprite_frames

func _load_sprite_frames_from_home_sprite(species: String, is_shiny: bool) -> SpriteFrames:
	var texture: Texture2D = PokemonAssets.load_home_sprite(species, is_shiny)
	if texture == null:
		return null

	var sprite_frames := _create_idle_sprite_frames(1.0)
	sprite_frames.add_frame(IDLE_ANIMATION, texture)
	var frame_size := texture.get_size()
	_set_sprite_frames_auto_anchor(sprite_frames, frame_size)
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
	current_single_species = ""
	current_single_side = ""
	current_single_is_shiny = false
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

	if (
		single_sprite.visible
		and current_single_species == species
		and current_single_side == side
		and current_single_is_shiny == is_shiny
	):
		_position_stat_stage_panel(single_sprite, single_stat_stage_panel)
		return

	single_sprite.visible = false
	_reset_sprite_pose(single_sprite)
	var frames := _load_sprite_frames(species, side, is_shiny)
	if frames == null:
		current_single_species = ""
		current_single_side = ""
		current_single_is_shiny = false
		return

	current_single_species = species
	current_single_side = side
	current_single_is_shiny = is_shiny
	single_sprite.sprite_frames = frames
	single_sprite.animation = IDLE_ANIMATION
	single_sprite.frame = 0
	_set_sprite_target_scale_from_frames(single_sprite, frames)
	_snap_sprite_to_pixel_grid(single_sprite)
	single_sprite.visible = true
	_apply_sprite_playback_mode(single_sprite)
	_position_stat_stage_panel(single_sprite, single_stat_stage_panel)
	if substitute_active:
		_sync_substitute_idle_pose()

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

func anchor_stat_stage_panel_below(anchor: Control) -> void:
	stat_stage_panel_anchor = anchor
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
	if stat_stage_panel_anchor != null and is_instance_valid(stat_stage_panel_anchor):
		var panel_parent := panel.get_parent() as Control
		if panel_parent != null:
			var anchor_rect := stat_stage_panel_anchor.get_global_rect()
			var anchor_bottom_center := Vector2(anchor_rect.get_center().x, anchor_rect.end.y)
			var local_anchor := panel_parent.get_global_transform().affine_inverse() * anchor_bottom_center
			panel.position = local_anchor + Vector2(-panel_size.x * 0.5, STAT_STAGE_PANEL_GAP)
			return
	var visual_rect := _get_sprite_visual_rect_in_parent(sprite)
	var top_center := Vector2(visual_rect.position.x + (visual_rect.size.x * 0.5), visual_rect.position.y)
	panel.position = top_center - Vector2(panel_size.x * 0.5, panel_size.y + STAT_STAGE_PANEL_GAP)

func _get_sprite_display_size(sprite: AnimatedSprite2D) -> Vector2:
	return _get_sprite_visual_rect_in_parent(sprite).size

func _get_sprite_visual_rect_global(sprite: AnimatedSprite2D) -> Rect2:
	var local_rect := _get_sprite_visual_rect_in_parent(sprite)
	var parent_canvas := sprite.get_parent() as CanvasItem
	if parent_canvas == null:
		return Rect2(sprite.global_position, local_rect.size)

	return Rect2(parent_canvas.get_global_transform() * local_rect.position, local_rect.size)

func _get_sprite_visual_rect_in_parent(sprite: AnimatedSprite2D) -> Rect2:
	var texture: Texture2D = _get_current_sprite_texture(sprite)
	var frame_size: Vector2 = Vector2(DEFAULT_SHEET_FRAME_SIZE)
	if texture != null:
		frame_size = texture.get_size()

	if sprite.sprite_frames != null:
		frame_size = _get_sprite_frames_frame_size(sprite.sprite_frames)

	var visual_bounds := Rect2(Vector2.ZERO, frame_size)
	if sprite.sprite_frames != null:
		visual_bounds = _get_sprite_frames_visual_bounds(sprite.sprite_frames)

	var sprite_scale := Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
	var top_left := sprite.position + ((sprite.offset - (frame_size * 0.5) + visual_bounds.position) * sprite_scale)
	return Rect2(top_left, visual_bounds.size * sprite_scale)
