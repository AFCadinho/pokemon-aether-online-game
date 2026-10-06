extends SceneTree
## Read-only timing of the catalog lookup performed synchronously by Play.
## Pass an explicit installed asset-bundles-v1 directory after --.

const BundleStore = preload("res://scripts/asset_bundle_store.gd")


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not arguments[0].is_absolute_path():
		printerr("Usage: --script res://tests/profile_play_catalog.gd -- /absolute/asset-bundles-v1")
		quit(2)
		return
	var store := BundleStore.new(arguments[0])
	for attempt in range(3):
		var started := Time.get_ticks_usec()
		var catalog: String = store.catalog_path()
		var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
		print("PLAY_CATALOG_PROFILE attempt=%d elapsed_ms=%.3f catalog_found=%s" % [attempt + 1, elapsed_ms, not catalog.is_empty()])
	quit()
