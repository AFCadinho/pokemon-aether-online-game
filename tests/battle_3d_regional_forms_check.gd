extends "res://tests/battle_3d_galar_birds_check.gd"
## Exact regional identities, on-demand installation and model swaps; same runtime assertions.
var observed_drawn_frame := -1
var forced_test_frames := 0

func _ensure_test_frame() -> void:
	# Desktop compositors may stop automatic draws for an occluded test window.
	# Draw the actual viewport; never replace the preparation readiness check.
	if DisplayServer.get_name() != "headless" and Engine.get_frames_drawn() == observed_drawn_frame:
		RenderingServer.force_draw(false)
		forced_test_frames += 1
	observed_drawn_frame = Engine.get_frames_drawn()

func _run() -> void:
	process_frame.connect(_ensure_test_frame)
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.always_on_top = true
		root.show()
		root.grab_focus()
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	fixture = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	var count_text := OS.get_environment("POKEAETHER_REGIONAL_EXPECTED_PAIRS")
	var count := 58 if count_text.is_empty() else int(count_text)
	assert(count > 0 and (count_text.is_empty() or count_text.is_valid_int()))
	assert(fixture.models.size() == count * 2)
	var admitted := OS.get_environment("POKEAETHER_REGIONAL_CATALOG_ADMITTED") == "1"
	if admitted:
		for key in fixture.models:
			var registered: Dictionary = Registry.DATA.data.models[key]
			assert(registered.sha256 == fixture.models[key].sha256)
			var expected_profile: Dictionary = fixture.profiles[fixture.models[key].profile].duplicate(true)
			expected_profile.motion.erase("sha256")
			assert(Registry.DATA.data.profiles[registered.profile] == expected_profile)
	else:
		Registry.DATA.data.models.merge(fixture.models, true)
		Registry.DATA.data.profiles.merge(fixture.profiles, true)
	var service := LocalBundles.new()
	service.local_index = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bundles/asset-index.json")))
	assert(service.local_index.assets.size() == count)
	service.local_release = Service.RELEASE_V9.data.duplicate(true)
	service.local_release.requiredAssetIds = []
	for asset in service.local_index.assets:
		service.local_release.requiredAssetIds.append(asset.asset_id)
		service.archives[asset.object_key] = directory.path_join("bundles").path_join(str(asset.object_key).get_file())
		for appearance in asset.appearances:
			assert(service._asset_id(appearance.runtime_identity) == asset.asset_id)
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	service.name = "OnDemand3DBundleService"
	root.add_child(service)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	stage = Renderer.new()
	root.add_child(stage)
	stage.setup()
	var selected := OS.get_environment("POKEAETHER_REGIONAL_RUNTIME_ONLY").split(",", false)
	var checked := 0
	var installed_entries: Array = []
	for asset in service.local_index.assets:
		var species: String = asset.appearances[0].runtime_identity.trim_suffix("@shiny")
		if not selected.is_empty() and species not in selected:
			continue
		stage.set_combatant(0, species, false)
		stage.set_combatant(1, species, true)
		var first_draw := Engine.get_frames_drawn()
		await stage.await_prepared(true, 30000)
		if stage.preparation_failed or not stage.active:
			print("REGIONAL_PREPARATION_DIAGNOSTIC ", {"species": species, "metrics": stage.preparation_metrics,
				"frames_drawn": Engine.get_frames_drawn() - first_draw, "identities": stage.identities,
				"failures": stage.failed_models, "packed": stage.packed.keys(), "pipelines": stage._blocking_pipelines(),
				"loaded_path": stage.loaded_path, "requested_path": settings.get_battle_3d_catalog_path(),
				"arena_preparing": stage.arena_preparing, "pending": stage._models_pending(), "active": stage.active})
		assert(stage.active and not stage.preparation_failed, stage.reason)
		assert(stage.handles("p1") and stage.handles("p2"))
		assert(stage.identities.slice(0, 2) == [species, species + "@shiny"])
		assert(not stage._models_pending())
		for identity in [species, species + "@shiny"]:
			installed_entries.append(stage.entries[identity].duplicate(true))
			assert(stage.packed.has(identity))
			assert(stage.entries[identity].runtime_sha256 == fixture.models[identity].sha256)
			assert(stage.placements[identity].calibrated)
			assert(not stage.motion_clips[identity].is_empty())
			var expected_profile: Dictionary = fixture.profiles[fixture.models[identity].profile]
			assert(stage.entries[identity].action_timing == expected_profile.action_timing)
			assert(stage.motion_clips[identity] == expected_profile.motion.clips)
			assert(is_equal_approx(stage.placements[identity].scale, expected_profile.grounding.scale))
			assert(is_equal_approx(stage.placements[identity].lift, expected_profile.grounding.lift))
		for action in ["idle", "physical_attack", "special_attack", "sleep", "faint_start"]:
			assert(stage.players[0].has_animation(action) and stage.players[1].has_animation(action))
		# Legacy forms hold their final faint frame when no separate loop exists.
		# Check the exact accepted channels, including every optional source clip.
		for side in 2:
			var profile: Dictionary = fixture.profiles[fixture.models[stage.identities[side]].profile]
			for action: String in profile.action_timing:
				assert(stage.players[side].has_animation(action))
			assert(stage.players[side].has_animation("faint_loop") == profile.action_timing.has("faint_loop"))
		var has_second: bool = stage.players[0].has_animation("physical_attack_2")
		assert(stage.attack_action_for("Body Slam", "p1") == ("physical_attack_2" if has_second else "physical_attack"))
		assert(stage.attack_action_for("Dragon Claw", "p1") == "physical_attack")
		var requests := service.requested.size()
		stage.set_combatant(0, species, true)
		stage.set_combatant(1, species, false)
		await process_frame
		await process_frame
		assert(stage.identities.slice(0, 2) == [species + "@shiny", species])
		assert(stage.active and not stage._models_pending() and service.requested.size() == requests)
		if species == "darmanitan-galar":
			# Zen Mode must already be installed and imported before the form event.
			for identity in ["darmanitan-galar-zen", "darmanitan-galar-zen@shiny"]:
				assert(stage.packed.has(identity))
			stage.set_combatant(0, "Darmanitan Galar Zen", true)
			stage.set_combatant(1, "Darmanitan Galar Zen", false)
			for frame in 5:
				await process_frame
			assert(stage.handles("p1") and stage.handles("p2") and not stage._models_pending())
			assert(service.requested.size() == requests, "Zen Mode must not download during transformation")
		checked += 1
		print("REGIONAL_RUNTIME_PAIR_OK ", species)
	assert(service.requested.size() <= count)
	assert(checked == (count if selected.is_empty() else selected.size()))
	if selected.is_empty():
		var requests := service.requested.size()
		for alias in ["Mr. Mime Galar", "mrmime-galar"]:
			stage.set_combatant(0, alias, false)
			stage.set_combatant(1, alias, true)
			await stage.await_prepared(true, 30000)
			assert(stage.active and not stage.preparation_failed)
			for shiny in [false, true]:
				var identity: String = Registry.key(alias, shiny)
				var canonical: String = Registry.key("mr-mime-galar", shiny)
				assert(stage.entries[identity].runtime_sha256 == fixture.models[canonical].sha256)
			assert(service.requested.size() == requests)
		assert(installed_entries.size() == count * 2)
		var catalog_name := "admitted-installed-catalog.json" if admitted else "on-demand-installed-catalog.json"
		var catalog_file := FileAccess.open(directory.path_join(catalog_name), FileAccess.WRITE)
		assert(catalog_file != null)
		catalog_file.store_string(JSON.stringify(installed_entries, "\t") + "\n")
		catalog_file.close()
	stage.queue_free()
	await process_frame
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("REGIONAL_RUNTIME_OK pairs=", checked, " loaded_before_reveal=true exact_shiny=true no_swap_download=true exact_motion=true forced_test_frames=", forced_test_frames)
	quit()
