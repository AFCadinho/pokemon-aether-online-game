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
	_check(str(service.call("_normalize_segment", "Mr. Mime_Form")) == "mr-mime-form", "asset paths are normalized safely")
	var service_source := FileAccess.get_file_as_string("res://scripts/services/web_pokemon_sprite_service.gd")
	_check(service_source.contains("spriteBases") and service_source.contains("WebRuntime.web_release_config()"),
		"production sprite catalogs use versioned R2 base URLs")
	var sprite_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	_check(sprite_source.contains("_upgrade_single_web_sprite.call_deferred"), "battle sprites upgrade without blocking the HOME fallback")
	_check(sprite_source.contains("request_web_sprite_frames"), "battle, preview and detail screens share the web loader")
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
