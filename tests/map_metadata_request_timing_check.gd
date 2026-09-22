extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var config := root.get_node("GatewayApiConfig")
	config.cached_url = ""
	var local_base_url: String = await config.get_base_url()
	_check(
		local_base_url == config.LOCAL_GATEWAY_URL,
		"debug desktop runs resolve metadata requests through the local gateway"
	)
	var desktop := {"done": false}
	_wait(config, false, desktop)
	_check(not desktop.done, "desktop metadata is deferred")
	var web := {"done": false}
	_wait(config, true, web)
	_check(not web.done, "web metadata is deferred")
	await process_frame
	_check(not desktop.done and not web.done, "metadata waits beyond the first frame boundary")
	await process_frame
	_check(desktop.done and web.done, "metadata requests become ready after two frame boundaries")
	var service_timeouts := {
		"npc_metadata_service": "3.0",
		"overworld_pokemon_metadata_service": "3.0",
		"encounter_metadata_service": "3.0",
		"trainer_progress_service": "REQUEST_TIMEOUT_SECONDS",
	}
	for service: String in service_timeouts:
		var source := FileAccess.get_file_as_string("res://scripts/services/%s.gd" % service)
		var delay := source.find("await GatewayApiConfig.wait_for_metadata_request_frame()")
		var request_creation := source.find("var request := HTTPRequest.new()", delay)
		_check(delay >= 0 and delay < request_creation, service + " defers before creating the request")
		_check(
			source.contains("request.timeout = %s" % service_timeouts[service]),
			service + " retains its bounded network timeout"
		)
	var progress_source := FileAccess.get_file_as_string("res://scripts/services/trainer_progress_service.gd")
	var progress_function := progress_source.find("func _request_progress")
	var transport_check := progress_source.find(
		"if request_result != HTTPRequest.RESULT_SUCCESS", progress_function
	)
	var json_parse := progress_source.find("JSON.parse_string", progress_function)
	_check(
		transport_check >= 0 and transport_check < json_parse,
		"trainer progress handles transport failures before parsing JSON"
	)
	print("map_metadata_request_timing_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _wait(config: Node, web: bool, state: Dictionary) -> void:
	await config.wait_for_metadata_request_frame(web)
	state.done = true

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
