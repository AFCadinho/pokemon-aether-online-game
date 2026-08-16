extends RefCounted

class_name BattleAnimationRouter

const BattleRenderLayers := preload("res://scripts/battle/battle_render_layers.gd")
const MOVE_ANIMATION_CATALOG_PATH := "res://data/battle_move_animations.json"
const EFFECT_ANIMATION_CATALOG_PATH := "res://data/battle_effect_animations.json"
const TAKE_DAMAGE_SOUND_PATH := "res://assets/battles/animations/common/damage/normaldamage.ogg"
const SUPER_EFFECTIVE_DAMAGE_SOUND_PATH := "res://assets/audio/sfx/battle/hit_super_effective.ogg"
const EFFECT_SOURCE_PLAYER_POSITION := Vector2(128, 224)
const EFFECT_SOURCE_ENEMY_POSITION := Vector2(384, 96)
const REVERSED_BATTLEFIELD_AXIS := Vector2(512, 320)
const MAX_ANIMATION_WAIT_SECONDS := 8.0

var player_sprite_box: Node
var enemy_sprite_box: Node
var animation_parent: Node
var move_animation_configs: Dictionary = {}
var loaded_move_animation_configs: Dictionary = {}
var effect_animation_configs: Dictionary = {}
var effect_animation_aliases: Dictionary = {}
var loaded_effect_animation_configs: Dictionary = {}
var animation_resource_cache: Dictionary = {}
var animation_data_cache: Dictionary = {}
var resource_cache: Dictionary = {}
var threaded_resource_requests: Dictionary = {}
var sound_stream_cache: Dictionary = {}
var animation_guard: Callable


func setup(player_box: Node, enemy_box: Node, parent_node: Node = null, animation_guard_callback: Callable = Callable()) -> void:
	player_sprite_box = player_box
	enemy_sprite_box = enemy_box
	animation_parent = parent_node
	animation_guard = animation_guard_callback


func reveal_pokemon_from_substitute_for_move(actor_ident: String) -> bool:
	var actor_box := _get_sprite_box_for_ident(actor_ident)
	if actor_box == null or not actor_box.has_method("reveal_pokemon_from_substitute_for_move"):
		return false
	return bool(await actor_box.call("reveal_pokemon_from_substitute_for_move"))


func restore_substitute_after_move(actor_ident: String) -> void:
	var actor_box := _get_sprite_box_for_ident(actor_ident)
	if actor_box == null or not actor_box.has_method("restore_substitute_after_move"):
		return
	await actor_box.call("restore_substitute_after_move")


func set_substitute_active(target_ident: String, is_active: bool, animate := true) -> void:
	var target_box := _get_sprite_box_for_ident(target_ident)
	if target_box == null or not target_box.has_method("set_substitute_active"):
		return
	await target_box.call("set_substitute_active", is_active, animate)


func play_substitute_damage_tween(target_ident: String) -> void:
	var target_box := _get_sprite_box_for_ident(target_ident)
	if target_box == null or not target_box.has_method("play_substitute_damage_tween"):
		return
	await target_box.call("play_substitute_damage_tween")


func clear_substitute_for_ident(target_ident: String) -> void:
	var target_box := _get_sprite_box_for_ident(target_ident)
	if target_box != null and target_box.has_method("clear_substitute_immediately"):
		target_box.call("clear_substitute_immediately")


func clear_all_substitutes() -> void:
	for sprite_box in [player_sprite_box, enemy_sprite_box]:
		if sprite_box != null and sprite_box.has_method("clear_substitute_immediately"):
			sprite_box.call("clear_substitute_immediately")


func play_attack_tween_for_actor(actor_ident: String) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.attack_tween", {"actor": actor_ident}):
		return

	match _get_player_id_from_ident(actor_ident):
		"p1":
			await player_sprite_box.play_attack_tween(Vector2(28, -6))
		"p2":
			await enemy_sprite_box.play_attack_tween(Vector2(-28, 6))


func play_move_animation(move_name: String, actor_ident: String = "", _target_ident: String = "", options: Dictionary = {}) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.move_animation", {
		"move": move_name,
		"actor": actor_ident,
		"target": _target_ident,
		"result": str(options.get("result", "")),
	}):
		return

	var move_key: String = _normalize_move_name(move_name)
	var config: Dictionary = _get_move_animation_config(move_key)
	if config.is_empty():
		return

	await _play_animation_config(config, "", _get_player_id_from_ident(actor_ident) == "p2", actor_ident, _target_ident, options)


func play_effect_animation(effect_key: String, target_ident: String = "") -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.effect_animation", {
		"effect": effect_key,
		"target": target_ident,
	}):
		return

	var config: Dictionary = _get_effect_animation_config(_normalize_animation_key(effect_key))
	if config.is_empty():
		return

	await _play_animation_config(config, target_ident)


func _play_animation_config(
	config: Dictionary,
	target_ident: String = "",
	reverse_battlefield: bool = false,
	move_actor_ident: String = "",
	move_target_ident: String = "",
	animation_options: Dictionary = {}
) -> void:
	var parent_node: Node = animation_parent
	if parent_node == null:
		parent_node = player_sprite_box.get_parent()
	if parent_node == null:
		return

	if not _animation_assets_available(config):
		return

	_request_animation_resources(config)
	await _wait_for_animation_resources(parent_node, config)
	var resources: Dictionary = _get_animation_resources(config)
	if resources.is_empty():
		return

	var animation_node: MoveAnimationPlayer = _create_move_animation_node(config, resources, reverse_battlefield)
	if bool(config.get("split_dark_pulse_layers", false)):
		animation_node.dark_pulse_config["draw_layer"] = "foreground"
	_apply_move_animation_options(animation_node, config, animation_options)
	var hidden_actor_sprites: Array = []
	_play_move_actor_motion_if_needed(config, move_actor_ident)
	var hide_actor_delay := maxf(float(config.get("hide_actor_delay", 0.0)), 0.0)
	if hide_actor_delay > 0.0 and bool(config.get("hide_actor_sprite", false)) and parent_node.get_tree() != null:
		await parent_node.get_tree().create_timer(hide_actor_delay).timeout
	_play_move_target_shake_if_needed(config, move_target_ident, animation_options)
	_play_move_target_hit_flash_if_needed(config, move_target_ident, animation_options)

	var overlay: Control = _create_animation_overlay(parent_node, config)
	if overlay != null:
		parent_node.add_child(overlay)
		_move_overlay_below_sprites(overlay, parent_node, config)
		_fit_animation_to_parent(animation_node, overlay)
		_apply_move_projectile_endpoint_anchors(animation_node, move_actor_ident, move_target_ident, overlay, config, animation_options)
		_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, overlay, config)
		_apply_effect_target_offset(animation_node, target_ident, config, overlay)
		hidden_actor_sprites = _hide_move_actor_sprite_if_needed(config, move_actor_ident)
		overlay.add_child(animation_node)
		_move_timing_background_below_sprites(animation_node, parent_node, config)
		# Add the procedural underlay only after the opaque timing background has
		# been detached. This keeps the floor ring above the background while it
		# remains below the Pokemon sprites.
		var underlay_overlay := _create_dark_pulse_underlay_if_needed(
			parent_node,
			config,
			resources,
			reverse_battlefield,
			move_actor_ident,
			move_target_ident,
			animation_options
		)
		await _wait_for_animation_node(animation_node, overlay)
		_restore_move_actor_sprite_if_needed(config, move_actor_ident, hidden_actor_sprites)
		if is_instance_valid(overlay):
			overlay.queue_free()
		if is_instance_valid(underlay_overlay):
			underlay_overlay.queue_free()
		return

	animation_node.z_index = BattleRenderLayers.MOVE_FOREGROUND
	_fit_animation_to_parent(animation_node, parent_node)
	_apply_move_projectile_endpoint_anchors(animation_node, move_actor_ident, move_target_ident, parent_node, config, animation_options)
	_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, parent_node, config)
	_apply_effect_target_offset(animation_node, target_ident, config, parent_node)
	hidden_actor_sprites = _hide_move_actor_sprite_if_needed(config, move_actor_ident)
	parent_node.add_child(animation_node)
	await _wait_for_animation_node(animation_node, parent_node)
	_restore_move_actor_sprite_if_needed(config, move_actor_ident, hidden_actor_sprites)


