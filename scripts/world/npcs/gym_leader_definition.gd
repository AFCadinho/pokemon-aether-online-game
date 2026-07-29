@tool
extends "res://scripts/world/npcs/trainer_definition.gd"

class_name GymLeaderDefinition

## Client-owned Gym Leader progression and presentation.
## Placement, dialogue, and battle content deliberately live elsewhere.
@export var badge_region := "kanto"
@export var badge_id := ""
@export var badge_display_name := "Gym Badge"
@export var badge_icon_texture: Texture2D
@export var required_badge_ids: Array[String] = []
