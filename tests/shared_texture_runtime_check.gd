extends "res://tools/sprite_factory/lossless_texture_storage_probe.gd"
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Store = preload("res://launcher/scripts/asset_bundle_store.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const DesktopStorage = preload("res://scripts/services/desktop_asset_storage.gd")
const Bulk = preload("res://launcher/scripts/bulk_asset_downloads.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Preview = preload("res://scripts/ui/pokedex_model_preview.gd")

class ProbeSettings extends Node:
	var battle_presentation_mode := "3d"
	var battle_3d_catalog_path := ""
	var battle_3d_arena := "classic"
	var battle_animations := true
	var battle_3d_camera_motion := false
	var terrain_effects := false
	var weather_effects := false
	func is_android_3d_experimental() -> bool: return false
	func has_manual_battle_3d_catalog_selection() -> bool: return false
	func get_battle_3d_catalog_path() -> String: return OS.get_environment("POKEAETHER_MODEL_CATALOG")

class LoopbackService extends Service:
	var origin := ""
	var requests := []
	func _ready() -> void: pass
	func _local_index_path(_release: Dictionary) -> String: return ROOT.path_join("runtime-test-index.json")
	func _start_download_request(url: String) -> Error:
		assert(url.begins_with(BASE_URL) and origin.begins_with("http://127.0.0.1:"))
		requests.append(url.trim_prefix(BASE_URL))
		return active_request.request(origin + url.trim_prefix(BASE_URL))

class Stage extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd":
	func _requested_arena() -> String: return "classic"

func write_bytes(path: String, data: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(data);file.close()

func texture_refs(value: Variant, refs: Dictionary, seen: Dictionary) -> void:
	if value is Resource:
		var id: int=value.get_instance_id()
		if seen.has(id): return
		seen[id]=true
		if value is Texture2D:
			refs[value.resource_path]=weakref(value)
			return
		for key in Audit.storage_properties(value): texture_refs(value.get(key),refs,seen)
	elif value is Array:
		for item in value: texture_refs(item,refs,seen)
	elif value is Dictionary:
		for item in value.values(): texture_refs(item,refs,seen)

func prove_model(entry: Dictionary, asset: Dictionary, expected: Dictionary, refs: Dictionary) -> Dictionary:
	var receipt:=Pair.inspect_entry(entry,asset)
	assert(str(receipt.error).is_empty(),str(receipt.error))
	assert(Pair.mount_checked(entry.pack_path,asset,receipt).is_empty())
	var scene:=ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	assert(scene != null)
	var signature:=normalized_signature(scene)
	var poses:=motion(scene)
	assert(signature == expected.signature and poses == expected.motion,"Runtime source model changed")
	var duplicate:=scene.duplicate(true) as PackedScene
	assert(duplicate != null and normalized_signature(duplicate)==signature)
	texture_refs(scene,refs,{})
	return {"signature":signature,"motion":poses}

func presenter(service: LoopbackService, first: String, second: String, directory: String, index: int) -> Dictionary:
	var stage:=Stage.new()
	root.add_child(stage)
	stage.setup()
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.size=Vector2(640,450)
	stage.set_combatant(0,first)
	stage.set_combatant(1,second.trim_suffix("@shiny"),second.ends_with("@shiny"))
	await stage.await_prepared(true,30000)
	assert(not stage.preparation_failed and stage.handles("p1") and stage.handles("p2"),stage.reason)
	assert(stage.actors[0] != null and stage.actors[1] != null)
	var frame:=stage.viewport.get_texture().get_image()
	assert(frame != null and not frame.is_empty())
	assert(frame.save_png(directory.path_join("battle-"+str(index)+".png"))==OK)
	var result: Dictionary={"first":first,"second":second,"actors":2,"cache_entries":Cache.items.size(),
		"cache_source_bytes":Cache.source_bytes,"texture_memory_bytes":int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"static_memory_bytes":OS.get_static_memory_usage(),"prepared":true}
	assert(Cache.items.size() <= Cache.MAX_ENTRIES and Cache.source_bytes <= Cache.MAX_SOURCE_BYTES)
	stage.queue_free()
	await process_frame
	await process_frame
	return result

func previews(identity: String, directory: String, index: int) -> void:
	for appearance in [false,true]:
		var preview:=Preview.new()
		root.add_child(preview)
		assert(preview.show_species(identity,appearance))
		var deadline:=Time.get_ticks_msec()+30000
		while preview.is_loading() and Time.get_ticks_msec()<deadline: await process_frame
		assert(preview.actor != null,"Preview did not load "+identity)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(preview.viewport.get_texture().get_image().save_png(directory.path_join("preview-"+str(index)+"-"+str(appearance)+".png"))==OK)
		preview.queue_free()
		await process_frame
		await process_frame

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_TEXTURE_TEST","1")
	OS.unset_environment("POKEAETHER_MODEL_PAIR_PACKS")
	var args:=OS.get_cmdline_user_args()
	assert(args.size()==3)
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var directory: String=args[1]
	var mode: String=args[2]
	var catalog: Dictionary=Pilot.catalog()
	var pool: Dictionary=catalog.assets[0]
	var service:=LoopbackService.new()
	service.origin=config.origin
	service.name="OnDemand3DBundleService"
	root.add_child(service)
	var settings:=ProbeSettings.new();settings.name="SettingsManager";root.add_child(settings)
	var pairs: Array=catalog.assets.slice(1)
	var identities: Array[String]=[]
	for asset: Dictionary in pairs: identities.append(str(asset.appearances[0].runtime_identity))
	if mode=="cold":
		var failed: Dictionary=await service.ensure_models([identities[0]],"")
		assert(not str(failed.get("error","")).is_empty(),"Injected failed pool download was accepted")
		assert(not FileAccess.file_exists(Service.ROOT.path_join("runtime-catalog.json")),"Partial download published models")
	var ready: Dictionary=await service.ensure_models(identities,"")
	assert(str(ready.error).is_empty(),str(ready.error))
	OS.set_environment("POKEAETHER_MODEL_CATALOG",ready.path)
	var pool_path:=ProjectSettings.globalize_path(Service.ROOT.path_join("objects").path_join(pool.sha256).path_join("model-pair.pck"))
	if mode=="cold":
		var file:=FileAccess.open(pool_path,FileAccess.READ_WRITE)
		assert(file != null);var byte:=file.get_8();file.seek(0);file.store_8(byte ^ 1);file.close()
		assert(service._installed_models([identities[0]],ready.path).is_empty(),"Corrupt dependency authorized cached model")
		var repaired: Dictionary=await service.ensure_models([identities[0]],ready.path)
		assert(str(repaired.error).is_empty(),str(repaired.error))
		assert(FileAccess.get_sha256(pool_path)==pool.sha256)
	else:
		assert(service.requests.is_empty(),"Warm process restart downloaded files")
	# Launcher stages a complete collection without exposing a partial generation.
	var launcher:=Release.new("user://runtime-launcher-store","user://runtime-launcher-index")
	var session: Dictionary=launcher.begin_collection(catalog,[pairs[0].asset_id,pairs[1].asset_id])
	assert(str(session.error).is_empty(),str(session.error))
	if mode=="cold":
		assert(session.downloads[0]==pool.asset_id)
		var premature:=launcher.stage_collection(session,pairs[0].asset_id,config.jobs[0].path)
		assert(not str(premature.error).is_empty() and launcher.store.active_generation().is_empty())
		assert(launcher.stage_collection(session,pool.asset_id,config.pool.path).error.is_empty())
		assert(launcher.store.active_generation().is_empty())
		for i in 2: assert(launcher.stage_collection(session,pairs[i].asset_id,config.jobs[i].path).error.is_empty())
		assert(launcher.finish_collection(session).error.is_empty())
		assert(not launcher.store.remove(pool.asset_id).error.is_empty(),"Required pool was removed")
	else:
		assert(session.downloads.is_empty())
		assert(launcher.finish_collection(session).error.is_empty())
	assert(DesktopStorage.register_model_usage(launcher.store.root,OS.get_process_id())==OK)
	OS.set_environment("POKEAETHER_LAUNCHER_MODEL_DIR",launcher.store.root)
	var handoff: String=launcher.store.catalog_path()
	var launcher_ready: Dictionary=await service.ensure_models([identities[0],identities[1]],handoff)
	assert(launcher_ready.error.is_empty() and launcher_ready.path==handoff,"Launcher catalog was not reused")
	var handoff_entries: Array=service._catalog(handoff)
	assert(handoff_entries.size()==4)
	var handoff_proof:=await service.verify_shared_entry(handoff_entries[0])
	assert(handoff_proof.error.is_empty() and Pair.mount_checked(handoff_entries[0].pack_path,handoff_proof.asset,handoff_proof.checked).is_empty())
	assert(not launcher.store.garbage_collect().error.is_empty(),"Mounted launcher pool became deletable")
	var fake_paths: Dictionary=handoff_entries[0].duplicate(true)
	fake_paths.texture_packs[pool.sha256]=handoff_entries[0].pack_path
	assert(not Pair.inspect_entry(fake_paths,Pilot.entry_asset(handoff_entries[0])).error.is_empty(),"Different pack passed as a texture pool")
	var expected: Dictionary=config.source_models
	var entries: Array=service._catalog(ready.path)
	assert(entries.size()==16)
	var installed_rows: Dictionary={}
	for entry: Dictionary in entries:
		var identity: String=str(entry.species)+("@shiny" if entry.variant=="shiny" else "")
		installed_rows[identity]=entry
	assert(Bulk._available(pool,installed_rows) and Bulk._available(pairs[0],installed_rows))
	var refs: Dictionary={}
	var models:= {}
	for entry: Dictionary in entries:
		var asset:=Pilot.entry_asset(entry)
		assert(not asset.is_empty())
		var identity: String=str(entry.species)+("@shiny" if entry.variant=="shiny" else "")
		models[identity]=prove_model(entry,asset,expected[identity],refs)
	var scenes := []
	for i in pairs.size():
		var identity: String=identities[i]
		scenes.append(await presenter(service,identity,identity+"@shiny",directory,i))
		await previews(identity,directory,i)
	Cache.clear()
	await process_frame
	await process_frame
	for path: String in refs: assert(refs[path].get_ref()==null,"Runtime cache retained a texture after eviction")
	assert(not service.can_clear_cache(),"Mounted pool/model archives became deletable in-process")
	var pool_requests:=service.requests.count(pool.object_key)
	assert(pool_requests==(3 if mode=="cold" else 0),"Shared pool downloaded repeatedly for separate forms")
	var report: Dictionary={"complete":true,"prototype_only":true,"production_approved":false,"mode":mode,
		"input_sha256":FileAccess.get_sha256(args[0]),"models":models,"battles":scenes,"preview_looks":16,
		"downloads":service.requests,"pool_http_requests":pool_requests,"runtime_evicted_texture_resources":refs.size(),
		"godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"device":RenderingServer.get_video_adapter_name(),"retained_files_protected":true,"launcher_handoff_verified":true,"wrong_texture_path_rejected":true,"pool_corruption_repaired":mode=="cold"}
	var out:=FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE);out.store_string(JSON.stringify(report)+"\n");out.close()
	service.free();settings.free()
	print("SHARED_TEXTURE_RUNTIME_OK ",mode," looks=16 battles=8 previews=16")
	quit()
