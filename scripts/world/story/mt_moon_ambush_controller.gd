extends Node2D

class_name MtMoonAmbushController

const QUEST_ID := "travel_through_mt_moon"
const FINAL_STEP_ID := "cross_mt_moon"
const OVERWORLD_POKEMON_SCENE := preload("res://scenes/npcs/overworld_pokemon.tscn")
const RIFT_TEXTURE := preload("res://assets/npcs/Ultimate Gen 4 Overworlds Pack/Animations & Others/DistortionWorld_Portal.png")
const CINEMATIC_MOVE_CATALOG := preload("res://scripts/world/story/mt_moon_cinematic_move_catalog.gd")
const ROCKET_SPECIES: Array[String] = ["zubat", "rattata", "ekans"]
const ROCKET_POKEMON_POSITIONS: Array[Vector2] = [Vector2(-64, -32), Vector2(64, -32), Vector2(0, 64)]

@export var miguel_path: NodePath
@export var helix_fossil_path: NodePath
@export var dome_fossil_path: NodePath

@onready var rockets: Array[Node] = [$RocketLeft, $RocketRight, $RocketRear]
@onready var future_self: AnimatedSprite2D = $FutureSelf

var _dialogue_stage := 0
var _starter: Node2D
var _starter_species_id := ""
var _starter_types: Array[String] = []
var _rocket_pokemon: Array[Node2D] = []
var _rift: Sprite2D
var _overlay_layer: CanvasLayer
var _overlay_root: Control
var _prepared := false
var _counterattack_played := false


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
	if _dialogue_stage == 0:
		await _prepare_ambush()
	elif _dialogue_stage == 1:
		await _reveal_rescuer()
	_dialogue_stage += 1
	var dialogue_box := get_tree().current_scene.get_node_or_null("DialogueBox/Box")
	if dialogue_box == null or not dialogue_box.has_method("start_dialogue"):
		return false
	dialogue_box.call("start_dialogue", lines, speaker_name)
	await dialogue_box.dialogue_finished
	if _dialogue_stage == 2:
		await _play_counterattack()
		await _dismiss_rescuer()
	return true


func _prepare_ambush() -> void:
	if _prepared:
		return
	_prepared = true
	await _show_miguel_takes_other_fossil()
	for rocket: Node in rockets:
		rocket.visible = true
		rocket.modulate.a = 0.0
		create_tween().tween_property(rocket, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(0.25).timeout
	await _summon_rocket_pokemon()


func _show_miguel_takes_other_fossil() -> void:
	var miguel := get_node_or_null(miguel_path) as Node2D
	var other_fossil := get_node_or_null(dome_fossil_path) if InventoryService.has_item("helix-fossil") else get_node_or_null(helix_fossil_path)
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
	_starter = _create_cutscene_pokemon(species_id, Vector2(32, 64))
	var localized_name := ContentLocalization.display_name("species", species_id, species_name)
	await _show_caption(_text("story.mt_moon.cutscene.go").replace("{pokemon}", localized_name), 0.75)
	await _play_ball_summon(future_self.global_position + Vector2(12, -16), _starter, "ultra-ball")
	await get_tree().create_timer(0.25).timeout


func _play_counterattack() -> void:
	if _counterattack_played:
		return
	_counterattack_played = true
	if not is_instance_valid(_starter):
		await _flee_rockets()
		return
	var move: Dictionary = CINEMATIC_MOVE_CATALOG.for_types(_starter_types)
	var move_id := str(move.get("id", "hyper-beam"))
	var move_name := ContentLocalization.display_name("moves", move_id, str(move.get("name", "Hyper Beam")))
	var pokemon_name := ContentLocalization.display_name("species", _starter_species_id, _starter_species_id.capitalize())
	await _show_caption(_text("story.mt_moon.cutscene.used_move").replace("{pokemon}", pokemon_name).replace("{move}", move_name), 0.7)
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
	await _flee_rockets()


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
	var interaction_shape := pokemon.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
	if interaction_shape != null:
		interaction_shape.set_deferred("disabled", true)
	return pokemon


func _play_ball_summon(throw_world_position: Vector2, pokemon: Node2D, ball_id: String) -> void:
	_ensure_overlay()
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
