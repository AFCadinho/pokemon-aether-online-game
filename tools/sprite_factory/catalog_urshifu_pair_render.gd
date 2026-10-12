extends "shared_model_catalog_render.gd"
const CandidatePilot = preload("res://scripts/services/model_pair_pilot.gd")

## Process-local bindings for unpublished candidates; the shipped index is unchanged.
func _run() -> void:
	# Complete cache maintenance before replacing process-local catalog bindings.
	var bundles := root.get_node("OnDemand3DBundleService")
	root.remove_child(bundles)
	bundles.free()
	auto_accept_quit = false
	root.mode = Window.MODE_WINDOWED
	root.always_on_top = true
	root.show()
	root.grab_focus()
	# A desktop compositor may stop drawing a covered diagnostic window.
	# Force actual GPU frames so the inherited frame_post_draw awaits complete.
	process_frame.connect(func(): RenderingServer.force_draw(false))
	var directory := OS.get_environment("POKEAETHER_FORM_BUNDLE_WORK")
	assert(directory.is_absolute_path())
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-fixture.json")))
	Reviewed.DATA.data.models.merge(fixture.models, true)
	Reviewed.DATA.data.profiles.merge(fixture.profiles, true)
	OS.set_environment("POKEAETHER_SHARED_MODEL_PRODUCTION_TEST", "0")
	OS.set_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST", "1")
	# Initialize static catalog storage before installing this process-local fixture.
	CandidatePilot.catalog()
	CandidatePilot._catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("shared/index.json")))
	CandidatePilot._lookups.clear()
	assert(CandidatePilot.catalog().assets.size() == 1)
	await super._run()
