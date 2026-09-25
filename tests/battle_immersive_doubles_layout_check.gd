extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "classic"
	settings.battle_presentation_mode = "2.5d"
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_WILD, true)
	_expect(battle.has_meta("immersive_battle_ui"), "co-op doubles override the Classic single-battle preference")
	_expect(battle.setup_coop_battle(), "immersive doubles setup succeeds")
	var presenter: Control = battle.coop_presenter
	presenter._apply_positions({
		"participant": "p1",
		"turn": 4,
		"opponentPartySize": 2,
		"positions": [
			{"controller": "p1", "details": "Bulbasaur, L50, M", "hpPercent": 77},
			{"controller": "p3", "details": "Squirtle, L50, M", "hpPercent": 100},
			{"controller": "p2", "details": "Furret, L50, M", "hpPercent": 100},
			{"controller": "p4", "details": "Furret, L50, M", "hpPercent": 55},
		],
		"ownTeam": [{"species": "Bulbasaur", "active": true, "hp": 77, "maxHp": 100}],
		"partnerTeam": [{"species": "Squirtle", "active": true, "hp": 100, "maxHp": 100}],
	})
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1024, 768)]:
		host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		host.size = Vector2(dimensions)
		host._fit_battle()
		for frame in 8:
			await process_frame
		_settle_immersive_hud(battle)
		_check_doubles_field_spacing(battle, presenter)
		_check_hud_clearance(battle)
		_check_concrete_anchors(battle, presenter)
		_check_move_animation_endpoints(battle, presenter)
		var output := OS.get_environment("POKEAETHER_DOUBLES_OUTPUT")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("immersive-doubles-%sx%s.png" % [dimensions.x, dimensions.y]))
	host.release()
	host.queue_free()
	await process_frame
	if failed:
		quit(1)
	print("IMMERSIVE_DOUBLES_LAYOUT_OK")
	quit()


func _settle_immersive_hud(battle: Control) -> void:
	var hud_script := load("res://scripts/battle/battle_ui/immersive_hud.gd")
	for child: Node in battle.get_children():
		if child.get_script() == hud_script:
			child.call("_process", 1.0)
			return
	_expect(false, "immersive HUD tracker is mounted")


func _check_doubles_field_spacing(battle: Control, presenter: Control) -> void:
	var player_platform: Control = battle.player_battle_platform
	var enemy_platform: Control = battle.enemy_battle_platform
	var player_image := player_platform.get_node("PlatformImage") as TextureRect
	var enemy_image := enemy_platform.get_node("PlatformImage") as TextureRect
	var player_center := player_platform.position.x + player_image.size.x * player_platform.scale.x * 0.5
	var enemy_center := enemy_platform.position.x + enemy_image.size.x * enemy_platform.scale.x * 0.5
	_expect(enemy_center - player_center >= player_image.size.x * player_platform.scale.x * 0.8,
		"the enlarged 2D doubles platforms keep separate visible grass fields")
	_expect(player_platform.scale.x > battle.player_sprite_box.scale.x
		and enemy_platform.scale.x > battle.enemy_sprite_box.scale.x,
		"the doubles platforms widen without shrinking the Pokémon")
	var player_bounds: Rect2 = battle.player_sprite_box.get_double_animation_visual_rect_in_node(battle.battle_stage)
	var enemy_bounds: Rect2 = battle.enemy_sprite_box.get_double_animation_visual_rect_in_node(battle.battle_stage)
	_expect(player_bounds.has_area() and enemy_bounds.has_area() and not player_bounds.intersects(enemy_bounds),
		"the allied and opposing 2D Pokémon remain visually separate")
	for controllers: Array in [["p1", "p3"], ["p2", "p4"]]:
		var platform: Control = player_platform if controllers[0] == "p1" else enemy_platform
		var platform_image: TextureRect = player_image if controllers[0] == "p1" else enemy_image
		var sprite_box: Control = battle.player_sprite_box if controllers[0] == "p1" else battle.enemy_sprite_box
		var grass_top := platform.position.y + platform_image.size.y * platform.scale.y * 0.5
		var first: AnimatedSprite2D = presenter._native_sprite(controllers[0])
		var second: AnimatedSprite2D = presenter._native_sprite(controllers[1])
		_expect(first.global_position.x < second.global_position.x,
			"each 2D doubles pair keeps a stable left-to-right order")
		for sprite: AnimatedSprite2D in [first, second]:
			var visual_rect: Rect2 = sprite_box.call("_get_sprite_visual_rect_global", sprite)
			var inverse: Transform2D = battle.battle_stage.get_global_transform().affine_inverse()
			var feet: float = (inverse * visual_rect.end).y
			_expect(feet >= grass_top - 8.0,
				"each 2D doubles Pokémon reaches the visible grass surface")


