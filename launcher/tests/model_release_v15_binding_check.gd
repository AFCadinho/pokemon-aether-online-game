extends SceneTree
## Run in the actual launcher project, with its own compiled JSON resources.
const Pilot = preload("res://scripts/model_pair_pilot.gd")
const Release = preload("res://scripts/release_asset_bundles.gd")
const Index = preload("res://scripts/asset_bundle_index.gd")
const Current = preload("res://data/approved_3d_release_v15.json")
const Previous = preload("res://data/approved_3d_release_v14.json")
const Legacy = preload("res://data/approved_3d_release_v13.json")

func _init() -> void:
	_run.call_deferred()

func descriptor(pin: Dictionary) -> Dictionary:
	return {"schema": 1, "kind": Release.DESCRIPTOR_KIND, "revision": pin.revision,
		"url": "https://updates.pokeaether.com/" + pin.index.object_key,
		"objectBaseUrl": "https://updates.pokeaether.com", "sha256": pin.index.sha256,
		"sizeBytes": pin.index.size_bytes, "requiredAssetIds": pin.requiredAssetIds}

func _run() -> void:
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "1")
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION")
	assert(Pilot.release() == Current.data)
	assert(Pilot.catalog().assets.size() == 1420)
	assert(FileAccess.get_sha256(Pilot.PRODUCTION_PATH) == Current.data.index.sha256)
	for pin: Dictionary in [Current.data, Previous.data, Legacy.data]:
		assert(Release.descriptor_error(descriptor(pin)).is_empty())
	var previous := Pilot.expand_index(load(Pilot.PREVIOUS_PRODUCTION_PATH).data)
	assert(previous.assets.size() == 1420 and Index.validate(previous).is_empty())
	var tampered := descriptor(Current.data)
	tampered.revision = Previous.data.revision
	assert(not Release.descriptor_error(tampered).is_empty())
	var unbound: Dictionary = load(Pilot.PRODUCTION_PATH).data.duplicate(true)
	unbound.assets[0].sha256 = "0".repeat(64)
	assert(Pilot.expand_index(unbound).is_empty())
	# Exercise revision changes within one process: neither cache may mask a pin.
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION", "v14")
	assert(Pilot.release() == Previous.data and Pilot.catalog() == previous)
	OS.unset_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_REVISION")
	assert(Pilot.release() == Current.data and Pilot.catalog().catalog_revision == Current.data.revision)
	print("LAUNCHER_V15_BINDING_OK current=1420 previous=1420 legacy_pin=true tamper_rejected=true")
	quit()
