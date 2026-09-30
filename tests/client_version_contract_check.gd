extends SceneTree

const ClientBuild := preload("res://scripts/services/client_build.gd")

var failed := false


func _init() -> void:
	var candidate_response := {"detail": {"code": "client_update_required", "requiredBuild": "published-6"}}
	_check(ClientBuild.android_candidate_target(candidate_response, "published-6", "candidate-7") == "published-6", "Android candidate can use only its approved prior release before publication")
	candidate_response.detail.requiredBuild = "candidate-7"
	_check(ClientBuild.android_candidate_target(candidate_response, "published-6", "candidate-7") == "candidate-7", "same signed candidate uses its real identity after publication")
	candidate_response.detail.requiredBuild = "newer-8"
	_check(ClientBuild.android_candidate_target(candidate_response, "published-6", "candidate-7") == "", "later Android releases still require a normal update")
	_check(ClientBuild.android_candidate_target(candidate_response, "", "candidate-7") == "", "ordinary builds do not enable candidate compatibility")
	var build_id := ClientBuild.get_build_id()
	_check(not build_id.is_empty(), "client build identity is always available")
	_check(
		ClientBuild.get_http_header() == "X-PokeAether-Client-Build: %s" % build_id,
		"HTTP build header uses the shared immutable identity"
	)
	var headers := ClientBuild.append_http_header(PackedStringArray())
	_check(
		headers.has("X-PokeAether-Client-Platform: %s" % ClientBuild.get_platform_id()),
		"HTTP version handshake identifies the client platform"
	)
	_check(
		ClientBuild.append_websocket_query("wss://api.test/ws?token=test").contains(
			"&clientBuild=%s&clientPlatform=%s" % [
				build_id.uri_encode(),
				ClientBuild.get_platform_id().uri_encode(),
			]
		),
		"websocket build query preserves authentication and identifies the platform"
	)

	var gateway_source := FileAccess.get_file_as_string(
		"res://scripts/services/gateway_api_config.gd"
	)
	var auth_source := FileAccess.get_file_as_string("res://scripts/services/auth_service.gd")
	_check(
		gateway_source.contains("ClientBuild.append_http_header(headers)"),
		"shared gateway headers include the client build"
	)
	_check(
		auth_source.contains("_client_headers(")
		and auth_source.contains("ClientBuild.append_http_header(headers)"),
		"login and saved-session restoration include the client build"
	)

	for websocket_service: String in [
		"res://scripts/services/chat_realtime_service.gd",
		"res://scripts/services/world_presence_service.gd",
		"res://scripts/services/trade_realtime_service.gd",
		"res://scripts/services/pvp_battle_realtime_service.gd",
	]:
		_check(
			FileAccess.get_file_as_string(websocket_service).contains(
				"ClientBuild.append_websocket_query("
			),
			"%s includes the client build in its handshake" % websocket_service
		)

	print("PASS client_version_contract_check")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
