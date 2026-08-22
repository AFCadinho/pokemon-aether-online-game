extends Node2D

class_name MtMoonAmbushController

const QUEST_ID := "travel_through_mt_moon"
const FINAL_STEP_ID := "cross_mt_moon"
const OVERWORLD_POKEMON_SCENE := preload("res://scenes/npcs/overworld_pokemon.tscn")
const RIFT_TEXTURE := preload("res://assets/npcs/Ultimate Gen 4 Overworlds Pack/Animations & Others/DistortionWorld_Portal.png")
const CINEMATIC_MOVE_CATALOG := preload("res://scripts/world/story/mt_moon_cinematic_move_catalog.gd")
const ROCKET_PORTRAIT_ID := "showdown_rainbowrocketgrunt"
const ROCKET_SPECIES: Array[String] = ["zubat", "rattata", "ekans", "koffing", "sandshrew"]
const ROCKET_POKEMON_POSITIONS: Array[Vector2] = [
	Vector2(-64, 0),
	Vector2(64, 0),
	Vector2(0, 72),
	Vector2(-48, -64),
	Vector2(48, -64),
]
const DIALOGUE_STAGE_AMBUSH := 0
const DIALOGUE_STAGE_FUTURE_VOICE := 1
const DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE := 2
const DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE := 3
const DIALOGUE_STAGE_ROCKET_FLEE := 4
const DIALOGUE_STAGE_PLAYER_QUESTION := 5
const DIALOGUE_STAGE_PLAYER_DEFENSE := 7
const DIALOGUE_STAGE_PLAYER_PROMISE := 9
const DIALOGUE_STAGE_FAREWELL := 10
const DIALOGUE_STAGE_PLAYER_SURPRISE := 11

@export var miguel_path: NodePath
@export var helix_fossil_path: NodePath
@export var dome_fossil_path: NodePath

@onready var rockets: Array[Node] = [
	$RocketLeft,
	$RocketRight,
	$RocketRear,
	$RocketUpperLeft,
	$RocketUpperRight,
]
@onready var future_self: AnimatedSprite2D = $FutureSelf

var _dialogue_stage := 0
var _starter: Node2D
var _starter_species_id := ""
var _starter_types: Array[String] = []
var _rocket_pokemon: Array[Node2D] = []
var _rift: Sprite2D
var _overlay_layer: CanvasLayer
var _overlay_root: Control
var _player_portrait_renderer: TrainerHeadPortrait
var _prepared := false
var _counterattack_played := false
var _future_self_spawn_global_position := Vector2.ZERO
var _fainted_follower: PokemonFollower
var _story_player: Node2D


func _ready() -> void:
	for rocket: Node in rockets:
		rocket.visible = false
	future_self.visible = false
	if not StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.connect(_on_story_changed)
	_on_story_changed(StoryService.get_revision())


func _exit_tree() -> void:
	if StoryService.story_changed.is_connected(_on_story_changed):
		StoryService.story_changed.disconnect(_on_story_changed)
	if is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()


func show_dialogue(lines: Array[String], speaker_name := "") -> bool:
	var current_stage := _dialogue_stage
	match current_stage:
		DIALOGUE_STAGE_AMBUSH:
			await _prepare_ambush()
	_dialogue_stage += 1
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null or not dialogue_box.has_method("start_dialogue"):
		return false
	var resolved_speaker_name := speaker_name
	if current_stage in [DIALOGUE_STAGE_PLAYER_QUESTION, DIALOGUE_STAGE_PLAYER_DEFENSE, DIALOGUE_STAGE_PLAYER_PROMISE, DIALOGUE_STAGE_PLAYER_SURPRISE]:
		resolved_speaker_name = _player_speaker_name()
	var portrait := await _dialogue_portrait(current_stage)
	var show_portrait := current_stage in [
		DIALOGUE_STAGE_AMBUSH,
		DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE,
		DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE,
		DIALOGUE_STAGE_ROCKET_FLEE,
		DIALOGUE_STAGE_PLAYER_QUESTION,
		DIALOGUE_STAGE_PLAYER_PROMISE,
	]
	dialogue_box.call("start_dialogue", lines, resolved_speaker_name, portrait, show_portrait)
	await dialogue_box.dialogue_finished
	await _wait_for_interact_release()
	if current_stage == DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE:
		await _reveal_rescuer()
	elif current_stage == DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE:
		if not await _play_counterattack():
			return false
	elif current_stage == DIALOGUE_STAGE_ROCKET_FLEE:
		await _flee_rockets()
		_face_future_self_and_player()
	elif current_stage == DIALOGUE_STAGE_FAREWELL:
		await _dismiss_rescuer()
	elif current_stage == DIALOGUE_STAGE_AMBUSH:
		if not await _attack_and_faint_follower():
			return false
	return true


