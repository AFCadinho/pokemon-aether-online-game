extends Resource

class_name BattleEnvironmentProfile

@export var environment_id: StringName = &""
@export_enum("classic", "forest", "cave", "sea", "stadium", "route_1", "route_1_water", "route_22", "route_22_water") var arena_3d_id := "classic"
@export var background_texture: Texture2D
@export var background_video: VideoStream
@export var loop_background_video := true
@export var platform_texture: Texture2D


func is_valid() -> bool:
	return environment_id != &"" and background_texture != null and platform_texture != null