func _check_concrete_anchors(battle: Control, presenter: Control) -> void:
	var router: RefCounted = presenter._native_move_router
	var stage: Control = battle.battle_stage
	for actor: String in ["p1", "p3", "p2", "p4"]:
		for target: String in ["p1", "p3", "p2", "p4"]:
			var actor_sprite: AnimatedSprite2D = presenter._native_sprite(actor)
			var target_sprite: AnimatedSprite2D = presenter._native_sprite(target)
			var actor_box: Control = battle.player_sprite_box if actor in ["p1", "p3"] else battle.enemy_sprite_box
			var target_box: Control = battle.player_sprite_box if target in ["p1", "p3"] else battle.enemy_sprite_box
			var aliases: Dictionary = router.call("bind_native_pair", actor, target,
				{actor: actor_sprite, target: target_sprite}, {actor: actor_box, target: target_box})
			_expect(not aliases.is_empty(), "%s to %s binds concrete sprites" % [actor, target])
			if aliases.is_empty():
				continue
			for endpoint: String in [actor, target]:
				var sprite: AnimatedSprite2D = actor_sprite if endpoint == actor else target_sprite
				var box: Control = actor_box if endpoint == actor else target_box
				var alias: String = aliases.actor if endpoint == actor else aliases.target
				var visual_rect: Rect2 = box.call("_get_sprite_visual_rect_global", sprite)
				var inverse := stage.get_global_transform().affine_inverse()
				var rect := Rect2(inverse * visual_rect.position, inverse * visual_rect.end - inverse * visual_rect.position)
				var facing := -1.0 if endpoint in ["p2", "p4"] else 1.0
				var expected := {
					"center": rect.get_center(),
					"feet": Vector2(rect.get_center().x, rect.end.y),
					"mouth": rect.position + rect.size * Vector2(0.5 + facing * 0.38, 0.38),
				}
				for anchor_point: String in expected:
					var actual: Vector2 = router.call("_get_effect_target_anchor_in_parent", alias, stage, anchor_point)
					_expect(actual.distance_to(expected[anchor_point]) <= 1.0,
						"%s %s anchor follows its immersive sprite after resize" % [endpoint, anchor_point])


func _check_move_animation_endpoints(battle: Control, presenter: Control) -> void:
	var router: RefCounted = presenter._native_move_router
	var stage: Control = battle.battle_stage
	var field_animation: Node2D = load("res://scripts/battle/animations/move_animation_player.gd").new()
	field_animation.set_meta("coop_full_field_effect", true)
	router.call("_fit_animation_to_parent", field_animation, stage)
	_expect(field_animation.scale.x >= stage.size.x / 512.0 - 0.001,
		"field-wide effects still fill the doubles battlefield")
	field_animation.free()
	for pair: Array in [["p1", "p4"], ["p3", "p2"], ["p4", "p1"], ["p1", "p3"], ["p4", "p2"]]:
		var actor: String = pair[0]
		var target: String = pair[1]
		var actor_box: Control = battle.player_sprite_box if actor in ["p1", "p3"] else battle.enemy_sprite_box
		var target_box: Control = battle.player_sprite_box if target in ["p1", "p3"] else battle.enemy_sprite_box
		var aliases: Dictionary = router.call("bind_native_pair", actor, target,
			{actor: presenter._native_sprite(actor), target: presenter._native_sprite(target)},
			{actor: actor_box, target: target_box})
		var animation: Node2D = load("res://scripts/battle/animations/move_animation_player.gd").new()
		animation.set("reverse_battlefield", actor in ["p2", "p4"])
		router.call("_fit_animation_to_parent", animation, stage)
		_expect(animation.scale.x <= stage.size.x / 1024.0 + 0.001,
			"doubles move visuals fit one half of the battlefield")
		var sheet_config := {"category": "projectile"}
		if actor == "p3":
			sheet_config["sheet_anchor_source_position"] = [350, 127]
		router.call("_apply_move_sheet_anchor", animation, aliases.actor, aliases.target, stage, sheet_config)
		_expect(bool(animation.get("sheet_path_enabled")), "projectile sheets retarget both endpoints")
		for endpoint: String in ["actor", "target"]:
			var alias: String = aliases[endpoint]
			var anchor: Vector2 = router.call("_get_effect_target_anchor_in_parent", alias, stage)
			var expected := (anchor - animation.position) / animation.scale
			var authored: Vector2 = animation.get("sheet_path_source_actor") if endpoint == "actor" else animation.get("sheet_path_source_target")
			var display: Vector2 = animation.call("_battlefield_position", authored)
			var actual: Vector2 = animation.call("_retarget_sheet_display_position", display)
			_expect(actual.distance_to(expected) < 1.0,
				"%s projectile sheet follows its concrete doubles %s" % [actor, endpoint])
		animation.free()


func _check_hud_clearance(battle: Control) -> void:
	for index in 2:
		var box: Control = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var hud: Control = battle.player_hud_panel if index == 0 else battle.enemy_hud_panel
		var sprite_bounds: Rect2 = box.call("get_double_animation_visual_rect_in_node", battle.battle_stage)
		var hud_bounds := Rect2(hud.position, hud.size * hud.scale)
		_expect(sprite_bounds.has_area(), "immersive doubles exposes a combined sprite boundary")
		_expect(hud_bounds.end.y <= sprite_bounds.position.y - 8.0,
			"immersive doubles HP panel stays clear above both sprites: hud=%s sprites=%s" % [hud_bounds, sprite_bounds])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
