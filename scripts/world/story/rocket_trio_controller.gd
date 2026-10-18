extends Node2D

## Presentation only. The catalog and durable battle settlement own progression.
const QUEST_ID := "celadon_rocket_trio"
const TRAINER_ID := "kanto_celadon_jessie_james"
const ROCKET_PORTRAIT_ID := "showdown_teamrocket"
const CONFRONTATION_MEOWTH_STAGE := 11
const CONFRONTATION_NOTICE_STAGE := 12
const CONFRONTATION_CHALLENGE_STAGE := 13
const ActorScript := preload("res://scripts/world/story/rocket_trio_actor.gd")
const MusicResolver := preload("res://scripts/world/npcs/trainer_battle_music_resolver.gd")

@export_enum("route7", "celadon") var encounter := "route7"
@export var victim_path: NodePath
@export var victim_pokemon_path: NodePath

@onready var actors: Array[AnimatedSprite2D] = [$Jessie, $James, $Meowth]
var _origins: Array[Vector2] = []
var _stage := 0
var _sequence_step := ""
var _story_player: Node2D
var _camera: Camera2D
var _previous_camera: Camera2D
var _motion: Tween
var _running := false
var _pair_frames: SpriteFrames
var _victim_pokemon_origin := Vector2.ZERO


func _ready() -> void:
	for actor: AnimatedSprite2D in actors:
		_origins.append(actor.position)
	var pokemon := get_node_or_null(victim_pokemon_path) as Node2D if not victim_pokemon_path.is_empty() else null
	if pokemon != null:
		_victim_pokemon_origin = pokemon.position
	StoryService.story_changed.connect(_on_story_changed)
	_on_story_changed(StoryService.get_revision())


func _exit_tree() -> void:
	_cancel_motion()
	_restore_camera()
	if StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.disconnect(_on_story_changed)


func set_story_player(player: Node2D) -> void:
	_story_player = player


func prepare_story_sequence() -> Dictionary:
	abort_story_sequence()
	_sequence_step = active_sequence_step()
	if _sequence_step.is_empty():
		return {"success": false}
	_running = true
	_reset_actors()
	if encounter == "celadon":
		for path: NodePath in [victim_path, victim_pokemon_path]:
			if path.is_empty():
				continue
			var victim := get_node_or_null(path)
			if victim != null and victim.has_method("face_world_position"):
				victim.call("face_world_position", actors[2].global_position)
	if _story_player != null and _story_player.has_method("face_world_position"):
		_story_player.call("face_world_position", global_position)
	await _focus_camera()
	return {"success": is_inside_tree() and _running and not _sequence_step.is_empty()}


func active_sequence_step() -> String:
	var steps: Array[String] = ["spot_trio"]
	if encounter == "celadon":
		steps.assign(["defeat_trio", "watch_trio_flee"])
	for step: String in steps:
		if StoryService.is_requirement_met(QUEST_ID, step, "active"):
			return step
	return ""


func abort_story_sequence() -> void:
	_cancel_motion()
	_restore_camera()
	_running = false
	_stage = 0
	_sequence_step = ""
	_reset_actors()
	_on_story_changed(StoryService.get_revision())


func _reset_actors() -> void:
	for index: int in range(mini(actors.size(), _origins.size())):
		var actor := actors[index]
		actor.position = _origins[index]
		actor.scale = Vector2.ONE
		actor.rotation = 0.0
		actor.modulate = Color.WHITE
		actor.visible = true
		actor.play("idle_left" if encounter == "route7" else "idle_right")
	var pokemon := get_node_or_null(victim_pokemon_path) as Node2D if not victim_pokemon_path.is_empty() else null
	if pokemon != null:
		pokemon.position = _victim_pokemon_origin


func _on_story_changed(_revision: int) -> void:
	if _running:
		# Completion is acknowledged only after all dialogue and motion finish.
		if active_sequence_step() == _sequence_step:
			return
		_cancel_motion()
		_running = false
		_restore_camera()
		_sequence_step = ""
		_stage = 0
		_reset_actors()
	var show_trio := not active_sequence_step().is_empty()
	for actor: AnimatedSprite2D in actors:
		actor.visible = show_trio
	var marker := get_node_or_null("QuestMarker") as CanvasItem
	if marker != null:
		marker.visible = show_trio


func show_dialogue(lines: Array[String], speaker_name := "") -> bool:
	var scene := get_tree().current_scene
	var dialogue := scene.get_node_or_null("DialogueBox/Box") if scene != null else null
	if dialogue == null or not dialogue.has_method("start_dialogue"):
		return false
	var stage := _stage
	var sequence_step := _sequence_step
	_stage += 1
	if _sequence_step == "defeat_trio" and stage == CONFRONTATION_NOTICE_STAGE:
		_face_player()
	if _sequence_step == "watch_trio_flee" and stage == 4:
		_launch_blast_off()
	var portrait_id := ROCKET_PORTRAIT_ID
	if sequence_step == "defeat_trio" and stage == 0:
		portrait_id = TrainerPortraitCatalog.resolve_portrait_id("", "kanto_celadon_city_mira", "")
	var portrait := TrainerPortraitCatalog.get_texture(portrait_id)
	# The player has not been introduced to the trio during the Route 7 cameo.
	var displayed_name := "" if sequence_step == "spot_trio" else speaker_name
	dialogue.call("start_dialogue", lines, displayed_name, portrait, portrait != null)
	await dialogue.dialogue_finished
	if not _running or _sequence_step != sequence_step:
		return false
	if _sequence_step == "spot_trio" and stage == 2:
		await _walk_towards_celadon()
		await _return_camera()
		for actor: AnimatedSprite2D in actors:
			actor.visible = false
	elif _sequence_step == "defeat_trio" and stage == CONFRONTATION_MEOWTH_STAGE:
		await _attempt_theft()
		if not _running:
			return false
	elif _sequence_step == "defeat_trio" and stage == CONFRONTATION_CHALLENGE_STAGE:
		# The player's catalog dialogue is presented by the shared runner, so
		# this is the final NPC line immediately before starting the battle.
		await _return_camera()
	elif _sequence_step == "watch_trio_flee" and stage == 4:
		await _wait_for_motion()
		await _return_camera()
	return is_inside_tree()


