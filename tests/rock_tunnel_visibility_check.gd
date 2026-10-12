extends SceneTree

const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")
const DayNightScript := preload("res://scripts/world/day_night_controller.gd")
const FlashScene := preload("res://scenes/world/lighting/field_move_flash_light.tscn")
const VisibilityScene := preload("res://scenes/world/lighting/cave_visibility_controller.tscn")
const FLOOR_SCENES := [
	"res://scenes/overworld/kanto/caves/rock_tunnel/1f.tscn",
	"res://scenes/overworld/kanto/caves/rock_tunnel/b1f.tscn",
]

var failed := false
var host: Node2D
var player: Node2D
var flash: OverworldFieldMoveFlashLight
var lighting: OverworldDayNightController
var visibility: OverworldCaveVisibilityController
var modulator: CanvasModulate
var viewport: SubViewport
var ui_base_layer: int


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	host = Node2D.new()
	host.add_to_group("world")
	modulator = CanvasModulate.new()
	modulator.name = "WorldCanvasModulate"
	host.add_child(modulator)
	lighting = DayNightScript.new()
	lighting.name = "DayNightController"
	lighting.canvas_modulate_path = NodePath("../WorldCanvasModulate")
	host.add_child(lighting)
	player = Node2D.new()
	player.name = "Player"
	player.position = Vector2(160.0, 128.0)
	flash = FlashScene.instantiate()
	player.add_child(flash)
	host.add_child(player)
	visibility = VisibilityScene.instantiate()
	host.add_child(visibility)
	viewport.add_child(host)
	await process_frame
	# UI scripts depend on autoloads, which are ready after test initialization.
	var overlay_script := load("res://scripts/ui/ui_overlay.gd")
	ui_base_layer = int(overlay_script.UI_OVERLAY_BASE_LAYER)

	var floors: Array[Node] = []
	for path: String in FLOOR_SCENES:
		# Read the real maps' root metadata without starting NPC/API activity.
		var state := (load(path) as PackedScene).get_state()
		var floor_map: Node = MapMetadataScript.new()
		for property_index in state.get_node_property_count(0):
			var property_name := state.get_node_property_name(0, property_index)
			if property_name in ["lighting_profile", "cave_visibility_group_id", "cave_visibility_radius", "cave_visibility_feather"]:
				floor_map.set(property_name, state.get_node_property_value(0, property_index))
		floors.append(floor_map)
		_check(floor_map.get("cave_visibility_group_id") == "kanto_rock_tunnel", "%s belongs to the Rock Tunnel visibility group" % path)

	var outside: Node = MapMetadataScript.new()
	outside.set("lighting_profile", "indoor")
	lighting.apply_map(outside)
	_check(not visibility.apply_map(outside), "ordinary interiors have no cave hint")
	_check(not visibility.darkness_mask.visible, "ordinary interiors have no sight mask")
	flash.set_darkness_intensity(1.0)
	_check(bool(flash.activate().get("success")), "outdoor Flash can be active before entering")
	lighting.apply_map(floors[0])
	_check(visibility.apply_map(floors[0]), "first cave entry requests one hint")
	_check(not flash.active and visibility.darkness_mask.visible, "entering the cave requires a fresh Flash activation")
	_check(is_equal_approx(visibility.sight_radius, 96.0), "unlit vision covers a three-tile radius")
	_check(visibility.darkness_mask.mouse_filter == Control.MOUSE_FILTER_IGNORE, "sight mask does not intercept input")
	_check(visibility.layer > 0 and visibility.layer < ui_base_layer, "mask covers world actors beneath the interface")
	_check(not visibility.apply_map(floors[1]), "unlit floor changes do not repeat the hint")
	_check(not flash.active and visibility.darkness_mask.visible, "unlit floor changes stay dark")
	lighting.set_creator_lighting_override(12.0, 1.4)
	_check(visibility.darkness_mask.visible and flash.can_activate(), "creator daylight does not bypass cave sight or prevent Flash")
	lighting.clear_creator_lighting_override()
	_check_mask_transform()
	if "--render-check" in OS.get_cmdline_user_args():
		await _check_rendered_mask()

	_check(bool(flash.activate().get("success")), "Flash activates inside Rock Tunnel")
	visibility._reveal_tween.pause()
	visibility._reveal_tween.custom_step(0.12)
	_check(visibility.reveal_progress > 0.0 and visibility.reveal_progress < 1.0, "Flash gradually expands visibility")
	visibility._reveal_tween.custom_step(0.6)
	_check(flash.active and not visibility.darkness_mask.visible, "Flash restores full visibility")
	_check(modulator.color.is_equal_approx(Color.WHITE), "Flash restores normal interior lighting")
	_check(not flash.point_light.enabled, "fully lit caves do not add an outdoor light halo")

	# Exercise the same removal/reparenting used by world map transitions.
	host.remove_child(player)
	lighting.apply_map(floors[1])
	_check(not visibility.apply_map(floors[1]), "lit floor change does not request another hint")
	var new_floor_container := Node2D.new()
	host.add_child(new_floor_container)
	new_floor_container.add_child(player)
	await process_frame
	_check(flash.active and not visibility.darkness_mask.visible, "Flash survives player reparenting between floors")
	_check(modulator.color.is_equal_approx(Color.WHITE), "both floors remain fully lit")
	_check(lighting.lighting_changed.is_connected(flash._on_lighting_changed), "Flash reconnects to lighting after a map swap")
	var world: Node = load("res://scripts/world/world.gd").new()
	world.set("field_move_flash_light", flash)
	world.set("is_in_battle", true)
	var battle_result: Dictionary = world.call("use_direct_field_move", "flash", {})
	_check(not bool(battle_result.get("success")) and flash.active, "battle Flash requests are rejected without losing the active cave light")
	world.set("is_in_battle", false)
	world.set("is_loading_map", true)
	var loading_result: Dictionary = world.call("use_direct_field_move", "flash", {})
	_check(not bool(loading_result.get("success")) and flash.active, "map-loading requests preserve the existing cave light")
	world.set("is_loading_map", false)
	var toggle_result: Dictionary = world.call("use_direct_field_move", "flash", {"itemName": "Flash Charm"})
	_check(bool(toggle_result.get("deactivated")) and not flash.active, "existing world dispatch can toggle cave Flash off")
	var charm_result: Dictionary = world.call("use_direct_field_move", "flash", {"itemName": "Flash Charm"})
	_check(bool(charm_result.get("success")) and flash.active, "existing Charm dispatch activates full cave visibility")
	world.free()

	flash.deactivate()
	await create_timer(0.3).timeout
	_check(visibility.darkness_mask.visible and is_zero_approx(visibility.reveal_progress), "losing a valid Flash source restores restricted vision")
	_check(modulator.color.is_equal_approx(DayNightScript.NIGHT_COLOR), "deactivation restores dark cave lighting")
	flash.activate()
	# Leaving during the reveal must cancel its tween as well as clear Flash.
	lighting.apply_map(outside)
	visibility.apply_map(outside)
	await create_timer(0.6).timeout
	_check(not flash.active and not visibility.darkness_mask.visible, "leaving cancels Flash and removes the cave mask")
	_check(modulator.color.is_equal_approx(Color.WHITE), "leaving restores the destination lighting")
	lighting.apply_map(floors[0])
	_check(visibility.apply_map(floors[0]), "returning to Rock Tunnel requests a new hint")
	_check(not flash.active and visibility.darkness_mask.visible, "returning starts with restricted vision")
	flash.activate()
	var other_cave: Node = MapMetadataScript.new()
	other_cave.set("lighting_profile", "dark")
	other_cave.set("cave_visibility_group_id", "other_cave")
	lighting.apply_map(other_cave)
	visibility.apply_map(other_cave)
	_check(not flash.active, "Flash does not transfer to a different cave group")

	for map_node: Node in floors + [outside, other_cave]:
		map_node.free()
	viewport.queue_free()
	await process_frame
	print("Rock Tunnel visibility checks passed." if not failed else "Rock Tunnel visibility checks failed.")
	quit(1 if failed else 0)