func _create_dark_pulse_underlay_if_needed(
	parent_node: Node,
	config: Dictionary,
	resources: Dictionary,
	reverse_battlefield: bool,
	move_actor_ident: String,
	move_target_ident: String,
	animation_options: Dictionary
) -> Control:
	if not bool(config.get("split_dark_pulse_layers", false)) or not parent_node is Control:
		return null

	var underlay_config := config.duplicate(true)
	underlay_config["render_below_sprites"] = true
	underlay_config["show_timing_backgrounds"] = false
	underlay_config["show_timing_foregrounds"] = false
	underlay_config["show_sheet_sprites"] = false
	underlay_config["show_pink_visual"] = false
	underlay_config["sound_paths"] = {}

	var underlay_node := _create_move_animation_node(underlay_config, resources, reverse_battlefield)
	underlay_node.dark_pulse_config["draw_layer"] = "underlay"
	underlay_node.sound_paths.clear()
	underlay_node.sound_streams.clear()
	_apply_move_animation_options(underlay_node, underlay_config, animation_options)

	var underlay_overlay := _create_animation_overlay(parent_node, underlay_config)
	parent_node.add_child(underlay_overlay)
	_move_overlay_below_sprites(underlay_overlay, parent_node, underlay_config)
	_fit_animation_to_parent(underlay_node, underlay_overlay)
	_apply_move_projectile_endpoint_anchors(
		underlay_node,
		move_actor_ident,
		move_target_ident,
		underlay_overlay,
		underlay_config,
		animation_options
	)
	_apply_effect_target_offset(underlay_node, "", underlay_config, underlay_overlay)
	underlay_overlay.add_child(underlay_node)
	return underlay_overlay


func prewarm_move_animations(move_names: Array) -> void:
	if not SettingsManager.battle_animations:
		return

	for move_name_value: Variant in move_names:
		var move_key: String = _normalize_move_name(str(move_name_value))
		if move_key == "":
			continue

		var config: Dictionary = _get_move_animation_config(move_key)
		if not config.is_empty():
			_prewarm_animation_assets(config)


func prewarm_effect_animations(effect_keys: Array) -> void:
	if not SettingsManager.battle_animations:
		return

	for effect_key_value: Variant in effect_keys:
		var effect_key: String = _normalize_animation_key(str(effect_key_value))
		if effect_key == "":
			continue

		var config: Dictionary = _get_effect_animation_config(effect_key)
		if not config.is_empty():
			_prewarm_animation_assets(config)


func prewarm_common_battle_sounds() -> void:
	if not SettingsManager.battle_animations:
		return

	_request_threaded_resource(TAKE_DAMAGE_SOUND_PATH)
	_request_threaded_resource(SUPER_EFFECTIVE_DAMAGE_SOUND_PATH)


func has_move_animation(move_name: String) -> bool:
	return not _get_move_animation_config(_normalize_move_name(move_name)).is_empty()


func has_effect_animation(effect_key: String) -> bool:
	return not _get_effect_animation_config(_normalize_animation_key(effect_key)).is_empty()


func clear_move_animation_cache() -> void:
	move_animation_configs.clear()
	loaded_move_animation_configs.clear()
	effect_animation_configs.clear()
	effect_animation_aliases.clear()
	loaded_effect_animation_configs.clear()
	animation_resource_cache.clear()
	animation_data_cache.clear()
	resource_cache.clear()
	threaded_resource_requests.clear()
	sound_stream_cache.clear()


func _get_move_animation_config(move_key: String) -> Dictionary:
	if loaded_move_animation_configs.has(move_key):
		return loaded_move_animation_configs[move_key] as Dictionary

	_load_move_animation_catalog()
	if not move_animation_configs.has(move_key):
		return {}

	var config: Dictionary = (move_animation_configs[move_key] as Dictionary).duplicate(true)
	loaded_move_animation_configs[move_key] = config
	return config


func _load_move_animation_catalog() -> void:
	if not move_animation_configs.is_empty():
		return

	var parsed_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVE_ANIMATION_CATALOG_PATH))
	if parsed_data == null or not parsed_data is Dictionary:
		push_error("Could not read move animation catalog: %s" % MOVE_ANIMATION_CATALOG_PATH)
		return

	var catalog: Dictionary = parsed_data as Dictionary
	var moves_value: Variant = catalog.get("moves", {})
	if not moves_value is Dictionary:
		push_error("Move animation catalog has no moves dictionary: %s" % MOVE_ANIMATION_CATALOG_PATH)
		return

	move_animation_configs = moves_value as Dictionary


func _get_effect_animation_config(effect_key: String) -> Dictionary:
	if loaded_effect_animation_configs.has(effect_key):
		return loaded_effect_animation_configs[effect_key] as Dictionary

	_load_effect_animation_catalog()
	var resolved_key: String = str(effect_animation_aliases.get(effect_key, effect_key))
	if not effect_animation_configs.has(resolved_key):
		return {}

	var config: Dictionary = (effect_animation_configs[resolved_key] as Dictionary).duplicate(true)
	loaded_effect_animation_configs[effect_key] = config
	return config


func _load_effect_animation_catalog() -> void:
	if not effect_animation_configs.is_empty():
		return

	var parsed_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(EFFECT_ANIMATION_CATALOG_PATH))
	if parsed_data == null or not parsed_data is Dictionary:
		push_error("Could not read effect animation catalog: %s" % EFFECT_ANIMATION_CATALOG_PATH)
		return

	var catalog: Dictionary = parsed_data as Dictionary
	var effects_value: Variant = catalog.get("effects", {})
	if not effects_value is Dictionary:
		push_error("Effect animation catalog has no effects dictionary: %s" % EFFECT_ANIMATION_CATALOG_PATH)
		return

	effect_animation_configs = effects_value as Dictionary
	var aliases_value: Variant = catalog.get("aliases", {})
	if aliases_value is Dictionary:
		effect_animation_aliases = aliases_value as Dictionary


func _hide_move_actor_sprite_if_needed(config: Dictionary, actor_ident: String) -> Array:
	if not bool(config.get("hide_actor_sprite", false)):
		return []

	var actor_box := _get_sprite_box_for_ident(actor_ident)
	if actor_box == null or not actor_box.has_method("set_battle_sprites_visible"):
		return []

	var changed_sprites: Variant = actor_box.call("set_battle_sprites_visible", false)
	if changed_sprites is Array:
		return changed_sprites as Array
	return []


func _restore_move_actor_sprite_if_needed(config: Dictionary, actor_ident: String, hidden_sprites: Array) -> void:
	if hidden_sprites.is_empty() or not bool(config.get("hide_actor_sprite", false)):
		return

	var actor_box := _get_sprite_box_for_ident(actor_ident)
	if actor_box == null or not actor_box.has_method("restore_battle_sprites_visibility"):
		return

	actor_box.call("restore_battle_sprites_visibility", hidden_sprites)


func _play_move_actor_motion_if_needed(config: Dictionary, actor_ident: String) -> void:
	var motion_value: Variant = config.get("actor_motion", {})
	if not motion_value is Dictionary:
		return

	var motion_config := motion_value as Dictionary
	if not bool(motion_config.get("enabled", false)):
		return

	var actor_box := _get_sprite_box_for_ident(actor_ident)
	if actor_box == null or not actor_box.has_method("play_move_actor_motion"):
		return

	var direction := Vector2.ONE
	if _get_player_id_from_ident(actor_ident) == "p2":
		direction = Vector2(-1.0, -1.0)
		if not bool(config.get("actor_motion_mirror_vertical", true)):
			direction.y = 1.0
	actor_box.call("play_move_actor_motion", motion_config, direction)


