extends DialogueNPC

class_name Route25MistyDateNPC

const PLAYER_DIALOGUE_STAGES: Array[int] = [0, 3, 6, 11, 13]
const MISTY_DIALOGUE_STAGES: Array[int] = [1, 4, 7, 9]
const DADINHO_DIALOGUE_STAGES: Array[int] = [2, 5, 8, 10, 12, 14]
const MISTY_PORTRAIT_ID := "showdown_misty_lgpe"
const MISTY_DEPARTURE_OFFSETS: Array[Vector2] = [Vector2(0, -64), Vector2(-128, 0)]

@export var misty_path: NodePath
@export var heart_path: NodePath

@onready var misty: AnimatedSprite2D = get_node_or_null(misty_path) as AnimatedSprite2D
@onready var heart: Label = get_node_or_null(heart_path) as Label

var _dialogue_stage := 0
var _story_player: Node2D
var _heart_origin := Vector2.ZERO
var _heart_tween: Tween


func _ready() -> void:
	super._ready()
	if heart != null:
		_heart_origin = heart.position
		_start_heart_animation()


func _exit_tree() -> void:
	if _heart_tween != null and _heart_tween.is_valid():
		_heart_tween.kill()


func set_story_player(player: Node2D) -> void:
	_story_player = player
	_dialogue_stage = 0


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	set_story_player(body)
	return await super._run_story_or_legacy_interaction(body, trigger)


func show_dialogue(lines: Array[String] = [], speaker_name_override := "") -> bool:
	if lines.is_empty():
		return await super.show_dialogue(lines, speaker_name_override)

	var current_stage := _dialogue_stage
	_dialogue_stage += 1
	if current_stage == 0:
		_break_date_pose()

	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null or not dialogue_box.has_method("start_dialogue"):
		push_warning("Route25MistyDateNPC: DialogueBox/Box not found.")
		return false

	var speaker_name := speaker_name_override.strip_edges()
	if current_stage in PLAYER_DIALOGUE_STAGES:
		speaker_name = _player_speaker_name()
	var portrait := _dialogue_portrait(current_stage, speaker_name)
	dialogue_box.call(
		"start_dialogue",
		lines,
		speaker_name,
		portrait,
		portrait != null
	)
	await dialogue_box.dialogue_finished
	await _wait_for_interact_release()

	if current_stage == 9:
		await _misty_storms_off()
	return true


func _break_date_pose() -> void:
	_hide_heart()
	var player := _story_player
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		face_world_position(player.global_position)
		if player.has_method("face_world_position"):
			player.call("face_world_position", global_position)
	if misty != null:
		_set_misty_animation(&"idle_left")


func _misty_storms_off() -> void:
	if misty == null or not misty.visible:
		return
	_set_misty_animation(&"walk_up")
	var upward_tween := create_tween()
	upward_tween.tween_property(misty, "position", misty.position + MISTY_DEPARTURE_OFFSETS[0], 0.45)
	await upward_tween.finished

	_set_misty_animation(&"walk_left")
	var exit_tween := create_tween()
	exit_tween.tween_property(misty, "position", misty.position + MISTY_DEPARTURE_OFFSETS[1], 0.8)
	await exit_tween.finished
	misty.visible = false


func _dialogue_portrait(stage: int, speaker_name: String) -> Texture2D:
	if stage in MISTY_DIALOGUE_STAGES:
		return TrainerPortraitCatalog.get_texture(MISTY_PORTRAIT_ID)
	if stage in DADINHO_DIALOGUE_STAGES or speaker_name == "Dadinho":
		return mugshot
	return null


func _player_speaker_name() -> String:
	var player_name := str(PlayerSave.player_name).strip_edges()
	return player_name if not player_name.is_empty() else "Player"


func _set_misty_animation(animation_name: StringName) -> void:
	if misty == null or misty.sprite_frames == null:
		return
	if misty.sprite_frames.has_animation(animation_name):
		misty.play(animation_name)


func _start_heart_animation() -> void:
	if heart == null or not visible:
		return
	heart.pivot_offset = heart.size * 0.5
	_heart_tween = create_tween().set_loops()
	_heart_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_heart_tween.tween_property(heart, "position:y", _heart_origin.y - 5.0, 0.65)
	_heart_tween.parallel().tween_property(heart, "scale", Vector2(1.08, 1.08), 0.65)
	_heart_tween.tween_property(heart, "position:y", _heart_origin.y, 0.65)
	_heart_tween.parallel().tween_property(heart, "scale", Vector2.ONE, 0.65)


func _hide_heart() -> void:
	if _heart_tween != null and _heart_tween.is_valid():
		_heart_tween.kill()
	if heart != null:
		heart.visible = false


func _wait_for_interact_release() -> void:
	while Input.is_action_pressed("interact") and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame
