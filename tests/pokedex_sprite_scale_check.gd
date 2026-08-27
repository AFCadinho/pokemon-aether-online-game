extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Pokédex overlay loads for sprite scale checks")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	var compact_frames := _create_frames(Vector2i(128, 128), Rect2i(48, 48, 32, 32))
	var compact_scale: Vector2 = overlay.call("_get_pokedex_sprite_scale", compact_frames)
	_check(
		compact_scale.is_equal_approx(Vector2(1.5, 1.5)),
		"compact Pokémon keep the Pokédex baseline scale instead of filling the card"
	)

	var large_visual_size := Vector2(120, 100)
	var large_frames := _create_frames(
		Vector2i(128, 128),
		Rect2i(4, 14, int(large_visual_size.x), int(large_visual_size.y))
	)
	var large_scale: Vector2 = overlay.call("_get_pokedex_sprite_scale", large_frames)
	var rendered_large_size := large_visual_size * large_scale
	_check(
		rendered_large_size.x <= 126.01 and rendered_large_size.y <= 104.01,
		"large Pokémon remain fitted inside the Pokédex sprite stage"
	)
	_check(
		large_scale.x < compact_scale.x,
		"large Pokémon scale down without enlarging compact Pokémon"
	)

	var sprite_loader := overlay.get("pokedex_sprite_loader") as Node
	var squirtle_frames_value: Variant = sprite_loader.call(
		"_load_sprite_frames",
		"squirtle",
		"front",
		false,
		false
	)
	_check(squirtle_frames_value is SpriteFrames, "Squirtle's Pokédex frames load")
	if squirtle_frames_value is SpriteFrames:
		var squirtle_frames := squirtle_frames_value as SpriteFrames
		var squirtle_texture_scale: Vector2 = overlay.call(
			"_get_pokedex_sprite_scale",
			squirtle_frames
		)
		var squirtle_render_scale := float(sprite_loader.call(
			"_get_sprite_frames_render_scale",
			squirtle_frames
		))
		_check(
			is_equal_approx(squirtle_texture_scale.x * squirtle_render_scale, 1.5),
			"Squirtle uses the compact Pokédex baseline scale"
		)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	await process_frame
	quit(1 if failed else 0)


func _create_frames(frame_size: Vector2i, used_rect: Rect2i) -> SpriteFrames:
	var image := Image.create(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(used_rect, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_frame("idle", texture)
	return frames


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
