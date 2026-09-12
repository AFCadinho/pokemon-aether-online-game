extends SceneTree

const Runtime := preload("res://scripts/services/web_runtime.gd")
const Build := preload("res://scripts/services/client_build.gd")
var failures := 0

func _init() -> void:
	var source := PackedStringArray([
		"User-Agent: PokeAether/1.0", "HOST: example.invalid", "Origin: example.invalid",
		"Content-Length: 123", "Connection: keep-alive", "Authorization: Bearer test-only",
		"Content-Type: application/json", "X-PokeAether-Client-Build: test-build",
	])
	var filtered := Runtime.browser_headers(source)
	_check(filtered == PackedStringArray([
		"Authorization: Bearer test-only", "Content-Type: application/json",
		"X-PokeAether-Client-Build: test-build",
	]), "browser headers keep authentication and remove browser-owned headers")
	_check(source.size() == 8, "filter does not modify caller headers")
	_check(Runtime.http_headers(source) == source, "desktop headers unchanged")
	_check(Build.append_http_header(source).has("User-Agent: PokeAether/1.0"), "desktop build headers preserve user agent")
	_check(Runtime.api_base_url() == "", "desktop never uses browser origin")
	var shell := FileAccess.get_file_as_string("res://infrastructure/web/shell.html")
	_check(shell.contains("if (!local && !webRelease)"), "only unconfigured non-local web exports are blocked")
	_check(shell.contains("window.POKEAETHER_WEB_RELEASE || null"), "production release configuration is explicit")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method.web") == "gl_compatibility", "web renderer override")
	print("web_runtime_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
