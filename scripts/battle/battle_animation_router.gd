extends RefCounted

class_name BattleAnimationRouter

const MOVE_ANIMATION_CATALOG_PATH := "res://data/battle_move_animations.json"
const EFFECT_ANIMATION_CATALOG_PATH := "res://data/battle_effect_animations.json"
const TAKE_DAMAGE_SOUND_PATH := "res://assets/battles/animations/common/damage/normaldamage.ogg"
const EFFECT_SOURCE_PLAYER_POSITION := Vector2(128, 224)
const EFFECT_SOURCE_ENEMY_POSITION := Vector2(384, 96)

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


func play_move_animation(move_name: String, actor_ident: String = "", _target_ident: String = "") -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.move_animation", {
		"move": move_name,
		"actor": actor_ident,
		"target": _target_ident,
	}):
		return

	var move_key: String = _normalize_move_name(move_name)
	var config: Dictionary = _get_move_animation_config(move_key)
	if config.is_empty():
		return

	await _play_animation_config(config, "", _get_player_id_from_ident(actor_ident) == "p2", actor_ident, _target_ident)


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
	move_target_ident: String = ""
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

	var overlay: Control = _create_animation_overlay(parent_node)
	if overlay != null:
		parent_node.add_child(overlay)
		_fit_animation_to_parent(animation_node, overlay)
		_apply_move_projectile_endpoint_anchors(animation_node, move_actor_ident, move_target_ident, overlay)
		_apply_effect_target_offset(animation_node, target_ident, config, overlay)
		overlay.add_child(animation_node)
		await _wait_for_animation_node(animation_node, overlay)
		if is_instance_valid(overlay):
			overlay.queue_free()
		return

	animation_node.z_index = 50
	_fit_animation_to_parent(animation_node, parent_node)
	_apply_move_projectile_endpoint_anchors(animation_node, move_actor_ident, move_target_ident, parent_node)
	_apply_effect_target_offset(animation_node, target_ident, config, parent_node)
	parent_node.add_child(animation_node)
	await _wait_for_animation_node(animation_node, parent_node)


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


func _create_move_animation_node(config: Dictionary, resources: Dictionary = {}, reverse_battlefield: bool = false) -> MoveAnimationPlayer:
	var animation_node: MoveAnimationPlayer = MoveAnimationPlayer.new()
	animation_node.data_path = str(config.get("data_path", ""))
	animation_node.sheet_path = str(config.get("sheet_path", ""))
	animation_node.background_path = str(config.get("background_path", ""))
	animation_node.foreground_path = str(config.get("foreground_path", ""))
	var sound_paths: Dictionary = (config.get("sound_paths", {}) as Dictionary).duplicate(true)
	animation_node.sound_paths = sound_paths
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
	animation_node.sparkle_size_multiplier = float(config.get("sparkle_size_multiplier", 1.0))
	animation_node.pattern_offset = int(config.get("pattern_offset", 0))
	animation_node.pattern_override = int(config.get("pattern_override", -1))
	animation_node.loop = false
	animation_node.free_on_finish = true
	animation_node.show_timing_backgrounds = bool(config.get("show_timing_backgrounds", false))
	animation_node.show_timing_foregrounds = bool(config.get("show_timing_foregrounds", false))
	animation_node.show_pink_visual = bool(config.get("show_pink_visual", false))
	animation_node.show_sheet_sprites = bool(config.get("show_sheet_sprites", true))
	animation_node.overlay_fill_enabled = bool(config.get("overlay_fill_enabled", true))
	animation_node.projectile_config = (config.get("projectile", {}) as Dictionary).duplicate(true)
	animation_node.orb_config = (config.get("orb", {}) as Dictionary).duplicate(true)
	animation_node.orb_projectile_config = (config.get("orb_projectile", {}) as Dictionary).duplicate(true)
	animation_node.visual_color = _color_from_config(config.get("visual_color", [1.0, 0.2, 0.75, 1.0]), Color(1.0, 0.2, 0.75, 1.0))
	animation_node.sprite_tint = _color_from_config(config.get("sprite_tint", [1.0, 1.0, 1.0, 1.0]), Color.WHITE)
	animation_node.reverse_battlefield = reverse_battlefield
	animation_node.overlay_peak_alpha = float(config.get("overlay_peak_alpha", 0.20))
	animation_node.sparkle_count = int(config.get("sparkle_count", 14))
	animation_node.sparkle_center = _vector2_from_config_value(config.get("sparkle_center", [256.0, 188.0]), Vector2(256, 188))
	animation_node.sparkle_radius_min = float(config.get("sparkle_radius_min", 26.0))
	animation_node.sparkle_radius_max = float(config.get("sparkle_radius_max", 78.0))
	return animation_node


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
	if data_path == "" or sheet_path == "":
		return false
	if not FileAccess.file_exists(data_path):
		return false
	if not ResourceLoader.exists(sheet_path):
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


