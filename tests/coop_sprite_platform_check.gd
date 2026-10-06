extends SceneTree
## Export-only check: real co-op scene, real HTTP downloads and native textures.
## The fixture server supplies local sprite packs, delaying the second Pokémon.

var failures := 0
var cases: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(OS.has_feature("mobile") or OS.has_feature("web"), "test runs in an exported Android/browser runtime")
	SettingsManager.battle_presentation_mode = "2d"
	SettingsManager.battle_ui_layout = "immersive"
	CoopService.set_process(false)
	CoopService.reset()
	var species := ["Pikachu", "Bulbasaur", "Geodude", "Golbat", "Pidgey", "Charmander", "Rattata", "Squirtle"]
	var icons := {"normal": {}, "shiny": {}}
	for name: String in species:
		for style: String in ["normal", "shiny"]:
			icons[style][name.to_lower()] = "home-icons/%s/%s.png" % [style, name.to_lower()]
	WebHomeIconService._catalog = icons
	for fixture: Dictionary in [
		{"kind": "wild", "species": ["Pikachu", "Bulbasaur", "Geodude", "Golbat"]},
		{"kind": "trainer", "species": ["Pidgey", "Charmander", "Rattata", "Squirtle"]},
	]:
		await _run_case(fixture)
	var file := FileAccess.open("user://coop-sprite-platform-details.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform": OS.get_name(), "mobile": OS.has_feature("mobile"),
		"failures": failures, "cases": cases}))
	print("coop_sprite_platform_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _run_case(fixture: Dictionary) -> void:
	var names: Array = fixture.species
	var kind: String = fixture.kind
	# The two leads are genuinely downloaded before mounting. Their partners
	# are intentionally cold, exactly reproducing the mixed initial display.
	for entry: Array in [[names[0], "back"], [names[2], "front"]]:
		var result: Dictionary = await WebPokemonSpriteService.load_frames(entry[0], entry[1])
		_check(result.get("frames") != null, kind + " warm lead download succeeds")
	for name: String in [names[1], names[3]]:
		await WebHomeIconService.load_icon(name, true)
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	_check(battle.setup_coop_battle(), kind + " mounts the real double battle scene")
	_check(battle.player_sprite_box.web_sprite_upgrades_allowed
		and battle.enemy_sprite_box.web_sprite_upgrades_allowed,
		kind + " actual platform enables sprite upgrades on both sides")
	battle.battle_type = battle.BattleType.WILD if kind == "wild" else battle.BattleType.TRAINER
	var snapshot := {"turn": 1, "participant": "p1", "opponentPartySize": 2,
		"ownTeam": [{"slot": 1, "species": names[0], "active": true, "level": 12, "hp": 30, "maxHp": 40}],
		"partnerTeam": [{"slot": 1, "species": names[1], "active": true, "shiny": true, "level": 12, "hp": 30, "maxHp": 40}],
		"positions": []}
	for index in 4:
		snapshot.positions.append({"controller": ["p1", "p3", "p2", "p4"][index],
			"details": "%s, L12, M%s" % [names[index], ", shiny" if index % 2 else ""], "hpPercent": 75})
	battle.coop_presenter._apply_native_positions(snapshot)
	var sprites: Array = [battle.player_sprite_box.double_sprite_1, battle.player_sprite_box.double_sprite_2,
		battle.enemy_sprite_box.double_sprite_1, battle.enemy_sprite_box.double_sprite_2]
	for index in 4:
		_check(bool(sprites[index].sprite_frames.get_meta("home_fallback", false)) == (index % 2 == 1),
			"%s initial position %d has the expected warm/cold sprite" % [kind, index])
	var player_generation: int = battle.player_sprite_box.web_sprite_request_generation
	var enemy_generation: int = battle.enemy_sprite_box.web_sprite_request_generation
	host.request_reveal()
	await host.wait_until_revealed()
	await _capture(kind + "-before")
	_check(not WebPokemonSpriteService._in_flight.is_empty(), kind + " second Pokémon downloads remain pending after reveal")
	battle.coop_presenter._apply_native_positions(snapshot)
	_check(battle.player_sprite_box.web_sprite_request_generation == player_generation
		and battle.enemy_sprite_box.web_sprite_request_generation == enemy_generation,
		kind + " repeated snapshot preserves pending downloads")
	var deadline := Time.get_ticks_msec() + 20000
	while sprites.any(func(sprite: AnimatedSprite2D) -> bool: return bool(sprite.sprite_frames.get_meta("home_fallback", false))) and Time.get_ticks_msec() < deadline:
		await process_frame
	var frame_counts: Array[int] = []
	var starts: Array[Vector2] = []
	for sprite: AnimatedSprite2D in sprites:
		var count := sprite.sprite_frames.get_frame_count("idle")
		frame_counts.append(count)
		starts.append(Vector2(sprite.frame, sprite.frame_progress))
		_check(sprite.is_visible_in_tree() and sprite.is_playing() and count > 1
			and not bool(sprite.sprite_frames.get_meta("home_fallback", false)),
			kind + " all four Pokémon have playing downloaded battle sprites")
	await create_timer(0.35).timeout
	for index in 4:
		_check(Vector2(sprites[index].frame, sprites[index].frame_progress) != starts[index],
			"%s position %d advances its animation" % [kind, index])
	await _capture(kind + "-after")
	cases.append({"kind": kind, "species": names, "frameCounts": frame_counts,
		"pendingAfterReveal": true, "playerUpgradeEnabled": battle.player_sprite_box.web_sprite_upgrades_allowed,
		"enemyUpgradeEnabled": battle.enemy_sprite_box.web_sprite_upgrades_allowed})
	host.release()
	host.queue_free()
	await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("user://coop-sprites-%s.png" % label) == OK,
		label + " captures the rendered native frame")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COOP_SPRITE_PLATFORM_QA: " + message)
