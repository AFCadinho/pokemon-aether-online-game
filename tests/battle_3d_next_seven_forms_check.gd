extends SceneTree
## Real approved base/form archives: download before reveal, then exact normal/shiny swaps.
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const PAIRS = {"aegislash-shield":"aegislash-blade", "darmanitan-standard":"darmanitan-zen", "eiscue":"eiscue-noice", "mimikyu":"mimikyu-busted", "morpeko":"morpeko-hangry", "palafin":"palafin-hero", "wishiwashi":"wishiwashi-school"}
class LocalBundles extends Service:
	var local_index: Dictionary
	var archives: Dictionary
	var requested: Array[String] = []
	var ensured: Array = []
	func ensure_models(identities: Array[String], source_catalog: String) -> Dictionary:
		ensured.append(identities.duplicate())
		return await super.ensure_models(identities,source_catalog)
	func _approved_index() -> Dictionary:
		return {"error":"", "index":local_index}
	func _fetch(url:String,path:String,expected:int,digest:String,limit:int,_label:String) -> String:
		assert(url.begins_with(BASE_URL) and expected<=limit)
		var key := url.trim_prefix(BASE_URL)
		assert(archives.has(key))
		requested.append(key)
		var absolute := ProjectSettings.globalize_path(path)
		assert(DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())==OK)
		assert(DirAccess.copy_absolute(archives[key],absolute)==OK)
		assert(_valid_file(absolute,expected,digest))
		return ""
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	var fixture:Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	Registry.DATA.data.models.merge(fixture.models,true)
	Registry.DATA.data.profiles.merge(fixture.profiles,true)
	var service := LocalBundles.new()
	service.local_index = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("test-combined-index.json")))
	for asset in service.local_index.assets:
		if asset.asset_id not in Service.RELEASE.data.requiredAssetIds:
			Service.RELEASE.data.requiredAssetIds.append(asset.asset_id)
		var folder := "bundles" if asset.species_id in PAIRS.values() else "test-base-bundles"
		service.archives[asset.object_key] = directory.path_join(folder).path_join(str(asset.object_key).get_file())
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	service.name="OnDemand3DBundleService"
	root.add_child(service)
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_3d_arena="classic"
	settings.battle_3d_camera_motion=false
	settings.battle_3d_catalog_path=""
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	var reverse_count := 0
	for base in PAIRS:
		var target:String=PAIRS[base]
		stage.set_combatant(0,base,false)
		stage.set_combatant(1,base,true)
		assert(stage._anticipated_form_keys()==[target,target+"@shiny"])
		await stage.await_prepared(true,30000)
		assert(stage.active and not stage.preparation_failed,stage.reason)
		for key in [base,base+"@shiny",target,target+"@shiny"]:
			assert(stage.packed.has(key),"Form must already be loaded before reveal: "+key)
		assert(service.ensured[-1]==[base,base+"@shiny",target,target+"@shiny"])
		var requests := service.requested.size()
		stage.set_combatant(0,target,false)
		stage.set_combatant(1,target,true)
		await process_frame
		await process_frame
		assert(stage.active and stage.handles("p1") and stage.handles("p2"))
		assert(stage.identities.slice(0,2)==[target,target+"@shiny"])
		assert(not stage._models_pending() and service.requested.size()==requests)
		assert(stage.entries[target].runtime_sha256==fixture.models[target].sha256)
		assert(stage.entries[target+"@shiny"].runtime_sha256==fixture.models[target+"@shiny"].sha256)
		if base not in ["mimikyu","palafin"]:
			assert(stage._anticipated_form_keys()==[base,base+"@shiny"])
			stage.set_combatant(0,base,false)
			stage.set_combatant(1,base,true)
			await process_frame
			await process_frame
			assert(stage.active and not stage._models_pending() and service.requested.size()==requests)
			assert(stage.identities.slice(0,2)==[base,base+"@shiny"])
			reverse_count+=1
		print("FORM_SWAP_OK ",base," -> ",target)
	assert(reverse_count==5)
	assert(not stage._supports_combatant("mimikyu-busted-totem",false,false,false))
	assert(not stage._supports_combatant("darmanitan-galar-zen",false,false,false))
	stage.queue_free()
	await process_frame
	Cache.clear()
	service.queue_free()
	root.add_child(original)
	print("NEXT_SEVEN_FORMS_OK pairs=7 reverse=5 loaded_before_reveal=true exact_shiny=true no_mid_swap_download=true")
	quit()