func set_story_player(player: Node2D) -> void:
	_story_player = player


func _prepare_ambush() -> void:
	if _prepared:
		return
	_prepared = true
	await _show_miguel_takes_other_fossil()
	var entrance_tween := create_tween().set_parallel(true)
	for rocket: Node in rockets:
		var surround_position: Vector2 = rocket.position
		var approach_offset := Vector2(0, -64 if surround_position.y < 0.0 else 64)
		rocket.position = surround_position + approach_offset
		rocket.visible = true
		rocket.modulate.a = 0.0
		entrance_tween.tween_property(rocket, "position", surround_position, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		entrance_tween.tween_property(rocket, "modulate:a", 1.0, 0.2)
	await entrance_tween.finished
	_face_rockets_toward_player()
	await _flee_miguel()
	await _summon_rocket_pokemon()


func _show_miguel_takes_other_fossil() -> void:
	var miguel := get_node_or_null(miguel_path) as Node2D
	var other_fossil := get_node_or_null(dome_fossil_path) if InventoryService.has_item("helix-fossil") else get_node_or_null(helix_fossil_path)
	if other_fossil != null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var fossil_side := signf(other_fossil.global_position.x - player.global_position.x)
			if is_zero_approx(fossil_side):
				fossil_side = -1.0
			# Dadinho's temporary frames have a visual baseline 16 px below the player frames.
			_future_self_spawn_global_position = player.global_position + Vector2(fossil_side * 32.0, -16)
	if miguel == null or other_fossil == null:
		return
	other_fossil.visible = true
	var previous_position := miguel.position
	var approach_tween := create_tween()
	approach_tween.tween_property(miguel, "global_position", other_fossil.global_position + Vector2(0, 32), 0.35)
	await approach_tween.finished
	other_fossil.visible = false
	var return_tween := create_tween()
	return_tween.tween_property(miguel, "position", previous_position, 0.3)
	await return_tween.finished


func _summon_rocket_pokemon() -> void:
	if not _rocket_pokemon.is_empty():
		return
	for index: int in range(ROCKET_SPECIES.size()):
		var pokemon := _create_cutscene_pokemon(ROCKET_SPECIES[index], ROCKET_POKEMON_POSITIONS[index])
		_rocket_pokemon.append(pokemon)
		await _play_ball_summon(rockets[index].global_position + Vector2(0, -18), pokemon, "poke-ball")


func _reveal_rescuer() -> void:
	if _future_self_spawn_global_position != Vector2.ZERO:
		future_self.global_position = _future_self_spawn_global_position
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			future_self.global_position = player.global_position + Vector2(32, 0)
	await _open_rift()
	future_self.visible = true
	future_self.modulate = Color(0.5, 0.65, 1.0, 0.0)
	future_self.position.y -= 16.0
	var reveal_tween := create_tween().set_parallel(true)
	reveal_tween.tween_property(future_self, "modulate", Color(0.72, 0.82, 1.0, 0.95), 0.35)
	reveal_tween.tween_property(future_self, "position:y", future_self.position.y + 16.0, 0.35)
	await reveal_tween.finished
	await _spawn_starter_final_evolution()


func _spawn_starter_final_evolution() -> void:
	if is_instance_valid(_starter):
		return
	var options: Dictionary = await PlayerPartyStateService.get_starter_options()
	var selected_species_id := str(options.get("selectedSpeciesId", PlayerSave.flags.get("starter_species", ""))).strip_edges().to_lower()
	var species_id := ""
	var species_name := ""
	for choice_value: Variant in options.get("choices", []):
		if not choice_value is Dictionary:
			continue
		var choice := choice_value as Dictionary
		if str(choice.get("speciesId", "")).strip_edges().to_lower() != selected_species_id:
			continue
		_starter_types = _normalize_types(choice.get("types", []))
		var paths: Array = choice.get("evolutionPaths", []) as Array
		if paths.is_empty() or not paths[0] is Array or (paths[0] as Array).is_empty():
			break
		var final_stage: Variant = (paths[0] as Array)[-1]
		if final_stage is Dictionary:
			var final_data := final_stage as Dictionary
			species_id = str(final_data.get("speciesId", "")).strip_edges().to_lower()
			species_name = str(final_data.get("name", "")).strip_edges()
			var final_types := _normalize_types(final_data.get("types", []))
			if not final_types.is_empty():
				_starter_types = final_types
		break
	if species_id.is_empty():
		push_warning("MtMoonAmbushController: starter final evolution is unavailable.")
		return
	_starter_species_id = species_id
	var starter_target := future_self.global_position + Vector2(0, 48)
	_starter = _create_cutscene_pokemon(species_id, to_local(starter_target))
	var localized_name := ContentLocalization.display_name("species", species_id, species_name)
	await _show_caption(_text("story.mt_moon.cutscene.go").replace("{pokemon}", localized_name), 0.75)
	await _play_ball_summon(future_self.global_position + Vector2(12, -16), _starter, "ultra-ball")
	await get_tree().create_timer(0.25).timeout


func _play_counterattack() -> bool:
	if _counterattack_played:
		return true
	if not is_instance_valid(_starter):
		await _spawn_starter_final_evolution()
	if not is_instance_valid(_starter):
		push_warning("MtMoonAmbushController: counterattack cannot start without the future starter.")
		return false
	_counterattack_played = true
	var move: Dictionary = CINEMATIC_MOVE_CATALOG.for_types(_starter_types)
	var move_id := str(move.get("id", "hyper-beam"))
	var move_name := ContentLocalization.display_name("moves", move_id, str(move.get("name", "Hyper Beam")))
	var pokemon_name := ContentLocalization.display_name("species", _starter_species_id, _starter_species_id.capitalize())
	await _show_caption(_text("story.mt_moon.cutscene.use_move").replace("{pokemon}", pokemon_name).replace("{move}", move_name), 0.7)
	var target_positions: Array[Vector2] = []
	for pokemon: Node2D in _rocket_pokemon:
		if is_instance_valid(pokemon):
			target_positions.append(pokemon.position)
	var attack := MtMoonCinematicAttack.new()
	attack.z_index = 20
	add_child(attack)
	await attack.play(_starter.position, target_positions, str(move.get("type", "normal")))
	for pokemon: Node2D in _rocket_pokemon:
		if is_instance_valid(pokemon):
			create_tween().tween_property(pokemon, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.2).timeout
	return true


func _flee_rockets() -> void:
	for rocket: Node in rockets:
		var direction: Vector2 = (rocket.global_position - global_position).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(rocket, "global_position", rocket.global_position + direction * 160.0, 0.45)
		tween.tween_property(rocket, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.5).timeout
	for rocket: Node in rockets:
		rocket.visible = false
	for pokemon: Node2D in _rocket_pokemon:
		if is_instance_valid(pokemon):
			pokemon.queue_free()
	_rocket_pokemon.clear()


func _dismiss_rescuer() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(future_self, "modulate:a", 0.0, 0.35)
	if is_instance_valid(_starter):
		tween.tween_property(_starter, "modulate:a", 0.0, 0.35)
	await tween.finished
	future_self.visible = false
	if is_instance_valid(_starter):
		_starter.queue_free()
	await _close_rift()
	_restore_follower()


func _attack_and_faint_follower() -> bool:
	var player := _story_player if is_instance_valid(_story_player) else get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_warning("MtMoonAmbushController: local story player is unavailable for follower attack.")
		return false
	_fainted_follower = _resolve_player_follower(player)
	if not is_instance_valid(_fainted_follower):
		push_warning("MtMoonAmbushController: player follower is unavailable for ambush attack.")
		return false
	_fainted_follower.visible = true
	_fainted_follower.set_process(false)
	var attacker_species := ROCKET_SPECIES[0]
	var attacker_name := ContentLocalization.display_name("species", attacker_species, attacker_species.capitalize())
	await _show_rocket_attack_command(attacker_name)
	var attack := MtMoonCinematicAttack.new()
	attack.z_index = 100
	attack.top_level = true
	add_child(attack)
	var attacker := _rocket_pokemon[0] if not _rocket_pokemon.is_empty() and is_instance_valid(_rocket_pokemon[0]) else null
	var attack_source: Vector2 = attacker.global_position if attacker != null else rockets[0].global_position
	if attacker != null:
		var attacker_origin: Vector2 = attacker.global_position
		var lunge_target := _fainted_follower.global_position + (attacker_origin - _fainted_follower.global_position).normalized() * 20.0
		var lunge := create_tween()
		lunge.tween_property(attacker, "global_position", lunge_target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lunge.tween_property(attacker, "global_position", attacker_origin, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await attack.play(attack_source, [_fainted_follower.global_position], "poison")
	var follower_sprite := _fainted_follower.sprite
	if follower_sprite != null:
		var resting_position := follower_sprite.position
		var hit_tween := create_tween()
		hit_tween.tween_property(follower_sprite, "modulate", Color(1.0, 0.25, 0.35, 1.0), 0.08)
		hit_tween.parallel().tween_property(follower_sprite, "position", resting_position + Vector2(10, 0), 0.08)
		hit_tween.tween_property(follower_sprite, "modulate", Color.WHITE, 0.12)
		hit_tween.parallel().tween_property(follower_sprite, "position", resting_position, 0.12)
		await hit_tween.finished
		var faint_tween := create_tween().set_parallel(true)
		faint_tween.tween_property(follower_sprite, "rotation", PI * 0.18, 0.35)
		faint_tween.tween_property(follower_sprite, "position:y", resting_position.y + 8.0, 0.35)
		faint_tween.tween_property(follower_sprite, "modulate", Color(0.55, 0.55, 0.62, 0.9), 0.35)
		await faint_tween.finished
	await get_tree().create_timer(0.35).timeout
	var follower_name := ContentLocalization.display_name("species", _fainted_follower.current_species, _fainted_follower.current_species.capitalize())
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box != null:
		dialogue_box.call("start_dialogue", [_text("story.mt_moon.cutscene.follower_fainted").replace("{pokemon}", follower_name)], _player_speaker_name(), await _player_mugshot(), true)
		await dialogue_box.dialogue_finished
		await _wait_for_interact_release()
	return true


func _resolve_player_follower(player: Node2D) -> PokemonFollower:
	var follower_value: Variant = player.get("pokemon_follower")
	if follower_value is PokemonFollower and is_instance_valid(follower_value):
		return follower_value as PokemonFollower
	for candidate: Node in get_tree().current_scene.find_children("*", "PokemonFollower", true, false):
		var follower := candidate as PokemonFollower
		if follower != null and follower.player == player:
			return follower
	return null


func _show_rocket_attack_command(attacker_name: String) -> void:
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null:
		return
	var line := _text("story.mt_moon.cutscene.follower_attack").replace("{pokemon}", attacker_name)
	dialogue_box.call("start_dialogue", [line], "Team Rocket Grunt", TrainerPortraitCatalog.get_texture(ROCKET_PORTRAIT_ID), true)
	await dialogue_box.dialogue_finished
	await _wait_for_interact_release()


func _restore_follower() -> void:
	if not is_instance_valid(_fainted_follower):
		return
	_fainted_follower.set_process(true)
	if _fainted_follower.sprite != null:
		_fainted_follower.sprite.rotation = 0.0
		_fainted_follower.sprite.modulate = Color.WHITE
	_fainted_follower.reset_follow_position()
	_fainted_follower = null


func _open_rift() -> void:
	if not is_instance_valid(_rift):
		_rift = Sprite2D.new()
		_rift.texture = RIFT_TEXTURE
		_rift.position = future_self.position + Vector2(0, -12)
		_rift.z_index = -1
		_rift.scale = Vector2(0.05, 0.05)
		_rift.modulate = Color(0.7, 0.82, 1.0, 0.0)
		add_child(_rift)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rift, "scale", Vector2(0.72, 0.9), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rift, "modulate:a", 0.95, 0.28)
	tween.tween_property(_rift, "rotation", 0.5, 0.45)
	await tween.finished


func _close_rift() -> void:
	if not is_instance_valid(_rift):
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_rift, "scale", Vector2(0.04, 0.1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_rift, "modulate:a", 0.0, 0.24)
	await tween.finished
	_rift.queue_free()


func _create_cutscene_pokemon(species_id: String, local_position: Vector2) -> Node2D:
	var pokemon := OVERWORLD_POKEMON_SCENE.instantiate() as Node2D
	pokemon.set("species_id", species_id)
	pokemon.set("display_name", "")
	pokemon.position = local_position
	pokemon.visible = false
	add_child(pokemon)
	# BaseNPC initialization can restore visibility while the node enters the tree.
	# Reassert the cinematic state after _ready() has completed.
	pokemon.visible = false
	var nameplate := pokemon.get_node_or_null("Nameplate") as Control
	if nameplate != null:
		nameplate.visible = false
	var interaction_shape := pokemon.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
	if interaction_shape != null:
		interaction_shape.set_deferred("disabled", true)
	return pokemon


func _play_ball_summon(throw_world_position: Vector2, pokemon: Node2D, ball_id: String) -> void:
	_ensure_overlay()
	if is_instance_valid(pokemon):
		pokemon.visible = false
		pokemon.modulate.a = 1.0
	var animation := PokeballSummonAnimationPlayer.new()
	animation.sprite_render_scale = Vector2(1.5, 1.5)
	_overlay_root.add_child(animation)
	animation.pokemon_released.connect(func() -> void:
		if is_instance_valid(pokemon):
			pokemon.visible = true
			pokemon.modulate.a = 0.0
			create_tween().tween_property(pokemon, "modulate:a", 1.0, 0.18)
	, CONNECT_ONE_SHOT)
	var canvas_transform := get_viewport().get_canvas_transform()
	await animation.play_overworld_summon(
		ball_id,
		canvas_transform * throw_world_position,
		canvas_transform * (pokemon.global_position + Vector2(0, -16))
	)
	animation.queue_free()


func _show_caption(message: String, duration: float) -> void:
	_ensure_overlay()
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("f4f7ff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -300.0
	label.offset_right = 300.0
	label.offset_top = 150.0
	label.offset_bottom = 184.0
	_overlay_root.add_child(label)
	label.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_property(label, "modulate:a", 1.0, 0.12)
	reveal.tween_interval(duration)
	reveal.tween_property(label, "modulate:a", 0.0, 0.12)
	await reveal.finished
	label.queue_free()


func _ensure_overlay() -> void:
	if is_instance_valid(_overlay_root):
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 80
	get_tree().current_scene.add_child(_overlay_layer)
	_overlay_root = Control.new()
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay_root)
	_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func _normalize_types(value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not value is Array:
		return normalized
	for type_value: Variant in value as Array:
		var type_id := str(type_value).strip_edges().to_lower()
		if not type_id.is_empty():
			normalized.append(type_id)
	return normalized


func _text(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("text"):
		return str(localization_manager.call("text", key))
	return key


func _player_speaker_name() -> String:
	var player_name := str(PlayerSave.player_name).strip_edges()
	if not player_name.is_empty():
		return player_name
	return _text("story.mt_moon.cutscene.player_speaker")


func _dialogue_portrait(stage: int) -> Texture2D:
	if stage in [
		DIALOGUE_STAGE_AMBUSH,
		DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE,
		DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE,
		DIALOGUE_STAGE_ROCKET_FLEE,
	]:
		return TrainerPortraitCatalog.get_texture(ROCKET_PORTRAIT_ID)
	if stage in [DIALOGUE_STAGE_PLAYER_QUESTION, DIALOGUE_STAGE_PLAYER_DEFENSE, DIALOGUE_STAGE_PLAYER_PROMISE, DIALOGUE_STAGE_PLAYER_SURPRISE]:
		return await _player_mugshot()
	return null


func _player_mugshot() -> Texture2D:
	if not is_instance_valid(_player_portrait_renderer):
		_ensure_overlay()
		_player_portrait_renderer = TrainerHeadPortrait.new()
		_player_portrait_renderer.name = "PlayerDialoguePortrait"
		_player_portrait_renderer.head_only = false
		_player_portrait_renderer.render_scale = 1.25
		_player_portrait_renderer.custom_minimum_size = Vector2(64, 64)
		_player_portrait_renderer.size = Vector2(64, 64)
		_player_portrait_renderer.position = Vector2(-128, -128)
		_player_portrait_renderer.appearance_state = PlayerSave.to_appearance_state()
		_overlay_root.add_child(_player_portrait_renderer)
		await get_tree().process_frame
	if _player_portrait_renderer.viewport == null:
		return null
	return _player_portrait_renderer.viewport.get_texture()


func _wait_for_interact_release() -> void:
	while Input.is_action_pressed("interact") and is_inside_tree():
		await get_tree().process_frame
	# Do not let the input frame that closed this dialogue also advance the next action.
	if is_inside_tree():
		await get_tree().process_frame


func _flee_miguel() -> void:
	var miguel := get_node_or_null(miguel_path)
	if miguel != null and miguel.has_method("flee_after_ambush"):
		await miguel.call("flee_after_ambush")


func _face_rockets_toward_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for rocket: Node in rockets:
		if rocket.has_method("face_world_position"):
			rocket.call("face_world_position", player.global_position)
			continue
		var sprite := rocket as AnimatedSprite2D
		if sprite != null:
			_face_sprite_toward(sprite, player.global_position)


func _face_sprite_toward(sprite: AnimatedSprite2D, world_position: Vector2) -> void:
	var delta := world_position - sprite.global_position
	var direction_name := "down"
	if abs(delta.x) > abs(delta.y):
		direction_name = "right" if delta.x > 0.0 else "left"
	elif delta.y < 0.0:
		direction_name = "up"
	var animation_name := StringName("idle_%s" % direction_name)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		sprite.stop()


func _face_future_self_and_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not future_self.visible:
		return
	if player.has_method("face_world_position"):
		player.call("face_world_position", future_self.global_position)

	var delta := player.global_position - future_self.global_position
	var direction_name := "down"
	if abs(delta.x) > abs(delta.y):
		direction_name = "right" if delta.x > 0.0 else "left"
	elif delta.y < 0.0:
		direction_name = "up"
	var animation_name := StringName("idle_%s" % direction_name)
	if future_self.sprite_frames != null and future_self.sprite_frames.has_animation(animation_name):
		future_self.play(animation_name)
		future_self.stop()


func _on_story_changed(_revision: int) -> void:
	if StoryService.is_requirement_met(QUEST_ID, FINAL_STEP_ID, "completed"):
		for rocket: Node in rockets:
			rocket.visible = false
		future_self.visible = false
		if is_instance_valid(_starter):
			_starter.queue_free()
		for pokemon: Node2D in _rocket_pokemon:
			if is_instance_valid(pokemon):
				pokemon.queue_free()
		_rocket_pokemon.clear()
		if is_instance_valid(_rift):
			_rift.queue_free()