func _face_player() -> void:
	if not is_instance_valid(_story_player):
		return
	for actor: AnimatedSprite2D in actors:
		var delta := _story_player.global_position - actor.global_position
		var direction := "down" if delta.y >= 0.0 else "up"
		if absf(delta.x) > absf(delta.y):
			direction = "right" if delta.x >= 0.0 else "left"
		actor.play("idle_" + direction)


func _attempt_theft() -> void:
	var pokemon := get_node_or_null(victim_pokemon_path) as Node2D if not victim_pokemon_path.is_empty() else null
	if pokemon == null:
		return
	var meowth := actors[2]
	meowth.play("walk_right")
	_motion = create_tween()
	_motion.tween_property(meowth, "position", _origins[2] + Vector2(8, 0), 0.15)
	_motion.parallel().tween_property(pokemon, "position", _victim_pokemon_origin + Vector2(0, -8), 0.15)
	_motion.tween_property(meowth, "position", _origins[2], 0.15)
	_motion.parallel().tween_property(pokemon, "position", _victim_pokemon_origin, 0.15)
	await _wait_for_motion()
	meowth.play("idle_right")


func _walk_towards_celadon() -> void:
	# Authored NPC staging only: retry starts from the same saved origins.
	for leg: Dictionary in [
		{"offset": Vector2(-128, 0), "direction": "left"},
		{"offset": Vector2(0, -192), "direction": "up"},
		{"offset": Vector2(-192, 0), "direction": "left"},
	]:
		if not _running:
			return
		_motion = create_tween().set_parallel(true)
		var offset: Vector2 = leg["offset"]
		for actor: AnimatedSprite2D in actors:
			actor.play("walk_" + str(leg["direction"]))
			_motion.tween_property(actor, "position", actor.position + offset, offset.length() / 160.0)
		await _wait_for_motion()
	if not _running:
		return


func _launch_blast_off() -> void:
	_motion = create_tween().set_parallel(true)
	for index: int in range(actors.size()):
		var actor := actors[index]
		actor.play("idle_down")
		_motion.tween_property(actor, "position", actor.position + Vector2(-48 + index * 16, -288), 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_motion.tween_property(actor, "scale", Vector2(0.05, 0.05), 0.85)
		_motion.tween_property(actor, "rotation", (-0.4 if index % 2 == 0 else 0.4), 0.85)
		_motion.tween_property(actor, "modulate:a", 0.0, 0.25).set_delay(0.6)


func _wait_for_motion() -> void:
	while _motion != null and _motion.is_valid() and _motion.is_running():
		await get_tree().process_frame


func _cancel_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _focus_camera() -> void:
	_previous_camera = get_viewport().get_camera_2d()
	if _previous_camera == null:
		return
	_camera = Camera2D.new()
	_camera.position = _previous_camera.get_screen_center_position()
	_camera.zoom = _previous_camera.zoom
	_camera.limit_left = _previous_camera.limit_left
	_camera.limit_top = _previous_camera.limit_top
	_camera.limit_right = _previous_camera.limit_right
	_camera.limit_bottom = _previous_camera.limit_bottom
	get_tree().current_scene.add_child(_camera)
	_camera.make_current()
	_motion = create_tween()
	_motion.tween_property(_camera, "global_position", global_position + Vector2(32, -32), 0.4)
	await _wait_for_motion()


func _return_camera() -> void:
	if is_instance_valid(_camera) and is_instance_valid(_previous_camera):
		_motion = create_tween()
		_motion.tween_property(_camera, "global_position", _previous_camera.get_screen_center_position(), 0.35)
		await _wait_for_motion()
	_restore_camera()


func _restore_camera() -> void:
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	_previous_camera = null


func build_battle_trainer_metadata(metadata: Dictionary) -> Dictionary:
	var result := metadata.duplicate(true)
	result["_battle_sprite_frames"] = _build_pair_frames()
	result["_battle_sprite_offset"] = Vector2(0, -16)
	var track := MusicResolver.resolve_track_id(metadata)
	if not track.is_empty():
		result["_battle_music_track_id"] = track
	return result


func _build_pair_frames() -> SpriteFrames:
	if _pair_frames != null:
		return _pair_frames
	_pair_frames = SpriteFrames.new()
	_pair_frames.remove_animation(&"default")
	for animation_name: StringName in actors[0].sprite_frames.get_animation_names():
		_pair_frames.add_animation(animation_name)
		_pair_frames.set_animation_speed(animation_name, 7.5)
		for frame: int in range(actors[0].sprite_frames.get_frame_count(animation_name)):
			var image := Image.create(112, 64, false, Image.FORMAT_RGBA8)
			for index: int in range(2):
				var source := actors[index].sprite_frames.get_frame_texture(animation_name, frame).get_image()
				image.blend_rect(source, Rect2i(0, 0, 64, 64), Vector2i(index * 48, 0))
			_pair_frames.add_frame(animation_name, ImageTexture.create_from_image(image))
	return _pair_frames
