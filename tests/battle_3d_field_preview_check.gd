extends SceneTree
## Actual catalog validation, twelve actors, public roster updates and persistent field sides.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Presentation = preload("res://scripts/battle/battle_side_condition_presentation.gd")
const Conditions = preload("res://scripts/battle/battle_ui/side_conditions_3d.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const FIXTURE := "user://battle-3d-field-preview-check"
const SPECIES := ["Dragonite", "Pikachu", "Garchomp", "Charizard", "Blastoise", "Venusaur"]
var stage: Node
var failed := false
var originals := {}
var original_profile_bounds := {}
var fixture_paths: Array[String] = []

class DownloadProbe extends Node:
	signal finish_download
	var requests: Array = []
	var next_result := {"error": "stale download must be ignored"}
	func ensure_models(needed: Array[String], _path: String) -> Dictionary:
		requests.append(needed.duplicate())
		await finish_download
		return next_result
	func progress_text() -> String: return "Offline fixture"
	func battle_download_progress() -> Dictionary: return {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.size = Vector2i(1920, 1080)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings._manual_model_catalog_this_session = true
	var previous_catalog := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	var catalog := _make_fixture()
	settings.battle_3d_catalog_path = catalog
	OS.set_environment("POKEAETHER_MODEL_CATALOG", catalog)
	stage = Stage.new()
	root.add_child(stage)
	stage.size = Vector2(960, 540)
	var platforms: Array = []
	for side in 2:
		var platform: Node = load("res://scenes/battle/battle_platform.tscn").instantiate()
		platform.platform_side = side
		root.add_child(platform)
		platforms.append(platform)
	stage.setup([], platforms)
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size = Vector2(960, 540)
	var layers: Array = []
	for side in 2:
		var layer := Node2D.new()
		root.add_child(layer)
		layers.append(layer)
	stage.set_team_preview(_team(false), _team(true), layers)
	await stage.await_prepared(true)
	await process_frame
	_check(stage.active and is_instance_valid(stage.preview_visual), "native Team Preview is ready: %s" % stage.reason)
	if not is_instance_valid(stage.preview_visual):
		_cleanup(platforms, layers, previous_catalog)
		return
	_check(stage.preview_visual.slots.size() == 12, "all six normal and six shiny public slots have actors")
	_check(stage.identities.all(func(identity): return identity.is_empty()), "preview does not invent active leads")
	_check(layers.all(func(layer): return not layer.visible), "legacy team sprites are hidden")
	_check(stage._needed_species().size() == 12, "preview demand includes distinct variants, without hidden forms")
	if DisplayServer.get_name() != "headless":
		_check(stage.material_response.copies.size() == 16 and stage.material_response.copies.slice(4).all(func(copy): return is_instance_valid(copy)), "all twelve actors use the existing material lighting pass")
	var occupied := []
	for slot in stage.preview_visual.slots:
		_check(slot.actor.position not in occupied, "preview slots have distinct arena positions")
		occupied.append(slot.actor.position)
		_check(slot.player.is_playing() and slot.player.current_animation == "idle", "preview uses native idle clips")
		_check(slot.actor.scale.x <= 1.65, "large bodies fit their preview slot")
		if slot.side == 0:
			_check(slot.nameplate == null, "local preview models do not receive enemy nameplates")
		else:
			_check(slot.nameplate.get_node("SpeciesName").text == SPECIES[slot.index], "enemy nameplates use the public species name without shiny model suffixes")
			_check(slot.nameplate.is_visible_in_tree() and slot.nameplate.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"enemy nameplates remain readable without intercepting lead selection")
	var plates := []
	for slot in stage.preview_visual.slots:
		if slot.side != 1: continue
		for rect: Rect2 in plates:
			_check(not rect.intersects(slot.nameplate.get_rect()), "projected enemy nameplates do not overlap")
		plates.append(slot.nameplate.get_rect())
	await _check_nameplate_clearance(settings)
	var nameplate_layer: Control = stage.preview_visual.nameplate_layer
	var preview: Node = stage.preview_visual
	stage.set_team_preview(_team(false), _team(true), layers)
	await process_frame
	_check(stage.preview_visual == preview, "repeated roster snapshots preserve animations")
	# Same model identity can arrive with corrected casing/display spelling.
	var renamed_team := _team(true)
	renamed_team[0].displaySpecies = "DRAGONITE"
	renamed_team[0].nickname = "Private nickname must not replace the species"
	stage.set_team_preview(_team(false), renamed_team, layers)
	_check(stage.preview_visual == preview and preview.slots[6].nameplate.get_node("SpeciesName").text == "DRAGONITE",
		"same-model public name updates preserve actors and ignore nicknames")
	stage.set_team_preview(_team(false), _team(true), layers)
	stage.playback_speed = 0.0
	await process_frame
	_check(preview.slots.all(func(slot): return slot.player.speed_scale == 0.0), "replay pause freezes every preview actor")
	stage.playback_speed = 1.0
	await _capture("team")
	settings.battle_presentation_mode = "2d"
	await process_frame
	await process_frame
	_check(not stage.active and layers.all(func(layer): return layer.visible), "2D mode restores populated legacy preview")
	_check(not is_instance_valid(nameplate_layer) or not nameplate_layer.visible, "leaving native 3D hides enemy nameplates")
	settings.battle_presentation_mode = "3d"
	stage.set_team_preview(_team(true), _team(false), layers)
	await stage.await_prepared(true)
	await process_frame
	_check(stage.preview_visual.slots[0].identity.ends_with("@shiny"), "spectator side swap rebuilds mapped public rosters")
	_check(stage.preview_visual.slots[6].side == 1 and stage.preview_visual.slots[6].nameplate.get_node("SpeciesName").text == SPECIES[0],
		"spectator side changes place nameplates only on the mapped enemy team")
	# Hold catalog/arena readiness to reproduce an interrupted preview import.
	# A preview timeout must not permanently disable the selected lead models.
	stage.set_process(false)
	stage.loaded_path = "!preview-stall-fixture"
	await stage.await_prepared(true, 100)
	_check(not stage.active and not stage.preview_problem.is_empty() and not stage.preparation_failed,
		"a stalled preview falls back without poisoning the complete battle")
	stage.set_process(true)
	nameplate_layer = stage.preview_visual.nameplate_layer
	stage.clear_team_preview()
	_check(stage.preview_visual == null and layers.all(func(layer): return not layer.visible), "lead transition clears preview synchronously")
	_check(not nameplate_layer.visible, "lead transition hides nameplates in the same frame")
	stage.set_combatant(0, "Dragonite")
	stage.set_combatant(1, "Pikachu", true)
	await stage.await_prepared(true)
	await process_frame
	_check(stage.handles("p1") and stage.handles("p2"), "selected leads enter the normal presenter")
	_check(not is_instance_valid(nameplate_layer), "lead transition releases the external nameplate layer")
	_check(stage.packed.size() <= stage._needed_species().size(), "preview-only resources leave presenter demand")
	var retained: Array = stage.actors.duplicate()
	var presentation := Presentation.new()
	presentation.setup(platforms[0], platforms[1], null, null)
	presentation.model_presenter = stage
	var all_effects := [{"effect": "move: Stealth Rock"}, {"effect": "Spikes", "layers": 3},
		{"effect": "Toxic Spikes", "layers": 2}, {"effect": "Sticky Web"},
		{"effect": "Reflect"}, {"effect": "Light Screen"}, {"effect": "Aurora Veil"}]
	presentation.update(all_effects, [{"effect": "Spikes", "layers": 1}], 1)
	await process_frame
	_check(stage.active and stage.actors == retained, "hazards and screens retain both 3D combatants")
	var own: Node = stage.side_condition_visuals[0]
	var enemy: Node = stage.side_condition_visuals[1]
	_check(own.effects.size() == 7 and enemy.effects.size() == 1, "effects belong to the correct field side")
	_check(own.effects.spikes.node.get_child_count() == 18 and own.effects.toxicspikes.node.get_child_count() == 12, "hazard layers change geometry")
	_check(own.position.is_equal_approx(stage._position(0)) and enemy.position.is_equal_approx(stage._position(1)), "hazards use arena surface spawns")
	_check(platforms[0].hazards.visible and platforms[0].spikes_image.self_modulate.a == 0.0, "remembered 2D hazards are visually suppressed")
	var rock: Node = own.effects.stealthrock.node
	presentation.update(all_effects, [{"effect": "Spikes", "layers": 1}], 2)
	_check(stage.side_condition_visuals[0] == own and own.effects.stealthrock.node == rock, "turn snapshots preserve persistent geometry")
	own.set_process(false)
	own._process(1.0)
	stage.playback_speed = 0.0
	var elapsed: float = own.elapsed
	var point: Vector3 = rock.get_child(0).position
	own._process(1.0)
	_check(own.elapsed == elapsed and rock.get_child(0).position == point, "hazard motion honors replay pause")
	stage.playback_speed = 1.0
	await _capture("hazards")
	presentation.update([{ "effect": "Spikes", "layers": 1}], [], 3)
	_check(own.effects.size() == 1 and own.effects.spikes.node.get_child_count() == 6, "layer reductions and hazard removal reconcile")
	_check(stage.side_condition_visuals[1] == null and not enemy.visible, "cleared side hides synchronously")
	stage.double_mode = true
	stage._sync_side_conditions()
	_check(own.radius == 3.5 and own.position.is_equal_approx(stage._position(0).lerp(stage._position(2), 0.5)), "doubles cover the team's two lanes")
	stage._set_active(false)
	_check(stage.side_condition_visuals[0] == null and not own.visible, "fallback stops and hides native field geometry")
	_check(platforms[0].spikes_image.self_modulate.a == 1.0, "fallback restores remembered 2D hazard art")
	stage.double_mode = false
	stage._set_active(true)
	_check(stage.side_condition_visuals[0].effects.spikes.layers == 1, "returning to 3D rebuilds current hazards")
	_check(Conditions.snapshot([{ "effectId": "toxic_spikes", "layers": 9}]).toxicspikes == 2, "hazard layers are bounded")
	stage.set_team_preview([{ "species": "Landorus-Therian"}], [], layers)
	await process_frame
	await process_frame
	_check(not stage.active and layers[0].visible, "unsupported preview keeps a complete 2D fallback")
	_check("landorus-therian" in stage.reason, "the fallback identifies the missing form without using Incarnate Landorus")
	stage.set_process(false)
	stage.loaded_path = "!unsupported-preview-does-not-need-a-catalog"
	await stage.await_prepared(true, 100)
	_check(stage.preview_problem.is_empty() and not stage.preparation_failed and "landorus-therian" in stage.reason,
		"known unsupported previews resolve before waiting for unrelated catalog/arena work")
	stage.set_process(true)
	stage.clear_team_preview()
	await stage.await_prepared(true)
	_check(stage.handles("p1") and stage.handles("p2"), "supported leads also recover after an unsupported roster preview")
	await _check_battle_wiring()
	await _check_late_download(settings)
	_cleanup(platforms, layers, previous_catalog)

func _check_battle_wiring() -> void:
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	var host: Control
	var capture_prefix := OS.get_environment("POKEAETHER_FIELD_PREVIEW_CAPTURE")
	if not capture_prefix.is_empty() and DisplayServer.get_name() != "headless":
		host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		root.add_child(host)
		host.mount(battle, null, WildEncounterTransition.STYLE_WILD, true)
	else:
		root.add_child(battle)
	var own_team := _team(false)
	var enemy_team := _team(true)
	for team in [own_team, enemy_team]:
		for pokemon in team:
			pokemon.active = false
			pokemon.condition = "100/100"
			pokemon.hp = 100
			pokemon.maxHp = 100
			pokemon.level = 100
	battle.battle_state.load_from_api_response({"success": true, "battleId": "offline-3d-preview-wiring",
		"phase": "team_preview", "battleOptions": {"teamPreview": true}, "ownTeam": own_team, "trainerTeam": enemy_team,
		"requests": {"p1": {"teamPreview": true, "side": {"pokemon": own_team}}, "p2": {"teamPreview": true, "side": {"pokemon": enemy_team}}}}, false)
	battle.team_preview_lead_selection_active = true
	battle._show_team_preview_layers()
	var presenter: Node = battle.animation_router.model_presenter
	await presenter.await_prepared(true)
	await process_frame
	_check(is_instance_valid(presenter.preview_visual) and presenter.preview_visual.slots.size() == 12,
		"real Battle controller routes its public rosters to native Team Preview")
	if host != null:
		await host.wait_until_revealed()
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(capture_prefix + "-nameplates.png") == OK, "capture enemy nameplates on the battle screen")
	battle.team_preview_lead_selection_active = false
	await battle._prepare_team_preview_lead_summon_transition()
	battle._show_team_preview_layers()
	_check(presenter.preview_visual == null and not presenter.preview_enabled, "real lead barrier clears native previews and rejects late redraws")
	battle._update_side_condition_ui([{"scope": "side", "effectType": "sideCondition", "side": "p2", "effect": "Spikes", "layers": 2}], 1)
	_check(presenter.side_conditions[0].is_empty() and presenter.side_conditions[1].get("spikes") == 2,
		"real field UI routes presentation effects to their mapped native side")
	if host != null:
		host.release()
		host.queue_free()
	else:
		battle.queue_free()
	await process_frame
	await process_frame

func _check_late_download(settings: Node) -> void:
	var service: Node = root.get_node("OnDemand3DBundleService")
	root.remove_child(service)
	var probe := DownloadProbe.new()
	probe.name = "OnDemand3DBundleService"
	root.add_child(probe)
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = false
	stage.set_team_preview(_team(false), _team(true))
	var deadline := Time.get_ticks_msec() + 3000
	while probe.requests.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	_check(probe.requests.size() == 1 and probe.requests[0].size() == 12, "download requests cover only the public preview variants")
	stage.clear_team_preview()
	probe.finish_download.emit()
	await process_frame
	await process_frame
	_check(not stage.preparation_failed and stage.preview_problem.is_empty() and stage.preview_visual == null, "late download cannot redraw preview or fail selected leads")
	stage.set_team_preview(_team(false), _team(true))
	deadline = Time.get_ticks_msec() + 3000
	while probe.requests.size() < 2 and Time.get_ticks_msec() < deadline: await process_frame
	probe.next_result = {"error": "offline preview model unavailable"}
	probe.finish_download.emit()
	await process_frame
	await process_frame
	_check(not stage.active and not stage.preparation_failed and stage.preview_problem == "offline preview model unavailable", "preview download failures preserve the lead preparation path")
	stage.clear_team_preview()
	probe.free()
	root.add_child(service)
	settings._manual_model_catalog_this_session = true

func _team(shiny: bool) -> Array:
	var result := []
	for species in SPECIES: result.append({"species": species, "shiny": shiny})
	return result

func _check_nameplate_clearance(settings: Node) -> void:
	var original_size: Vector2 = stage.size
	var original_scale: float = settings.ui_scale
	var original_yaw: float = stage.user_camera_yaw
	var original_pitch: float = stage.user_camera_pitch
	for dimensions in [Vector2(960, 540), Vector2(1280, 720), Vector2(640, 360)]:
		stage.size = dimensions
		for angle in [Vector2.ZERO, Vector2(0.35, 0.1), Vector2(-0.35, -0.1)]:
			stage.user_camera_yaw = angle.x
			stage.user_camera_pitch = angle.y
			settings.ui_scale = 125.0 if dimensions.x == 1280 else 100.0
			await process_frame
			await process_frame
			var model_rects: Array[Rect2] = []
			# Independently project each mesh's corners, including its depth.
			for slot in stage.preview_visual.slots:
				for mesh in slot.actor.find_children("*", "MeshInstance3D", true, false):
					if not mesh.is_visible_in_tree(): continue
					var box: AABB = mesh.get_aabb()
					var rect := Rect2()
					for corner in 8:
						var point: Vector3 = mesh.global_transform * box.get_endpoint(corner)
						var projected: Vector2 = stage.camera.unproject_position(point) * stage.size / Vector2(stage.viewport.size)
						rect = Rect2(projected, Vector2.ZERO) if corner == 0 else rect.expand(projected)
					model_rects.append(rect)
				if slot.identity.begins_with("dragonite"):
					# The measured animation reaches beyond this fixture's mesh.
					var envelope := AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 3.0, 1.0))
					var rect := Rect2()
					for corner in 8:
						var point: Vector3 = slot.actor.global_transform * envelope.get_endpoint(corner)
						var projected: Vector2 = stage.camera.unproject_position(point) * stage.size / Vector2(stage.viewport.size)
						rect = Rect2(projected, Vector2.ZERO) if corner == 0 else rect.expand(projected)
					model_rects.append(rect)
			var cards: Array[Rect2] = []
			for slot in stage.preview_visual.slots:
				if slot.side != 1: continue
				_check(slot.nameplate.visible, "all six names remain visible at supported preview sizes and camera angles")
				var rect: Rect2 = slot.nameplate.get_rect()
				_check(not model_rects.any(func(model: Rect2): return model.intersects(rect)), "names do not cover either team's models")
				_check(not cards.any(func(other: Rect2): return other.intersects(rect)), "names remain separated while orbiting and resizing")
				cards.append(rect)
	stage.size = original_size
	stage.user_camera_yaw = original_yaw
	stage.user_camera_pitch = original_pitch
	settings.ui_scale = original_scale
	await process_frame
	await process_frame

