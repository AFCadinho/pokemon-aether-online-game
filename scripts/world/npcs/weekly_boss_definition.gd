@tool
extends Resource

class_name WeeklyBossDefinition

## Presentation only. Teams, difficulties, rewards and victory checks belong to the server.
@export var boss_id := ""
@export var display_name := ""
@export var species_id := ""
@export var battle_environment_id := "inherit"
