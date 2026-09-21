extends SceneTree

const SERVICE_SCRIPT := preload("res://scripts/services/web_pokemon_sprite_service.gd")

var failures := 0


func _init() -> void:
	var service := SERVICE_SCRIPT.new()
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var frames: SpriteFrames = service.call("_build_frames", {
		"speed": 2.0,
		"frame_width": 4,
		"frame_height": 4,
		"frames": [
			{"x": 0, "y": 0, "w": 4, "h": 4, "duration": 0.25},
			{"x": 4, "y": 0, "w": 4, "h": 4, "duration": 0.75},
		],
	}, image)
	_check(frames != null and frames.get_frame_count("idle") == 2, "downloaded sheets become idle animations")
	_check(is_equal_approx(frames.get_frame_duration("idle", 0), 0.25), "frame durations are preserved")
	var first_texture := frames.get_frame_texture("idle", 0) as AtlasTexture
	var second_texture := frames.get_frame_texture("idle", 1) as AtlasTexture
	_check(first_texture != null and second_texture != null, "downloaded frames use atlas regions")
	_check(first_texture != null and second_texture != null and first_texture.atlas == second_texture.atlas,
		"all downloaded frames share one WebGL sheet texture")
	_check(first_texture != null and first_texture.region == Rect2(0, 0, 4, 4), "atlas frame region is preserved")
	_check(first_texture != null and second_texture != null and first_texture.filter_clip and second_texture.filter_clip,
		"linear filtering is clipped to each web sprite frame to prevent atlas seams")
	_check(
		service.call("_calculate_visual_bounds", {
			"frame_width": 4,
			"frame_height": 4,
			"frames": [
				{"x": 0, "y": 0, "w": 4, "h": 4},
				{"x": 4, "y": 0, "w": 4, "h": 4},
			],
		}, image) == Rect2(0, 0, 4, 4),
		"downloaded sheets calculate reusable visual bounds before GPU upload"
	)
	_check(str(service.call("_normalize_segment", "Mr. Mime_Form")) == "mr-mime-form", "asset paths are normalized safely")
	var roaring_moon_identity := service.call("_sprite_identity", "Roaring Moon", "back", false, "animated") as Dictionary
	_check(roaring_moon_identity.get("candidate_ids", []) == ["roaring-moon", "roaringmoon"],
		"web sprites try the compact catalog id used by forms such as Roaring Moon")
	_check(str(service.call("_catalog_style", "animated")) == "animated", "normal animated sprites are the browser default")
	_check(str(service.call("_catalog_style", "pixel")) == "pixel", "Gen 5 remains available as the pixel style")
	_check(str(service.call("_catalog_style", "static")) == "", "static style does not request a battle catalog")
	service.call("_remember", "animated/front/pikachu", {"frames": frames})
	var cached_result: Dictionary = service.call("get_cached_frames", "Pikachu", "front", false, "animated")
	_check(cached_result.get("frames") == frames, "prefetched sheets can be read synchronously before first render")
	var service_source := FileAccess.get_file_as_string("res://scripts/services/web_pokemon_sprite_service.gd")
	_check(service_source.contains("spriteStyles") and service_source.contains("WebRuntime.web_release_config()"),
		"production sprite styles use versioned R2 base URLs")
	_check(service_source.contains('"/web-release-config.json"') and service_source.contains("_has_sprite_styles"),
		"browser sprites recover versioned release URLs when the JavaScript bridge loses its object")
	_check(service_source.contains("DOWNLOAD_ATTEMPTS := 3") and service_source.contains("await _download_once(url)"),
		"browser sprite downloads retry bounded transient failures")
	_check(not service_source.contains("Accept: application/json,image/png"),
		"browser sprite downloads avoid unnecessary CORS preflight headers")
	_check(service_source.contains("PREFETCH_CONCURRENCY := 4") and service_source.contains("_in_flight"),
		"background prefetching is bounded and concurrent requests are deduplicated")
	_check(service_source.contains('"visual_bounds": visual_bounds'),
		"prefetched sprite results retain their CPU-calculated visual bounds")
	var sprite_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	_check(sprite_source.contains("_load_cached_web_sprite_frames") and sprite_source.find("_load_cached_web_sprite_frames") < sprite_source.find("sprite_frames_cache.has"),
		"battle sprites consume prefetched web sheets before any local HOME fallback")
	_check(sprite_source.contains("request_web_sprite_frames"), "battle, preview and detail screens share the web loader")
	_check(sprite_source.contains('if str(result.get("style", "animated")) == "pixel"'),
		"Gen 5 display scaling is limited to the optional pixel style")
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	_check(settings_source.contains("func get_active_sprite_style") and settings_source.contains('ContentPacks.has_sprite_collection_style("gen5")'),
		"desktop content packs select the active Gen 5 sprite style")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(world_source.contains("_prefetch_current_map_wild_sprites") and world_source.contains("encounterTypes"),
		"browser maps prefetch their wild encounter pool")
	_check(world_source.contains("WebPokemonSpriteService.prefetch(priority_entries)") and world_source.contains("await WebPokemonSpriteService.prefetch_and_wait(priority_entries)"),
		"ordinary encounters wait only for the visible leads while the remaining roster warms in the background")
	_check(world_source.contains("await _prefetch_web_battle_sprites(response, true)"),
		"AI and custom team-preview battles can still finish their full-roster prefetch")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(overlay_source.contains('_prefetch_web_team_sprites(pokemon, "front")') and overlay_source.contains('_prefetch_web_team_sprites(pokemon, "back")'),
		"AI Sparring and custom-game team previews begin loading both player and opponent rosters early")
	var sprite_scene := FileAccess.get_file_as_string("res://scenes/battle/sprite_box.tscn")
	var preview_scene := FileAccess.get_file_as_string("res://scenes/battle/team_preview_layer.tscn")
	_check(not sprite_scene.contains("assets/sprites/pokemon/front/") and sprite_scene.contains("pokemon_home/Pikachu.png"), "battle fallback does not require an excluded legacy sheet")
	_check(not preview_scene.contains("assets/sprites/pokemon/front/") and preview_scene.contains("pokemon_home/Eevee.png"), "team preview fallback does not require an excluded legacy sheet")
	service.free()
	if failures == 0:
		print("web_dynamic_pokemon_sprite_check: PASS")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("web_dynamic_pokemon_sprite_check: %s" % message)
