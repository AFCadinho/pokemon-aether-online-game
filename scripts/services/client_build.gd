extends RefCounted

class_name ClientBuild

const BUILD_ID_SETTING := "application/config/build_id"
const RELEASE_VERSION_SETTING := "application/config/version"
const BUILD_ID_ENV := "POKEAETHER_CLIENT_BUILD_ID"
const HEADER_NAME := "X-PokeAether-Client-Build"
const PLATFORM_HEADER_NAME := "X-PokeAether-Client-Platform"
const QUERY_NAME := "clientBuild"
const PLATFORM_QUERY_NAME := "clientPlatform"
const WebRuntime := preload("res://scripts/services/web_runtime.gd")
static var _android_test_build_id := ""


static func get_build_id() -> String:
	if OS.get_name() == "Android" and _android_test_build_id != "":
		return _android_test_build_id
	if OS.has_feature("web"):
		# A preview page may use the currently allowed production build ID while
		# serving a candidate runtime from its own immutable asset path. This lets
		# testers log in without opening the candidate manifest to all players.
		var release_config := WebRuntime.web_release_config()
		var compatible_build_id := str(release_config.get("clientBuildId", "")).strip_edges()
		if not compatible_build_id.is_empty():
			return compatible_build_id
		return str(ProjectSettings.get_setting("application/config/web_build_id", "web-preview-2"))
	var environment_build_id := OS.get_environment(BUILD_ID_ENV).strip_edges()
	if not environment_build_id.is_empty():
		return environment_build_id

	var configured_build_id := str(ProjectSettings.get_setting(BUILD_ID_SETTING, "")).strip_edges()
	if not configured_build_id.is_empty():
		return configured_build_id

	return str(ProjectSettings.get_setting(RELEASE_VERSION_SETTING, "dev")).strip_edges()


static func android_candidate_target(body: Dictionary, compatible: String, actual: String) -> String:
	if compatible == "" or actual == "":
		return ""
	var detail: Variant = body.get("detail", {})
	if not detail is Dictionary or str(detail.get("code", "")) != "client_update_required":
		return ""
	var required := str(detail.get("requiredBuild", ""))
	return required if required == compatible or required == actual else ""


static func accept_android_candidate_requirement(body: Dictionary) -> bool:
	if OS.get_name() != "Android":
		return false
	var actual := str(ProjectSettings.get_setting(BUILD_ID_SETTING, ""))
	var compatible := str(ProjectSettings.get_setting("application/config/android_test_compatible_build_id", ""))
	var target := android_candidate_target(body, compatible, actual)
	if target == "" or target == get_build_id():
		return false
	_android_test_build_id = "" if target == actual else target
	return true


static func get_http_header() -> String:
	return "%s: %s" % [HEADER_NAME, get_build_id()]


static func get_platform_id() -> String:
	if OS.has_feature("web"):
		return "web"
	match OS.get_name():
		"Windows":
			return "windows"
		"Linux":
			return "linux"
		"macOS":
			return "macos"
		"Android":
			return "android"
		_:
			return OS.get_name().strip_edges().to_lower()


static func append_http_header(headers: PackedStringArray) -> PackedStringArray:
	var result := WebRuntime.http_headers(headers).duplicate()
	result.append(get_http_header())
	result.append("%s: %s" % [PLATFORM_HEADER_NAME, get_platform_id()])
	return result


static func append_websocket_query(url: String) -> String:
	var separator := "&" if url.contains("?") else "?"
	return "%s%s%s=%s&%s=%s" % [
		url,
		separator,
		QUERY_NAME,
		get_build_id().uri_encode(),
		PLATFORM_QUERY_NAME,
		get_platform_id().uri_encode(),
	]
