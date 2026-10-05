extends SceneTree

# Evaluate the platform predicates used by the real co-op wiring. This covers
# the Android regression without pretending a desktop engine is an Android GPU.
class PlatformProbe extends RefCounted:
	var features: Array
	var view := {"positions": []}
	func has_feature(feature: String) -> bool:
		return feature in features

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_platform_wiring()
	for side: String in ["back", "front"]:
		var box = load("res://scenes/battle/sprite_box.tscn").instantiate()
		box.set_script(load("res://tests/fixtures/coop_sprite_download_probe.gd"))
		box.warm_frames = _frames(false)
		box.home_frames = _frames(true)
		box.downloaded_frames = _frames(false)
		root.add_child(box)
		box.set_double_pokemon_species("Pikachu", "Bulbasaur", side, false, true)
		_check(box.double_sprite_1.sprite_frames == box.warm_frames
			and box.double_sprite_2.sprite_frames == box.home_frames,
			"%s starts with one animated sprite and one HOME fallback" % side)
		box.allow_web_sprite_upgrades(true)
		await process_frame
		await process_frame
		_check(box.requests.size() == 1 and box.double_sprite_2.sprite_frames == box.home_frames,
			"%s can display both Pokémon while a download is pending" % side)
		var generation: int = box.web_sprite_request_generation
		box.set_double_pokemon_species("Pikachu", "Bulbasaur", side, false, true)
		_check(box.web_sprite_request_generation == generation,
			"%s repeated snapshots preserve the pending sprite request" % side)
		box.blocked = false
		await process_frame
		await process_frame
		_check(box.requests == [
			{"species": "Pikachu", "side": side, "shiny": false},
			{"species": "Bulbasaur", "side": side, "shiny": true}],
			"%s downloads both positions with their own shiny identity" % side)
		for sprite: AnimatedSprite2D in [box.double_sprite_1, box.double_sprite_2]:
			_check(sprite.visible and sprite.is_playing()
				and sprite.sprite_frames == box.downloaded_frames
				and not bool(sprite.sprite_frames.get_meta("home_fallback", false)),
				"%s replaces the HOME fallback with a playing battle sprite" % side)

		# A switch/teardown must invalidate both old downloads, including the
		# second one that starts after the first asynchronous request completes.
		box.requests.clear()
		box.blocked = true
		box.set_double_pokemon_species("Charmander", "Squirtle", side)
		await process_frame
		await process_frame
		box.clear_pokemon()
		box.blocked = false
		await process_frame
		await process_frame
		_check(not box.double_sprite_1.visible and not box.double_sprite_2.visible
			and box.double_sprite_1.sprite_frames == box.home_frames
			and box.double_sprite_2.sprite_frames == box.home_frames,
			"%s late downloads cannot repopulate cleared Pokémon" % side)

		box.requests.clear()
		box.web_sprite_upgrades_allowed = true
		box.set_double_pokemon_species("", "Bulbasaur", side, false, true)
		await process_frame
		await process_frame
		_check(not box.double_sprite_1.visible and box.double_sprite_2.visible
			and box.double_sprite_2.sprite_frames == box.downloaded_frames
			and box.requests == [{"species": "Bulbasaur", "side": side, "shiny": true}],
			"%s still upgrades the second Pokémon when the first position is empty" % side)
		box.free()
	print("coop_sprite_download_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _frames(home: bool) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	frames.add_frame("idle", texture)
	if home:
		frames.set_meta("home_fallback", true)
	else:
		frames.add_frame("idle", texture)
	return frames

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _check_platform_wiring() -> void:
	var predicates: Array[String] = []
	var assignment := RegEx.new()
	assignment.compile("\\.web_sprite_upgrades_allowed = ([^\\n]+)")
	for path: String in ["res://scripts/battle/battle.gd", "res://scripts/battle/coop_battle_panel.gd"]:
		for match in assignment.search_all(FileAccess.get_file_as_string(path)):
			predicates.append(match.get_string(1))
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var state_handler := world_source.get_slice("func _on_coop_state_changed()", 1).get_slice("\nfunc ", 0)
	for line: String in state_handler.split("\n"):
		if line.contains("CoopService.view.is_empty()"):
			predicates.append(line.strip_edges().trim_prefix("if ").trim_suffix(":"))
	_check(predicates.size() == 4, "both embedded sides, card sprites and roster prefetch have platform policies")
	for features: Array in [["mobile", "android"], ["web"], ["linux"]]:
		var platform := PlatformProbe.new()
		platform.features = features
		for predicate: String in predicates:
			var expression := Expression.new()
			var parsed := expression.parse(predicate.replace("OS.has_feature", "has_feature").replace("CoopService.view", "view"))
			_check(parsed == OK, "co-op platform policy can be evaluated: " + predicate)
			if parsed != OK:
				continue
			var result: Variant = expression.execute([], platform, false)
			_check(not expression.has_execute_failed() and result == ("mobile" in features or "web" in features),
				"co-op downloads are enabled for Android/browser, preserving desktop policy: %s, %s" % [features, predicate])
