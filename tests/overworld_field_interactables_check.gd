extends SceneTree

const REGULAR_BALL_PATH := "res://assets/npcs/gen4-ow-sprites/Object ball.png"
const MACHINE_BALL_PATH := "res://assets/npcs/gen4-ow-sprites/Object ball gold.png"
const VIRIDIAN_CITY_PATH := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"

var failed := false


func _init() -> void:
	var item_scene_source := FileAccess.get_file_as_string(
		"res://scenes/world/interactables/overworld_item.tscn"
	)
	var item_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/overworld_item.gd"
	)
	var boulder_scene_source := FileAccess.get_file_as_string(
		"res://scenes/world/interactables/strength_boulder.tscn"
	)
	var boulder_script_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/strength_boulder.gd"
	)
	var inventory_source := FileAccess.get_file_as_string(
		"res://scripts/services/inventory_service.gd"
	)

	_check(ResourceLoader.exists("res://scenes/world/interactables/overworld_item.tscn"), "overworld item scene exists")
	_check(item_scene_source.contains("Object ball.png"), "overworld item uses the reusable Poké Ball asset")
	_check(FileAccess.file_exists(MACHINE_BALL_PATH), "TM and HM pickups have a gold Poké Ball asset")
	_check(item_script_source.contains('begins_with("tm-")') and item_script_source.contains('begins_with("hm-")'), "TM and HM pickups select the gold Poké Ball automatically")
	_check_machine_ball_geometry()
	_check_viridian_earthquake_teaser()
	_check(item_script_source.contains("@export var pickup_id"), "overworld items expose a persistent pickup id")
	_check(item_script_source.contains("claim_world_pickup(pickup_id)"), "overworld item claims through the inventory service")
	_check(item_script_source.contains("set_claimed(true)"), "collected overworld items are hidden")
	_check(item_script_source.contains("world_pickup_state_changed.connect"), "exclusive pickup choices hide their counterpart immediately")
	_check(inventory_source.contains('const WORLD_PICKUPS_ENDPOINT := "/game/world-pickups"'), "inventory service loads collected pickups")
	_check(inventory_source.contains("func claim_world_pickup"), "inventory service exposes world pickup claims")
	_check(inventory_source.contains('body.get("collectedPickupIds"'), "inventory service applies every collected id from exclusive choices")

	_check(ResourceLoader.exists("res://scenes/world/interactables/strength_boulder.tscn"), "Strength boulder scene exists")
	_check(boulder_scene_source.contains("Object boulder.png"), "Strength boulder uses the official boulder sheet")
	_check(boulder_scene_source.contains('"name": &"push"'), "Strength boulder has a push animation")
	_check(boulder_script_source.contains('can_use_field_move("strength")'), "Strength boulder validates the field move")
	_check(boulder_script_source.contains('player.call("can_move_to", destination)'), "Strength boulder validates its destination")
	_check(boulder_script_source.contains('push_direction * TILE_SIZE'), "Strength boulder moves exactly one tile")

	quit(1 if failed else 0)


func _check_machine_ball_geometry() -> void:
	var regular_image := _load_png(REGULAR_BALL_PATH)
	var machine_image := _load_png(MACHINE_BALL_PATH)
	_check(not regular_image.is_empty() and not machine_image.is_empty(), "overworld Poké Ball images can be read")
	if regular_image.is_empty() or machine_image.is_empty():
		return
	_check(machine_image.get_size() == regular_image.get_size(), "gold Poké Ball preserves the original sheet size")
	if machine_image.get_size() != regular_image.get_size():
		return
	var changed_color := false
	var alpha_matches := true
	for y in range(regular_image.get_height()):
		for x in range(regular_image.get_width()):
			var regular_pixel := regular_image.get_pixel(x, y)
			var machine_pixel := machine_image.get_pixel(x, y)
			if not is_equal_approx(regular_pixel.a, machine_pixel.a):
				alpha_matches = false
			if regular_pixel != machine_pixel:
				changed_color = true
	_check(alpha_matches, "gold Poké Ball preserves every transparent pixel")
	_check(changed_color, "gold Poké Ball uses a distinct color palette")


func _check_viridian_earthquake_teaser() -> void:
	var city_source := FileAccess.get_file_as_string(VIRIDIAN_CITY_PATH)
	_check(not city_source.is_empty(), "Viridian City scene can be read for the Earthquake teaser check")
	_check(city_source.contains('path="%s" id="44_machine_ball"' % MACHINE_BALL_PATH), "Viridian TM Earthquake teaser uses the gold Poké Ball")
	_check(city_source.contains('[node name="RocketGruntRook"') and city_source.contains("position = Vector2(1728, 832)"), "Rook remains at the expected Viridian City tile")
	var teaser_start := city_source.find('[node name="TMEarthquakeTeaser"')
	var teaser_end := city_source.find("\n[node ", teaser_start + 1)
	var teaser_source := city_source.substr(teaser_start, teaser_end - teaser_start) if teaser_start >= 0 and teaser_end > teaser_start else ""
	_check(teaser_source.contains('type="Sprite2D"'), "Viridian City contains the decorative TM Earthquake teaser")
	_check(teaser_source.contains("position = Vector2(1728, 800)"), "TM Earthquake teaser is one tile north of Rook")
	_check(teaser_source.contains('metadata/item_id = "tm-earthquake"'), "Viridian teaser represents TM Earthquake")
	_check(teaser_source.contains("metadata/decorative_only = true"), "Viridian TM Earthquake teaser is explicitly decorative")
	_check(not teaser_source.contains("InteractionArea") and not teaser_source.contains("pickup_id"), "Viridian TM Earthquake teaser cannot be interacted with or picked up")


func _load_png(path: String) -> Image:
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return Image.new()
	return image


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
