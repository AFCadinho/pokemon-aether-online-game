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

	_check(first_floor.contains('npc_id = "mt_moon_warning_hiker"'), "1F places the warning Hiker")
	_check(first_floor.contains('interaction_id = "kanto_mt_moon_entrance_warning"'), "1F binds the entrance warning")
	_check(miguel_script.contains('BATTLE_STEP_ID := "defeat_miguel"'), "Miguel checks the story battle step")
	_check(miguel_script.contains('BLOCKED_DIALOGUE_ID := "kanto_mt_moon_miguel_blocked"'), "Miguel has blocked dialogue")
	_check(basement.contains('interaction_id = "kanto_mt_moon_ambush_rescue"'), "B2F binds the resumable ambush")
	_check(basement.contains('adinho_dad_frames.tres'), "ambush uses the temporary future-self frames")
	_check(ambush_script.contains('PlayerPartyStateService.get_starter_options()'), "ambush resolves the chosen starter's final evolution")
	_check(ambush_script.contains('InventoryService.has_item("helix-fossil")'), "Miguel takes the unchosen fossil")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
