extends SceneTree
## Exact Galar bird bundle downloads before reveal and normal/shiny runtime identities.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
var fixture: Dictionary
var stage: Control

class LocalBundles extends Service:
	var local_index: Dictionary
	var local_release: Dictionary
	var archives: Dictionary
	var requested: Array[String] = []
	var ensured: Array = []
	func ensure_models(identities: Array[String], source_catalog: String) -> Dictionary:
		ensured.append(identities.duplicate())
		return await super.ensure_models(identities, source_catalog)
	func _approved_index() -> Dictionary:
		return {"error":"", "index":local_index}
	func _selected_release() -> Dictionary:
		return local_release
	func _fetch(url: String, path: String, expected: int, digest: String, limit: int, _label: String) -> String:
		assert(url.begins_with(BASE_URL) and expected <= limit)
		var key := url.trim_prefix(BASE_URL)
		assert(archives.has(key))
		requested.append(key)
		var absolute := ProjectSettings.globalize_path(path)
		assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) == OK)
		assert(DirAccess.copy_absolute(archives[key], absolute) == OK)
		assert(_valid_file(absolute, expected, digest))
		return ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Shader readiness requires real drawn frames. A covered/minimized desktop
	# test window otherwise reports a timeout despite all models being loaded.
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.always_on_top = true
		root.show()
		root.grab_focus()
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	fixture = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	if OS.get_environment("POKEAETHER_GALAR_ADMITTED") == "1":
		for key in fixture.models:
			assert(Registry.DATA.data.models[key].sha256 == fixture.models[key].sha256)
	else:
		Registry.DATA.data.models.merge(fixture.models, true)
		Registry.DATA.data.profiles.merge(fixture.profiles, true)
	var service := LocalBundles.new()
	service.local_index = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bundles/asset-index.json")))
	# The editor now selects v8 automatically. Pin this offline candidate cohort
	# explicitly instead of mutating an older, unselected production descriptor.
	service.local_release = Service.RELEASE_V8.data.duplicate(true)
	service.local_release.requiredAssetIds = []
	for asset in service.local_index.assets:
		service.local_release.requiredAssetIds.append(asset.asset_id)
		service.archives[asset.object_key] = directory.path_join("bundles").path_join(str(asset.object_key).get_file())
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
	for name in ["Articuno Galar", "Zapdos Galar", "Moltres Galar"]:
		var species: String = name.to_lower().replace(" ", "-")
		stage.set_combatant(0, name, false)
		stage.set_combatant(1, name, true)
		assert(stage._anticipated_form_keys().is_empty(), "Selected forms have no anticipated alternate identity")
		await stage.await_prepared(true, 30000)
		if stage.preparation_failed or not stage.active:
			print("GALAR_PREPARATION_DIAGNOSTIC ", {"species": species,
				"metrics": stage.preparation_metrics, "identities": stage.identities,
				"failures": stage.failed_models, "catalog_problem": stage.catalog_problem,
				"packed": stage.packed.keys(), "frames_drawn": Engine.get_frames_drawn()})
		assert(stage.active and not stage.preparation_failed, stage.reason)
		assert(stage.handles("p1") and stage.handles("p2"))
		assert(stage.identities.slice(0, 2) == [species, species + "@shiny"])
		assert(not stage._models_pending())
		for identity in [species, species + "@shiny"]:
			assert(stage.packed.has(identity))
			assert(stage.entries[identity].runtime_sha256 == fixture.models[identity].sha256)
			assert(stage.placements[identity].calibrated)
			assert(is_equal_approx(stage.placements[identity].hover_height, 0.0 if species == "zapdos-galar" else 0.45))
			assert(not stage.motion_clips[identity].is_empty())
		assert(stage.players[0].has_animation("sleep") and stage.players[1].has_animation("sleep"))
		assert(stage.attack_action_for("Body Slam", "p1") == "physical_attack_2")
		assert(stage.attack_action_for("Dragon Claw", "p1") == "physical_attack")
		var requests := service.requested.size()
		stage.set_combatant(0, name, true)
		stage.set_combatant(1, name, false)
		await process_frame
		await process_frame
		assert(stage.identities.slice(0, 2) == [species + "@shiny", species])
		assert(stage.active and not stage._models_pending() and service.requested.size() == requests)
	# Cached, hash-valid bundles need no fetch on a restart. The first run
	# may fetch one archive per form; swaps must never fetch again.
	assert(service.requested.size() <= 3)
	stage.queue_free()
	await process_frame
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("GALAR_RUNTIME_OK pairs=3 loaded_before_reveal=true exact_shiny=true no_swap_download=true")
	quit()
