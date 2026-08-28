extends SceneTree

const ServerHealthService := preload("res://scripts/server_health_service.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_url := OS.get_environment("LAUNCHER_HEALTH_TEST_BASE_URL")
	_check(not base_url.is_empty(), "server health test URL is configured")
	if base_url.is_empty():
		quit(1)
		return

	var recovered := await ServerHealthService.check_async(root, base_url + "/retry")
	_check(bool(recovered.get("online", false)), "server health check recovers from temporary failures")
	_check(int(recovered.get("attempts", 0)) == 3, "server health check records all retry attempts")

	var failed_result := await ServerHealthService.check_async(root, base_url + "/fail")
	_check(not bool(failed_result.get("online", true)), "server health check reports a persistent failure")
	_check(int(failed_result.get("attempts", 0)) == 3, "server health retries remain bounded")

	if not failed:
		print("PASS launcher server_health_retry_check")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failed = true
	push_error("FAIL: %s" % message)
