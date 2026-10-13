extends SceneTree
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const LauncherPilot = preload("res://launcher/scripts/model_pair_pilot.gd")
const Release = preload("res://launcher/scripts/release_asset_bundles.gd")
const Index = preload("res://launcher/scripts/asset_bundle_index.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pin = preload("res://data/approved_3d_release_v14.json")
const Old = preload("res://data/approved_3d_release_v13.json")

class ErrorSink extends Logger:
 var tree: SceneTree
 func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
  if _kind != Logger.ERROR_TYPE_WARNING:
   print("V14_BINDING_ABORT ",code," ",rationale)
   tree.call_deferred("quit",2)
var sink:=ErrorSink.new()
func _init() -> void:
 sink.tree=self;OS.add_logger(sink)
 _run.call_deferred()

func descriptor(pin: Dictionary) -> Dictionary:
 return {"schema":1,"kind":Release.DESCRIPTOR_KIND,"revision":pin.revision,"url":"https://updates.pokeaether.com/"+pin.index.object_key,"objectBaseUrl":"https://updates.pokeaether.com","sha256":pin.index.sha256,"sizeBytes":pin.index.size_bytes,"requiredAssetIds":pin.requiredAssetIds}

func _run() -> void:
 OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","1")
 OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION")
 var index: Dictionary = Pilot.catalog()
 assert(index==LauncherPilot.catalog())
 print("V14_INDEX_DIAGNOSTIC size=",index.assets.size()," error=",Index.validate(index))
 assert(index.assets.size()==1420 and Index.validate(index).is_empty())
 assert(Pilot.release()==Pin.data and LauncherPilot.release()==Pin.data)
 assert(FileAccess.get_sha256(Pilot.PRODUCTION_PATH)==Pin.data.index.sha256)
 var service:=Service.new()
 assert(service._selected_release()==Pin.data)
 assert(Release.descriptor_error(descriptor(Pin.data)).is_empty())
 assert(Release.descriptor_error(descriptor(Old.data)).is_empty())
 var old_compact: Dictionary=load(Pilot.LEGACY_PRODUCTION_PATH).data
 var legacy:=Pilot.expand_index(old_compact)
 assert(legacy.assets.size()==1200 and Index.validate(legacy).is_empty())
 var aliases := preload("res://scripts/battle/battle_ui/shared_form_models.gd")
 var appearances:=0
 for asset: Dictionary in index.assets:
  for appearance: Dictionary in asset.appearances:
   assert(not Reviewed.resolve(appearance.runtime_identity,appearance.runtime_sha256).is_empty(),appearance.runtime_identity)
   assert(not Reviewed.resolve(appearance.runtime_identity,appearance.get("source_sha256",appearance.runtime_sha256)).is_empty())
   appearances+=1
 assert(appearances==2840)
 var bad:=descriptor(Pin.data);bad.sha256="0".repeat(64)
 assert(not Release.descriptor_error(bad).is_empty())
 bad=descriptor(Pin.data);bad.requiredAssetIds=Old.data.requiredAssetIds
 assert(not Release.descriptor_error(bad).is_empty())
 var compact: Dictionary=load(Pilot.PRODUCTION_PATH).data.duplicate(true)
 compact.assets[0].sha256="0".repeat(64)
 assert(Pilot.expand_index(compact).is_empty())
 for name in ["landorus-therian","urshifu-rapid-strike","greninja-ash","pikachu-rock-star"]:
  assert(aliases.canonical_species(name)==name)
 var report={"complete":true,"pairs":1420,"appearances":2840,"legacy_pairs":1200,"tamper_checks":3,"selected_revision":Pin.data.revision}
 var output:=OS.get_environment("POKEAETHER_V14_BINDING_REPORT")
 if output.is_empty():output="user://model-v14-binding.json"
 var file:=FileAccess.open(output,FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
 service.free()
 print("APPROVED_3D_V14_OK pairs=1420 appearances=2840 previous_pin=true")
 quit()
