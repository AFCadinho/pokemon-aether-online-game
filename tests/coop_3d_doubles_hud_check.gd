extends SceneTree
const ArenaCatalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
const ImmersiveHud = preload("res://scripts/battle/battle_ui/immersive_hud.gd")

class PresenterFixture:
	extends Node
	var stage: Control
	var bounds: Dictionary = {}

	func handles(controller: String) -> bool:
		return bounds.has(controller)

	func actor_visual_rect(controller: String) -> Rect2:
		var local_rect: Rect2 = bounds[controller]
		var transform := stage.get_global_transform()
		return Rect2(transform * local_rect.position, transform.basis_xform(local_rect.size))

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_WILD, true)
	assert(battle.setup_coop_battle())
	battle.coop_presenter._native_move_router.call("play_damage_sound")
	assert((battle.coop_presenter._native_move_router.get("sound_stream_cache") as Dictionary).has(
		"res://assets/battles/animations/common/damage/normaldamage.ogg"),
		"Co-op damage must use the regular battle damage sound")
	var snapshot := {"participant": "p1", "turn": 1, "opponentPartySize": 2,
		"field": {"weather": "sandstorm", "terrain": "electricterrain"},
		"positions": [
			{"controller": "p1", "details": "Dragonite, L100, F", "hpPercent": 65, "boosts": {"atk": 1, "spe": 1}},
			{"controller": "p3", "details": "Garchomp, L100, F", "hpPercent": 80},
			{"controller": "p2", "details": "Roaring Moon, L100", "hpPercent": 100},
			{"controller": "p4", "details": "Roaring Moon, L100", "hpPercent": 45}],
		"ownTeam": [{"species": "Dragonite", "active": true, "hp": 130, "maxHp": 200}]}
	battle.coop_presenter._apply_positions(snapshot)
	var stage: Control = battle.battle_stage
	var presenter := PresenterFixture.new()
	presenter.stage = stage
	presenter.bounds = {
		"p1": Rect2(Vector2(250, 400), Vector2(140, 160)),
		"p3": Rect2(Vector2(480, 405), Vector2(140, 160)),
		"p2": Rect2(Vector2(720, 225), Vector2(140, 160)),
		"p4": Rect2(Vector2(970, 230), Vector2(140, 160)),
	}
	stage.add_child(presenter)
	var hud: Node = null
	for child: Node in battle.get_children():
		if child.get_script() == load("res://scripts/battle/battle_ui/immersive_hud.gd"):
			hud = child
			break
	assert(hud != null)
	hud.set_process(false)
	var portraits: Node = null
	for child: Node in battle.get_children():
		if child.get_script() == load("res://scripts/battle/battle_ui/immersive_portraits.gd"):
			portraits = child
			break
	assert(portraits != null)
	var coop_service := root.get_node("CoopService")
	var previous_activity: Dictionary = coop_service.activity.duplicate(true)
	var previous_view: Dictionary = coop_service.view.duplicate(true)
	coop_service.activity["activityId"] = "wild_route_1"
	coop_service.view = snapshot.duplicate(true)
	var appearance: Dictionary = root.get_node("PlayerSave").to_appearance_state()
	battle.coop_presenter._first_trainer.player_appearance_state = appearance
	battle.coop_presenter._second_trainer.player_appearance_state = appearance
	portraits._process(0.0)
	assert(stage.get_node("TrainerPortrait0").visible and stage.get_node("TrainerPortrait2").visible,
		"Both co-op Trainers need portraits in the left corner")
	assert(stage.get_node("TrainerPortrait1").visible and stage.get_node_or_null("TrainerPortrait3") == null,
		"Wild doubles need one shared opponent portrait")
	assert((stage.get_node("TrainerPortrait1").get_child(1) as TextureRect).texture.resource_path ==
		"res://assets/ui/wild_encounter_radar.svg", "Wild portrait must use the generic encounter icon")
	assert(stage.get_node("TrainerPortrait0").position.x < stage.get_node("TrainerPortrait2").position.x,
		"The two party Trainer portraits must stay side by side")
	hud._process(0.016)
	var turn_panel: Control = battle.battle_status_panel
	var reset_camera: Control = stage.get_node("ResetCameraButton")
	assert(turn_panel.position.x > stage.size.x * 0.7 and reset_camera.position.x > stage.size.x * 0.7
		and turn_panel.position.x + turn_panel.size.x * turn_panel.scale.x < stage.get_node("TrainerPortrait1").position.x,
		"3D co-op turn and camera controls must fit beside the right portraits")
	coop_service.activity["activityId"] = "trainer_brock"
	battle.coop_presenter._opponent_trainer.catalog_sprite.texture = load(
		"res://assets/sprites/trainer_cards/showdown/veteran-gen7.png")
	portraits._process(0.0)
	assert(stage.get_node("TrainerPortrait1").visible,
		"Trainer doubles need one opponent Trainer portrait")
	coop_service.activity = previous_activity
	coop_service.view = previous_view
	hud._update_coop_3d_huds(stage, presenter, stage.size, true)
	assert(not battle.player_hud_panel.visible and not battle.enemy_hud_panel.visible)
	assert(battle.field_timers_panel.visible and battle.field_timers_panel.current_effects.size() == 2,
		"Co-op weather and terrain indicators must follow the server snapshot")
	var boost_panel: Control = battle.coop_presenter._stat_overlays.p1
	assert(boost_panel.visible and boost_panel.scale.x < 1.0,
		"3D stat indicators must match the compact HP card scale")
	var rectangles: Array[Rect2] = []
	for controller: String in ["p1", "p3", "p2", "p4"]:
		var card: Control = hud.coop_huds[controller]
		assert(card.visible and card.active_info_rows[0].visible)
		assert(not card.active_info_rows[1].visible)
		for previous: Rect2 in rectangles:
			assert(not previous.intersects(Rect2(card.position, card.size * card.scale)), "Independent HP cards overlap")
		rectangles.append(Rect2(card.position, card.size * card.scale))
	assert(hud.coop_huds.p1.active_info_rows[0].get_meta("battle_hud_data").current_hp == 130)
	assert(hud.coop_huds.p4.active_info_rows[0].get_meta("battle_hud_data").current_hp == 45)
	var damaged_snapshot: Dictionary = snapshot.duplicate(true)
	for position: Dictionary in damaged_snapshot.positions:
		if position.controller == "p4":
			position.hpPercent = 20
	battle.coop_presenter._apply_positions(damaged_snapshot)
	hud._update_coop_3d_huds(stage, presenter, stage.size, true)
	assert(hud.coop_huds.p4.active_info_rows[0].get_meta("battle_hud_data").current_hp == 20)
	assert(hud.coop_huds.p1.active_info_rows[0].get_meta("battle_hud_data").current_hp == 130)
	var model: Node = stage.get_node("ExperimentalBattle3D")
	var pair: Vector3 = model._position(2) - model._position(0)
	var opponent_pair: Vector3 = model._position(3) - model._position(1)
	var view: Vector3 = ArenaCatalog.camera_home(model.arena_id) - ArenaCatalog.camera_target(model.arena_id)
	view.y = 0.0
	view = view.normalized()
	var right := Vector3(view.z, 0.0, -view.x)
	assert(absf(pair.dot(view)) < 0.01 and pair.dot(right) > 4.49,
		"Allies must project side by side in the home camera")
	assert(absf(opponent_pair.dot(view)) < 0.01 and opponent_pair.dot(right) > 4.49,
		"Opponents must project side by side in the home camera")
	var ally_center: Vector3 = (model._position(0) + model._position(2)) * 0.5
	var opponent_center: Vector3 = (model._position(1) + model._position(3)) * 0.5
	assert((ally_center - opponent_center).dot(view) > 5.39,
		"Teams must occupy separate rows along the camera depth")
	var horde_size := Vector2(460, 100)
	var horde_allies: Array[Vector2] = [horde_size]
	var horde_opponents: Array[Vector2] = [horde_size, horde_size, horde_size, horde_size, horde_size]
	var horde_layout: Dictionary = ImmersiveHud.plan_3d_hud_layout(Vector2(1280, 900),
		horde_allies, horde_opponents)
	var player_rect := Rect2(horde_layout["allies"][0], horde_size * float(horde_layout["ally_scale"]))
	assert(player_rect.end.y < 225.0, "Horde player HP card covers the upper battlefield")
	var horde_cards: Array[Rect2] = []
	for position: Vector2 in horde_layout["opponents"]:
		var rect := Rect2(position, horde_size * float(horde_layout["opponent_scale"]))
		assert(player_rect.end.x < rect.position.x, "Horde player HP card must stay left of wild Pokémon")
		assert(rect.end.y < 225.0, "Horde HP card covers the upper battlefield")
		assert(rect.position.x >= 96.0 and rect.end.x <= 1220.0, "Horde HP card leaves the status rail")
		for previous: Rect2 in horde_cards:
			assert(not rect.intersects(previous), "Horde opponents' HP cards overlap")
		horde_cards.append(rect)
	assert(horde_cards.size() == 5, "Horde layout must place five wild Pokémon")
	assert(is_equal_approx(horde_cards[0].position.y, horde_cards[1].position.y)
		and is_equal_approx(horde_cards[1].position.y, horde_cards[2].position.y),
		"First horde row must hold three Pokémon")
	assert(horde_cards[3].position.y > horde_cards[0].end.y
		and is_equal_approx(horde_cards[3].position.y, horde_cards[4].position.y),
		"Second horde row must hold two Pokémon")
	var first_row_center := (horde_cards[0].position.x + horde_cards[2].end.x) * 0.5
	var second_row_center := (horde_cards[3].position.x + horde_cards[4].end.x) * 0.5
	assert(absf(first_row_center - second_row_center) < 1.0, "Horde's second row should be centered")
	var normal_bounds: Dictionary = presenter.bounds.duplicate(true)
	for controller: String in presenter.bounds:
		presenter.bounds[controller] = Rect2(Vector2(560, 300), Vector2(140, 160))
	hud._update_coop_3d_huds(stage, presenter, stage.size, true)
	var crowded: Array[Rect2] = []
	for controller: String in ["p1", "p3", "p2", "p4"]:
		var card: Control = hud.coop_huds[controller]
		var rect := Rect2(card.position, card.size * card.scale)
		for previous: Rect2 in crowded:
			assert(not rect.intersects(previous), "3D health cards overlap after camera alignment")
		crowded.append(rect)
	presenter.bounds = normal_bounds
	hud._update_coop_3d_huds(stage, presenter, stage.size, true)
	var capture_path := OS.get_environment("COOP_3D_HUD_CAPTURE_PATH")
	if not capture_path.is_empty():
		host.set_process(false)
		host.get_node("Cover").hide()
		host.loading_label.get_parent().hide()
		battle.coop_presenter.set_process(false)
		battle.coop_presenter._loading_overlay.hide()
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(capture_path) == OK)
	hud._update_coop_3d_huds(stage, presenter, stage.size, false)
	assert(battle.player_hud_panel.visible and battle.enemy_hud_panel.visible, "2D HUD was not restored")
	assert(boost_panel.scale == Vector2.ONE, "2D stat indicators must keep their original scale")
	var clear_snapshot: Dictionary = snapshot.duplicate(true)
	clear_snapshot.field = {"weather": "", "terrain": ""}
	battle.coop_presenter._apply_native_field(clear_snapshot)
	assert(not battle.field_timers_panel.visible, "Expired co-op weather must clear from the HUD")
	for card: Control in hud.coop_huds.values():
		assert(not card.visible, "3D health card survived the 2D fallback")
	print("COOP_3D_DOUBLES_HUD_OK: four independent cards, 3+2 horde layout, 2D fallback")
	host.release()
	host.free()
	quit()
