extends Resource

class_name BattleEnvironmentProfile

@export var environment_id: StringName = &""
@export_enum("pallet_town", "pallet_town_water", "viridian_city", "viridian_city_water", "pewter_city", "pewter_city_gym", "cerulean_city_gym", "classic", "forest", "cave", "sea", "stadium", "route_1", "route_1_water", "route_22", "route_22_water", "route_3", "route_2", "route_2_water", "route_4", "route_4_water", "cerulean_city", "cerulean_city_water", "route_24", "route_24_water", "route_25", "route_25_water") var arena_3d_id := "classic"
@export var background_texture: Texture2D
@export var background_video: VideoStream
@export var loop_background_video := true
@export var platform_texture: Texture2D
## Optional 2D art override; encounter location and 3D arena remain on this profile.
@export var wild_2d_background: BattleEnvironmentProfile


func is_valid() -> bool:
	return environment_id != &"" and background_texture != null and platform_texture != null


func get_2d_profile(is_wild: bool) -> BattleEnvironmentProfile:
	return wild_2d_background if is_wild and wild_2d_background != null else self