func _create_animation_overlay(parent_node: Node) -> Control:
	if not parent_node is Control:
		return null

	var parent_control: Control = parent_node as Control
	var overlay: Control = Control.new()
	overlay.name = "MoveAnimationOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.clip_contents = true
	overlay.z_index = 50
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 0.0
	overlay.anchor_bottom = 0.0
	overlay.position = Vector2.ZERO
	overlay.custom_minimum_size = parent_control.size
	overlay.size = parent_control.size
	return overlay


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
	animation_node.position += target_anchor - source_anchor_in_parent

	var effect_offset: Vector2 = _vector2_from_config_value(config.get("effect_position_offset", [0.0, 0.0]), Vector2.ZERO)
	animation_node.position += Vector2(effect_offset.x * animation_node.scale.x, effect_offset.y * animation_node.scale.y)


func _apply_move_projectile_endpoint_anchors(
	animation_node: MoveAnimationPlayer,
	actor_ident: String,
	target_ident: String,
	parent_node: Node
) -> void:
	if actor_ident == "" or animation_node == null:
		return

	var actor_id := _get_player_id_from_ident(actor_ident)
	if actor_id == "":
		return

	var target_id := _get_player_id_from_ident(target_ident)
	if target_id == "":
		target_id = "p2" if actor_id == "p1" else "p1"

	var actor_anchor_parent := _get_effect_target_anchor_in_parent(actor_id, parent_node)
	var target_anchor_parent := _get_effect_target_anchor_in_parent(target_id, parent_node)
	if actor_anchor_parent == Vector2.ZERO or target_anchor_parent == Vector2.ZERO:
		return

	var actor_anchor := _parent_position_to_animation_source(animation_node, actor_anchor_parent)
	var target_anchor := _parent_position_to_animation_source(animation_node, target_anchor_parent)
	animation_node.projectile_config = _with_projectile_endpoint_anchors(
		animation_node.projectile_config,
		actor_anchor,
		target_anchor
	)
	animation_node.orb_projectile_config = _with_projectile_endpoint_anchors(
		animation_node.orb_projectile_config,
		actor_anchor,
		target_anchor
	)


func _with_projectile_endpoint_anchors(config: Dictionary, actor_anchor: Vector2, target_anchor: Vector2) -> Dictionary:
	if config.is_empty():
		return config

	var updated_config: Dictionary = config.duplicate(true)
	if updated_config.has("path"):
		_set_projectile_path_endpoints(updated_config, "path", actor_anchor, target_anchor)
	if updated_config.has("reverse_path"):
		_set_projectile_path_endpoints(updated_config, "reverse_path", actor_anchor, target_anchor)
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

	var last_index: int = path.size() - 1
	if path[last_index] is Dictionary:
		var last_point: Dictionary = (path[last_index] as Dictionary).duplicate(true)
		last_point["position"] = [target_anchor.x, target_anchor.y]
		path[last_index] = last_point

	config[path_key] = path


func _parent_position_to_animation_source(animation_node: Node2D, parent_position: Vector2) -> Vector2:
	var scale_x: float = animation_node.scale.x if absf(animation_node.scale.x) > 0.001 else 1.0
	var scale_y: float = animation_node.scale.y if absf(animation_node.scale.y) > 0.001 else 1.0
	return Vector2(
		(parent_position.x - animation_node.position.x) / scale_x,
		(parent_position.y - animation_node.position.y) / scale_y
	)


func _get_effect_anchor_position(anchor: String) -> Vector2:
	match anchor.strip_edges().to_lower():
		"p1", "player", "source":
			return EFFECT_SOURCE_PLAYER_POSITION
		"p2", "enemy", "target":
			return EFFECT_SOURCE_ENEMY_POSITION
		_:
			return Vector2.ZERO


func _get_effect_target_anchor_in_parent(player_id: String, parent_node: Node) -> Vector2:
	if player_id != "p1" and player_id != "p2":
		return Vector2.ZERO

	var target_box: Node = player_sprite_box if player_id == "p1" else enemy_sprite_box
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
	if not animation_node.has_signal("animation_finished"):
		await parent_node.get_tree().create_timer(3.0).timeout
		if is_instance_valid(animation_node):
			animation_node.queue_free()
		return

	await animation_node.tree_exited


func play_damage_tween_for_target(target_ident: String) -> void:
	if not SettingsManager.battle_animations:
		return
	if not _can_start_battle_animation("router.damage_tween", {"target": target_ident}):
		return

	_play_one_shot_sound(TAKE_DAMAGE_SOUND_PATH)
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_damage_tween()
		"p2":
			await enemy_sprite_box.play_damage_tween()


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


func _normalize_move_name(move_name: String) -> String:
	return move_name.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")


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
