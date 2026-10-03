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
