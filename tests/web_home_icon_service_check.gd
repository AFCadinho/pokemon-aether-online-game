extends SceneTree

const Service := preload("res://scripts/services/web_home_icon_service.gd")

class FixtureService extends Service:
	var requests: Dictionary = {}
	func _asset_url(relative: String) -> String:
		return relative
	func _download(url: String) -> PackedByteArray:
		requests[url] = int(requests.get(url, 0)) + 1
		await get_tree().process_frame
		if url.ends_with("catalog.json"):
			return JSON.stringify({"normal": {"Pikachu": "home-icons/normal.png", "Vulpix-Alola": "home-icons/normal.png"}, "shiny": {"pikachu": "home-icons/shiny.png"}}).to_utf8_buffer()
		var image := Image.create(20, 20, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		image.fill_rect(Rect2i(8, 8, 4, 4), Color.BLUE if "shiny" in url else Color.RED)
		return image.save_png_to_buffer()

var failures := 0
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var service := FixtureService.new()
	root.add_child(service)
	var full := service.get_icon("Pikachu")
	var party := service.get_icon("Pikachu", false, true)
	_check(full == service.get_icon("pikachu"), "duplicate consumers share mutable texture")
	var shiny := service.get_icon("Pikachu", true)
	var alias := service.get_icon("vulpix-alola")
	for i in range(20):
		await process_frame
	_check(full.get_width() == 20 and (service._files["home-icons/normal.png"] as Image).get_pixel(9, 9).is_equal_approx(Color.RED), "visible full placeholder updates in place")
	_check(party.get_width() == 12, "party icon crops downloaded pixels with padding")
	_check((service._files["home-icons/shiny.png"] as Image).get_pixel(9, 9).is_equal_approx(Color.BLUE), "shiny identity stays separate")
	_check(alias.get_width() == 20, "form alias resolves")
	_check(service.requests.get("home-icons/catalog.json") == 1, "catalog fetch is coalesced")
	_check(service.requests.get("home-icons/normal.png") == 1, "same file across aliases downloads once")
	_check(await service._load_image("home-icons/../secret.png") == null, "unsafe catalog path refused")
	service.queue_free()
	await process_frame
	print("web_home_icon_service_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
