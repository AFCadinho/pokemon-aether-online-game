extends SceneTree
const Service = preload("res://scripts/services/on_demand_3d_bundle_service.gd")

class LocalService extends Service:
	var fixture_url := ""
	func _start_download_request(_url: String) -> Error:
		return active_request.request(fixture_url)

class MissingModel extends Node:
	var server := TCPServer.new()
	var peer: StreamPeerTCP
	var received := ""
	func _process(_delta: float) -> void:
		if peer == null and server.is_connection_available():
			peer = server.take_connection()
		if peer == null: return
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			received += peer.get_data(available)[1].get_string_from_utf8()
		if received.contains("\r\n\r\n"):
			peer.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 7\r\nConnection: close\r\n\r\nmissing".to_utf8_buffer())
			set_process(false)
	func _exit_tree() -> void:
		if peer != null: peer.disconnect_from_host()
		server.stop()

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var fixture := MissingModel.new()
	if fixture.server.listen(0, "127.0.0.1") != OK:
		fixture.free()
		quit(1)
		return
	root.add_child(fixture)
	var service := LocalService.new()
	service.fixture_url = "http://127.0.0.1:%d/toxapex.zip" % fixture.server.get_local_port()
	root.add_child(service)
	var destination := "user://missing-model-http-check.zip"
	var error: String = await service._fetch(Service.BASE_URL + "optional-assets/pokemon_3d/toxapex/base/missing.zip",
		destination, 7, "0".repeat(64), 1024, "toxapex")
	var ok := "toxapex" in error and "HTTP 404" in error and "request result 0" in error
	ok = ok and service.active_request == null and not FileAccess.file_exists(destination + ".partial") and not FileAccess.file_exists(destination)
	fixture.queue_free()
	service.queue_free()
	await process_frame
	if not ok: push_error("Missing model response lost its identity/status or retained unverified files: " + error)
	print("ON_DEMAND_3D_HTTP_ERROR_", "OK" if ok else "FAIL", " missing_model=true http_status=true partial_removed=true")
	quit(0 if ok else 1)
