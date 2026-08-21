extends Node2D

class_name MtMoonAmbushController

const QUEST_ID := "travel_through_mt_moon"
const FINAL_STEP_ID := "cross_mt_moon"
const HELIX_PICKUP_ID := "kanto_mt_moon_b2f_helix_fossil"
const DOME_PICKUP_ID := "kanto_mt_moon_b2f_dome_fossil"
const OVERWORLD_POKEMON_SCENE := preload("res://scenes/npcs/overworld_pokemon.tscn")

@export var miguel_path: NodePath
@export var helix_fossil_path: NodePath
@export var dome_fossil_path: NodePath

@onready var rockets: Array[Node] = [$RocketLeft, $RocketRight, $RocketRear]
@onready var future_self: AnimatedSprite2D = $FutureSelf

var _dialogue_stage := 0
var _starter: Node2D
var _prepared := false


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


func _show_miguel_takes_other_fossil() -> void:
	var miguel := get_node_or_null(miguel_path) as Node2D
	var other_fossil := (
		get_node_or_null(dome_fossil_path)
		if InventoryService.has_item("helix-fossil")
		else get_node_or_null(helix_fossil_path)
	)
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


func _reveal_rescuer() -> void:
	future_self.visible = true
	future_self.modulate = Color(0.22, 0.3, 0.55, 0.0)
	create_tween().tween_property(future_self, "modulate:a", 0.9, 0.35)
	await _spawn_starter_final_evolution()
	await get_tree().create_timer(0.45).timeout
	for rocket: Node in rockets:
		var direction: Vector2 = (rocket.global_position - global_position).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(rocket, "global_position", rocket.global_position + direction * 160.0, 0.45)
		tween.tween_property(rocket, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.5).timeout
	for rocket: Node in rockets:
		rocket.visible = false


func _spawn_starter_final_evolution() -> void:
	if is_instance_valid(_starter):
		return
	var options: Dictionary = await PlayerPartyStateService.get_starter_options()
	var selected_species_id := str(options.get("selectedSpeciesId", "")).strip_edges().to_lower()
	var species_id := ""
	for choice_value: Variant in options.get("choices", []):
		if not choice_value is Dictionary:
			continue
		var choice := choice_value as Dictionary
		if str(choice.get("speciesId", "")).strip_edges().to_lower() != selected_species_id:
			continue
		var paths: Array = choice.get("evolutionPaths", []) as Array
		if paths.is_empty() or not paths[0] is Array or (paths[0] as Array).is_empty():
			break
		var final_stage: Variant = (paths[0] as Array)[-1]
		if final_stage is Dictionary:
			species_id = str((final_stage as Dictionary).get("speciesId", "")).strip_edges().to_lower()
		break
	if species_id.is_empty():
		push_warning("MtMoonAmbushController: starter final evolution is unavailable.")
		return
	_starter = OVERWORLD_POKEMON_SCENE.instantiate() as Node2D
	_starter.set("species_id", species_id)
	_starter.set("display_name", "")
	_starter.position = Vector2(32, 64)
	_starter.modulate.a = 0.0
	add_child(_starter)
	create_tween().tween_property(_starter, "modulate:a", 1.0, 0.3)


func _dismiss_rescuer() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(future_self, "modulate:a", 0.0, 0.35)
	if is_instance_valid(_starter):
		tween.tween_property(_starter, "modulate:a", 0.0, 0.35)
	await tween.finished
	future_self.visible = false
	if is_instance_valid(_starter):
		_starter.queue_free()


func _on_story_changed(_revision: int) -> void:
	if StoryService.is_requirement_met(QUEST_ID, FINAL_STEP_ID, "completed"):
		for rocket: Node in rockets:
			rocket.visible = false
		future_self.visible = false
		if is_instance_valid(_starter):
			_starter.queue_free()
