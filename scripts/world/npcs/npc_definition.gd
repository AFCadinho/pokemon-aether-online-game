@tool
extends Resource

class_name NpcDefinition

## Stable, client-owned identity and presentation for a reusable NPC.
## Dialogue, teams, shops, rewards, and other live content stay server-owned.
@export_group("Identity")
@export var npc_id := ""
@export var npc_definition_id := ""
@export var display_name := ""

@export_group("Presentation")
@export var sprite_frames: SpriteFrames
@export var mugshot: Texture2D
