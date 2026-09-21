extends Resource

class_name BattleEnvironmentProfile

@export var environment_id: StringName = &""
@export_enum("classic", "forest", "cave", "sea", "stadium") var arena_3d_id := "classic"
@export var background_texture: Texture2D
@export var background_video: VideoStream
@export var loop_background_video := true
@export var platform_texture: Texture2D
@export_group("Rendered arena")
@export var rendered_arena_background_texture: Texture2D
@export var rendered_arena_background_video: VideoStream
@export var rendered_arena_loop_background_video := true
@export var rendered_arena_platform_texture: Texture2D


func is_valid() -> bool:
	return environment_id != &"" and background_texture != null and platform_texture != null


func resolve_background(style: String) -> Dictionary:
	var use_rendered_arena := (
		style in ["rendered_arena", "automatic"]
		and (rendered_arena_background_texture != null or rendered_arena_background_video != null)
	)
	return {
		"resolved_style": "rendered_arena" if use_rendered_arena else "original_2d",
		"texture": rendered_arena_background_texture if use_rendered_arena and rendered_arena_background_texture != null else background_texture,
		"video": rendered_arena_background_video if use_rendered_arena else background_video,
		"loop_video": rendered_arena_loop_background_video if use_rendered_arena else loop_background_video,
		"platform_texture": rendered_arena_platform_texture if use_rendered_arena and rendered_arena_platform_texture != null else platform_texture,
	}
