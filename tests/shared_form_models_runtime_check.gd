extends "battle_3d_alternate_form_check.gd"
## Exercise aliases through the real downloader/catalog/presenter, with local packs.
const Forms = preload("res://scripts/battle/battle_ui/shared_form_models.gd")

func _run() -> void:
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	root.mode = Window.MODE_WINDOWED
	root.always_on_top = true
	root.show()
	root.grab_focus()
	process_frame.connect(func(): RenderingServer.force_draw(false))
	var directory := OS.get_environment("POKEAETHER_SHARED_FORM_WORK")
	assert(directory.is_absolute_path())
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("alias-input.json")))
	var service := LocalBundles.new()
	service.local_index = {"schema":1,"kind":"pokeaether-optional-asset-index","catalog_revision":"shared-forms-local-v1","runtime_contract":{"pokemon_3d":2,"godot":"4.6"},"assets":[]}
	service.local_release = Service.RELEASE_V8.data.duplicate(true)
	service.local_release.revision = service.local_index.catalog_revision
	service.local_release.requiredAssetIds = []
	for row: Dictionary in input.entries:
		assert(FileAccess.get_sha256(row.path) == row.asset.sha256)
		service.local_index.assets.append(row.asset)
		service.local_release.requiredAssetIds.append(row.asset.asset_id)
		service.archives[row.asset.object_key] = row.path
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	PairPilot.catalog()
	PairPilot._catalog = service.local_index
	PairPilot._lookups.clear()
	service.name = "OnDemand3DBundleService"
	root.add_child(service)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = ""
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var output := directory.path_join("alias-runtime")
	DirAccess.make_dir_recursive_absolute(output)
	var records := []
	for row: Dictionary in input.entries:
		var species: String = row.species
		stage = Renderer.new()
		root.add_child(stage)
		stage.setup()
		var record := {"species":species,"asset_sha256":row.asset.sha256,"ratio":row.ratio,"shots":[]}
		for arena: String in ["classic", "stadium"]:
			settings.battle_3d_arena = arena
			stage.set_battle_context(&"", "")
			stage.set_combatant(0, species, false)
			stage.set_combatant(1, species, true)
			await stage.await_prepared(true, 30000)
			assert(stage.active and not stage.preparation_failed, species + ": " + stage.reason)
			assert(stage.identities.slice(0, 2) == [species, species + "@shiny"])
			for side in 2:
				var identity := species + ("@shiny" if side else "")
				var base := str(row.base) + ("@shiny" if side else "")
				var appearance: Dictionary = row.asset.appearances[side]
				assert(appearance.runtime_identity == base)
				assert(stage.entries[identity].runtime_sha256 == appearance.runtime_sha256)
				assert(stage.placements[identity].calibrated)
				var source := Registry.resolve(base, appearance.runtime_sha256)
				assert(is_equal_approx(stage.placements[identity].scale, source.placement.scale * float(row.ratio)))
				assert(stage.players[side].has_animation("sleep"))
			await process_frame
			await process_frame
			var image_path := output.path_join(species + "-" + arena + ".png")
			assert(stage.viewport.get_texture().get_image().save_png(image_path) == OK)
			record.shots.append({"arena":arena,"path":image_path,"sha256":FileAccess.get_sha256(image_path)})
			var requests := service.requested.size()
			stage.set_combatant(0, species, true)
			stage.set_combatant(1, species, false)
			await stage.await_prepared(true, 30000)
			assert(stage.active and service.requested.size() == requests)
		stage.queue_free()
		await process_frame
		records.append(record)
		print("SHARED_FORM_RUNTIME ",species," normal=true shiny=true arenas=2 same_pack=true")
	var report := {"complete":true,"entries":records,"forms":records.size(),"input_sha256":FileAccess.get_sha256(directory.path_join("alias-input.json"))}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	original.free()
	print("SHARED_FORM_RUNTIME_OK forms=", records.size())
	quit()
