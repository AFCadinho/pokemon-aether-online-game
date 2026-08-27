extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var presenter_script: Script = load("res://scripts/world/thieving_arrest_presenter.gd")
	_check(
		presenter_script.get_position_behind_player(Vector2(96.0, 64.0), Vector2.RIGHT)
		== Vector2(64.0, 64.0),
		"A responding officer appears exactly one tile behind the player"
	)
	_check(
		presenter_script.get_position_behind_player(Vector2(96.0, 64.0), Vector2.ZERO)
		== Vector2(96.0, 32.0),
		"The arrest officer uses a safe default direction"
	)
	var current_map := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	var npcs := Node2D.new()
	npcs.name = "NPCs"
	entities.add_child(npcs)
	current_map.add_child(entities)
	get_root().add_child(current_map)
	var game_state := get_root().get_node("GameState")
	game_state.set("current_map", current_map)
	var player := Node2D.new()
	current_map.add_child(player)
	var officer := presenter_script.call(
		"_spawn_temporary_officer",
		player,
		Vector2(64.0, 96.0)
	) as Node2D
	await process_frame
	_check(
		officer != null
		and officer.get_parent() == npcs
		and officer.global_position == Vector2(64.0, 96.0),
		"The temporary arrest officer is visibly spawned in the active NPC layer"
	)
	var officer_frames := officer.get("npc_sprite_frames") as SpriteFrames if officer != null else null
	_check(
		officer_frames != null
		and officer_frames.resource_path == "res://assets/npcs/classes/officer_jenny_frames.tres"
		and officer.get("mugshot") != null,
		"The temporary officer uses Officer Jenny's overworld visual and a police portrait"
	)
	game_state.set("current_map", null)
	current_map.queue_free()

	var service := FileAccess.get_file_as_string("res://scripts/services/thieving_service.gd")
	var npc := FileAccess.get_file_as_string("res://scripts/world/npcs/base_npc.gd")
	var presenter := FileAccess.get_file_as_string("res://scripts/world/thieving_arrest_presenter.gd")
	_check(
		"defer_arrest_transfer" in service
		and "complete_deferred_arrest" in service
		and "attempt_pickpocket(target_id, true)" in npc,
		"Pickpocket arrests defer teleporting until after the confrontation"
	)
	_check(
		"LAW_ENFORCEMENT_NPC_TYPE" in presenter
		and "officer_confrontation" in presenter
		and "source_npc.call" in presenter,
		"A police target turns and delivers its own arrest dialogue"
	)
	_check(
		"TemporaryArrestOfficer" in presenter
		and "civilian_confrontation" in presenter
		and "get_position_behind_player" in presenter,
		"A civilian arrest summons a temporary officer behind the player"
	)
	_check(
		"show_jail_arrival" in presenter
		and "ui.thieving.arrest.jail_arrival" in presenter
		and "await ThievingArrestPresenterScript.show_jail_arrival" in service,
		"The arresting officer explains the sentence after the jail transfer"
	)

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://localization/%s.json" % locale
		))
		var values := parsed as Dictionary if parsed is Dictionary else {}
		for key: String in [
			"ui.thieving.arrest.civilian_confrontation",
			"ui.thieving.arrest.officer_confrontation",
			"ui.thieving.arrest.jail_arrival",
		]:
			_check(not str(values.get(key, "")).is_empty(), "%s provides %s" % [locale, key])

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
