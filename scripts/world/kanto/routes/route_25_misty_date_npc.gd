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
var _misty_nameplate: Control
var _portrait_overlay_layer: CanvasLayer
var _portrait_overlay_root: Control
var _player_portrait_renderer: TrainerHeadPortrait


func _ready() -> void:
	super._ready()
	_setup_misty_nameplate()
	if heart != null:
		_heart_origin = heart.position
		_start_heart_animation()


func _exit_tree() -> void:
	if _heart_tween != null and _heart_tween.is_valid():
		_heart_tween.kill()
	if is_instance_valid(_portrait_overlay_layer):
		_portrait_overlay_layer.queue_free()


func set_story_player(player: Node2D) -> void:
	_story_player = player
	_dialogue_stage = 0


func _run_story_or_legacy_interaction(body: Node2D, trigger: String) -> Dictionary:
	set_story_player(body)
	return await super._run_story_or_legacy_interaction(body, trigger)


func _after_story_interaction(_player: Node2D, result: Dictionary) -> void:
	_present_moomoo_milk_reward(result.get("effects", []))


func _present_moomoo_milk_reward(effects_value: Variant) -> bool:
	var quantity := 0
	if effects_value is Array:
		for effect_value: Variant in effects_value as Array:
			if effect_value is not Dictionary:
				continue
			var effect := effect_value as Dictionary
			if bool(effect.get("alreadyGranted", false)):
				continue
			var grants_value: Variant = effect.get("grants", [])
			if grants_value is not Array:
				continue
			for grant_value: Variant in grants_value as Array:
				if grant_value is not Dictionary:
					continue
				var grant := grant_value as Dictionary
				if str(grant.get("itemId", "")).strip_edges().to_lower() == "moomoo-milk":
					quantity += maxi(int(grant.get("quantity", 0)), 0)
	if quantity <= 0:
		return false
	get_tree().call_group(
		"ui_overlay",
		"add_system_message",
		LocalizationManager.text("ui.world.reward.story_item", {
			"item": ItemLocalization.display_name("moomoo-milk"),
			"quantity": quantity,
		})
	)
	SfxManager.play("item_received")
	return true


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
	var portrait := await _dialogue_portrait(current_stage, speaker_name)
	dialogue_box.call(
		"start_dialogue",
		_format_story_lines(lines),
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
	if _misty_nameplate != null:
		_misty_nameplate.visible = false


func blocks_world_position(world_position: Vector2) -> bool:
	if super.blocks_world_position(world_position):
		return true
	return (
		is_visible_in_tree()
		and misty != null
		and misty.visible
		and _to_tile(world_position) == _to_tile(_misty_feet_position())
	)


func _is_player_facing_npc(body: Node2D) -> bool:
	if super._is_player_facing_npc(body):
		return true
	if body == null or misty == null or not misty.visible:
		return false
	var direction_value: Variant = body.get("last_direction")
	if not direction_value is Vector2:
		return false
	var direction := direction_value as Vector2
	if direction == Vector2.ZERO:
		return false
	var player_tile := _to_tile(_get_body_feet_position(body))
	var facing_tile := player_tile + Vector2i(roundi(direction.x), roundi(direction.y))
	return facing_tile == _to_tile(_misty_feet_position())


func _misty_feet_position() -> Vector2:
	return misty.global_position + Vector2(0, 16)


func _setup_misty_nameplate() -> void:
	if nameplate == null or _misty_nameplate != null:
		return
	_misty_nameplate = nameplate.duplicate() as Control
	if _misty_nameplate == null:
		return
	_misty_nameplate.name = "MistyNameplate"
	nameplate.position.x -= 20.0
	_misty_nameplate.position.x += 52.0
	add_child(_misty_nameplate)
	var label := _misty_nameplate.get_node_or_null("NameLabel") as Label
	var background := _misty_nameplate.get_node_or_null("NameplateBackground") as Panel
	if label == null or background == null:
		return
	label.text = "Misty"
	var name_size := _get_nameplate_label_text_size(label)
	name_size.x = minf(name_size.x, NAMEPLATE_MAX_NAME_WIDTH)
	var card_top := NAMEPLATE_CARD_BOTTOM - name_size.y - (NAMEPLATE_VERTICAL_PADDING * 2.0)
	label.offset_left = NAMEPLATE_CENTER_X - (name_size.x * 0.5)
	label.offset_right = label.offset_left + name_size.x
	label.offset_top = card_top + NAMEPLATE_VERTICAL_PADDING
	label.offset_bottom = label.offset_top + name_size.y
	background.offset_left = label.offset_left - NAMEPLATE_HORIZONTAL_PADDING
	background.offset_right = label.offset_right + NAMEPLATE_HORIZONTAL_PADDING
	background.offset_top = card_top
	background.offset_bottom = NAMEPLATE_CARD_BOTTOM


func _dialogue_portrait(stage: int, speaker_name: String) -> Texture2D:
	if stage in PLAYER_DIALOGUE_STAGES:
		return await _player_mugshot()
	if stage in MISTY_DIALOGUE_STAGES:
		return TrainerPortraitCatalog.get_texture(MISTY_PORTRAIT_ID)
	if stage in DADINHO_DIALOGUE_STAGES or speaker_name == "Dadinho":
		return mugshot
	return null


func _player_mugshot() -> Texture2D:
	if not is_instance_valid(_player_portrait_renderer):
		_ensure_portrait_overlay()
		_player_portrait_renderer = TrainerHeadPortrait.new()
		_player_portrait_renderer.name = "PlayerDialoguePortrait"
		_player_portrait_renderer.head_only = false
		_player_portrait_renderer.render_scale = 1.25
		_player_portrait_renderer.custom_minimum_size = Vector2(64, 64)
		_player_portrait_renderer.size = Vector2(64, 64)
		_player_portrait_renderer.position = Vector2(-128, -128)
		_player_portrait_renderer.appearance_state = PlayerSave.to_appearance_state()
		_portrait_overlay_root.add_child(_player_portrait_renderer)
		await get_tree().process_frame
	if _player_portrait_renderer.viewport == null:
		return null
	return _player_portrait_renderer.viewport.get_texture()


func _ensure_portrait_overlay() -> void:
	if is_instance_valid(_portrait_overlay_root):
		return
	_portrait_overlay_layer = CanvasLayer.new()
	_portrait_overlay_layer.layer = 80
	var overlay_host := get_tree().current_scene
	if overlay_host == null:
		overlay_host = get_tree().root
	overlay_host.add_child(_portrait_overlay_layer)
	_portrait_overlay_root = Control.new()
	_portrait_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_overlay_layer.add_child(_portrait_overlay_root)
	_portrait_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _player_speaker_name() -> String:
	var player_name := str(PlayerSave.player_name).strip_edges()
	return player_name if not player_name.is_empty() else "Player"


func _format_story_lines(lines: Array[String]) -> Array[String]:
	var formatted_lines: Array[String] = []
	var player_name := _player_speaker_name()
	for line: String in lines:
		formatted_lines.append(line.replace("{player_name}", player_name))
	return formatted_lines


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
