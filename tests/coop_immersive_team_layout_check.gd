extends SceneTree
## Shared 2D/3D doubles UI; real 3D arena/camera with local procedural actors.
## No downloaded models, login, battle network or animation timing are exercised.
var minimum_gap := INF
var typography: Node
var capture_host: Control
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings._manual_model_catalog_this_session = true
	settings.battle_animations = false
	settings.ui_scale = 100.0
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	capture_host = host
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(root.content_scale_size)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, true)
	_check(battle.setup_coop_battle(), "co-op scene setup succeeds")
	var model: Node = battle.animation_router.model_presenter
	model.set_process(false)
	for child: Node in battle.get_children():
		if child.get_script() == load("res://scripts/battle/battle_ui/immersive_typography.gd"):
			typography = child
	var panel: Control = battle.coop_presenter
	var appearance: Dictionary = root.get_node("PlayerSave").to_appearance_state()
	var view := {"battleId": "layout-fixture", "revision": 1, "decisionId": "layout-1", "turn": 1,
		"participant": "p1", "locked": true, "partnerReady": false, "ended": false, "eventCursor": 0,
		"events": [], "opponentPartySize": 2, "field": {"weather": "sandstorm", "terrain": "electricterrain"},
		"legalActions": [], "moves": [], "positions": [
			{"controller": "p1", "details": "Dragonite, L100", "hpPercent": 65, "boosts": {"atk": 1, "def": -1}},
			{"controller": "p3", "details": "Garchomp, L100", "hpPercent": 80},
			{"controller": "p2", "details": "Roaring Moon, L100", "hpPercent": 100},
			{"controller": "p4", "details": "Roaring Moon, L100", "hpPercent": 45}],
		"ownTeam": [{"species": "Dragonite", "active": true, "hp": 130, "maxHp": 200}],
		"partnerTeam": [{"species": "Garchomp", "active": true, "hp": 160, "maxHp": 200}]}
	service.apply_state({"party": {"leaderId": 1, "memberIds": [1, 2],
		"memberUsernames": {"1": "adinho", "2": "m1bhompson"},
		"memberAppearances": {"1": appearance, "2": appearance}},
		"activity": {"reservationId": "layout", "battleId": "layout-fixture", "activityId": "wild_route_1",
			"status": "active", "partnerConnected": true}, "view": view})
	service.confirmed_decision_id = "layout-1"
	service.state_changed.emit()
	host.request_reveal()
	for _frame in 30:
		await process_frame
	settings.battle_presentation_mode = "3d"
	model._build_world()
	for controller: String in ["p1", "p3", "p2", "p4"]:
		var index: int = model.actor_index(controller)
		var actor := Node3D.new()
		model.world.add_child(actor)
		actor.position = model._position(index)
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.65
		mesh.height = 2.1
		body.mesh = mesh
		body.position.y = 1.05
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("67e8bf") if index % 2 == 0 else Color("f9a8d4")
		body.material_override = material
		actor.add_child(body)
		model.actors[index] = actor
		model.identities[index] = model._combatant_key(index)
		model.visual_bounds[model.identities[index]] = {"idle": {"min": [-0.65, 0, -0.65], "size": [1.3, 2.1, 1.3]}}
	model._set_active(true)
	model._update_camera(0.0)
	_check(model.active and model.double_mode, "four actors use the actual 3D renderer")
	var hud: Node = battle.get_node("ImmersiveHud")
	var portraits: Node = battle.get_node("ImmersivePortraits")
	var localization: Node = root.get_node("LocalizationManager")
	var resolutions: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	for mode: String in ["3d", "2d"]:
		settings.battle_presentation_mode = mode
		model._set_active(mode == "3d")
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			localization.set_locale(locale)
			for resolution: Vector2i in resolutions:
				root.size = resolution
				root.content_scale_size = resolution
				host.size = Vector2(resolution)
				host._fit_battle()
				await _settle(model, hud, portraits)
				_check_clearance(battle, hud)
				_check(not battle.player_hud_panel.visible and not battle.enemy_hud_panel.visible, "native data-source health panels are hidden")
				_check(hud.coop_huds.values().all(func(card: Control) -> bool: return card.visible), "all four shared HP cards are visible")
				if locale in ["en", "zh_CN"] and resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
					await _capture("%s-%s-%sx%s" % [mode, locale, resolution.x, resolution.y])
			# Include all four public Trainer rows and longer status labels.
			battle.vs_panel_container.show_team_status([
				{"name": "adinho", "local": true, "state": "ready"},
				{"name": "m1bhompson", "state": "disconnected"}],
				[{"name": "Trainer Three", "state": "switching"}, {"name": "Trainer Four", "state": "ready"}])
			await _settle(model, hud, portraits)
			_check_clearance(battle, hud)
	# Also exercise the largest supported text size on a small window.
	service.view.turn = 2
	panel._playing = true
	panel._playback_event = {"kind": "move", "actor": "p1", "move": "Tackle"}
	panel._action_signature = ""
	panel._update_actions()
	settings.ui_scale = 150.0
	host.size = Vector2(960, 540)
	host._fit_battle()
	for mode: String in ["3d", "2d"]:
		settings.battle_presentation_mode = mode
		model._set_active(mode == "3d")
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			localization.set_locale(locale)
			await _settle(model, hud, portraits)
			_check_clearance(battle, hud)
	service.view.turn = 1
	panel._playing = false
	panel._playback_event = {}
	panel._action_signature = ""
	panel._update_actions()
	settings.battle_presentation_mode = "3d"
	model._set_active(true)
	settings.ui_scale = 100.0
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	host.size = Vector2(1920, 1080)
	host._fit_battle()
	localization.set_locale("en")
	service.state_changed.emit()
	await _settle(model, hud, portraits)
	await _capture("3d-preview")
	service.view.turn = 2
	panel._playing = true
	panel._playback_event = {"kind": "move", "actor": "p1", "move": "Tackle"}
	panel._action_signature = ""
	panel._update_actions()
	await _settle(model, hud, portraits)
	_check_clearance(battle, hud)
	_check(hud.coop_huds.p1.get_theme_stylebox("panel") == hud.coop_huds.p1.get_meta("coop_playback_style"), "3D playback highlights the current actor's HP card")
	await _capture("3d-playing")
	service.view.turn = 1
	panel._playing = false
	panel._playback_event = {}
	panel._action_signature = ""
	panel._update_actions()
	await _settle(model, hud, portraits)
	var card_ids: Dictionary = {}
	var card_positions: Dictionary = {}
	for controller: String in hud.coop_huds:
		card_ids[controller] = hud.coop_huds[controller].get_instance_id()
		card_positions[controller] = hud.coop_huds[controller].position
	settings.battle_presentation_mode = "2d"
	model._set_active(false)
	await _settle(model, hud, portraits)
	_check_clearance(battle, hud)
	for controller: String in hud.coop_huds:
		var card: Control = hud.coop_huds[controller]
		_check(card.get_instance_id() == card_ids[controller] and card.position.is_equal_approx(card_positions[controller]), "2D and 3D reuse the same HP cards and arrangement")
		var source: Control = battle.player_hud_panel if controller in ["p1", "p3"] else battle.enemy_hud_panel
		var row: Control = source.active_info_rows[1 if controller in ["p3", "p4"] else 0]
		_check(card.get_meta("coop_source_data") == row.get_meta("battle_hud_data"), "shared card preserves combatant metadata")
	var source_bar: ProgressBar = battle.player_hud_panel.active_info_rows[0].get_node("MarginContainer/VBoxContainer/HPRow/HpBar")
	source_bar.value = 37.0
	hud.layout_now(0.0, true)
	_check(is_equal_approx(hud.coop_huds["p1"].active_info_rows[0].get_node("MarginContainer/VBoxContainer/HPRow/HpBar").value, source_bar.value), "shared 2D HP follows animated source values")
	panel._position_coop_stat_overlays()
	var badge: Control = panel._stat_overlays["p1"]
	var own_card: Control = hud.coop_huds["p1"]
	_check(badge.visible and badge.position.y >= own_card.position.y + own_card.size.y * own_card.scale.y, "stat updates preserve placement below shared HP")
	await _capture("2d-preview")
	battle.player_hud_panel.active_info_rows[1].hide()
	hud.layout_now(0.0, true)
	_check(not hud.coop_huds["p3"].visible, "an absent source row hides the card instead of retaining stale HP")

	print("COOP_IMMERSIVE_TEAM_LAYOUT_", "FAIL" if failed else "OK", " minimum stage-space gap=", snappedf(minimum_gap, 0.01))
	host.release()
	host.queue_free()
	service.reset()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _check_clearance(battle: Control, hud: Node) -> void:
	var stage: Control = battle.battle_stage
	var header: Control = battle.vs_panel_container
	var prompt: Control = battle.get_node("%CurrentActionPanel")
	var message: Label = prompt.message_label
	var prompt_bounds := prompt.get_global_rect()
	var message_bounds := message.get_global_rect()
	_check(message_bounds.position.y >= prompt_bounds.position.y - 0.1 and message_bounds.end.y <= prompt_bounds.end.y + 0.1, "wrapped waiting/playback text fits inside its prompt panel")
	var team_rect := Rect2(header.position, header.size * header.scale)
	_check(team_rect.position.x >= 0 and team_rect.end.x <= stage.size.x, "Team header fits the viewport")
	_check(header.is_visible_in_tree() and header.z_index > battle.animation_router.model_presenter.z_index, "Team status must draw above the 3D render layer")
	_check(battle.battle_status_panel.z_index > battle.animation_router.model_presenter.z_index, "Turn display must draw above 3D")
	_check(stage.get_node("ResetCameraButton").z_index > battle.animation_router.model_presenter.z_index, "Camera button must draw above 3D")
	var reserved: Array[Control] = [battle.field_timers_panel, battle.battle_status_panel, stage.get_node("ResetCameraButton")]
	for portrait: String in ["TrainerPortrait0", "TrainerPortrait1", "TrainerPortrait2"]:
		var control: Control = stage.get_node_or_null(portrait)
		if control != null:
			reserved.append(control)
	for control: Control in reserved:
		if control.visible:
			_check(not team_rect.intersects(Rect2(control.position, control.size * control.scale)), "Team header overlaps " + control.name)
	for card: Control in hud.coop_huds.values():
		var rectangle := Rect2(card.position, card.size * card.scale)
		_check(not team_rect.intersects(rectangle), "Team status overlaps a shared HP HUD")
		minimum_gap = minf(minimum_gap, rectangle.position.y - team_rect.end.y)
		_check(rectangle.position.y - team_rect.end.y >= 11.99, "Shared HP needs a clear gap below team status")
		_check(rectangle.position.x >= 0 and rectangle.end.x <= stage.size.x, "HP card fits the viewport")
		for control: Control in reserved:
			if control.visible:
				_check(not rectangle.intersects(Rect2(control.position, control.size * control.scale)), "HP HUD overlaps " + control.name)

func _capture(name: String) -> void:
	var directory := OS.get_environment("COOP_3D_TEAM_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var transform: Transform2D = root.get_final_transform() * capture_host.get_global_transform_with_canvas()
	var rectangle := Rect2(transform * Vector2.ZERO, transform.basis_xform(capture_host.size))
	var region := Rect2i(rectangle).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_check(region.has_area(), "3D preview viewport is visible")
	_check(image.get_region(region).save_png(directory.path_join(name + ".png")) == OK, "3D preview capture saved")
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _settle(model: Node, hud: Node, portraits: Node) -> void:
	# Force the same pixel-sized typography used after the periodic UI scan.
	# Frame counts alone can finish before that scan on a fast headless runner.
	for _frame in 6:
		portraits._process(0.0)
		hud.layout_now(0.0, true)
		model._sync_render_size()
		typography._process(1.0)
		await process_frame
	hud.layout_now(0.0, true)
