@tool
extends "res://scripts/world/npcs/npc_definition.gd"

class_name TrainerDefinition

## Server trainer reference. The team and battle content remain server-owned.
@export var trainer_id := ""
## Optional visual arena override. The inherit value uses the current map.
@export_enum("inherit", "grass", "water", "cave", "pvp_stadium", "pewter_city_gym", "cerulean_city_gym") var battle_environment_id := "inherit"
