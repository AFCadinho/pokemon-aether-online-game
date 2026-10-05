extends SceneTree

const Catalog := preload("res://scripts/battle/battle_environment_catalog.gd")
const Resolver := preload("res://scripts/battle/battle_environment_resolver.gd")
const DayNight := preload("res://scripts/world/day_night_controller.gd")
const VIDEO := "res://assets/video/battle/grass_meadow.ogv"
const GRASS_IDS := ["grass", "pallet_town", "viridian_city", "pewter_city", "cerulean_city", "route_1", "route_2", "route_3", "route_4", "route_22", "route_24", "route_25"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var animated := Catalog.get_profile(&"grass").get_2d_profile(true)
	assert(animated.is_valid() and animated.background_video is VideoStreamTheora)
	assert(animated.background_texture.get_size() == Vector2(1920, 1080))
	var file := FileAccess.open(VIDEO, FileAccess.READ)
	assert(file != null and file.get_length() <= 12 * 1024 * 1024, "1080p grass video stays within its 12 MiB budget")
	for id: String in GRASS_IDS:
		var location := Catalog.get_profile(StringName(id))
		assert(location.get_2d_profile(true) == animated, "%s wild battles share animated grass" % id)
		assert(location.get_2d_profile(false) == location, "%s trainers retain their art" % id)
		assert(location.platform_texture != animated.platform_texture, "wild meadow has its own platform art")
	for id: StringName in Catalog.PROFILES:
		if str(id) not in GRASS_IDS:
			var location := Catalog.get_profile(id)
			assert(location.get_2d_profile(true) == location, "%s keeps its own background" % id)
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_22"}) == &"route_22")
	assert(Resolver.resolve({"battle_kind": "wild", "map_id": "kanto_route_22", "encounter_type": "surf"}) == &"route_22_water")
	assert(Resolver.resolve({"battle_kind": "wild", "map_environment_id": "cave"}) == &"cave")
	var settings := root.get_node("SettingsManager")
	var world_time := root.get_node("WorldTimeService")
	world_time.set_debug_time(12)
	settings.battle_presentation_mode = "2d"
	root.size = Vector2i(1400, 800)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	battle.battle_type = battle.BattleType.WILD
	battle._apply_battle_environment(&"route_22")
	assert(battle.active_battle_environment_id == &"route_22", "2D override preserves encounter location")
	assert(battle.animation_router.model_presenter.environment_id == &"route_22", "3D retains route context")
	var player: VideoStreamPlayer = battle.battle_background_video
	assert(player.stream == animated.background_video and player.visible)
	assert(battle.battle_background.texture == animated.background_texture)
	assert(battle.player_battle_platform.get_platform_texture() == animated.platform_texture)
	assert(battle.enemy_battle_platform.get_platform_texture() == animated.platform_texture)
	assert(battle.battle_background.self_modulate == Color.WHITE, "day retains original background colors")
	assert(player.material is ShaderMaterial and player.material == battle.battle_background.material, "video and fallback share the sky effect")
	assert(is_zero_approx(player.material.get_shader_parameter("night_amount")), "daytime sky stays unchanged")
	var hud_color: Color = battle.player_hud_panel.modulate
	var sprite_color: Color = battle.player_sprite_box.modulate
	for hour in [6, 19, 23]:
		world_time.set_debug_time(hour)
		var expected := DayNight.color_for_seconds(hour * 3600.0)
		assert(battle.battle_background.self_modulate.is_equal_approx(expected), "fallback follows outdoor time")
		assert(player.self_modulate.is_equal_approx(expected), "video follows outdoor time")
		assert(is_equal_approx(player.material.get_shader_parameter("night_amount"), DayNight.night_intensity_for_seconds(hour * 3600.0)), "sky follows the same clock")
	assert(battle.player_hud_panel.modulate == hud_color and battle.player_sprite_box.modulate == sprite_color, "background lighting preserves HUD and sprite readability")
	battle.weather_presentation.update_weather("raindance")
	assert(player.self_modulate == DayNight.NIGHT_COLOR and player.modulate != Color.WHITE, "weather and night lighting compose")
	battle.weather_presentation.update_weather("")
	assert(player.modulate == Color.WHITE and player.self_modulate == DayNight.NIGHT_COLOR, "clearing weather retains nighttime")
	# Clock progression between synchronization signals must also refresh lighting.
	world_time._debug_seconds_since_midnight = 12 * 3600
	await create_timer(1.1).timeout
	assert(player.self_modulate == Color.WHITE, "ongoing battle polls clock progression")
	world_time.set_debug_time(23)
	await create_timer(0.3).timeout
	assert(player.is_playing() and player.stream_position > 0.0)
	assert(player.get_video_texture().get_size() == Vector2(1920, 1080))
	battle.hide()
	battle._sync_battle_background_video()
	assert(player.paused, "hidden/prewarmed battles do not decode video")
	battle.show()
	battle._sync_battle_background_video()
	assert(not player.paused)
	# A visible full 3D arena covers the video; 2.5D still needs the 2D art.
	var original_presenter = battle.animation_router.model_presenter
	var presenter := Control.new()
	root.add_child(presenter)
	battle.animation_router.model_presenter = presenter
	settings.battle_presentation_mode = "3d"
	battle._sync_battle_background_video()
	assert(player.paused and not player.visible)
	settings.battle_presentation_mode = "2.5d"
	battle._sync_battle_background_video()
	assert(not player.paused and player.visible)
	battle.animation_router.model_presenter = original_presenter
	presenter.free()
	settings.battle_presentation_mode = "2d"
	var loops := [0]
	player.finished.connect(func(): loops[0] += 1)
	await create_timer(19.5).timeout
	assert(loops[0] >= 1 and player.is_playing(), "grass video restarts after its complete loop")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		battle.player_sprite_box.set_single_pokemon_species("pikachu", "back", false)
		battle.enemy_sprite_box.set_single_pokemon_species("rattata", "front", false)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(args[0]) == OK)
	battle.battle_type = battle.BattleType.TRAINER
	battle._apply_battle_environment(&"route_22")
	assert(player.stream == null and not player.visible and not player.is_playing())
	assert(battle.battle_background.texture == Catalog.get_profile(&"route_22").background_texture)
	assert(battle.player_battle_platform.get_platform_texture() == Catalog.get_profile(&"route_22").platform_texture)
	assert(player.self_modulate == Color.WHITE and battle.battle_background.self_modulate == Color.WHITE, "other backgrounds reset the meadow tint")
	assert(player.material == null and battle.battle_background.material == null, "other backgrounds release the meadow sky effect")
	battle.battle_type = battle.BattleType.WILD
	battle._apply_battle_environment(&"route_22_water")
	assert(player.stream == null and not player.visible)
	battle._apply_battle_environment(&"pvp_stadium")
	assert(player.stream == Catalog.get_profile(&"pvp_stadium").background_video and player.is_playing())
	world_time.set_debug_time(6)
	assert(player.self_modulate == Color.WHITE, "stadium keeps its own lighting")
	world_time.clear_debug_time()
	battle.queue_free()
	await process_frame
	print("animated_grass_background_check: PASS (selection, decode, looping, visibility, environment switches)")
	quit(0)
