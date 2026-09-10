extends RefCounted

## Shared boundary for the first, local-only browser preview.
## This is NOT a server authorization policy. Gameplay stays disconnected until
## web sessions, world limits and ranked restrictions have server-side tests.
class_name WebRuntime


static func api_base_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var origin := str(JavaScriptBridge.eval("window.location.origin", true))
	return origin + "/api"


static func http_headers(headers: PackedStringArray) -> PackedStringArray:
	if not OS.has_feature("web"):
		return headers
	return browser_headers(headers)


static func browser_headers(headers: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for header: String in headers:
		# The browser owns these headers. Preserve Authorization and build headers.
		var name := header.get_slice(":", 0).strip_edges().to_lower()
		if name not in ["user-agent", "host", "origin", "content-length", "connection"]:
			result.append(header)
	return result
