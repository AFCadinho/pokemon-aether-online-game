extends Node
const Pilot = preload("res://scripts/services/model_pair_pilot.gd")
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")
const Pin = preload("res://data/approved_3d_release_v13.json")

func _ready() -> void:
	if OS.is_debug_build() or not Pilot.production_enabled():
		_fail("Expected a desktop release export")
		return
	if FileAccess.get_sha256(Pilot.PRODUCTION_PATH) != Pin.data.index.sha256:
		_fail("Production index differs from its compiled pin")
		return
	var catalog := Pilot.catalog()
	var service := Service.new()
	var selected := service._selected_release()
	if catalog.get("catalog_revision") != Pin.data.revision or catalog.assets.size() != 1200 or selected != Pin.data:
		_fail("Production geometry release binding is invalid")
		return
	var packs := 0
	for asset: Dictionary in catalog.assets:
		if asset.get("format") == "model-pair-pck-v1":
			packs += 1
	if packs != 1145:
		_fail("Unexpected production shared pack count")
		return
	service.free()
	print("SHARED_GEOMETRY_RELEASE_SMOKE_OK revision=", selected.revision, " pairs=1200 shared=", packs)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(2)
