extends Resource

class_name BattleEnvironmentProfile

@export var environment_id: StringName = &""
@export var background_texture: Texture2D
@export var background_video: VideoStream
@export var loop_background_video := true
@export var platform_texture: Texture2D


func is_valid() -> bool:
	return environment_id != &"" and background_texture != null and platform_texture != null