func _make_fixture() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var entries := []
	var models: Dictionary = Registry.DATA.data.models
	for species in SPECIES:
		for shiny in [false, true]:
			var identity := Registry.key(species, shiny)
			var actor := Node3D.new()
			actor.name = "FixtureActor"
			# Exercise compiled two-pass lighting on the rendered run. The dummy
			# headless renderer has no instance shader-parameter implementation.
			if DisplayServer.get_name() != "headless": actor.set_meta("pokeaether_material_response", 1)
			var mesh := MeshInstance3D.new()
			var shape := CapsuleMesh.new()
			shape.height = 2.0 if species != "Venusaur" else 7.0
			shape.radius = 0.4 if species != "Venusaur" else 2.0
			mesh.mesh = shape
			if species == "Charizard": mesh.scale = Vector3(3.0, 0.45, 5.0)
			mesh.position.y = shape.height * 0.5
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("71d9cd") if shiny else Color("ecb86c")
			var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			image.fill(material.albedo_color)
			var texture := ImageTexture.create_from_image(image)
			material.set_meta("pokeaether_material_response", {"schema": 1, "endpoint_0": texture, "endpoint_1": texture, "specular": 0.1})
			shape.material = material
			actor.add_child(mesh)
			mesh.owner = actor
			var player := AnimationPlayer.new()
			actor.add_child(player)
			player.owner = actor
			var library := AnimationLibrary.new()
			var profile: Dictionary = Registry.DATA.data.profiles[models[identity].profile]
			var profile_key: String = models[identity].profile
			if not original_profile_bounds.has(profile_key):
				original_profile_bounds[profile_key] = {"present": profile.has("bounds"), "value": profile.get("bounds", {}).duplicate(true)}
			# These synthetic meshes must not inherit real Pokémon pose envelopes.
			profile.bounds = {"idle": {"min": [-0.5, 0.0, -0.5], "size": [1.0, 3.0, 1.0]}} if species == "Dragonite" else {}
			for action: String in profile.action_timing:
				var animation := Animation.new()
				animation.length = float(profile.action_timing[action].frames) / 60.0
				library.add_animation(action, animation)
			player.add_animation_library("", library)
			var packed := PackedScene.new()
			var path := ProjectSettings.globalize_path(FIXTURE.path_join(identity + ".scn"))
			_check(packed.pack(actor) == OK and ResourceSaver.save(packed, path) == OK, "save animated fixture")
			actor.free()
			fixture_paths.append(path)
			var digest := FileAccess.get_sha256(path)
			originals[identity] = models[identity].duplicate(true)
			models[identity].sha256 = digest
			models[identity].previous_sha256 = []
			entries.append({"species": species, "variant": "shiny" if shiny else "normal", "runtime_schema": 1,
				"runtime_path": path, "runtime_sha256": digest, "bytes": FileAccess.get_file_as_bytes(path).size()})
	var catalog := ProjectSettings.globalize_path(FIXTURE.path_join("catalog.json"))
	var file := FileAccess.open(catalog, FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	fixture_paths.append(catalog)
	return catalog

func _capture(label: String) -> void:
	var prefix := OS.get_environment("POKEAETHER_FIELD_PREVIEW_CAPTURE")
	if prefix.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(stage.viewport.get_texture().get_image().save_png(prefix + "-" + label + ".png") == OK, "save rendered " + label)

func _cleanup(platforms: Array, layers: Array, previous_catalog: String) -> void:
	stage.free()
	for node in platforms + layers: node.free()
	Cache.clear()
	var models: Dictionary = Registry.DATA.data.models
	for identity in originals: models[identity] = originals[identity]
	for key in original_profile_bounds:
		var profile: Dictionary = Registry.DATA.data.profiles[key]
		if original_profile_bounds[key].present: profile.bounds = original_profile_bounds[key].value
		else: profile.erase("bounds")
	for path in fixture_paths: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	if previous_catalog.is_empty(): OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	else: OS.set_environment("POKEAETHER_MODEL_CATALOG", previous_catalog)
	print("BATTLE_3D_FIELD_PREVIEW_CHECK ", "FAIL" if failed else "PASS", " slots=12 variants=true field_sides=true layers=true pause=true transition=true late_download=true")
	_finish.call_deferred()

func _finish() -> void:
	# Let queued light-pass deletion and cancelled threaded I/O drain before exit.
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
