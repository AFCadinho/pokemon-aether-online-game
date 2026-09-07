extends SceneTree

var failed := false


class DummyPlayer extends Node2D:
	var last_direction := Vector2.DOWN

	func get_feet_position() -> Vector2:
		return global_position


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var npc_script: Script = load("res://scripts/world/npcs/base_npc.gd")
	var npc := npc_script.new() as Node2D
	npc.set("display_name", "Officer Jenny")
	var look := Node2D.new()
	look.name = "Look"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	look.add_child(sprite)
	npc.add_child(look)
	var feet := Marker2D.new()
	feet.name = "FeetMarker"
	feet.position = Vector2(16.0, 16.0)
	npc.add_child(feet)
	var interaction_area := Area2D.new()
	interaction_area.name = "InteractionArea"
	npc.add_child(interaction_area)
	get_root().add_child(npc)

	var player := DummyPlayer.new()
	get_root().add_child(player)
	await process_frame

	var cases: Array[Dictionary] = [
		{"npcDirection": Vector2.DOWN, "playerPosition": Vector2(16.0, -16.0), "playerDirection": Vector2.DOWN},
		{"npcDirection": Vector2.UP, "playerPosition": Vector2(16.0, 48.0), "playerDirection": Vector2.UP},
		{"npcDirection": Vector2.RIGHT, "playerPosition": Vector2(-16.0, 16.0), "playerDirection": Vector2.RIGHT},
		{"npcDirection": Vector2.LEFT, "playerPosition": Vector2(48.0, 16.0), "playerDirection": Vector2.LEFT},
	]
	for case: Dictionary in cases:
		npc.set("facing_direction", case.get("npcDirection", Vector2.DOWN))
		player.global_position = case.get("playerPosition", Vector2.ZERO)
		player.last_direction = case.get("playerDirection", Vector2.DOWN)
		_check(
			bool(npc.call("_is_player_in_pickpocket_position", player)),
			"Pickpocket position works behind an NPC facing %s" % npc.get("facing_direction")
		)

	npc.set("facing_direction", Vector2.DOWN)
	player.global_position = Vector2(16.0, 48.0)
	player.last_direction = Vector2.UP
	_check(not bool(npc.call("_is_player_in_pickpocket_position", player)), "A player in front cannot pickpocket")

	player.global_position = Vector2(48.0, 16.0)
	player.last_direction = Vector2.LEFT
	_check(not bool(npc.call("_is_player_in_pickpocket_position", player)), "A player beside the NPC cannot pickpocket")

	player.global_position = Vector2(16.0, -16.0)
	player.last_direction = Vector2.UP
	_check(not bool(npc.call("_is_player_in_pickpocket_position", player)), "The player must face the NPC from behind")

	npc.set("npc_id", "test_pickpocket_target")
	npc.set("npc_metadata_loaded", true)
	npc.set("pickpocket_enabled", true)
	npc.set("pickpocket_required_level", 1)
	npc.set("player_nearby", true)
	npc.set("nearby_player", player)
	var thieving_service := get_root().get_node("ThievingService")
	thieving_service.set("state_loaded", true)
	thieving_service.set("state", {"unlocked": true, "level": 1, "attemptedNpcIds": []})
	player.last_direction = Vector2.DOWN
	npc.call("_setup_nameplate")
	npc.call("_setup_thieving_prompt")
	npc.call("_sync_thieving_prompt")
	var prompt := npc.get_node_or_null("ThievingPromptButton") as Button
	_check(prompt != null and prompt.visible, "The clickable Thieving icon appears behind an eligible target")
	var nameplate := npc.get_node_or_null("Nameplate") as Control
	_check(
		prompt != null
		and nameplate != null
		and is_equal_approx(
			prompt.position.x + prompt.size.x * 0.5,
			nameplate.position.x + nameplate.size.x * 0.5
		),
		"The Thieving icon is horizontally centered above the nameplate"
	)
	_check(
		prompt != null
		and nameplate != null
		and prompt.position.y + prompt.size.y <= nameplate.position.y - 4.0,
		"The Thieving icon has clear vertical spacing above the nameplate"
	)
	_check(
		prompt != null
		and nameplate != null
		and not prompt.z_as_relative
		and prompt.z_index > nameplate.z_index,
		"The Thieving icon renders above NPC nameplates"
	)
	var player_scene_source := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_check(
		player_scene_source.contains("visible = false\nz_index = 4095\nz_as_relative = false"),
		"Player nameplates remain below the Thieving icon overlay"
	)

	player.global_position = Vector2(16.0, 48.0)
	player.last_direction = Vector2.UP
	npc.call("_sync_thieving_prompt")
	_check(prompt != null and not prompt.visible, "The Thieving icon hides when the player moves in front")
	_check(
		bool(npc.call("_can_show_pickpocket_position_hint")),
		"Available Thieving targets explain that the player must stand behind them"
	)

	player.global_position = Vector2(16.0, -16.0)
	player.last_direction = Vector2.DOWN
	_check(
		not bool(npc.call("_can_show_pickpocket_position_hint")),
		"The position hint stays hidden when the player can pickpocket"
	)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
