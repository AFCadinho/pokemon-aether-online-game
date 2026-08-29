extends SceneTree

var failed := false
var dialogue_wait_completed := false


class FakeDialogueBox extends Node:
	signal dialogue_finished
	var started := false
	var shown_lines: Array = []
	var shown_speaker := ""

	func start_dialogue(
		lines: Array,
		speaker_name := "",
		_mugshot: Texture2D = null,
		_show_mugshot := true
	) -> void:
		started = true
		shown_lines = lines.duplicate()
		shown_speaker = speaker_name


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
	var officer_portrait := officer.get("mugshot") as AtlasTexture if officer != null else null
	_check(
		officer_frames != null
		and officer_frames.resource_path == "res://assets/npcs/classes/officer_jenny_frames.tres"
		and officer_portrait != null
		and officer_portrait.resource_path \
			== "res://assets/npcs/classes/officer_jenny_portrait.tres"
		and officer_portrait.region == Rect2(0, 0, 64, 64)
		and officer_portrait.atlas.resource_path \
			== "res://assets/npcs/classes/officer_jenny.png",
		"The temporary officer uses Officer Jenny's overworld visual and cropped portrait"
	)
	game_state.set("current_map", null)
	current_map.queue_free()

	var arrest_scene := Node.new()
	var dialogue_root := Node.new()
	dialogue_root.name = "DialogueBox"
	var dialogue_box := FakeDialogueBox.new()
	dialogue_box.name = "Box"
	dialogue_root.add_child(dialogue_box)
	arrest_scene.add_child(dialogue_root)
	var dialogue_player := Node2D.new()
	arrest_scene.add_child(dialogue_player)
	get_root().add_child(arrest_scene)
	current_scene = arrest_scene
	dialogue_wait_completed = false
	_exercise_dialogue_wait(presenter_script, dialogue_player)
	await process_frame
	_check(
		dialogue_box.started
		and dialogue_box.shown_lines == ["You are under arrest."]
		and dialogue_box.shown_speaker == "Officer Jenny",
		"The arrest presenter opens Officer Jenny's dialogue"
	)
	_check(
		not dialogue_wait_completed,
		"The arrest sequence remains paused while Jenny is speaking"
	)
	dialogue_box.dialogue_finished.emit()
	await process_frame
	_check(
		dialogue_wait_completed,
		"The arrest sequence resumes only after Jenny's dialogue closes"
	)
	current_scene = null
	arrest_scene.queue_free()

	var service := FileAccess.get_file_as_string("res://scripts/services/thieving_service.gd")
	var npc := FileAccess.get_file_as_string("res://scripts/world/npcs/base_npc.gd")
	var presenter := FileAccess.get_file_as_string("res://scripts/world/thieving_arrest_presenter.gd")
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(
		"defer_arrest_transfer" in service
		and "complete_deferred_arrest" in service
		and "attempt_pickpocket(target_id, true)" in npc,
		"Pickpocket arrests defer teleporting until after the confrontation"
	)
	_check(
		"LAW_ENFORCEMENT_NPC_TYPE" in presenter
		and "officer_confrontation" in presenter
		and "_show_officer_dialogue" in presenter,
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
	_check(
		"await dialogue_box.dialogue_finished" in presenter
		and 'call("show_dialogue"' not in presenter,
		"Jail transfer waits for the arrest dialogue to be dismissed"
	)
	_check(
		"arrest_transfer_pending = true" in service
		and "func is_arrest_transfer_pending" in service
		and "arrest_transfer_pending = false" in service,
		"Deferred arrests expose their pending transfer boundary"
	)
	var thieving_service := get_root().get_node("ThievingService")
	thieving_service.set("arrest_transfer_pending", true)
	_check(
		bool(thieving_service.call("is_arrest_transfer_pending")),
		"The Thieving service reports an active arrest transfer"
	)
	thieving_service.set("arrest_transfer_pending", false)
	_check(
		not bool(thieving_service.call("is_arrest_transfer_pending")),
		"The Thieving service clears a completed arrest transfer"
	)
	_check(
		"or ThievingService.is_arrest_transfer_pending()" in world
		and "if not ThievingService.is_arrest_transfer_pending():" in world,
		"Position autosave pauses quietly while an arrest transfer is pending"
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


func _exercise_dialogue_wait(presenter_script: Script, player: Node2D) -> void:
	await presenter_script._show_officer_dialogue(player, "You are under arrest.")
	dialogue_wait_completed = true
