extends SceneTree
## Real compiled v13/v14 pins, transactional installation and independent restarts.
const Pilot=preload("res://scripts/services/model_pair_pilot.gd")
const Adapter=preload("res://launcher/scripts/release_asset_bundles.gd")
const Pair=preload("res://scripts/services/model_pair_pack.gd")
const Service=preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Old=preload("res://data/approved_3d_release_v13.json")
const New=preload("res://data/approved_3d_release_v14.json")
var output: String
class ErrorSink extends Logger:
 var tree: SceneTree
 func _log_error(_function: String,_file: String,_line: int,code: String,rationale: String,_notify: bool,kind: int,_backtraces: Array[ScriptBacktrace]) -> void:
  if kind!=Logger.ERROR_TYPE_WARNING:
   print("V14_UPGRADE_ABORT ",code," ",rationale);tree.call_deferred("quit",2)
var sink:=ErrorSink.new()
func _init() -> void:
 sink.tree=self;OS.add_logger(sink);_run.call_deferred()
func descriptor(pin: Dictionary) -> Dictionary:
 return {"schema":1,"kind":Adapter.DESCRIPTOR_KIND,"revision":pin.revision,"url":"https://updates.pokeaether.com/"+pin.index.object_key,"objectBaseUrl":"https://updates.pokeaether.com","sha256":pin.index.sha256,"sizeBytes":pin.index.size_bytes,"requiredAssetIds":pin.requiredAssetIds}
func _run() -> void:
 var args:=OS.get_cmdline_user_args();assert(args.size()==3)
 var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]));output=args[1];var phase: String=args[2]
 assert(output.is_absolute_path());DirAccess.make_dir_recursive_absolute(output)
 OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST","1")
 var adapter:=Adapter.new(output.path_join("store"),output.path_join("indexes"));adapter.store.prune_previous_models=false
 var old_pin:=descriptor(Old.data);var new_pin:=descriptor(New.data)
 assert(adapter.accept_index(old_pin,Pilot.LEGACY_PRODUCTION_PATH,false).error.is_empty())
 assert(adapter.accept_index(new_pin,Pilot.PRODUCTION_PATH,false).error.is_empty())
 var old_index:=adapter.cached_index(old_pin);var new_index:=adapter.cached_index(new_pin)
 assert(old_index.assets.size()==1200 and new_index.assets.size()==1420)
 var report: Dictionary={"complete":false,"phase":phase,"pairs":config.previous.size(),"new_pairs":config.additional.size()}
 if phase in ["original","upgrade","rollback"]:
  var paths: Dictionary=config.previous if phase in ["original","rollback"] else config.current.duplicate()
  if phase=="upgrade":
   paths.merge(config.additional)
   var before: String=adapter.store.active_generation();var failed: Dictionary={}
   var keys: Array=paths.keys();keys.sort();failed[keys[0]]=paths[keys[0]];failed[keys[-1]]=output.path_join("missing.pck")
   assert(not adapter.accept_bundles(new_index,failed).error.is_empty())
   assert(adapter.store.active_generation()==before,"Failed update changed the active generation")
   report["failed_batch_preserved_generation"]=true
  var index: Dictionary=old_index if phase in ["original","rollback"] else new_index
  var result:=adapter.accept_bundles(index,paths);assert(result.error.is_empty(),result.error)
  var ids: Array[String]=[];ids.assign(paths.keys())
  assert(adapter.store.plan(index,ids).downloads.is_empty(),"Restart would download installed models again")
  report["restart_no_download"]=true
  report["generation"]=adapter.store.active_generation()
 else:
  assert(phase in ["verify-original","verify-upgrade","verify-rollback"])
  var expected: Dictionary=config.previous if phase!="verify-upgrade" else config.current.duplicate()
  if phase=="verify-upgrade":expected.merge(config.additional)
  var current: Dictionary=old_index if phase!="verify-upgrade" else new_index
  var by_id: Dictionary=preload("res://launcher/scripts/asset_bundle_index.gd").by_id(current)
  var service:=Service.new();var entries:=service._catalog(adapter.catalog_path_for_launch());var count:=0
  for entry: Dictionary in entries:
   var identity: String=entry.species+("@shiny" if entry.variant=="shiny" else "")
   var asset_id: String=Service.asset_id_for_identity(identity)
   if not expected.has(asset_id):continue
   var asset: Dictionary=by_id[asset_id];var digest: String=""
   for appearance: Dictionary in asset.appearances:
    if appearance.runtime_identity==identity:digest=appearance.runtime_sha256
   assert(not digest.is_empty() and entry.runtime_sha256==digest)
   if entry.has("pair_asset"):
    var checked:=Pair.inspect(entry.pack_path,entry.pair_asset);assert(checked.error.is_empty())
    assert(Pair.mount_checked(entry.pack_path,entry.pair_asset,checked).is_empty())
   else:assert(FileAccess.get_sha256(entry.runtime_path)==digest)
   var scene:=ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
   assert(scene!=null);var actor:=scene.instantiate();root.add_child(actor)
   await process_frame;await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
   assert(not actor.find_children("*","AnimationPlayer",true,false).is_empty());actor.queue_free();await process_frame;await process_frame
   count+=1
  assert(count==expected.size()*2,"Not all installed appearances loaded: "+str(count))
  report["appearances_loaded"]=count;service.free()
 report.complete=true
 var file:=FileAccess.open(output.path_join(phase+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
 print("MODEL_V14_UPGRADE_OK ",phase," ",JSON.stringify(report));quit()