func _create_move_animation_node(config: Dictionary, resources: Dictionary = {}, reverse_battlefield: bool = false) -> MoveAnimationPlayer:
	var animation_node: MoveAnimationPlayer = MoveAnimationPlayer.new()
	animation_node.data_path = str(config.get("data_path", ""))
	animation_node.sheet_path = str(config.get("sheet_path", ""))
	animation_node.background_path = str(config.get("background_path", ""))
	animation_node.foreground_path = str(config.get("foreground_path", ""))
	var sound_paths: Dictionary = (config.get("sound_paths", {}) as Dictionary).duplicate(true)
	animation_node.sound_paths = sound_paths
	animation_node.custom_sound_events = (config.get("custom_sound_events", []) as Array).duplicate(true)
	animation_node.disable_data_sound_events = bool(config.get("disable_data_sound_events", false))
	if not resources.is_empty():
		animation_node.data_override = resources.get("data", {}) as Dictionary
		animation_node.sheet_texture_override = resources.get("sheet_texture", null) as Texture2D
		animation_node.background_texture_override = resources.get("background_texture", null) as Texture2D
		animation_node.foreground_texture_override = resources.get("foreground_texture", null) as Texture2D
		animation_node.sound_streams = resources.get("sound_streams", {}) as Dictionary
	animation_node.speed_scale = float(config.get("speed_scale", 1.0))
	animation_node.sprite_zoom_multiplier = float(config.get("sprite_zoom_multiplier", 1.0))
	animation_node.sprite_position_scale = float(config.get("sprite_position_scale", 1.0))
	animation_node.sprite_position_anchor = _vector2_from_config_value(
		config.get("sprite_position_anchor", [EFFECT_SOURCE_PLAYER_POSITION.x, EFFECT_SOURCE_PLAYER_POSITION.y]),
		EFFECT_SOURCE_PLAYER_POSITION
	)
	var sprite_position_offset := _vector2_from_config_value(
		config.get("sprite_position_offset", [0.0, 0.0]),
		Vector2.ZERO
	)
	if reverse_battlefield:
		sprite_position_offset += _vector2_from_config_value(
			config.get("reverse_sprite_position_offset", [0.0, 0.0]),
			Vector2.ZERO
		)
	animation_node.sprite_position_offset = sprite_position_offset
	animation_node.sheet_visual_offset = _vector2_from_config_value(config.get("sheet_visual_offset", [0.0, 0.0]), Vector2.ZERO)
	animation_node.sheet_frame_offsets = (config.get("sheet_frame_offsets", []) as Array).duplicate(true)
	animation_node.sparkle_size_multiplier = float(config.get("sparkle_size_multiplier", 1.0))
	animation_node.pattern_offset = int(config.get("pattern_offset", 0))
	animation_node.pattern_override = int(config.get("pattern_override", -1))
	animation_node.reverse_pattern_override = int(config.get("reverse_pattern_override", -1))
	animation_node.sheet_pattern_min = int(config.get("sheet_pattern_min", 0))
	animation_node.sheet_pattern_max = int(config.get("sheet_pattern_max", 999))
	animation_node.sheet_pattern_exclude = (config.get("sheet_pattern_exclude", []) as Array).duplicate()
	animation_node.sheet_visible_start_frame = int(config.get("sheet_visible_start_frame", 0))
	animation_node.animation_start_frame = int(config.get("animation_start_frame", 0))
	animation_node.animation_end_frame = int(config.get("animation_end_frame", -1))
	animation_node.loop = false
	animation_node.free_on_finish = true
	animation_node.show_timing_backgrounds = bool(config.get("show_timing_backgrounds", false))
	animation_node.timing_background_fill_canvas = bool(config.get("timing_background_fill_canvas", false))
	animation_node.timing_background_persist_until_clear = bool(config.get("timing_background_persist_until_clear", false))
	animation_node.background_motion_config = (config.get("background_motion", {}) as Dictionary).duplicate(true)
	animation_node.show_timing_foregrounds = bool(config.get("show_timing_foregrounds", false))
	animation_node.timing_foreground_scale = _vector2_from_config_value(config.get("timing_foreground_scale", [1.0, 1.0]), Vector2.ONE)
	animation_node.foreground_opacity_multiplier = clampf(float(config.get("foreground_opacity_multiplier", 1.0)), 0.0, 1.0)
	animation_node.show_pink_visual = bool(config.get("show_pink_visual", false))
	animation_node.show_sheet_sprites = bool(config.get("show_sheet_sprites", true))
	animation_node.mirror_sheet_sprites_on_reverse = bool(config.get("mirror_sheet_sprites_on_reverse", false))
	animation_node.overlay_fill_enabled = bool(config.get("overlay_fill_enabled", true))
	animation_node.projectile_config = (config.get("projectile", {}) as Dictionary).duplicate(true)
	animation_node.orb_config = (config.get("orb", {}) as Dictionary).duplicate(true)
	animation_node.orb_projectile_config = (config.get("orb_projectile", {}) as Dictionary).duplicate(true)
	animation_node.orb_barrage_config = (config.get("orb_barrage", {}) as Dictionary).duplicate(true)
	animation_node.psychic_pulse_config = (config.get("psychic_pulse", {}) as Dictionary).duplicate(true)
	animation_node.energy_blast_config = (config.get("energy_blast", {}) as Dictionary).duplicate(true)
	animation_node.water_splash_config = (config.get("water_splash", {}) as Dictionary).duplicate(true)
	animation_node.electric_switch_config = (config.get("electric_switch", {}) as Dictionary).duplicate(true)
	animation_node.fire_stream_config = (config.get("fire_stream", {}) as Dictionary).duplicate(true)
	animation_node.heat_wave_config = (config.get("heat_wave", {}) as Dictionary).duplicate(true)
	animation_node.draco_meteor_config = (config.get("draco_meteor", {}) as Dictionary).duplicate(true)
	animation_node.coin_rain_config = (config.get("coin_rain", {}) as Dictionary).duplicate(true)
	animation_node.solar_beam_config = (config.get("solar_beam", {}) as Dictionary).duplicate(true)
	animation_node.bloom_doom_config = (config.get("bloom_doom", {}) as Dictionary).duplicate(true)
	animation_node.solar_charge_config = (config.get("solar_charge", {}) as Dictionary).duplicate(true)
	animation_node.celestial_charge_config = (config.get("celestial_charge", {}) as Dictionary).duplicate(true)
	animation_node.focus_aura_config = (config.get("focus_aura", {}) as Dictionary).duplicate(true)
	animation_node.afterimage_config = (config.get("afterimage", {}) as Dictionary).duplicate(true)
	animation_node.stat_change_config = (config.get("stat_change", {}) as Dictionary).duplicate(true)
	animation_node.heal_energy_config = (config.get("heal_energy", {}) as Dictionary).duplicate(true)
	animation_node.dragon_dance_config = (config.get("dragon_dance", {}) as Dictionary).duplicate(true)
	animation_node.dragon_claw_config = (config.get("dragon_claw", {}) as Dictionary).duplicate(true)
	animation_node.thunder_punch_config = (config.get("thunder_punch", {}) as Dictionary).duplicate(true)
	animation_node.bullet_punch_config = (config.get("bullet_punch", {}) as Dictionary).duplicate(true)
	animation_node.dark_pulse_config = (config.get("dark_pulse", {}) as Dictionary).duplicate(true)
	animation_node.nasty_plot_config = (config.get("nasty_plot", {}) as Dictionary).duplicate(true)
	animation_node.court_change_config = (config.get("court_change", {}) as Dictionary).duplicate(true)
	animation_node.sound_wave_config = (config.get("sound_wave", {}) as Dictionary).duplicate(true)
	animation_node.leaf_rush_config = (config.get("leaf_rush", {}) as Dictionary).duplicate(true)
	animation_node.flash_config = (config.get("flash", {}) as Dictionary).duplicate(true)
	animation_node.shake_config = (config.get("shake", {}) as Dictionary).duplicate(true)
	animation_node.visual_color = _color_from_config(config.get("visual_color", [1.0, 0.2, 0.75, 1.0]), Color(1.0, 0.2, 0.75, 1.0))
	animation_node.sprite_tint = _color_from_config(config.get("sprite_tint", [1.0, 1.0, 1.0, 1.0]), Color.WHITE)
	animation_node.reverse_battlefield = reverse_battlefield
	animation_node.reverse_battlefield_vertical = bool(config.get("reverse_battlefield_vertical", true))
	animation_node.overlay_peak_alpha = float(config.get("overlay_peak_alpha", 0.20))
	animation_node.sparkle_count = int(config.get("sparkle_count", 14))
	animation_node.sparkle_center = _vector2_from_config_value(config.get("sparkle_center", [256.0, 188.0]), Vector2(256, 188))
	animation_node.sparkle_radius_min = float(config.get("sparkle_radius_min", 26.0))
	animation_node.sparkle_radius_max = float(config.get("sparkle_radius_max", 78.0))
	return animation_node


