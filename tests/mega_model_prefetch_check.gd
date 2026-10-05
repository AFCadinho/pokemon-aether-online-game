extends SceneTree
const Forms = preload("res://scripts/battle/battle_ui/model_form_dependencies.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const FIXTURE := "user://mega-prefetch-check"

class BackgroundProbe extends Service:
	var queued: Array[String] = []
	func _run_prefetch(ids: Array[String], _generation: int) -> void:
		queued = ids

class DownloadProbe extends Node:
	var requests: Array = []
	var catalog := ""
	func ensure_models(ids: Array[String], _source: String) -> Dictionary:
		requests.append(ids.duplicate())
		# Delayed, offline delivery exercises the actual pre-battle await path.
		for frame in 3: await get_tree().process_frame
		return {"error":"", "path":catalog, "catalog_changed":true}
	func progress_text() -> String:
		return "Downloading test models"

var originals := {}
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Forms.anticipated("charizard")==["charizard-mega-x","charizard-mega-y"])
	assert(Forms.anticipated("garchomp@shiny")==["garchomp-mega@shiny","garchomp-mega-z@shiny"])
	assert(Forms.anticipated("rayquaza")==["rayquaza-mega"])
	assert(Forms.anticipated("floette-eternal")==["floette-mega"])
	assert(Forms.anticipated("floette").is_empty(), "Only the catalogued Eternal base can become Mega Floette")
	assert(Forms.anticipated("meowstic-f@shiny")==["meowstic-f-mega@shiny"])
	assert("zygarde-mega" in Forms.anticipated("zygarde-10"))
	assert(Forms.anticipated("groudon").is_empty(), "No unapproved Primal downloads")
	assert(Forms.anticipated("kyogre@shiny").is_empty())
	assert(Forms.anticipated("terapagos")==["terapagos-terastal","terapagos-stellar"])
	assert(Forms.anticipated("mimikyu")==["mimikyu-busted"])
	assert(Forms.anticipated("aegislash-blade@shiny")==["aegislash-shield@shiny"])
	assert(Forms.anticipated("garchomp-mega").is_empty())
	assert(Forms.anticipated("pikachu").is_empty())
	assert(Forms.anticipated("unknown").is_empty())
	var all := Forms.with_forms(["charizard","garchomp@shiny","charizard","pikachu"])
	assert(all.slice(0,3)==["charizard","garchomp@shiny","pikachu"])
	assert(all.size()==7 and "garchomp-mega" not in all)
	var background := BackgroundProbe.new()
	root.add_child(background)
	background.prefetch_models(["charizard","garchomp@shiny"])
	await process_frame
	assert(background.queued==Forms.with_forms(["charizard","garchomp@shiny"]))
	background.free()
	assert(await _runtime_check())
	print("MEGA_MODEL_PREFETCH_OK variants=true multi_megas=true background=true before_battle=true no_download_at_transformation=true cached_battle=true")
	quit()

func _runtime_check() -> bool:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode="3d"
	settings.battle_3d_arena="classic"
	settings.battle_3d_camera_motion=false
	settings.battle_3d_catalog_path=""
	settings._manual_model_catalog_this_session=false
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var original := root.get_node("OnDemand3DBundleService")
	root.remove_child(original)
	var probe := DownloadProbe.new()
	probe.catalog=_make_fixture()
	probe.name="OnDemand3DBundleService"
	root.add_child(probe)
	var stage := Renderer.new()
	root.add_child(stage)
	stage.setup()
	stage.set_combatant(0,"Garchomp",false)
	stage.set_combatant(1,"Garchomp",true)
	assert(stage.packed.is_empty())
	await stage.await_prepared(true,10000)
	assert(stage.active and not stage.preparation_failed,stage.reason)
	var expected := ["garchomp","garchomp@shiny","garchomp-mega","garchomp-mega-z","garchomp-mega@shiny","garchomp-mega-z@shiny"]
	assert(probe.requests==[expected], "All possible forms requested before the first turn")
	for identity in expected: assert(stage.packed.has(identity), "Must be imported before transformation: "+identity)
	for target in ["Garchomp-Mega","Garchomp-Mega-Z"]:
		for i in 2:
			assert(await stage.prepare_mega_form("p"+str(i+1),target,i==1))
			stage.set_combatant(i,target,i==1)
		for frame in 5: await process_frame
		assert(stage.active and stage.handles("p1") and stage.handles("p2"))
		assert(stage.identities[0]==target.to_lower() and stage.identities[1]==target.to_lower()+"@shiny")
		assert(not stage._models_pending() and probe.requests.size()==1, "Mega event neither downloads nor imports")
		for i in 2: stage.set_combatant(i,"Garchomp",i==1)
		for frame in 1200:
			await process_frame
			if stage.handles("p1") and stage.handles("p2") and not stage._models_pending(): break
		assert(stage.handles("p1") and stage.handles("p2") and not stage._models_pending())
	# The same local catalog must work with downloading explicitly disabled.
	stage.free()
	await process_frame
	settings.battle_3d_catalog_path=probe.catalog
	settings._manual_model_catalog_this_session=true
	var cached := Renderer.new()
	root.add_child(cached)
	cached.setup()
	cached.set_combatant(0,"Garchomp",false)
	cached.set_combatant(1,"Garchomp",true)
	await cached.await_prepared(true,10000)
	assert(cached.active and not cached.preparation_failed)
	assert(await cached.prepare_mega_form("p1","Garchomp-Mega",false))
	assert(probe.requests.size()==1)
	cached.free()
	probe.free()
	root.add_child(original)
	var models: Dictionary = Registry.DATA.data.models
	for identity in originals: models[identity]=originals[identity]
	preload("res://scripts/battle/battle_ui/model_resource_cache.gd").clear()
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	return true

func _make_fixture() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE))
	var entries := []
	for species in ["garchomp","garchomp-mega","garchomp-mega-z"]:
		for shiny in [false,true]:
			var identity := Registry.key(species,shiny)
			var actor := Node3D.new()
			actor.name="OfflineFixture"
			var mesh := MeshInstance3D.new()
			mesh.mesh=SphereMesh.new()
			actor.add_child(mesh)
			mesh.owner=actor
			var player := AnimationPlayer.new()
			actor.add_child(player)
			player.owner=actor
			var library := AnimationLibrary.new()
			var model: Dictionary=Registry.DATA.data.models[identity]
			var profile: Dictionary=Registry.DATA.data.profiles[model.profile]
			for action: String in profile.action_timing:
				var animation := Animation.new()
				animation.length=float(profile.action_timing[action].frames)/60.0
				library.add_animation(action,animation)
			player.add_animation_library("",library)
			var packed := PackedScene.new()
			var path := ProjectSettings.globalize_path(FIXTURE.path_join(identity+".scn"))
			assert(packed.pack(actor)==OK and ResourceSaver.save(packed,path)==OK)
			actor.free()
			originals[identity]=model.duplicate(true)
			model.sha256=FileAccess.get_sha256(path)
			model.previous_sha256=[]
			entries.append({"species":species,"variant":"shiny" if shiny else "normal","runtime_schema":1,"runtime_path":path,"runtime_sha256":model.sha256,"bytes":FileAccess.get_file_as_bytes(path).size()})
	var path := ProjectSettings.globalize_path(FIXTURE.path_join("catalog.json"))
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(entries))
	file.close()
	return path
