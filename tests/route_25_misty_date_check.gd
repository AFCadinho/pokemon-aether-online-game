extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ROUTE_SCENE) as PackedScene
	_check(packed != null, "Route 25 scene loads with the Misty date encounter")
	if packed == null:
		quit(1)
		return

	var route := packed.instantiate()
	root.add_child(route)
	await process_frame

	var date := route.get_node_or_null("Entities/NPCs/MistyDate") as Node2D
	_check(date != null, "Route 25 places Dadinho and Misty by the water")
	if date != null:
		_check(date.position == Vector2(1840, 1040), "the date uses its designed waterside position")
		_check(str(date.get("npc_id")) == "kanto_route_25_dadinho_date", "Dadinho keeps the server-authorized story identity")
		_check(str(date.get("dialogue_id")) == "kanto_route_25_dadinho_after_date", "Dadinho retains localized guidance toward Bill")
		_check(str(date.get("visibility_required_quest_id")) == "explore_cerulean_city", "the couple only appears during the Cerulean search")
		_check(str(date.get("visibility_required_quest_step_id")) == "visit_nugget_bridge", "the date belongs to the active Misty-search step")
		_check(bool(date.get("defer_story_hide_until_reload")), "Dadinho remains long enough to finish the scene after completion")
		_check(date.get("facing_direction") == Vector2.RIGHT, "Dadinho faces Misty during their date")

		var misty := date.get_node_or_null("Misty") as AnimatedSprite2D
		_check(misty != null and misty.sprite_frames != null, "Misty uses her overworld animation frames")
		_check(misty != null and misty.position == Vector2(32, -16), "Misty stands beside Dadinho")
		_check(misty != null and misty.animation == &"idle_left", "Misty faces Dadinho during their date")

		var heart := date.get_node_or_null("Heart") as Label
		_check(heart != null and heart.text == "♥", "a heart floats above the couple")
		_check(heart != null and heart.get_theme_font_size("font_size") == 28, "the heart is readable at overworld scale")
		var nameplate := date.get_node_or_null("Nameplate") as Control
		var nameplate_background := date.get_node_or_null("Nameplate/NameplateBackground") as Panel
		var heart_bottom := heart.position.y + heart.size.y if heart != null else 0.0
		var nameplate_top := nameplate.position.y + nameplate_background.position.y if nameplate != null and nameplate_background != null else 0.0
		_check(nameplate != null and nameplate_background != null, "Dadinho displays his nameplate")
		_check(heart != null and heart_bottom <= nameplate_top and nameplate_top - heart_bottom <= 16.0, "the heart sits directly above Dadinho's nameplate")

		var story_hook: Node = date.get_node_or_null("StoryHook")
		_check(story_hook != null, "Dadinho exposes the story interaction")
		if story_hook != null:
			_check(str(story_hook.get("interaction_id")) == "kanto_route_25_misty_found", "the interaction completes the Misty-search event")
			_check(str(story_hook.get("entity_id")) == "kanto_route_25_dadinho_date", "the client and server use the same Dadinho entity identity")

		var collision := route.get_node("Tiles/Collision") as TileMapLayer
		var water := route.get_node("Tiles/Water") as TileMapLayer
		for world_position: Vector2 in [date.position, date.position + Vector2(32, 0)]:
			var standing_cell := collision.local_to_map(world_position)
			_check(collision.get_cell_source_id(standing_cell) < 0, "the couple stands on walkable ground")
			var water_is_nearby := false
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				for distance: int in range(1, 5):
					if water.get_cell_source_id(standing_cell + direction * distance) >= 0:
						water_is_nearby = true
			_check(water_is_nearby, "the couple stands beside the water's shoreline")

		var date_script := date.get_script() as Script
		var departure_offsets: Array = date_script.get_script_constant_map().get("MISTY_DEPARTURE_OFFSETS", [])
		_check(departure_offsets.size() == 2, "Misty uses a short two-part departure toward Cerulean")
		var departure_position := misty.global_position
		for offset_value: Variant in departure_offsets:
			var offset := offset_value as Vector2
			var step_count := int(maxf(absf(offset.x), absf(offset.y)) / 32.0)
			var step_direction := offset.normalized() * 32.0
			for _step: int in range(step_count):
				departure_position += step_direction
				var departure_cell := collision.local_to_map(departure_position)
				_check(collision.get_cell_source_id(departure_cell) < 0, "Misty's departure stays on walkable ground")
				_check(water.get_cell_source_id(departure_cell) < 0, "Misty's departure avoids the water")
		_check(departure_position.x < misty.global_position.x, "Misty leaves west toward Route 24 and Cerulean Gym")

	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
