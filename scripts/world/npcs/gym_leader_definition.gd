extends Resource

class_name GymLeaderDefinition

## Alle vaste gegevens die samen één Gym Leader beschrijven.
## Plaatsing in de wereld, zoals positie en kijkrichting, blijft op de scene-instantie.
@export var npc_id := ""
@export var trainer_id := ""
@export var display_name := ""
@export var dialogue_id := ""
@export var sprite_frames: SpriteFrames
@export var mugshot: Texture2D
@export var badge_region := "kanto"
@export var badge_id := ""
@export var badge_display_name := "Gym Badge"
@export var badge_icon_texture: Texture2D
@export var required_badge_ids: Array[String] = []
