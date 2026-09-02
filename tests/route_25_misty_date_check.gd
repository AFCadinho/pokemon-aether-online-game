extends SceneTree

const ROUTE_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"

var failed := false


class DummyPlayer extends CharacterBody2D:
	var last_direction := Vector2.LEFT

	func get_feet_position() -> Vector2:
		return global_position


class SystemMessageOverlay extends Node:
	var messages: Array[String] = []

	func add_system_message(message: String) -> void:
		messages.append(message)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var system_overlay := SystemMessageOverlay.new()
	system_overlay.add_to_group("ui_overlay")
	root.add_child(system_overlay)
	var packed := load(ROUTE_SCENE) as PackedScene
	_check(packed != null, "Route 25 scene loads with the Misty date encounter")
	if packed == null:
		quit(1)
		return

	var route := packed.instantiate()
	root.add_child(route)
	await process_frame

	var date := route.get_node_or_null("Entities/NPCs/MistyDate") as Node2D
	var misty_after_bill := route.get_node_or_null("Entities/NPCs/MistyAfterBill") as Node2D
	_check(misty_after_bill != null, "Route 25 brings Misty back after Bill's rescue")
	if misty_after_bill != null:
		_check(
			str(misty_after_bill.get("visibility_required_quest_id")) == "help_bill"
			and str(misty_after_bill.get("visibility_required_quest_status")) == "completed",
			"Misty's follow-up only appears after the S.S. Anne ticket is earned"
		)
		_check(
			str(misty_after_bill.get("display_name")) == "Misty"
			and misty_after_bill.get("mugshot") != null,
			"Misty's follow-up uses her own name and portrait"
		)
		var misty_lines: Array = misty_after_bill.get("dialogue_lines")
		_check(
			misty_lines.size() == 3
			and str(misty_lines[0]).contains("Dadinho")
			and str(misty_lines[1]).contains("S.S. Anne")
			and str(misty_lines[2]).contains("Vermilion City"),
			"Misty connects Dadinho, Bill's ticket, Vermilion City, and its Gym"
		)
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
		var misty_nameplate := date.get_node_or_null("MistyNameplate") as Control
		var misty_name_label := date.get_node_or_null("MistyNameplate/NameLabel") as Label
		_check(misty_nameplate != null and misty_nameplate.visible, "Misty displays her own nameplate")
		_check(misty_name_label != null and misty_name_label.text == "Misty", "Misty's nameplate identifies her")
		var player_portrait: Texture2D = await date.call("_dialogue_portrait", 0, "")
		_check(player_portrait != null, "the player's opening line uses their current trainer mugshot")
		_check(player_portrait != null and player_portrait.get_size() == Vector2(64, 64), "the player mugshot uses the dialogue portrait size")
		var player_save := root.get_node("PlayerSave")
		var original_player_name := str(player_save.get("player_name"))
		player_save.set("player_name", "Admin")
		var story_lines: Array[String] = ["{player_name}, look what you've done."]
		var formatted_lines: Array = date.call("_format_story_lines", story_lines)
		player_save.set("player_name", original_player_name)
		_check(formatted_lines == ["Admin, look what you've done."], "Dadinho can address the player by their current name")
		var milk_effects := [{
			"alreadyGranted": false,
			"grants": [{"itemId": "moomoo-milk", "quantity": 1}],
		}]
		_check(bool(date.call("_present_moomoo_milk_reward", milk_effects)), "a new Moomoo Milk story grant is presented")
		_check(system_overlay.messages.size() == 1 and system_overlay.messages[0].contains("Moomoo Milk"), "Moomoo Milk produces a localized system message")
		milk_effects[0]["alreadyGranted"] = true
		_check(not bool(date.call("_present_moomoo_milk_reward", milk_effects)) and system_overlay.messages.size() == 1, "an idempotent Moomoo Milk replay does not notify twice")

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

		var misty_feet := date.position + Vector2(32, 0)
		date.set("story_visibility_active", true)
		date.visible = true
		var date_interaction_area := date.get_node("InteractionArea") as Area2D
		var date_interaction_shape := date.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D
		date_interaction_area.monitoring = true
		date_interaction_area.monitorable = true
		_check(date_interaction_shape.shape is RectangleShape2D and (date_interaction_shape.shape as RectangleShape2D).size == Vector2(96, 64), "the shared interaction area covers both sides of the couple")
		_check(bool(date.call("blocks_world_position", misty_feet)), "Misty blocks players from walking through her")
		var player := DummyPlayer.new()
		player.name = "Player"
		player.position = misty_feet + Vector2(32, 0)
		var player_collision := CollisionShape2D.new()
		var player_shape := RectangleShape2D.new()
		player_shape.size = Vector2(32, 32)
		player_collision.shape = player_shape
		player.add_child(player_collision)
		route.add_child(player)
		await physics_frame
		await physics_frame
		_check(bool(date.get("player_nearby")), "Misty's side is covered by the shared interaction area")
		_check(bool(date.call("_is_player_facing_npc", player)), "the shared date interaction can be started while facing Misty")
		player.queue_free()

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
	system_overlay.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