func _apply_move_animation_options(animation_node: MoveAnimationPlayer, config: Dictionary, animation_options: Dictionary) -> void:
	if animation_node == null or not _is_miss_animation(animation_options):
		return

	var miss_config := _get_miss_animation_config(config)
	if miss_config.is_empty():
		return

	var target_offset := _get_miss_animation_offset(miss_config, "target_offset", Vector2(56.0, -20.0))
	var default_sheet_offset := target_offset if str(config.get("category", "")) == "physical_contact" else Vector2.ZERO
	var sheet_offset := _get_miss_animation_offset(miss_config, "sheet_offset", default_sheet_offset)
	animation_node.sprite_position_offset += sheet_offset

	if bool(miss_config.get("shift_visual_center", false)):
		animation_node.sparkle_center += target_offset
		if animation_node.orb_config.has("center"):
			var orb_center := _vector2_from_config_value(animation_node.orb_config.get("center", []), animation_node.sparkle_center - target_offset)
			animation_node.orb_config["center"] = [
				orb_center.x + target_offset.x,
				orb_center.y + target_offset.y,
			]

	if bool(miss_config.get("suppress_shake", true)):
		animation_node.shake_config.clear()


func _play_move_target_shake_if_needed(config: Dictionary, target_ident: String, animation_options: Dictionary = {}) -> void:
	if target_ident == "":
		return
	if _should_suppress_target_feedback_for_miss(config, animation_options):
		return

	var shake_config: Dictionary = (config.get("target_shake", {}) as Dictionary).duplicate(true)
	if not bool(shake_config.get("enabled", false)):
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			player_sprite_box.play_shake_tween(shake_config)
		"p2":
			enemy_sprite_box.play_shake_tween(shake_config)


func _play_move_target_hit_flash_if_needed(config: Dictionary, target_ident: String, animation_options: Dictionary = {}) -> void:
	if target_ident == "":
		return
	if _should_suppress_target_feedback_for_miss(config, animation_options):
		return

	var flash_config: Dictionary = (config.get("target_hit_flash", {}) as Dictionary).duplicate(true)
	if not bool(flash_config.get("enabled", false)):
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			player_sprite_box.play_hit_flash_tween(flash_config)
		"p2":
			enemy_sprite_box.play_hit_flash_tween(flash_config)


func _should_suppress_target_feedback_for_miss(config: Dictionary, animation_options: Dictionary) -> bool:
	if not _is_miss_animation(animation_options):
		return false
	var miss_config := _get_miss_animation_config(config)
	return miss_config.is_empty() or bool(miss_config.get("suppress_target_feedback", true))


func _is_miss_animation(animation_options: Dictionary) -> bool:
	return str(animation_options.get("result", "")).strip_edges().to_lower() == "miss"


func _get_miss_animation_config(config: Dictionary) -> Dictionary:
	var miss_config: Dictionary = {}
	var miss_value: Variant = config.get("miss", {})
	if miss_value is Dictionary:
		miss_config = miss_value as Dictionary

	var category := str(config.get("category", ""))
	var default_enabled := category != "field_impact" and category != "status_buff"
	if not bool(miss_config.get("enabled", default_enabled)):
		return {}

	return miss_config


func _get_miss_animation_offset(miss_config: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _vector2_from_config_value(miss_config.get(key, [fallback.x, fallback.y]), fallback)


func _color_from_config(value: Variant, fallback: Color) -> Color:
	if not value is Array:
		return fallback

	var channels: Array = value as Array
	if channels.size() < 3:
		return fallback

	var alpha: float = 1.0
	if channels.size() >= 4:
		alpha = float(channels[3])
	return Color(float(channels[0]), float(channels[1]), float(channels[2]), alpha)


func _vector2_from_config_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array:
		var channels: Array = value as Array
		if channels.size() >= 2:
			return Vector2(float(channels[0]), float(channels[1]))
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		return Vector2(float(dictionary.get("x", fallback.x)), float(dictionary.get("y", fallback.y)))

	return fallback


func _prepare_animation_sheet_texture(texture: Texture2D, config: Dictionary) -> Texture2D:
	if not config.has("chroma_key_color"):
		return texture

	var image: Image = texture.get_image()
	if image == null:
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var key_color: Color = _color_from_config(config.get("chroma_key_color", [0.0, 1.0, 0.0, 1.0]), Color.GREEN)
	var tolerance: float = maxf(float(config.get("chroma_key_tolerance", 0.05)), 0.0)

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if (
				absf(pixel.r - key_color.r) <= tolerance
				and absf(pixel.g - key_color.g) <= tolerance
				and absf(pixel.b - key_color.b) <= tolerance
			):
				pixel.a = 0.0
				image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)


func _prewarm_animation_assets(config: Dictionary) -> void:
	if not _animation_assets_available(config):
		return

	_get_animation_data(config)
	_request_animation_resources(config)


func _get_animation_resources(config: Dictionary) -> Dictionary:
	var cache_key: String = _animation_cache_key(config)
	if animation_resource_cache.has(cache_key):
		return animation_resource_cache[cache_key] as Dictionary

	var resource_path_keys: Array[String] = ["data_path", "sheet_path", "background_path", "foreground_path"]
	var resources: Dictionary = {}
	var animation_data: Dictionary = _get_animation_data(config)
	if animation_data.is_empty():
		return {}
	resources["data"] = animation_data
	_request_animation_resources(config)

	for path_key: String in resource_path_keys:
		var resource_path: String = str(config.get(path_key, ""))
		if resource_path == "" or path_key == "data_path":
			continue

		var resource: Resource = _get_cached_resource(resource_path)
		if resource == null:
			return {}
		if path_key == "sheet_path":
			if not resource is Texture2D:
				push_warning("Could not preload animation sheet: %s" % resource_path)
				return {}
			resources["sheet_texture"] = _prepare_animation_sheet_texture(resource as Texture2D, config)
		elif path_key == "background_path":
			resources["background_texture"] = resource as Texture2D
		elif path_key == "foreground_path":
			resources["foreground_texture"] = resource as Texture2D

	var sound_paths: Dictionary = config.get("sound_paths", {}) as Dictionary
	var sound_streams: Dictionary = {}
	for sound_path_value: Variant in sound_paths.values():
		var sound_path: String = str(sound_path_value)
		if sound_path != "":
			var stream: AudioStream = _get_cached_sound_stream(sound_path)
			if stream == null:
				return {}
			if stream != null:
				sound_streams[_sound_name_for_path(sound_paths, sound_path)] = stream
	resources["sound_streams"] = sound_streams

	animation_resource_cache[cache_key] = resources
	return resources


func _get_animation_data(config: Dictionary) -> Dictionary:
	var data_path: String = str(config.get("data_path", ""))
	if animation_data_cache.has(data_path):
		return animation_data_cache[data_path] as Dictionary

	var parsed_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if parsed_data == null or not parsed_data is Dictionary:
		push_warning("Could not preload animation data: %s" % data_path)
		return {}

	var animation_data: Dictionary = parsed_data as Dictionary
	if not _animation_data_is_valid(animation_data):
		push_warning("Animation data is incomplete: %s" % data_path)
		return {}

	animation_data_cache[data_path] = animation_data
	return animation_data


