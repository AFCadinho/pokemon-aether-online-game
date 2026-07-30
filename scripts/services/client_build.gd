extends RefCounted

class_name ClientBuild

const BUILD_ID_SETTING := "application/config/build_id"
const RELEASE_VERSION_SETTING := "application/config/version"
const BUILD_ID_ENV := "POKEAETHER_CLIENT_BUILD_ID"
const HEADER_NAME := "X-PokeAether-Client-Build"
const PLATFORM_HEADER_NAME := "X-PokeAether-Client-Platform"
const QUERY_NAME := "clientBuild"
const PLATFORM_QUERY_NAME := "clientPlatform"


static func get_build_id() -> String:
	var environment_build_id := OS.get_environment(BUILD_ID_ENV).strip_edges()
	if not environment_build_id.is_empty():
		return environment_build_id

	var configured_build_id := str(ProjectSettings.get_setting(BUILD_ID_SETTING, "")).strip_edges()
	if not configured_build_id.is_empty():
		return configured_build_id

	return str(ProjectSettings.get_setting(RELEASE_VERSION_SETTING, "dev")).strip_edges()


static func get_http_header() -> String:
	return "%s: %s" % [HEADER_NAME, get_build_id()]


static func get_platform_id() -> String:
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
	var result := headers.duplicate()
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
