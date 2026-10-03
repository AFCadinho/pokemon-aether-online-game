@tool
extends "res://scripts/world/npcs/overworld_pokemon.gd"

class_name WeeklyBossNPC

const BossDefinition := preload("res://scripts/world/npcs/weekly_boss_definition.gd")
const DIFFICULTIES: Array[String] = ["easy", "intermediate", "hard"]

## A world controller loads the server status and opens its difficulty selector here.
signal interaction_requested(boss: Node2D, player: Node2D)
## The controller must use a trusted weekly-boss battle adapter, not a wild battle.
signal challenge_requested(boss_id: String, difficulty: String)

@export var boss_definition: BossDefinition
@export var boss_nameplate_color := Color("#ff5555")

var weekly_status: Dictionary = {}
var selector_open := false


func _ready() -> void:
	_apply_boss_definition()
	super._ready()


func _apply_boss_definition() -> void:
	if boss_definition == null:
		return
	display_name = boss_definition.display_name
	species_id = boss_definition.species_id
	battle_environment_id = boss_definition.battle_environment_id
	movement_behavior = "idle"
	_sync_nameplate()


func _make_nameplate_label_settings() -> LabelSettings:
	var settings := super._make_nameplate_label_settings()
	settings.font_color = boss_nameplate_color
	return settings


func _get_npc_metadata_id() -> String:
	return ""


func _load_overworld_pokemon_metadata_if_needed() -> Dictionary:
	# Bosses have their own catalog; they are not cry-only overworld Pokémon.
	return {"success": true, "metadata": {}}


func interact_with_player(player: Node2D) -> void:
	if boss_definition != null and not boss_definition.boss_id.strip_edges().is_empty():
		interaction_requested.emit(self, player)
		if not selector_open and not Engine.is_editor_hint():
			_open_difficulty_selector(player)


func apply_weekly_status(status: Dictionary) -> bool:
	if boss_definition == null or str(status.get("bossId", "")) != boss_definition.boss_id:
		return false
	if str(status.get("state", "")) not in ["available", "in_battle", "completed"]:
		return false
	weekly_status = status.duplicate(true)
	return true


func request_challenge(difficulty: String) -> bool:
	if boss_definition == null or boss_definition.boss_id.strip_edges().is_empty():
		return false
	if difficulty not in DIFFICULTIES or str(weekly_status.get("state", "")) != "available":
		return false
	# Presentation guard only: the server atomically reserves the real attempt.
	weekly_status["state"] = "in_battle"
	challenge_requested.emit(boss_definition.boss_id, difficulty)
	return true


func _open_difficulty_selector(player: Node2D) -> void:
	selector_open = true
	is_interacting = true
	GameState.lock_overworld_input()
	if player.has_method("face_world_position"):
		player.face_world_position(get_feet_position())
	var request := HTTPRequest.new()
	add_child(request)
	var api := _root_service("BattleApiClient")
	var response: Dictionary = await api.get_weekly_boss_status(request, boss_definition.boss_id)
	request.queue_free()
	var dialog := ConfirmationDialog.new()
	add_child(dialog)
	dialog.title = display_name
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().text = LocalizationManager.text("weekly_boss.close")
	var selected := {"difficulty": ""}
	if bool(response.get("success", false)) and apply_weekly_status(response.get("boss", {})):
		if str(weekly_status.get("state", "")) == "available":
			dialog.dialog_text = LocalizationManager.text("weekly_boss.choose")
			for difficulty: String in DIFFICULTIES:
				var profile: Dictionary = weekly_status.get("difficulties", {}).get(difficulty, {})
				dialog.add_button(LocalizationManager.text("weekly_boss." + difficulty) + " (Lv. %d)" % int(profile.get("level", 0)), false, difficulty)
		elif str(weekly_status.get("state", "")) == "completed":
			dialog.dialog_text = LocalizationManager.text("weekly_boss.completed", {"reset": str(weekly_status.get("nextResetAt", ""))})
		else:
			dialog.dialog_text = LocalizationManager.text("weekly_boss.in_battle")
	else:
		dialog.dialog_text = LocalizationManager.text("weekly_boss.unavailable")
	dialog.custom_action.connect(func(action: StringName):
		selected["difficulty"] = str(action)
		dialog.hide()
	)
	dialog.popup_centered(Vector2i(650, 250))
	await dialog.visibility_changed
	dialog.queue_free()
	GameState.unlock_overworld_input()
	selector_open = false
	is_interacting = false
	var difficulty := str(selected["difficulty"])
	if difficulty.is_empty() or not request_challenge(difficulty):
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var trainer_data := build_battle_trainer_metadata({
		"id": "weekly_boss_" + boss_definition.boss_id + "_" + difficulty,
		"name": display_name, "weeklyBossId": boss_definition.boss_id, "difficulty": difficulty,
		"battleOptions": {"teamPreview": true, "strictChoices": true},
	})
	trainer_data["_battle_sprite_id"] = ""
	var result: Dictionary = await world.start_trainer_battle(trainer_data)
	if not bool(result.get("success", false)):
		weekly_status.clear()
		get_tree().call_group("ui_overlay", "add_system_message", LocalizationManager.text("weekly_boss.unavailable"))
