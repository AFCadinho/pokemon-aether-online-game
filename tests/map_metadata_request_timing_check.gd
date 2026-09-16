extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := root.get_node("GatewayApiConfig")
	var desktop := {"done": false}
	_wait(config, false, desktop)
	_check(desktop.done, "desktop does not introduce a frame delay")
	var web := {"done": false}
	_wait(config, true, web)
	_check(not web.done, "web metadata is deferred")
	await process_frame
	_check(not web.done, "web waits beyond the first frame boundary")
	await process_frame
	_check(web.done, "web request becomes ready after two frame boundaries")
	for service in ["npc_metadata_service", "overworld_pokemon_metadata_service", "encounter_metadata_service"]:
		var source := FileAccess.get_file_as_string("res://scripts/services/%s.gd" % service)
		var delay := source.find("await GatewayApiConfig.wait_for_metadata_request_frame()")
		_check(delay >= 0 and delay < source.find("var request := HTTPRequest.new()"), service + " defers before creating the request")
		_check(source.contains("request.timeout = 3.0"), service + " retains its bounded network timeout")
	print("map_metadata_request_timing_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _wait(config: Node, web: bool, state: Dictionary) -> void:
	await config.wait_for_metadata_request_frame(web)
	state.done = true

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