func _request_animation_resources(config: Dictionary) -> void:
	var resource_path_keys: Array[String] = ["sheet_path", "background_path", "foreground_path"]
	for path_key: String in resource_path_keys:
		var resource_path: String = str(config.get(path_key, ""))
		if resource_path != "":
			_request_threaded_resource(resource_path)

	var sound_paths: Dictionary = config.get("sound_paths", {}) as Dictionary
	for sound_path_value: Variant in sound_paths.values():
		var sound_path: String = str(sound_path_value)
		if sound_path != "":
			_request_threaded_resource(sound_path)


func _wait_for_animation_resources(parent_node: Node, config: Dictionary) -> void:
	if parent_node == null or parent_node.get_tree() == null:
		return

	var timeout_seconds: float = 1.5
	var started_msec: int = Time.get_ticks_msec()
	while not _animation_resources_finished_loading(config):
		var elapsed_seconds: float = float(Time.get_ticks_msec() - started_msec) / 1000.0
		if elapsed_seconds >= timeout_seconds:
			return
		await parent_node.get_tree().process_frame


func _animation_resources_finished_loading(config: Dictionary) -> bool:
	var resource_paths: Array[String] = _get_animation_resource_paths(config)
	for resource_path: String in resource_paths:
		if resource_cache.has(resource_path):
			continue
		if not ResourceLoader.exists(resource_path):
			return false
		if not threaded_resource_requests.has(resource_path):
			_request_threaded_resource(resource_path)
			return false

		var status: int = ResourceLoader.load_threaded_get_status(resource_path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				continue
			_:
				return false

	return true


func _get_animation_resource_paths(config: Dictionary) -> Array[String]:
	var resource_paths: Array[String] = []
	var resource_path_keys: Array[String] = ["sheet_path", "background_path", "foreground_path"]
	for path_key: String in resource_path_keys:
		var resource_path: String = str(config.get(path_key, ""))
		if resource_path != "":
			resource_paths.append(resource_path)

	var sound_paths: Dictionary = config.get("sound_paths", {}) as Dictionary
	for sound_path_value: Variant in sound_paths.values():
		var sound_path: String = str(sound_path_value)
		if sound_path != "":
			resource_paths.append(sound_path)

	return resource_paths


func _animation_data_is_valid(animation_data: Dictionary) -> bool:
	var frames_value: Variant = animation_data.get("frames", [])
	if not frames_value is Array or (frames_value as Array).is_empty():
		return false

	var tile_size_value: Variant = animation_data.get("tile_size", [])
	if not tile_size_value is Array or (tile_size_value as Array).size() < 2:
		return false

	if float(animation_data.get("fps", 20.0)) <= 0.0:
		return false

	return true


func _animation_cache_key(config: Dictionary) -> String:
	return str(config.get("data_path", ""))


func _sound_name_for_path(sound_paths: Dictionary, sound_path: String) -> String:
	for sound_name: Variant in sound_paths.keys():
		if str(sound_paths.get(sound_name, "")) == sound_path:
			return str(sound_name)

	return sound_path


func _request_threaded_resource(resource_path: String) -> void:
	if resource_path == "":
		return
	if resource_cache.has(resource_path) or threaded_resource_requests.has(resource_path):
		return
	if not ResourceLoader.exists(resource_path):
		return

	var error: Error = ResourceLoader.load_threaded_request(resource_path)
	if error == OK or error == ERR_BUSY:
		threaded_resource_requests[resource_path] = true


func _get_cached_resource(resource_path: String) -> Resource:
	if resource_path == "":
		return null
	if resource_cache.has(resource_path):
		return resource_cache[resource_path] as Resource
	if not ResourceLoader.exists(resource_path):
		return null

	if not threaded_resource_requests.has(resource_path):
		_request_threaded_resource(resource_path)
		return null

	var status: int = ResourceLoader.load_threaded_get_status(resource_path)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(resource_path)
			if resource != null:
				resource_cache[resource_path] = resource
			threaded_resource_requests.erase(resource_path)
			return resource
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			threaded_resource_requests.erase(resource_path)

	return null


func _animation_assets_available(config: Dictionary) -> bool:
	var data_path: String = str(config.get("data_path", ""))
	var sheet_path: String = str(config.get("sheet_path", ""))
	if data_path == "":
		return false
	if not FileAccess.file_exists(data_path):
		return false
	if sheet_path == "" and bool(config.get("show_sheet_sprites", true)):
		return false
	if sheet_path != "" and not ResourceLoader.exists(sheet_path):
		return false

	var optional_resource_path_keys: Array[String] = ["background_path", "foreground_path"]
	for path_key: String in optional_resource_path_keys:
		var resource_path: String = str(config.get(path_key, ""))
		if resource_path != "" and not ResourceLoader.exists(resource_path):
			return false

	var sound_paths: Dictionary = config.get("sound_paths", {}) as Dictionary
	for sound_path_value: Variant in sound_paths.values():
		var sound_path: String = str(sound_path_value)
		if sound_path != "" and not ResourceLoader.exists(sound_path):
			return false

	return true


func _create_animation_overlay(parent_node: Node, config: Dictionary = {}) -> Control:
	if not parent_node is Control:
		return null

	var parent_control: Control = parent_node as Control
	var overlay: Control = Control.new()
	overlay.name = "MoveAnimationOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	overlay.z_index = (
		BattleRenderLayers.FIELD
		if bool(config.get("render_below_sprites", false))
		else BattleRenderLayers.MOVE_FOREGROUND
	)
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 0.0
	overlay.anchor_bottom = 0.0
	overlay.position = Vector2.ZERO
	overlay.custom_minimum_size = parent_control.size
	overlay.size = parent_control.size
	return overlay


func _move_overlay_below_sprites(overlay: Control, parent_node: Node, config: Dictionary) -> void:
	if overlay == null or parent_node == null or not bool(config.get("render_below_sprites", false)):
		return

	var sibling_index: int = parent_node.get_child_count()
	for sprite_box: Node in [player_sprite_box, enemy_sprite_box]:
		if sprite_box != null and sprite_box.get_parent() == parent_node:
			sibling_index = mini(sibling_index, sprite_box.get_index())
	parent_node.move_child(overlay, sibling_index)


func _move_timing_background_below_sprites(animation_node: MoveAnimationPlayer, parent_node: Node, config: Dictionary) -> void:
	if animation_node == null or parent_node == null or not bool(config.get("background_below_sprites", false)):
		return

	var sibling_index: int = parent_node.get_child_count()
	for sprite_box: Node in [player_sprite_box, enemy_sprite_box]:
		if sprite_box != null and sprite_box.get_parent() == parent_node:
			sibling_index = mini(sibling_index, sprite_box.get_index())
	animation_node.move_timing_background_to(parent_node, sibling_index)


func _fit_animation_to_parent(animation_node: Node2D, parent_node: Node) -> void:
	const SOURCE_SIZE := Vector2(512, 384)
	if parent_node is Control:
		var parent_control: Control = parent_node as Control
		var available_size: Vector2 = parent_control.size
		var cover_scale: float = maxf(available_size.x / SOURCE_SIZE.x, available_size.y / SOURCE_SIZE.y)
		animation_node.scale = Vector2(cover_scale, cover_scale)
		animation_node.position = (available_size - SOURCE_SIZE * cover_scale) * 0.5
		return

	animation_node.position = Vector2.ZERO


