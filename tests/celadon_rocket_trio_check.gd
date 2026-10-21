extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_7.tscn"
const CITY := "res://scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn"
const TRIO := "res://scenes/world/story/rocket_trio.tscn"
const QUEST := "celadon_rocket_trio"
var failures := 0
var StoryService: Node
var CoopService: Node


class DialogueProbe extends Node:
	signal dialogue_finished
	var speakers: Array[String] = []
	var portraits: Array[Texture2D] = []
	var portrait_visibility: Array[bool] = []
	func start_dialogue(_lines: Array[String], speaker: String, portrait: Texture2D = null, show_portrait := false) -> void:
		speakers.append(speaker)
		portraits.append(portrait)
		portrait_visibility.append(show_portrait)
		_finish.call_deferred()
	func _finish() -> void:
		await get_tree().process_frame
		dialogue_finished.emit()


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	StoryService = root.get_node("StoryService")
	CoopService = root.get_node("CoopService")
	_check_placement()
	await _check_presentation_recovery()
	print("celadon_rocket_trio_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)


func _check_placement() -> void:
	var route := (load(ROUTE) as PackedScene).instantiate()
	var city := (load(CITY) as PackedScene).instantiate()
	var sighting := route.get_node("Story/RocketTrio/Sighting")
	_check(sighting.get("required_step_id") == "spot_trio", "Route 7 sighting is quest-gated")
	_check(sighting.get_node("StoryHook").get("interaction_id") == "kanto_route_7_rocket_sighting", "Route sighting binds the catalog interaction")
	var origin := route.get_node("Story/RocketTrio") as Node2D
	var spawn := route.get_node("Spawns/FromUndergroundPath") as Node2D
	var trigger_shape := sighting.get_node("CollisionShape2D").shape as RectangleShape2D
	_check(Rect2(origin.position + sighting.position - trigger_shape.size / 2.0, trigger_shape.size).has_point(spawn.position), "Underground arrival lies inside the sighting trigger")
	var encounter := city.get_node("Story/RocketTrio") as Node2D
	_check(encounter.position == Vector2(2256, 1648), "Rescue takes place in southeast Celadon")
	_check(encounter.get_node("James").position == Vector2(0, 32) and encounter.get_node("Meowth").position == Vector2(32, 0), "Celadon retains its actor staging when the map is saved in Godot")
	for trigger_name: String in ["Confrontation", "Escape"]:
		var trigger := encounter.get_node(trigger_name)
		_check(trigger.get("story_host_path") == NodePath(".."), "Story trigger resolves the trio controller")
		_check(trigger.get_node("StoryHook").get("entity_id") == "kanto_celadon_rocket_trio", "Rescue uses the catalog entity")
	_check(encounter.get_node("Confrontation").get("required_step_id") == "defeat_trio", "Battle trigger requires the battle objective")
	_check(encounter.get_node("Escape").get("required_step_id") == "watch_trio_flee", "Flight requires the committed victory step")
	_check(CoopService.trainer_entity("kanto_celadon_jessie_james") == "kanto_celadon_rocket_trio", "Adventure Party routes the exact duo to doubles")
	route.free()
	city.free()


func _story(active_step: String, completed := false) -> Dictionary:
	var steps: Array = []
	var passed := true
	for id: String in ["spot_trio", "defeat_trio", "watch_trio_flee"]:
		var status := "completed" if passed else "inactive"
		if id == active_step:
			status = "active"
			passed = false
		steps.append({"stepId": id, "status": "completed" if completed else status})
	return {"revision": 20, "quests": [{"questId": QUEST, "storylineId": "kanto_main", "definitionVersion": 2,
		"status": "completed" if completed else "active", "steps": steps}]}


func _check_presentation_recovery() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var box_parent := Node.new()
	box_parent.name = "DialogueBox"
	scene.add_child(box_parent)
	var dialogue := DialogueProbe.new()
	dialogue.name = "Box"
	box_parent.add_child(dialogue)
	var camera := Camera2D.new()
	scene.add_child(camera)
	camera.make_current()
	var player := Node2D.new()
	scene.add_child(player)
	StoryService.apply_story(_story("spot_trio"))
	var trio := (load(TRIO) as PackedScene).instantiate()
	scene.add_child(trio)
	await process_frame
	trio.call("set_story_player", player)
	for actor_name: String in ["Jessie", "James", "Meowth"]:
		var actor := trio.get_node(actor_name) as AnimatedSprite2D
		_check(actor.sprite_frames != null, "Actor has a usable sprite sheet: %s" % actor_name)
		for direction: String in ["down", "left", "right", "up"]:
			_check(actor.sprite_frames.get_frame_count("walk_" + direction) == 4, "Actor has four walking frames: %s %s" % [actor_name, direction])
	var prepared: Dictionary = await trio.call("prepare_story_sequence")
	_check(prepared.get("success", false), "Sighting preflight succeeds")
	# Localized labels must still select the right portrait before names are hidden.
	for speaker: String in ["武藏", "小次郎", "喵喵"]:
		var lines: Array[String] = ["Fixture line"]
		await trio.call("show_dialogue", lines, speaker)
		_check(dialogue.speakers.back().is_empty(), "Route 7 does not reveal the trio's names")
		_check_portrait(dialogue, speaker)
	_check(not trio.get_node("Jessie").visible, "Trio walks towards Celadon before the quest acknowledgement")
	_check(root.get_camera_2d() == camera, "Sighting restores the original camera")
	trio.call("abort_story_sequence")
	_check(trio.get_node("Jessie").position == Vector2(-32, 0), "Failed ACK restores fixed staging for a safe retry")
	_check(trio.get_node("Jessie").visible, "Uncommitted sighting remains replayable")
	trio.set("encounter", "celadon")
	StoryService.apply_story(_story("defeat_trio"))
	_check(trio.call("active_sequence_step") == "defeat_trio", "Loss leaves the confrontation available")
	var eevee := Node2D.new()
	eevee.name = "Eevee"
	trio.add_child(eevee)
	trio.set("victim_pokemon_path", NodePath("Eevee"))
	prepared = await trio.call("prepare_story_sequence")
	_check(prepared.get("success", false), "Rescue preflight succeeds")
	var confrontation_speakers: Array[String] = [
		"Trainer Mira", "Jessie", "James", "Jessie", "James", "Jessie", "James",
		"Jessie", "James", "Jessie", "James", "Meowth", "Jessie", "James",
	]
	for index: int in range(confrontation_speakers.size()):
		var speaker := confrontation_speakers[index]
		var lines: Array[String] = ["Fixture line"]
		await trio.call("show_dialogue", lines, speaker)
		_check(dialogue.speakers.back() == speaker, "Celadon retains the named speaker")
		_check_portrait(dialogue, speaker)
		if index < confrontation_speakers.size() - 1:
			_check(root.get_camera_2d() != camera, "Camera stays on the full motto and confrontation until the challenge")
		_check(trio.get_node("James").animation == ("idle_left" if index >= 12 else "idle_right"), "Trio notices the player only after Meowth ends the motto")
	_check(eevee.position == Vector2.ZERO, "Eevee lands after Meowth attempts the theft")
	_check(root.get_camera_2d() == camera, "Confrontation restores the camera before battle")
	var metadata: Dictionary = trio.call("build_battle_trainer_metadata", {"id": "kanto_celadon_jessie_james", "trainer_class": "team_rocket"})
	var pair := metadata.get("_battle_sprite_frames") as SpriteFrames
	_check(pair != null and pair.get_frame_texture("idle_left", 0).get_width() == 112, "Solo battle art contains both Jessie and James")
	StoryService.apply_story(_story("watch_trio_flee"))
	prepared = await trio.call("prepare_story_sequence")
	_check(prepared.get("success", false), "Reloaded victory resumes at escape")
	for speaker: String in ["Jessie", "James", "Jessie", "Meowth", "Team Rocket"]:
		var lines: Array[String] = ["Fixture line"]
		await trio.call("show_dialogue", lines, speaker)
		_check_portrait(dialogue, speaker)
	_check(trio.get_node("James").scale.x < 0.1, "Trio blasts away at the final line")
	_check(root.get_camera_2d() == camera, "Escape restores the original camera")
	trio.call("abort_story_sequence")
	_check(trio.get_node("James").scale == Vector2.ONE, "Failed escape restores actor scale for replay")
	StoryService.apply_story(_story("watch_trio_flee", true))
	_check(not trio.get_node("Jessie").visible, "Committed escape removes the trio")
	trio.queue_free()
	await process_frame
	scene.queue_free()
	current_scene = null
	await process_frame
	StoryService.reset_story()


func _check_portrait(dialogue: DialogueProbe, speaker: String) -> void:
	var expected_path := "showdown/teamrocket.png"
	match speaker:
		"Jessie", "武藏":
			expected_path = "pixelheim/jessie.png"
		"James", "小次郎":
			expected_path = "pixelheim/james.png"
		"Trainer Mira":
			expected_path = "showdown/lass-gen6.png"
	var portrait: Texture2D = dialogue.portraits.back()
	_check(portrait != null and dialogue.portrait_visibility.back(), "Dialogue displays a portrait for %s" % speaker)
	if portrait != null:
		_check(portrait.resource_path.ends_with(expected_path), "Correct individual or group portrait for %s" % speaker)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
