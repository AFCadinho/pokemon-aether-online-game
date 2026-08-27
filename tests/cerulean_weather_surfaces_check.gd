extends SceneTree

const WeatherScene := preload("res://scenes/world/weather/overworld_weather_controller.tscn")
const CeruleanVisualScene := preload(
	"res://generated/tiled_visuals/cerulean_city/cerulean_city.visual.tscn"
)
const CeruleanWeatherWaterMaskScript := preload(
	"res://scripts/world/kanto/towns/cerulean_weather_water_mask.gd"
)

var failed := false


func _init() -> void:
	var city_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/cerulean_city.gd"
	)
	_check_true(
		city_source.contains('CeruleanWeatherWaterMaskScript.build(get_node_or_null("CeruleanCityVisual"))'),
		"Cerulean builds its weather water mask during map setup"
	)
	var visual := CeruleanVisualScene.instantiate()
	root.add_child(visual)
	var ground := visual.get_node("Ground") as TileMapLayer
	var ground_detail := visual.get_node("GroundDetail") as TileMapLayer
	var water_mask := CeruleanWeatherWaterMaskScript.build(visual)
	_check_true(water_mask != null, "Cerulean builds a weather water mask")
	if water_mask == null:
		quit(1)
		return
	_check_true(not water_mask.visible, "Cerulean weather water mask remains invisible")
	_check_equal(str(water_mask.get_meta("pao_rain_surface", "")), "water", "Cerulean mask declares water weather semantics")
	_check_true(
		water_mask.get_used_cells().size() >= 800,
		"Cerulean water tiles populate the complete weather mask"
	)
	_check_true(
		CeruleanWeatherWaterMaskScript.build(visual) == water_mask,
		"Cerulean water mask construction is idempotent"
	)

	for cell: Vector2i in water_mask.get_used_cells():
		_check_equal(
			water_mask.get_cell_source_id(cell),
			ground.get_cell_source_id(cell),
			"water mask preserves the visual tile source"
		)
		_check_equal(
			water_mask.get_cell_atlas_coords(cell),
			ground.get_cell_atlas_coords(cell),
			"water mask preserves the visual atlas tile"
		)

	var controller := WeatherScene.instantiate() as OverworldWeatherController
	controller.transition_duration = 0.0
	root.add_child(controller)
	await process_frame
	controller.apply_map(visual)
	var rain = controller.rain_ground_effects
	var snow = controller.snow_ground_effects
	_check_equal(rain.get_surface_layer_count(), 2, "Cerulean Ground and GroundDetail accept rain impacts")
	_check_equal(rain.get_water_layer_count(), 1, "Cerulean exposes its generated water mask to rain")
	_check_true(rain.z_index > ground_detail.z_index, "Cerulean rain impacts render above GroundDetail")

	var water_cell: Vector2i = water_mask.get_used_cells()[0]
	var water_position := water_mask.to_global(water_mask.map_to_local(water_cell))
	_check_equal(
		rain._weather_surface_type_at_position(water_position),
		"water",
		"Cerulean rain selects ripples on water"
	)
	_check_equal(
		snow._weather_surface_type_at_position(water_position),
		"",
		"Cerulean snow does not land on water"
	)

	var found_ground_detail_surface := false
	for cell: Vector2i in ground_detail.get_used_cells():
		var detail_position := ground_detail.to_global(ground_detail.map_to_local(cell))
		if rain._weather_surface_type_at_position(detail_position) == "ground":
			found_ground_detail_surface = true
			break
	_check_true(found_ground_detail_surface, "Cerulean GroundDetail retains open rain-impact cells")

	controller.queue_free()
	visual.queue_free()
	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
