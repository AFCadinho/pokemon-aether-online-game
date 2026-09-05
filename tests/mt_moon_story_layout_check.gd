extends SceneTree

var failed := false


func _init() -> void:
	var first_floor := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/caves/mt_moon/1f.tscn"
	)
	var basement := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn"
	)
	var miguel_script := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/mt_moon_miguel_npc.gd"
	)
	var ambush_script := FileAccess.get_file_as_string(
		"res://scripts/world/story/mt_moon_ambush_controller.gd"
	)
	var trainer_script := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/trainer_npc.gd"
	)

	_check(first_floor.contains('npc_id = "mt_moon_warning_hiker"'), "1F places the warning Hiker")
	_check(first_floor.contains('portrait_id = "showdown_hiker_gen6"'), "warning Hiker uses the Showdown Hiker portrait")
	_check(first_floor.contains('interaction_id = "kanto_mt_moon_entrance_warning"'), "1F binds the entrance warning")
	_check(first_floor.contains('trainer_id = "kanto_mt_moon_1f_lass_iris"\nnpc_id = "kanto_mt_moon_1f_lass_iris"') and trainer_script.contains("var sight_range_tiles := 5"), "Lass Iris inherits the five-tile Trainer sight range")
	_check(first_floor.contains('[node name="MoonStone" parent="Entities/Interactables" unique_id=618258656 instance=ExtResource("14_item")]\nposition = Vector2(432, 240)'), "1F places the Moon Stone in its intended spot")
	_check(miguel_script.contains('BATTLE_STEP_ID := "defeat_miguel"'), "Miguel checks the story battle step")
	_check(miguel_script.contains('BLOCKED_DIALOGUE_ID := "kanto_mt_moon_miguel_blocked"'), "Miguel has blocked dialogue")
	_check(miguel_script.contains('FOSSIL_DIALOGUE_ID := "kanto_mt_moon_miguel_fossil_choice"'), "Miguel has fossil-choice dialogue")
	_check(miguel_script.contains("cleared_position_marker"), "Miguel uses an explicit safe story marker after battle")
	_check(miguel_script.contains("BLOCKING_TILE_OFFSETS"), "Miguel blocks the full fossil corridor before his battle")
	_check(miguel_script.contains("Vector2i.RIGHT * 3"), "Miguel blocks the far-right approach tile before his battle")
	_check(miguel_script.contains("func is_gate_open()"), "Miguel exposes his story corridor as an intentional gate")
	_check(miguel_script.contains("func blocks_world_position(world_position: Vector2) -> bool:\n\tif is_gate_open():\n\t\treturn super.blocks_world_position(world_position)"), "Miguel releases the extra corridor tiles when his confrontation becomes active")
	_check(miguel_script.contains("func on_route_gate_blocked(player: Node2D)"), "walking into Miguel's gate starts visible feedback")
	_check(miguel_script.contains('await _show_blocked_dialogue()\n\tif is_instance_valid(player):\n\t\tawait _send_player_back(player)'), "Miguel speaks before sending the player back")
	_check(miguel_script.contains('var retreat_path: Array[String] = ["down"]'), "Miguel visibly sends the player one tile back")
	_check(miguel_script.contains("var rewound_before_battle := _battle_step_was_completed and not battle_step_completed"), "ordinary Grunt progress does not trigger Miguel's checkpoint recovery")
	_check(miguel_script.contains("if recover_blocked_players:\n\t\t\t_recover_players_to_blocked_side.call_deferred()"), "rewound checkpoints recover players from behind Miguel")
	_check(miguel_script.contains("func _recover_players_to_blocked_side() -> void:\n\t# A checkpoint reset can replace the map before this deferred callback runs.\n\tif not is_inside_tree():"), "checkpoint resets cancel Miguel's stale deferred recovery")
	_check(basement.contains('[node name="MiguelCleared" type="Marker2D" parent="Entities/StoryMarkers"'), "B2F places Miguel's cleared-position marker")
	_check(basement.contains('position = Vector2(720, 720)'), "Miguel's cleared marker stays on the open corridor tile")
	_check(basement.contains('[node name="MiguelBlockedSide" type="Marker2D" parent="Entities/StoryMarkers"'), "B2F places the safe marker in front of Miguel")
	_check(basement.contains('position = Vector2(752, 688)'), "Miguel's recovery marker stays on the open approach tile")
	_check(basement.contains('interaction_id = "kanto_mt_moon_ambush_rescue"'), "B2F binds the resumable ambush")
	_check(not basement.contains('adinho_dad_frames.tres'), "ambush no longer gives the future self Dadinho's outfit")
	_check(basement.contains('[node name="FaceGearSprite" type="AnimatedSprite2D" parent="Entities/MtMoonAmbush/FutureSelf"'), "ambush layers the future-self outfit")
	_check(ambush_script.contains('"id": "Mysterious_Mask"') and ambush_script.contains('"id": "Mysterious_Shirt"') and ambush_script.contains('"id": "Mysterious_Trousers"') and ambush_script.contains('"id": "Mysterious_Shoes"'), "future self wears every Mysterious Outfit component")
	_check(ambush_script.contains('PlayerPartyStateService.get_starter_options()'), "ambush resolves the chosen starter's final evolution")
	_check(ambush_script.contains('InventoryService.has_item("helix-fossil")'), "Miguel takes the unchosen fossil")
	_check(ambush_script.contains("await miguel.show_fossil_choice_dialogue()\n\tother_fossil.visible = false"), "Miguel speaks before taking the unchosen fossil")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