func _apply_effect_target_offset(animation_node: Node2D, target_ident: String, config: Dictionary, parent_node: Node) -> void:
	if target_ident == "":
		return

	var source_anchor: Vector2 = _get_effect_anchor_position(str(config.get("source_anchor", "player")))
	var target_anchor: Vector2 = _get_effect_target_anchor_in_parent(_get_player_id_from_ident(target_ident), parent_node)
	if target_anchor == Vector2.ZERO or source_anchor == Vector2.ZERO:
		return

	var source_anchor_in_parent := animation_node.position + Vector2(source_anchor.x * animation_node.scale.x, source_anchor.y * animation_node.scale.y)
	var effect_offset: Vector2 = _vector2_from_config_value(config.get("effect_position_offset", [0.0, 0.0]), Vector2.ZERO)
	if bool(config.get("keep_screen_overlay_fullscreen", false)) and animation_node is MoveAnimationPlayer:
		var scale_x: float = animation_node.scale.x if absf(animation_node.scale.x) > 0.001 else 1.0
		var scale_y: float = animation_node.scale.y if absf(animation_node.scale.y) > 0.001 else 1.0
		var visual_offset := Vector2(
			(target_anchor.x - source_anchor_in_parent.x) / scale_x + effect_offset.x,
			(target_anchor.y - source_anchor_in_parent.y) / scale_y + effect_offset.y
		)
		_apply_effect_visual_offset(animation_node as MoveAnimationPlayer, visual_offset)
		return

	animation_node.position += target_anchor - source_anchor_in_parent
	animation_node.position += Vector2(effect_offset.x * animation_node.scale.x, effect_offset.y * animation_node.scale.y)


func _apply_effect_visual_offset(animation_node: MoveAnimationPlayer, visual_offset: Vector2) -> void:
	animation_node.sprite_position_offset += visual_offset
	animation_node.sparkle_center += visual_offset
	if animation_node.orb_config.has("center"):
		var orb_center := _vector2_from_config_value(animation_node.orb_config.get("center", []), animation_node.sparkle_center - visual_offset)
		animation_node.orb_config["center"] = [
			orb_center.x + visual_offset.x,
			orb_center.y + visual_offset.y,
		]
	if animation_node.solar_charge_config.has("center"):
		var charge_center := _vector2_from_config_value(animation_node.solar_charge_config.get("center", []), animation_node.sparkle_center - visual_offset)
		animation_node.solar_charge_config["center"] = [
			charge_center.x + visual_offset.x,
			charge_center.y + visual_offset.y,
		]


