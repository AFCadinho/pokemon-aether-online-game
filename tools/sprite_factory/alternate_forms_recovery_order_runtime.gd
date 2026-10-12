extends SceneTree
const Audit = preload("model_texture_audit.gd")
const Ordering = preload("alternate_forms_recovery_opaque_order.gd")
class ErrorSink extends Logger:
	var failed := false
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, _kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		failed = true
		tree.call_deferred("quit", 2)
var sink := ErrorSink.new()

func _initialize() -> void:
	sink.tree = self
	OS.add_logger(sink)
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2 and DisplayServer.get_name() == "headless")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for entry: Dictionary in entries:
		assert(str(entry.species).begins_with("sawsbuck-"))
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		var scene := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var actor := scene.instantiate()
		var records := Ordering.apply(actor)
		entry["opaque_order_source_path"] = entry.runtime_path
		entry["opaque_order_source_sha256"] = entry.runtime_sha256
		entry["opaque_order_changes"] = records
		entry.runtime_path = str(args[1]).get_base_dir().path_join(str(entry.species)+".scn")
		var packed := PackedScene.new()
		assert(packed.pack(actor) == OK)
		assert(ResourceSaver.save(packed, entry.runtime_path, ResourceSaver.FLAG_COMPRESS) == OK)
		assert(Audit.signature(ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)) == Audit.signature(packed))
		entry.runtime_sha256 = FileAccess.get_sha256(entry.runtime_path)
		actor.free()
	if sink.failed:
		quit(2)
		return
	var handle := FileAccess.open(args[1], FileAccess.WRITE)
	handle.store_string(JSON.stringify(entries,"  "))
	print("RECOVERY_OPAQUE_ORDER_OK ",entries.size())
	quit()
