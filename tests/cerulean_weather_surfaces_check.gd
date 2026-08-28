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
	var water_mask := CeruleanWeatherWaterMaskScript.build(visual)
	var ground := _find_visual_layer(visual, 1)
	var grass := _find_visual_layer(visual, 6)
	var ground_detail := _find_visual_layer(visual, 2)
	var objects := _find_visual_layer(visual, 3)
	_check_true(grass != null, "Cerulean preserves its dedicated Grass visual layer")
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
	var gameplay_tiles := Node2D.new()
	gameplay_tiles.name = "Tiles"
	gameplay_tiles.visible = false
	var gameplay_water := TileMapLayer.new()
	gameplay_water.name = "Water"
	gameplay_water.z_index = 4095
	gameplay_water.tile_set = ground.tile_set
	gameplay_tiles.add_child(gameplay_water)
	visual.add_child(gameplay_tiles)

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
	_check_equal(rain.get_surface_layer_count(), 3, "Cerulean Ground, Grass, and GroundDetail accept rain impacts")
	_check_equal(rain.get_water_layer_count(), 2, "Cerulean recognizes its visual mask and hidden gameplay water")
	_check_equal(
		rain.z_index,
		ground_detail.z_index,
		"hidden gameplay water does not lift Cerulean rain above the visible ground"
	)
	_check_true(
		rain.z_index < objects.z_index,
		"Cerulean rain impacts stay beneath trees and other Objects"
	)
	_check_true(
		rain.z_index < 32,
		"Cerulean rain impacts stay beneath the lowest regular actor depth"
	)

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


func _find_visual_layer(visual: Node, layer_id: int) -> TileMapLayer:
	for child: Node in visual.get_children():
		var layer := child as TileMapLayer
		if layer != null and int(layer.get_meta("tiled_layer_id", -1)) == layer_id:
			return layer
	return null


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check_true(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _check_true(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
