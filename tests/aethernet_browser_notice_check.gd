extends SceneTree

const KEEPER_SCRIPT := "res://scripts/world/npcs/transit_keeper_npc.gd"
const TRANSIT_SERVICE_SCRIPT := "res://scripts/services/transit_service.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var keeper_source := FileAccess.get_file_as_string(KEEPER_SCRIPT)
	var transit_service_source := FileAccess.get_file_as_string(TRANSIT_SERVICE_SCRIPT)
	_check(
		not keeper_source.contains('if OS.has_feature("web")')
		and not keeper_source.contains("_show_browser_demo_notice"),
		"browser Keepers do not stop before loading the Aethernet network"
	)
	_check(
		transit_service_source.contains('return "/auth/web/transit" if OS.has_feature("web") else TRANSIT_ENDPOINT'),
		"browser Aethernet calls the restricted authenticated transit API"
	)
	_check(
		keeper_source.contains("TransitService.load_network")
		and keeper_source.contains("TransitService.travel(destination_id)"),
		"browser and desktop Keepers share the authorized travel flow"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
