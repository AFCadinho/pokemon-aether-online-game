extends RefCounted

## Browser transport and storage; authorization is enforced by the backend.
class_name WebRuntime

const SESSION_KEY := "pokeaether.web.session.v1"


static func save_session(value: Dictionary, remember: bool) -> void:
	var storage := "localStorage" if remember else "sessionStorage"
	var encoded := JSON.stringify(JSON.stringify(value))
	JavaScriptBridge.eval("(() => { try { localStorage.removeItem('%s'); sessionStorage.removeItem('%s'); %s.setItem('%s', %s); } catch (_) {} })()" % [SESSION_KEY, SESSION_KEY, storage, SESSION_KEY, encoded], true)


static func load_session() -> Dictionary:
	var raw: Variant = JavaScriptBridge.eval("(() => { try { return sessionStorage.getItem('%s') || localStorage.getItem('%s') || ''; } catch (_) { return ''; } })()" % [SESSION_KEY, SESSION_KEY], true)
	var parsed: Variant = JSON.parse_string(str(raw)) if raw != null and str(raw) != "" else {}
	return parsed if parsed is Dictionary else {}


static func clear_session() -> void:
	JavaScriptBridge.eval("(() => { try { localStorage.removeItem('%s'); sessionStorage.removeItem('%s'); } catch (_) {} })()" % [SESSION_KEY, SESSION_KEY], true)


static func api_base_url() -> String:
	if not OS.has_feature("web"):
		return ""
	var origin := str(JavaScriptBridge.eval("window.location.origin", true))
	return origin + "/api"


static func web_release_config() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var value: Variant = JavaScriptBridge.eval("window.POKEAETHER_WEB_RELEASE || null", true)
	if value == null:
		return {}
	var json_value: Variant = JavaScriptBridge.eval("JSON.stringify(window.POKEAETHER_WEB_RELEASE)", true)
	var parsed: Variant = JSON.parse_string(str(json_value))
	return parsed if parsed is Dictionary else {}


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