func _apply_move_projectile_endpoint_anchors(
	animation_node: MoveAnimationPlayer,
	actor_ident: String,
	target_ident: String,
	parent_node: Node,
	config: Dictionary = {},
	animation_options: Dictionary = {}
) -> void:
	if actor_ident == "" or animation_node == null:
		return

	var actor_id := _get_player_id_from_ident(actor_ident)
	if actor_id == "":
		return

	var target_id := _get_player_id_from_ident(target_ident)
	if target_id == "":
		target_id = "p2" if actor_id == "p1" else "p1"

	var actor_anchor_point := str(config.get("projectile_actor_anchor_point", "center")).strip_edges().to_lower()
	var target_anchor_point := str(config.get("projectile_target_anchor_point", "center")).strip_edges().to_lower()
	var actor_anchor_parent := _get_effect_target_anchor_in_parent(actor_id, parent_node, actor_anchor_point)
	var target_anchor_parent := _get_effect_target_anchor_in_parent(target_id, parent_node, target_anchor_point)
	var player_feet_parent := _get_effect_target_anchor_in_parent("p1", parent_node, "feet")
	var enemy_feet_parent := _get_effect_target_anchor_in_parent("p2", parent_node, "feet")
	if player_feet_parent != Vector2.ZERO and enemy_feet_parent != Vector2.ZERO:
		animation_node.court_change_config = _with_court_change_anchors(
			animation_node.court_change_config,
			_parent_position_to_animation_source(animation_node, player_feet_parent),
			_parent_position_to_animation_source(animation_node, enemy_feet_parent)
		)
	if actor_anchor_parent == Vector2.ZERO or target_anchor_parent == Vector2.ZERO:
		return

	if _is_miss_animation(animation_options):
		var miss_config := _get_miss_animation_config(config)
		if not miss_config.is_empty():
			var target_offset := _get_miss_animation_offset(miss_config, "target_offset", Vector2(56.0, -20.0))
			if actor_id == "p2":
				target_offset = Vector2(-target_offset.x, -target_offset.y)
			target_anchor_parent += Vector2(target_offset.x * animation_node.scale.x, target_offset.y * animation_node.scale.y)

	var actor_anchor := _parent_position_to_animation_source(animation_node, actor_anchor_parent)
	var target_anchor := _parent_position_to_animation_source(animation_node, target_anchor_parent)
	animation_node.projectile_config = _with_projectile_endpoint_anchors(
		animation_node.projectile_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.orb_projectile_config = _with_projectile_endpoint_anchors(
		animation_node.orb_projectile_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.orb_barrage_config = _with_projectile_endpoint_anchors(
		animation_node.orb_barrage_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.psychic_pulse_config = _with_projectile_endpoint_anchors(
		animation_node.psychic_pulse_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.energy_blast_config = _with_projectile_endpoint_anchors(
		animation_node.energy_blast_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.water_splash_config = _with_projectile_endpoint_anchors(
		animation_node.water_splash_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.electric_switch_config = _with_projectile_endpoint_anchors(
		animation_node.electric_switch_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.fire_stream_config = _with_projectile_endpoint_anchors(
		animation_node.fire_stream_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.heat_wave_config = _with_projectile_endpoint_anchors(
		animation_node.heat_wave_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.solar_beam_config = _with_projectile_endpoint_anchors(
		animation_node.solar_beam_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.bloom_doom_config = _with_projectile_endpoint_anchors(
		animation_node.bloom_doom_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.draco_meteor_config = _with_target_effect_anchor(
		animation_node.draco_meteor_config,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.stat_change_config = _with_target_effect_anchor(
		animation_node.stat_change_config,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.celestial_charge_config = _with_self_effect_anchor(
		animation_node.celestial_charge_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.focus_aura_config = _with_self_effect_anchor(
		animation_node.focus_aura_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.afterimage_config = _with_self_effect_anchor(
		animation_node.afterimage_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.orb_config = _with_self_effect_anchor(
		animation_node.orb_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)
	if animation_node.orb_config.has("center"):
		animation_node.sparkle_center = _vector2_from_config_value(animation_node.orb_config.get("center", []), animation_node.sparkle_center)
	animation_node.dragon_dance_config = _with_self_effect_anchor(
		animation_node.dragon_dance_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.dragon_claw_config = _with_target_effect_anchor(
		animation_node.dragon_claw_config,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.thunder_punch_config = _with_target_effect_anchor(
		animation_node.thunder_punch_config,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.bullet_punch_config = _with_target_effect_anchor(
		animation_node.bullet_punch_config,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.dark_pulse_config = _with_projectile_endpoint_anchors(
		animation_node.dark_pulse_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.sound_wave_config = _with_projectile_endpoint_anchors(
		animation_node.sound_wave_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.leaf_rush_config = _with_projectile_endpoint_anchors(
		animation_node.leaf_rush_config,
		actor_anchor,
		target_anchor,
		animation_node.reverse_battlefield
	)
	animation_node.nasty_plot_config = _with_self_effect_anchor(
		animation_node.nasty_plot_config,
		actor_anchor,
		animation_node.reverse_battlefield
	)


func _apply_move_sheet_anchor(
	animation_node: MoveAnimationPlayer,
	actor_ident: String,
	target_ident: String,
	parent_node: Node,
	config: Dictionary
) -> void:
	if animation_node == null or not animation_node.show_sheet_sprites:
		return

	var anchor_player_id := _resolve_move_sheet_anchor_player_id(config, actor_ident, target_ident)
	if anchor_player_id == "":
		return

	var anchor_point := str(config.get("sheet_anchor_point", "center")).strip_edges().to_lower()
	var dynamic_anchor_parent := _get_effect_target_anchor_in_parent(anchor_player_id, parent_node, anchor_point)
	if dynamic_anchor_parent == Vector2.ZERO:
		return

	var dynamic_anchor_source := _parent_position_to_animation_source(animation_node, dynamic_anchor_parent)
	var source_anchor_player_id := anchor_player_id
	if animation_node.reverse_battlefield:
		source_anchor_player_id = "p2" if anchor_player_id == "p1" else "p1"
	var default_fixed_anchor_source := EFFECT_SOURCE_PLAYER_POSITION if source_anchor_player_id == "p1" else EFFECT_SOURCE_ENEMY_POSITION
	var fixed_anchor_source := _vector2_from_config_value(
		config.get("sheet_anchor_source_position", [default_fixed_anchor_source.x, default_fixed_anchor_source.y]),
		default_fixed_anchor_source
	)
	var source_anchor_offset := dynamic_anchor_source - fixed_anchor_source
	var display_anchor_offset := animation_node.battlefield_offset_to_display(source_anchor_offset)
	var pattern_groups_value: Variant = config.get("sheet_pattern_anchor_groups", [])
	if pattern_groups_value is Array and not (pattern_groups_value as Array).is_empty():
		for group_value: Variant in pattern_groups_value as Array:
			if not group_value is Dictionary:
				continue
			var group: Dictionary = group_value as Dictionary
			var group_anchor_source := _vector2_from_config_value(
				group.get("source_anchor", [fixed_anchor_source.x, fixed_anchor_source.y]),
				fixed_anchor_source
			)
			var group_source_offset := dynamic_anchor_source - group_anchor_source
			var group_display_offset := animation_node.battlefield_offset_to_display(group_source_offset)
			var patterns_value: Variant = group.get("patterns", [])
			if not patterns_value is Array:
				continue
			for pattern_value: Variant in patterns_value as Array:
				animation_node.sheet_pattern_visual_offsets[str(int(pattern_value))] = group_display_offset
		return
	animation_node.sheet_visual_offset += display_anchor_offset


func _resolve_move_sheet_anchor_player_id(config: Dictionary, actor_ident: String, target_ident: String) -> String:
	var actor_id := _get_player_id_from_ident(actor_ident)
	var target_id := _get_player_id_from_ident(target_ident)
	if target_id == "" and actor_id != "":
		target_id = "p2" if actor_id == "p1" else "p1"

	match str(config.get("static_visual_anchor", "")).strip_edges().to_lower():
		"none", "battlefield":
			return ""
		"actor", "source":
			return actor_id
		"target":
			return target_id
		"p1", "player":
			return "p1"
		"p2", "enemy":
			return "p2"

	match str(config.get("category", "")).strip_edges().to_lower():
		"field", "field_hazard", "screen":
			return ""
		"status_buff":
			return actor_id
		_:
			return target_id


func _with_projectile_endpoint_anchors(
	config: Dictionary,
	actor_anchor: Vector2,
	target_anchor: Vector2,
	reverse_battlefield := false
) -> Dictionary:
	if config.is_empty():
		return config

	var updated_config: Dictionary = config.duplicate(true)
	var actor_offset := _vector2_from_config_value(updated_config.get("actor_offset", [0.0, 0.0]), Vector2.ZERO)
	var target_offset := _vector2_from_config_value(updated_config.get("target_offset", [0.0, 0.0]), Vector2.ZERO)
	var source_actor_offset := -actor_offset if reverse_battlefield else actor_offset
	var source_target_offset := -target_offset if reverse_battlefield else target_offset
	var source_actor_anchor := actor_anchor + source_actor_offset
	var source_target_anchor := target_anchor + source_target_offset
	if updated_config.has("path"):
		_set_projectile_path_endpoints(updated_config, "path", source_actor_anchor, source_target_anchor)
	if updated_config.has("reverse_path"):
		var reverse_actor_anchor := source_actor_anchor
		var reverse_target_anchor := source_target_anchor
		if reverse_battlefield:
			# Explicit reverse paths are already authored in display coordinates and
			# bypass the renderer's battlefield mirror. Convert live source anchors
			# back to display space while keeping visual offsets screen-relative.
			reverse_actor_anchor = _reverse_battlefield_position(actor_anchor) + actor_offset
			reverse_target_anchor = _reverse_battlefield_position(target_anchor) + target_offset
		_set_projectile_path_endpoints(updated_config, "reverse_path", reverse_actor_anchor, reverse_target_anchor)
	return updated_config


func _reverse_battlefield_position(position: Vector2) -> Vector2:
	return Vector2(
		REVERSED_BATTLEFIELD_AXIS.x - position.x,
		REVERSED_BATTLEFIELD_AXIS.y - position.y
	)


func _with_self_effect_anchor(config: Dictionary, actor_anchor: Vector2, reverse_battlefield := false) -> Dictionary:
	if config.is_empty():
		return config

	var updated_config: Dictionary = config.duplicate(true)
	var center_offset := _vector2_from_config_value(updated_config.get("center_offset", [0.0, 0.0]), Vector2.ZERO)
	actor_anchor += -center_offset if reverse_battlefield else center_offset
	updated_config["center"] = [actor_anchor.x, actor_anchor.y]
	updated_config.erase("center_offset")
	return updated_config


func _with_target_effect_anchor(config: Dictionary, target_anchor: Vector2, reverse_battlefield := false) -> Dictionary:
	if config.is_empty():
		return config

	var updated_config: Dictionary = config.duplicate(true)
	var center_offset := _vector2_from_config_value(updated_config.get("center_offset", [0.0, 0.0]), Vector2.ZERO)
	target_anchor += -center_offset if reverse_battlefield else center_offset
	updated_config["center"] = [target_anchor.x, target_anchor.y]
	updated_config.erase("center_offset")
	return updated_config


func _with_court_change_anchors(config: Dictionary, player_feet: Vector2, enemy_feet: Vector2) -> Dictionary:
	if config.is_empty():
		return config

	var updated_config: Dictionary = config.duplicate(true)
	updated_config["player_center"] = [player_feet.x, player_feet.y]
	updated_config["enemy_center"] = [enemy_feet.x, enemy_feet.y]
	return updated_config


func _set_projectile_path_endpoints(config: Dictionary, path_key: String, actor_anchor: Vector2, target_anchor: Vector2) -> void:
	var path_value: Variant = config.get(path_key, [])
	if not path_value is Array:
		return

	var path: Array = (path_value as Array).duplicate(true)
	if path.is_empty():
		return

	if path[0] is Dictionary:
		var first_point: Dictionary = (path[0] as Dictionary).duplicate(true)
		first_point["position"] = [actor_anchor.x, actor_anchor.y]
		path[0] = first_point

	if bool(config.get("return_to_actor", false)):
		var target_point_index: int = clampi(int(config.get("target_point_index", path.size() - 1)), 0, path.size() - 1)
		if path[target_point_index] is Dictionary:
			var target_point: Dictionary = (path[target_point_index] as Dictionary).duplicate(true)
			target_point["position"] = [target_anchor.x, target_anchor.y]
			path[target_point_index] = target_point

		var return_index: int = path.size() - 1
		if path[return_index] is Dictionary:
			var return_point: Dictionary = (path[return_index] as Dictionary).duplicate(true)
			return_point["position"] = [actor_anchor.x, actor_anchor.y]
			path[return_index] = return_point

		config[path_key] = path
		return

	var last_index: int = path.size() - 1
	if path[last_index] is Dictionary:
		var last_point: Dictionary = (path[last_index] as Dictionary).duplicate(true)
		last_point["position"] = [target_anchor.x, target_anchor.y]
		path[last_index] = last_point

	config[path_key] = path


func _parent_position_to_animation_source(animation_node: Node2D, parent_position: Vector2) -> Vector2:
	var scale_x: float = animation_node.scale.x if absf(animation_node.scale.x) > 0.001 else 1.0
	var scale_y: float = animation_node.scale.y if absf(animation_node.scale.y) > 0.001 else 1.0
	var source_position := Vector2(
		(parent_position.x - animation_node.position.x) / scale_x,
		(parent_position.y - animation_node.position.y) / scale_y
	)
	if animation_node is MoveAnimationPlayer:
		return (animation_node as MoveAnimationPlayer).display_position_to_battlefield_source(source_position)
	return source_position


func _get_effect_anchor_position(anchor: String) -> Vector2:
	match anchor.strip_edges().to_lower():
		"p1", "player", "source":
			return EFFECT_SOURCE_PLAYER_POSITION
		"p2", "enemy", "target":
			return EFFECT_SOURCE_ENEMY_POSITION
		_:
			return Vector2.ZERO


func _get_effect_target_anchor_in_parent(player_id: String, parent_node: Node, anchor_point := "center") -> Vector2:
	if player_id != "p1" and player_id != "p2":
		return Vector2.ZERO

	var target_box: Node = player_sprite_box if player_id == "p1" else enemy_sprite_box
	var use_battle_anchor := anchor_point == "feet" or anchor_point == "battle"
	if use_battle_anchor and target_box != null and parent_node is CanvasItem and target_box.has_method("get_single_battle_anchor_in_node"):
		var battle_anchor: Variant = target_box.call("get_single_battle_anchor_in_node", parent_node as CanvasItem)
		if battle_anchor is Vector2 and battle_anchor != Vector2.ZERO:
			return battle_anchor as Vector2

	if target_box != null and parent_node is CanvasItem and target_box.has_method("get_single_animation_anchor_in_node"):
		var animation_anchor: Variant = target_box.call("get_single_animation_anchor_in_node", parent_node as CanvasItem)
		if animation_anchor is Vector2 and animation_anchor != Vector2.ZERO:
			return animation_anchor as Vector2

	if target_box != null and parent_node is CanvasItem and target_box.has_method("get_single_battle_anchor_in_node"):
		var dynamic_anchor: Variant = target_box.call("get_single_battle_anchor_in_node", parent_node as CanvasItem)
		if dynamic_anchor is Vector2 and dynamic_anchor != Vector2.ZERO:
			return dynamic_anchor as Vector2

	return _get_effect_anchor_position(player_id)


func _wait_for_animation_node(animation_node: Node2D, parent_node: Node) -> void:
	if not is_instance_valid(animation_node):
		return
	var tree := parent_node.get_tree() if parent_node != null else null
	if tree == null:
		animation_node.queue_free()
		return

	var started_msec := Time.get_ticks_msec()
	while is_instance_valid(animation_node) and animation_node.is_inside_tree():
		var elapsed_seconds := float(Time.get_ticks_msec() - started_msec) / 1000.0
		if elapsed_seconds >= MAX_ANIMATION_WAIT_SECONDS:
			push_warning(
				"Battle animation exceeded %.1f seconds and was stopped so presentation can continue. data=%s"
				% [MAX_ANIMATION_WAIT_SECONDS, str(animation_node.get("data_path"))]
			)
			animation_node.queue_free()
			await tree.process_frame
			return
		await tree.process_frame

	if is_instance_valid(animation_node):
		# A non-autofree animation may leave the tree through its parent. Dispose
		# it here as well; callers only need the presentation boundary to finish.
		animation_node.queue_free()


func play_damage_tween_for_target(target_ident: String, sound_variant: String = "normal") -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.damage_tween", {"target": target_ident}):
		return

	var sound_path := get_damage_sound_path(sound_variant)
	_play_one_shot_sound(sound_path)
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_damage_tween()
		"p2":
			await enemy_sprite_box.play_damage_tween()


static func get_damage_sound_path(sound_variant: String) -> String:
	if sound_variant == "super_effective":
		return SUPER_EFFECTIVE_DAMAGE_SOUND_PATH
	return TAKE_DAMAGE_SOUND_PATH


func _play_one_shot_sound(sound_path: String) -> void:
	if not _can_start_battle_animation("router.render_sound", {"sound": sound_path}):
		return

	var stream: AudioStream = _get_cached_sound_stream(sound_path)
	if stream == null:
		return

	var parent_node: Node = animation_parent
	if parent_node == null and player_sprite_box != null:
		parent_node = player_sprite_box.get_parent()
	if parent_node == null:
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SettingsManager.SFX_BUS
	player.finished.connect(player.queue_free)
	parent_node.add_child(player)
	player.play()


func _get_cached_sound_stream(sound_path: String) -> AudioStream:
	if sound_path == "":
		return null
	if sound_stream_cache.has(sound_path):
		return sound_stream_cache[sound_path] as AudioStream

	var stream: AudioStream = _get_cached_resource(sound_path) as AudioStream
	if stream != null:
		sound_stream_cache[sound_path] = stream
	return stream


func play_heal_tween_for_target(target_ident: String, event_data: Dictionary = {}) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.heal_tween", {"target": target_ident}):
		return
	if not is_event_target_currently_visible(target_ident, event_data):
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_heal_tween()
		"p2":
			await enemy_sprite_box.play_heal_tween()


func play_heal_presentation_for_target(target_ident: String, effect_key: String = "", event_data: Dictionary = {}) -> void:
	if effect_key == "":
		await play_heal_tween_for_target(target_ident, event_data)
		return

	# The glow pulse belongs to the same beat as the energy particles. Starting
	# it without awaiting lets both finish together instead of playing serially.
	play_heal_tween_for_target(target_ident, event_data)
	await play_effect_animation(effect_key, target_ident)


func play_faint_tween_for_target(target_ident: String) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.faint_tween", {"target": target_ident}):
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_faint_tween()
		"p2":
			await enemy_sprite_box.play_faint_tween()


func play_stat_change_tween_for_target(target_ident: String, amount: int) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.stat_change_tween", {
		"target": target_ident,
		"amount": amount,
	}):
		return

	if amount == 0:
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			if amount > 0:
				await player_sprite_box.play_stat_raise_tween()
			else:
				await player_sprite_box.play_stat_drop_tween()
		"p2":
			if amount > 0:
				await enemy_sprite_box.play_stat_raise_tween()
			else:
				await enemy_sprite_box.play_stat_drop_tween()


func play_stat_change_presentation_for_target(target_ident: String, amount: int, effect_key: String = "") -> void:
	if amount == 0:
		return

	var resolved_effect_key := effect_key
	if resolved_effect_key == "":
		resolved_effect_key = "stat_up" if amount > 0 else "stat_down"

	# Start the sprite response without awaiting it so the colored flash and
	# movement belong to the same beat as the surrounding energy particles.
	play_stat_change_tween_for_target(target_ident, amount)
	await play_effect_animation(resolved_effect_key, target_ident)


func _normalize_move_name(move_name: String) -> String:
	return (
		move_name.strip_edges()
		.to_lower()
		.replace(" ", "")
		.replace("-", "")
		.replace("_", "")
		.replace(",", "")
		.replace("'", "")
		.replace("’", "")
		.replace("*", "")
	)


func _can_start_battle_animation(source: String, details: Dictionary = {}) -> bool:
	if not animation_guard.is_valid():
		return true

	return bool(animation_guard.call(source, details))


func _normalize_animation_key(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func is_target_ident_currently_visible(target_ident: String) -> bool:
	var species := _get_species_from_ident(target_ident)
	if species == "":
		return true

	return _is_target_species_currently_visible(target_ident, species)


func is_event_target_currently_visible(target_ident: String, event_data: Dictionary) -> bool:
	var event_species := _get_event_target_display_species(event_data)
	if event_species != "":
		return _is_target_species_currently_visible(target_ident, event_species)

	return is_target_ident_currently_visible(target_ident)


func _is_target_species_currently_visible(target_ident: String, species: String) -> bool:
	var sprite_box := _get_sprite_box_for_ident(target_ident)
	if sprite_box == null:
		return true
	if not sprite_box.has_method("is_showing_species"):
		return true

	return bool(sprite_box.call("is_showing_species", species))


func _get_event_target_display_species(event_data: Dictionary) -> String:
	for ref_key in ["targetRef", "target_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_species := _get_display_species_from_dictionary(ref_value as Dictionary)
		if ref_species != "":
			return ref_species

	return _get_display_species_from_dictionary(event_data)


func _get_display_species_from_dictionary(data: Dictionary) -> String:
	for key in ["displaySpecies", "display_species", "transformedSpecies", "megaSpecies", "species"]:
		var species := str(data.get(key, "")).strip_edges()
		if species != "":
			return species

	return ""


func _get_sprite_box_for_ident(ident: String) -> Node:
	match _get_player_id_from_ident(ident):
		"p1":
			return player_sprite_box
		"p2":
			return enemy_sprite_box

	return null


func _get_species_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges()


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
