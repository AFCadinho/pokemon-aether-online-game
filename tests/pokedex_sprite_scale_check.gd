extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const RENDERED_ASSETS := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")

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
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		overlay_source.contains(
			"pokedex_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS"
		),
		"rendered Pokédex animation uses mipmapped filtering while downscaled"
	)
	_check(
		overlay_source.contains(
			"sprite_viewport_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR"
		),
		"completed Pokédex preview uses linear filtering at fractional window scales"
	)
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

	if not RENDERED_ASSETS._preview_catalog_path().is_empty():
		var dragonite_value: Variant = sprite_loader.call(
			"_load_preview_sprite_frames",
			"dragonite",
			"front",
			false,
			false,
			true
		)
		_check(dragonite_value is SpriteFrames, "rendered Dragonite loads for non-battle preview checks")
		if dragonite_value is SpriteFrames:
			var dragonite_frames := dragonite_value as SpriteFrames
			_check(bool(dragonite_frames.get_meta("rendered_static_preview", false)), "non-battle Dragonite uses a lightweight lossless still")
			_check(bool(dragonite_frames.get_meta("rendered_mipmaps", false)), "non-battle Dragonite still includes mipmaps")
			_check(dragonite_frames.get_frame_count("idle") == 1, "non-battle Dragonite does not decode its 60 FPS atlas")
			var visual_bounds_value: Variant = sprite_loader.call(
				"_get_sprite_frames_visual_bounds",
				dragonite_frames
			)
			var visual_bounds := visual_bounds_value as Rect2
			(overlay.get("pokemon_summary_sprite_loader") as Node).call("_prepare_rendered_sprite_frames", dragonite_frames)
			var summary_size: Vector2 = visual_bounds.size * overlay.call(
				"_get_pokemon_summary_sprite_scale",
				dragonite_frames
			)
			var pokedex_size: Vector2 = visual_bounds.size * overlay.call(
				"_get_pokedex_sprite_scale",
				dragonite_frames
			)
			print("Rendered bounds=%s Summary=%s Pokedex=%s" % [visual_bounds, summary_size, pokedex_size])
			_check(summary_size.y >= 120.0 and summary_size.y <= 155.0 * 1.22 + 0.01,
				"rendered Summary art uses the visible silhouette instead of the 512px canvas")
			_check(pokedex_size.y >= 80.0 and pokedex_size.y <= 112.0 * 1.22 + 0.01,
				"rendered Pokédex portrait stays inside the bounded enlargement budget")
			var animated_value: Variant = await sprite_loader.call(
				"request_rendered_sprite_frames",
				"dragonite",
				"front",
				false,
				Callable(),
				Callable(),
				true
			)
			_check(animated_value is SpriteFrames and (animated_value as SpriteFrames).get_frame_count("idle") > 1,
				"rendered Pokédex still upgrades to the streamed 60 FPS idle animation")
			if animated_value is SpriteFrames:
				var animated_frames := animated_value as SpriteFrames
				_check(bool(animated_frames.get_meta("rendered_mipmaps", false)), "streamed Pokédex animation includes mipmaps")
				_check(
					await sprite_loader.call(
						"request_rendered_sprite_action", animated_frames, "damage", Callable()
					),
					"rendered preview actions decode asynchronously on demand"
				)
				_check(animated_frames.has_animation("damage"), "decoded preview action is ready for direct playback")
			var animated_scale: Vector2 = overlay.call("_get_pokedex_sprite_scale", animated_value)
			_check(animated_scale.is_equal_approx(pokedex_size / visual_bounds.size), "portrait scale remains fixed after streaming")

			var rendered_summary_heights := {}
			for species: String in ["diglett", "jigglypuff", "dragonite"]:
				var species_frames_value: Variant = sprite_loader.call(
					"_load_preview_sprite_frames", species, "front", false, false, true
				)
				_check(species_frames_value is SpriteFrames, "rendered %s loads for natural Summary scale checks" % species)
				if not species_frames_value is SpriteFrames:
					continue
				var species_frames := species_frames_value as SpriteFrames
				(overlay.get("pokemon_summary_sprite_loader") as Node).call(
					"_prepare_rendered_sprite_frames", species_frames
				)
				var species_bounds := species_frames.get_meta("rendered_visual_bounds", Rect2()) as Rect2
				var species_summary_scale: Vector2 = overlay.call(
					"_get_pokemon_summary_sprite_scale", species_frames
				)
				rendered_summary_heights[species] = species_bounds.size.y * species_summary_scale.y
				if species == "diglett":
					var presentation := species_frames.get_meta("rendered_presentation", {}) as Dictionary
					var source_offset := presentation.get("position_offset", [0, 0]) as Array
					var prepared_offset: Vector2 = sprite_loader.call(
						"_get_sprite_frames_position_offset", species_frames
					)
					_check(
						is_equal_approx(
							prepared_offset.y,
							float(source_offset[1]) + 12.0
						),
						"rendered battle sprites share the lower platform baseline"
					)
			_check(
				float(rendered_summary_heights.get("diglett", 0.0))
					< float(rendered_summary_heights.get("jigglypuff", 0.0))
					and float(rendered_summary_heights.get("jigglypuff", 0.0))
					< float(rendered_summary_heights.get("dragonite", 0.0)),
				"rendered Summary preserves compact-to-large species size differences"
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