func _check_mask_transform() -> void:
	# Include translation and nonuniform zoom, as well as a camera at a map edge.
	var original := viewport.canvas_transform
	viewport.canvas_transform = Transform2D(Vector2(0.5, 0.0), Vector2(0.0, 0.75), Vector2(17.0, 29.0))
	visibility._update_mask_geometry()
	var material := visibility.mask_material
	var center: Vector2 = material.get_shader_parameter("player_screen_position")
	_check(center.is_equal_approx(viewport.canvas_transform * player.global_position), "mask tracks the actual screen position rather than the screen center")
	var inverse_x: Vector2 = material.get_shader_parameter("world_per_screen_x")
	var inverse_y: Vector2 = material.get_shader_parameter("world_per_screen_y")
	_check(inverse_x.is_equal_approx(Vector2(2.0, 0.0)), "horizontal zoom retains world-distance vision")
	_check(inverse_y.is_equal_approx(Vector2(0.0, 1.0 / 0.75)), "vertical zoom retains world-distance vision")
	viewport.canvas_transform = original
	visibility._update_mask_geometry()


func _check_rendered_mask() -> void:
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2(-2048, -2048), Vector2(2048, -2048), Vector2(2048, 2048), Vector2(-2048, 2048)])
	host.add_child(backdrop)
	var nameplate := Polygon2D.new()
	nameplate.polygon = PackedVector2Array([Vector2(280, 100), Vector2(300, 100), Vector2(300, 120), Vector2(280, 120)])
	nameplate.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	nameplate.color = Color.GREEN
	host.add_child(nameplate)
	var ui := CanvasLayer.new()
	ui.layer = ui_base_layer
	host.add_child(ui)
	var ui_marker := ColorRect.new()
	ui_marker.position = Vector2(8, 8)
	ui_marker.size = Vector2(24, 24)
	ui_marker.color = Color.RED
	ui.add_child(ui_marker)
	for zoom in [1.0, 0.5, 1.5]:
		viewport.canvas_transform = Transform2D(Vector2(zoom, 0), Vector2(0, zoom), Vector2(320, 180) - player.position * zoom)
		visibility._update_mask_geometry()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		_check(image != null and not image.is_empty(), "renderer supplies the cave image")
		if image == null or image.is_empty():
			continue
		_check(image.get_pixel(320, 180).r > 0.1, "player surroundings are visible at zoom %s" % zoom)
		_check(image.get_pixel(320 + int(80 * zoom), 180).r > 0.1, "nearby world stays visible at zoom %s" % zoom)
		_check(image.get_pixel(320 + int(100 * zoom), 180).r < 0.01, "world beyond three tiles is black at zoom %s" % zoom)
		var nameplate_screen := viewport.canvas_transform * Vector2(290, 110)
		_check(image.get_pixelv(Vector2i(nameplate_screen)).g < 0.01, "high-z nameplates outside sight are masked")
		_check(image.get_pixel(12, 12).r > 0.95, "interface remains above darkness")
	flash.activate()
	visibility._reveal_tween.pause()
	visibility._reveal_tween.custom_step(1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var lit_image := viewport.get_texture().get_image()
	_check(lit_image.get_pixel(500, 300).r > 0.95, "Flash reveals and brightens the distant world")
	flash.deactivate()
	visibility._reveal_tween.pause()
	visibility._reveal_tween.custom_step(1.0)
	viewport.canvas_transform = Transform2D.IDENTITY
	backdrop.queue_free()
	nameplate.queue_free()
	ui.queue_free()


func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
