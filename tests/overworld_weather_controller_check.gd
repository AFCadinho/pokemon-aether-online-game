extends SceneTree

const WeatherScene := preload("res://scenes/world/weather/overworld_weather_controller.tscn")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const PalletVisualScene := preload("res://generated/tiled_visuals/pallet_town/pallet_town.visual.tscn")

var failed := false


func _init() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var metadata_source := FileAccess.get_file_as_string("res://scripts/world/map_metadata.gd")
	var oaks_lab_source := FileAccess.get_file_as_string("res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn")
	_check_true(metadata_source.contains('@export_enum("outdoor", "disabled") var weather_profile'), "map metadata exposes an explicit weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(target_map)"), "authorized teleports apply the destination weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(new_map)"), "regular map transitions apply the destination weather policy")
	_check_true(world_source.contains("_apply_weather_for_map(initial_map)"), "initial world setup applies the map weather policy")
	_check_true(world_source.contains("weather_controller.clear_debug_weather()"), "legacy local previews cannot leak into the next map")
	_check_true(oaks_lab_source.contains('weather_profile = "disabled"'), "Oak's Lab explicitly disables overworld weather")

	var controller := WeatherScene.instantiate() as OverworldWeatherController
	controller.transition_duration = 0.0
	root.add_child(controller)
	await process_frame
	var rain := controller.get_node("RainParticles") as GPUParticles2D
	var rain_ground_effects := controller.rain_ground_effects
	var snow := controller.get_node("SnowParticles") as GPUParticles2D
	var snow_ground_effects := controller.snow_ground_effects

	_check_true(controller is CanvasLayer, "weather renderer has a dedicated canvas layer")
	_check_equal(controller.layer, 1, "weather renders above overworld canvas items")
	_check_true(controller.follow_viewport_enabled, "weather layer follows the world camera")
	_check_true(rain_ground_effects.get_parent() == root, "rain impacts render in the world canvas")
	_check_true(snow_ground_effects.get_parent() == root, "snow landings render in the world canvas")
	_check_true(not rain_ground_effects.z_as_relative, "rain impacts use map surface depth rather than the weather overlay depth")
	_check_true(not snow_ground_effects.z_as_relative, "snow landings use map surface depth rather than the weather overlay depth")
	_check_true(not rain.local_coords and not snow.local_coords, "weather particles remain in world space when the camera moves")
	_check_equal(controller.get_effective_weather(), "clear", "weather defaults to clear")
	_check_true(not rain.emitting and not snow.emitting, "clear weather has no particle effect")
	_check_true(not rain_ground_effects.emitting and not rain_ground_effects.visible, "clear weather has no rain ground effects")
	_check_true(not snow_ground_effects.emitting and not snow_ground_effects.visible, "clear weather has no snow ground effects")

	var visual_map := Node2D.new()
	var ground_layer := TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.set_meta("tiled_name", "Ground")
	ground_layer.set_meta("tiled_visual_layer", true)
	var tree_layer := TileMapLayer.new()
	tree_layer.name = "TreeTop"
	tree_layer.set_meta("tiled_name", "TreeTop")
	tree_layer.set_meta("tiled_visual_layer", true)
	visual_map.add_child(ground_layer)
	visual_map.add_child(tree_layer)
	root.add_child(visual_map)
	controller.apply_map(visual_map)
	_check_equal(rain_ground_effects.get_surface_layer_count(), 1, "ground visual layers accept rain impacts")
	_check_equal(snow_ground_effects.get_surface_layer_count(), 1, "ground visual layers accept snow landings")
	_check_equal(rain_ground_effects.get_cover_layer_count(), 1, "tree and structure visual layers block rain impacts")
	_check_equal(snow_ground_effects.get_cover_layer_count(), 1, "tree and structure visual layers block snow landings")
	var unclassified_visual_map := Node2D.new()
	var unclassified_layer := TileMapLayer.new()
	unclassified_layer.name = "Meadow"
	unclassified_layer.set_meta("tiled_name", "Meadow")
	unclassified_layer.set_meta("tiled_visual_layer", true)
	unclassified_visual_map.add_child(unclassified_layer)
	root.add_child(unclassified_visual_map)
	controller.apply_map(unclassified_visual_map)
	_check_true(
		not rain_ground_effects._is_position_on_weather_surface(Vector2.ZERO),
		"unclassified imported maps fail closed instead of splashing over covers"
	)
	var pallet_visual := PalletVisualScene.instantiate()
	root.add_child(pallet_visual)
	controller.apply_map(pallet_visual)
	_check_true(rain_ground_effects.get_surface_layer_count() >= 1, "imported outdoor visuals expose weather surfaces")
	_check_true(rain_ground_effects.get_cover_layer_count() >= 1, "imported outdoor visuals expose weather covers")
	_check_true(_has_allowed_and_covered_surface_points(rain_ground_effects), "Pallet Town ground effects distinguish open ground from covered tiles")

	controller.set_server_weather("rain")
	_check_equal(controller.get_effective_weather(), "rain", "server weather can select rain")
	_check_true(rain.emitting and rain.visible, "rain enables only rain particles")
	_check_true(rain_ground_effects.emitting and rain_ground_effects.visible, "rain enables animated ground impacts")
	_check_true(rain_ground_effects.spawn_rect.has_area(), "rain impacts cover the visible ground area")
	_check_true(rain_ground_effects.get_active_event_count() > 0, "rain immediately prewarms visible ground impacts")
	_check_true(not snow_ground_effects.emitting and not snow_ground_effects.visible, "rain keeps snow landings disabled")
	_check_true(not snow.emitting and not snow.visible, "rain keeps snow disabled")

	controller.set_debug_weather("snow")
	_check_true(controller.is_debug_weather_active(), "developer preview records an override")
	_check_equal(controller.get_effective_weather(), "snow", "developer snow overrides server rain")
	_check_true(snow.emitting and snow.visible, "snow preview enables snow particles")
	_check_true(not rain.emitting and not rain.visible, "snow preview disables rain particles")
	_check_true(not rain_ground_effects.emitting and not rain_ground_effects.visible, "snow preview disables rain ground impacts")
	_check_true(snow_ground_effects.emitting and snow_ground_effects.visible, "snow preview enables ground landings")
	_check_true(snow_ground_effects.spawn_rect.has_area(), "snow landings cover the visible ground area")
	_check_true(snow_ground_effects.get_active_event_count() > 0, "snow immediately prewarms visible ground landings")

	controller.set_server_weather("clear")
	_check_equal(controller.get_effective_weather(), "snow", "server updates do not replace an active preview")
	controller.clear_debug_weather()
	_check_equal(controller.get_effective_weather(), "clear", "reset returns to the latest server/default weather")
	_check_true(not rain.emitting and not snow.emitting, "reset to clear removes all weather particles")
	_check_true(not rain_ground_effects.emitting, "reset to clear stops rain ground impacts")
	_check_true(not snow_ground_effects.emitting, "reset to clear stops snow ground landings")

	controller.set_debug_weather("unsupported")
	_check_equal(controller.get_effective_weather(), "clear", "unsupported weather safely normalizes to clear")
	controller.clear_debug_weather()
	controller.set_server_weather("rain")
	var disabled_map := MapMetadataScript.new()
	disabled_map.weather_profile = "disabled"
	controller.apply_map(disabled_map)
	_check_true(not controller.is_weather_enabled_for_current_map(), "maps can explicitly disable overworld weather")
	_check_equal(controller.get_effective_weather(), "clear", "disabled maps always render clear weather")
	_check_true(not rain.emitting and not snow.emitting, "disabled maps stop active weather particles")
	_check_true(not rain_ground_effects.emitting, "disabled maps stop rain ground impacts")
	_check_true(not snow_ground_effects.emitting, "disabled maps stop snow ground landings")
	controller.set_server_weather("snow")
	_check_equal(controller.server_weather, "snow", "disabled maps still retain the latest server weather")
	var outdoor_map := MapMetadataScript.new()
	outdoor_map.weather_profile = "outdoor"
	controller.apply_map(outdoor_map)
	_check_equal(controller.get_effective_weather(), "snow", "weather returns after entering an enabled outdoor map")
	_check_true(snow.emitting and snow.visible, "the retained server weather resumes outdoors")
	_check_true(snow_ground_effects.emitting and snow_ground_effects.visible, "retained snow resumes ground landings outdoors")
	controller.set_creator_weather_effects_visible(false)
	_check_equal(controller.get_effective_weather(), "clear", "photo mode can locally hide overworld weather")
	_check_true(not rain.emitting and not snow.emitting, "hidden creator weather stops all particles")
	_check_true(not rain_ground_effects.emitting and not snow_ground_effects.emitting, "hidden creator weather stops all ground effects")
	_check_equal(controller.server_weather, "snow", "hiding creator weather preserves authoritative weather")
	controller.clear_creator_weather_effects_override()
	_check_equal(controller.get_effective_weather(), "snow", "closing photo mode restores authoritative weather")
	_check_true(snow.emitting and snow.visible, "restored creator weather resumes particles")
	_check_true(snow_ground_effects.emitting and snow_ground_effects.visible, "restored creator weather resumes snow landings")
	controller.transition_duration = 0.01
	controller.set_server_weather("rain")
	await create_timer(0.03).timeout
	_check_true(rain_ground_effects.emitting and rain_ground_effects.visible, "rain impacts finish their weather fade-in")
	controller.set_server_weather("snow")
	await create_timer(0.03).timeout
	_check_true(not rain_ground_effects.emitting and not rain_ground_effects.visible, "rain impacts stop after fading to snow")
	_check_true(snow_ground_effects.emitting and snow_ground_effects.visible, "snow landings finish their weather fade-in")
	controller.set_server_weather("clear")
	await create_timer(0.03).timeout
	_check_true(not snow_ground_effects.emitting and not snow_ground_effects.visible, "snow landings stop after their weather fade-out")
	disabled_map.free()
	outdoor_map.free()
	controller.queue_free()
	visual_map.queue_free()
	unclassified_visual_map.queue_free()
	pallet_visual.queue_free()
	quit(1 if failed else 0)


func _has_allowed_and_covered_surface_points(ground_effects: Node) -> bool:
	var found_allowed := false
	var found_covered := false
	for surface_layer: TileMapLayer in ground_effects._surface_layers:
		for cell: Vector2i in surface_layer.get_used_cells():
			var world_position := surface_layer.to_global(surface_layer.map_to_local(cell))
			if ground_effects._is_position_on_weather_surface(world_position):
				found_allowed = true
			else:
				found_covered = true
			if found_allowed and found_covered:
				return true
	return false


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
