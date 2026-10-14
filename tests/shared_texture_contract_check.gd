extends SceneTree
const Pair = preload("res://scripts/services/model_pair_pack.gd")
const LauncherPair = preload("res://launcher/scripts/model_pair_pack.gd")
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const LauncherPilot = preload("res://launcher/scripts/model_pair_pilot.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, why: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("SHARED_TEXTURE_CONTRACT_ABORT ",code," ",why)
			tree.call_deferred("quit",2)
var sink := Sink.new()
func _init() -> void:
	sink.tree=self;OS.add_logger(sink)
	_run.call_deferred()
func _run() -> void:
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_TEXTURE_TEST","1")
	assert(Pilot.catalog()==LauncherPilot.catalog())
	var index: Dictionary=Pilot.catalog()
	assert(Index.validate(index).is_empty(),Index.validate(index))
	assert(Pilot.release()==LauncherPilot.release())
	assert(FileAccess.get_sha256("res://scripts/services/model_pair_pack.gd")==FileAccess.get_sha256("res://launcher/scripts/model_pair_pack.gd"))
	var pool: Dictionary=index.assets[0]
	var pair: Dictionary=index.assets[1]
	assert(Pair.metadata_error(pool).is_empty() and Pair.metadata_error(pair).is_empty())
	for asset: Dictionary in index.assets:
		for appearance: Dictionary in asset.appearances:
			assert(not Reviewed.resolve(appearance.runtime_identity,appearance.runtime_sha256).is_empty(),appearance.runtime_identity)
	var bad:=index.duplicate(true);bad.runtime_contract.pokemon_3d=2
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[0].sha256="0".repeat(64)
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[1].pair_manifest.schema=2
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets.remove_at(0)
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[0].pair_manifest.files[0].path="models/normal.scn"
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[0].dependencies=[pair.asset_id];bad.assets[0].pair_manifest.dependencies=bad.assets[0].dependencies
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[1].pair_manifest.erase("texture_pools")
	assert(not Index.validate(bad).is_empty())
	bad=index.duplicate(true);bad.assets[0].erase("pair_manifest")
	assert(not Index.validate(bad).is_empty())
	var assets:=Index.by_id(index)
	var plan:=Index.plan(index,{},[pair.asset_id])
	assert(plan.downloads==[pool.asset_id,pair.asset_id])
	assert(Release.new()._release_index_error(index).is_empty())
	var descriptor: Dictionary=Pilot.release()
	var pin: Dictionary=descriptor.index
	var d={"schema":1,"kind":Release.DESCRIPTOR_KIND,"revision":descriptor.revision,"url":"https://updates.pokeaether.com/"+pin.object_key,"objectBaseUrl":"https://updates.pokeaether.com","sha256":pin.sha256,"sizeBytes":pin.size_bytes,"requiredAssetIds":descriptor.requiredAssetIds}
	assert(Release.descriptor_error(d).is_empty())
	OS.unset_environment("POKEAETHER_SHARED_MODEL_TEXTURE_TEST")
	assert(Pilot.asset_for("asset:"+pool.asset_id,pool.sha256).is_empty())
	assert(not Release.descriptor_error(d).is_empty())
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","1")
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION","v15")
	assert(Index.validate(Pilot.catalog()).is_empty(), Index.validate(Pilot.catalog()))
	assert(Pilot.production_revision()=="v15" and Pilot.release()==Pilot.PRODUCTION.data)
	print("SHARED_TEXTURE_CONTRACT_OK tamper_cases=8 production_v15_unchanged=true")
	quit()
