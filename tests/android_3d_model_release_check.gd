extends SceneTree
const PairPilot = preload("res://scripts/services/model_pair_pilot.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Pin = preload("res://data/approved_3d_release_v14.json")
const Experiment = preload("res://data/android_3d_experiment.json")
class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			print("ANDROID_MODEL_RELEASE_ABORT ", code, " ", rationale)
			tree.call_deferred("quit", 2)
var sink := ErrorSink.new()

func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	ProjectSettings.set_setting("_custom_features", "mobile,android,android_3d_experimental")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION")
	_run.call_deferred()

func _run() -> void:
	assert(OS.has_feature("android") and OS.has_feature("android_3d_experimental"))
	assert(PairPilot.production_enabled(), "Android experiment uses published shared models without a diagnostic override")
	assert(PairPilot.release() == Pin.data and Experiment.data.model_release == Pin.data.revision)
	var service := Service.new()
	assert(service._selected_release() == Pin.data, "Legacy v12 repair receipt cannot override experimental Android v14")
	var index := PairPilot.catalog()
	assert(index.assets.size() == 1420)
	for identity in ["hydreigon@shiny", "tyranitar", "landorus-therian", "urshifu-rapid-strike"]:
		var entry: Dictionary = {}
		for asset: Dictionary in index.assets:
			for appearance: Dictionary in asset.appearances:
				if appearance.runtime_identity == identity:
					entry = appearance
		assert(not entry.is_empty(), identity)
		var asset := PairPilot.asset_for(identity, str(entry.runtime_sha256))
		assert(not asset.is_empty() and asset.appearances.size() == 2, "Normal and shiny share a verified download")
	assert(root.get_node("SettingsManager").supports_3d_presentation())
	service.free()
	print("ANDROID_3D_MODEL_RELEASE_OK revision=v14 pairs=1420 shared_normal_shiny=true")
	quit()
