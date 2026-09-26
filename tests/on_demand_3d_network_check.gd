extends SceneTree

const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := Service.new()
	root.add_child(service)
	var result: Dictionary = await service.ensure_models(["volcarona", "volcarona@shiny"], "")
	assert(result.error.is_empty())
	assert(service._entry_available(service._catalog(result.path), "volcarona"))
	assert(service._entry_available(service._catalog(result.path), "volcarona@shiny"))
	print("ON_DEMAND_3D_NETWORK_OK approved_index=true volcarona_pair=true")
	quit()
