extends SceneTree

const POLICY := preload("res://scripts/services/aether_clash_camera_policy.gd")
const PIXELS := preload("res://scripts/services/pixel_perfect_rendering.gd")
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(3840, 2160), Vector2i(3440, 1440), Vector2i(1280, 1024), Vector2i(720, 1280)]
var failed := false


class TestWorld extends Node2D:
	var is_in_battle := false
	var is_loading_map := false
	func set_creator_remote_players_visible(_value: bool) -> void:
		pass
	func set_creator_nameplates_visible(_value: bool) -> void:
		pass
	func clear_creator_remote_players_visibility_override() -> void:
		pass
	func clear_creator_nameplates_visibility_override() -> void:
		pass


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	var game_state := root.get_node("GameState")
	var save := root.get_node("PlayerSave")
	var original_scale: float = settings.world_pixel_scale
	var original_mode: String = settings.world_pixel_scale_mode
	var original_id: String = str(save.player_id)
	var original_size := root.size
	var original_frame := root.content_scale_size
	var original_aspect := root.content_scale_aspect
	var original_factor := root.content_scale_factor
	var original_scale_mode := root.content_scale_mode
	# Deliberately start with expandable framing to prove the arena owns aspect
	# ratio and restores the previous configuration rather than a hardcoded default.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	save.player_id = "1"
	settings.set_world_pixel_scale(1.5)
	var world := TestWorld.new()
	world.add_to_group("world")
	root.add_child(world)
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var camera := player.get_node("Camera2D") as Camera2D
	var menu = load("res://scenes/interface/settings/settings_menu.tscn").instantiate()
	root.add_child(menu)
	menu.open()
	var dropdown: OptionButton = menu.world_pixel_scale_options_button
	_check(not dropdown.disabled, "Normal world settings allow personal zoom")
	var photo = load("res://scenes/interface/content_creator_photo_mode.tscn").instantiate()
	root.add_child(photo)
	photo.open_photo_mode()
	_check(photo.active, "Photo Mode can open outside the arena")
	var duel = load("res://scenes/overworld/aether_clash/aether_clash_duel.tscn").instantiate()
	world.add_child(duel)
	_check(not POLICY.is_locked(self), "Unconfigured staff preview leaves personal zoom available")
	game_state.current_map = duel
	duel.configure_aether_clash_instance("aether_clash_duel:fixed-view-test")
	duel.arena_state_timer.stop()
	_check(not photo.active, "Entering the arena closes an existing free Photo Mode camera")
	_check(not duel.has_received_arena_state and POLICY.is_locked(self), "Arena view locks before the first server state arrives")
	_check_view(camera, "initial syncing")
	await process_frame
	await process_frame
	_check(dropdown.disabled, "Already-open Settings switches to the locked arena view")
	_check(dropdown.item_count == 1, "Arena Settings shows a fixed-view label instead of a misleading personal zoom")
	var stored_scale: float = settings.world_pixel_scale
	menu._on_world_pixel_scale_selected(0)
	_check(settings.world_pixel_scale == stored_scale, "A stale Settings selection cannot change the saved preference")
	photo.open_photo_mode()
	_check(not photo.active, "Photo Mode cannot open in the arena")
	# Stop the map's per-frame correction: settings and resize must be safe at
	# the point of application, not repaired on a later frame.
	duel.set_process(false)
	for resolution: Vector2i in RESOLUTIONS:
		root.size = resolution
		await process_frame
		await process_frame
		for scale: float in [1.0, 1.5, 2.0]:
			settings.set_world_pixel_scale(scale)
			_check_view(camera, "%s at saved %sx" % [resolution, scale])
		settings.set_world_pixel_scale_auto()
		_check_view(camera, "%s automatic" % resolution)
		var screen_transform := root.get_screen_transform()
		var output_frame := Rect2(screen_transform.origin, Vector2(POLICY.FRAME_SIZE) * screen_transform.get_scale())
		_check(is_equal_approx(output_frame.size.x / output_frame.size.y, 16.0 / 9.0), "%s keeps 16:9 without distortion" % resolution)
		# Godot rounds the bars to whole output pixels (an odd remainder can
		# make opposite bars differ by one pixel).
		_check(output_frame.position.distance_to((Vector2(root.size) - output_frame.size) / 2.0) <= 1.0, "%s centers letterboxing/pillarboxing" % resolution)
	for role: String in ["participant", "spectator"]:
		duel.viewer_role = role
		for phase: String in ["entry_open", "roster_locked", "active", "finishing", "finished"]:
			duel.arena_session = {"status": phase}
			settings.set_world_pixel_scale(1.0)
			player._apply_world_pixel_scale()
			_check_view(camera, "%s / %s without a roster entry" % [role, phase])
	duel.viewer_role = "spectator"
	duel.arena_session = {"status": "active"}
	var orb: Node = duel.get_node("Entities/Interactables/Guild1SpectatorOrb")
	var result: Dictionary = duel.request_spectator_orb(player, orb)
	_check(result.get("success", false), "A spectator can activate the orb")
	var orb_camera := duel.get_node("SpectatorCamera") as Camera2D
	_check(orb_camera.enabled and not camera.enabled, "Only the orb activates the overview camera")
	for resolution: Vector2i in RESOLUTIONS:
		root.size = resolution
		await process_frame
		for zoom: float in [0.7, 0.75, 1.5]:
			duel._set_spectator_zoom(zoom)
			_check((orb_camera.get_viewport_rect().size / orb_camera.zoom).is_equal_approx(Vector2(1920, 1080) / zoom), "%s orb overview is resolution independent at %s" % [resolution, zoom])
	settings.set_world_pixel_scale(1.5)
	_check(root.get_camera_2d() == orb_camera, "Personal settings cannot steal the active orb camera")
	duel._deactivate_spectator_camera()
	_check(camera.enabled and not orb_camera.enabled, "Returning from the orb restores the player camera")
	_check_view(camera, "return to jail")
	duel.viewer_role = "participant"
	_check(not duel.request_spectator_orb(player, orb).get("success", false), "Participants cannot activate the overview")
	game_state.current_map = null
	world.remove_child(duel)
	duel.queue_free()
	await process_frame
	_check(not POLICY.is_locked(self) and not dropdown.disabled, "Leaving the map restores normal Settings")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Leaving restores the previous aspect policy")
	_check(root.content_scale_size == original_frame and root.content_scale_mode == original_scale_mode and root.content_scale_factor == original_factor, "Leaving restores the remaining window framing")
	_check(camera.zoom.is_equal_approx(PIXELS.camera_zoom_for_output_scale(1.5, root.get_screen_transform().get_scale())), "Leaving immediately restores saved personal zoom")
	settings.set_world_pixel_scale(1.0)
	_check(camera.zoom.is_equal_approx(PIXELS.camera_zoom_for_output_scale(1.0, root.get_screen_transform().get_scale())), "Personal settings work again outside the arena")
	photo.open_photo_mode()
	_check(photo.active, "Photo Mode works again after leaving")
	photo.close_photo_mode()
	photo.queue_free()
	menu.queue_free()
	world.queue_free()
	await process_frame
	save.player_id = original_id
	settings.set_world_pixel_scale(original_scale)
	if original_mode == "auto":
		settings.set_world_pixel_scale_auto()
	root.content_scale_aspect = original_aspect
	root.size = original_size
	quit(1 if failed else 0)


func _check_view(camera: Camera2D, context: String) -> void:
	_check((camera.get_viewport_rect().size / camera.zoom).is_equal_approx(POLICY.WORLD_VIEW_SIZE), "Exactly 1280×720 world pixels: %s" % context)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
