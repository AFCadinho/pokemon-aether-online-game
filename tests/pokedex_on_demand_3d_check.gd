extends SceneTree

const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")

class DownloadProbe extends Node:
	signal completed
	var requests: Array = []
	var result := {}
	func ensure_models(identities: Array[String], _source: String) -> Dictionary:
		requests.append(identities.duplicate())
		await completed
		return result
	func progress_text() -> String:
		return "Downloading model… 50%"

class PreviewProbe extends "res://scripts/ui/pokedex_model_preview.gd":
	var cached: Array[String] = []
	var loaded := ""
	func _request_cached_model() -> bool:
		if requested_key not in cached:
			return false
		loaded = requested_key
		return true

var failed := false
var failure_count := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = false
	var old_catalog := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var downloader := root.get_node("OnDemand3DBundleService")
	root.remove_child(downloader)
	var probe := DownloadProbe.new()
	probe.name = "OnDemand3DBundleService"
	root.add_child(probe)
	var preview := PreviewProbe.new()
	root.add_child(preview)
	preview.model_failed.connect(func(): failure_count += 1)
	for shiny in [false, true]:
		var identity := "bulbasaur@shiny" if shiny else "bulbasaur"
		_check(preview.show_species("Bulbasaur", shiny), "uncached approved normal/shiny starts loading")
		_check(preview.is_loading(), "pending download is reported to cards")
		await process_frame
		_check(probe.requests.back() == [identity], "only the selected identity is requested")
		preview._process(0)
		_check("50%" in preview.status.text, "download progress is visible")
		preview.cached.append(identity)
		probe.result = {"error": "", "path": "/offline-probe/catalog.json"}
		probe.completed.emit()
		_check(preview.loaded == identity and not preview.is_loading(), "downloaded identity is loaded")
	var count := probe.requests.size()
	_check(preview.show_species("Bulbasaur", false), "cached preview is available immediately")
	await process_frame
	_check(probe.requests.size() == count, "cached preview does not download again")
	_check(preview.show_species("Hoothoot", false), "next uncached selection begins loading")
	await process_frame
	_check(preview.show_species("Bulbasaur", false), "selection can change during download")
	probe.result = {"error": "Offline"}
	probe.completed.emit()
	_check(preview.loaded == "bulbasaur" and failure_count == 0, "old failure cannot replace a newer selection")
	_check(preview.show_species("Hoothoot", true), "uncached shiny begins loading")
	await process_frame
	probe.completed.emit()
	_check(failure_count == 1 and not preview.is_loading(), "current failure signals sprite fallback")
	_check(preview.show_species("Hoothoot", false), "new request starts after failure")
	await process_frame
	preview._clear_actor()
	probe.completed.emit()
	_check(failure_count == 1, "cleared selection ignores late failures")
	count = probe.requests.size()
	settings._manual_model_catalog_this_session = true
	_check(not preview.show_species("Hoothoot", false), "manual offline catalog does not download")
	settings._manual_model_catalog_this_session = false
	settings.battle_presentation_mode = "2d"
	_check(not preview.show_species("Hoothoot", false), "classic presentation retains sprites")
	settings.battle_presentation_mode = "3d"
	_check(not preview.show_species("not-a-reviewed-pokemon", false), "unsupported models retain sprites")
	await process_frame
	_check(probe.requests.size() == count, "fallback cases do not start network requests")
	preview.free()
	# Exercise real card refresh and Pokédex error handling, not only the preview.
	# Mark the cached digest unavailable in this process so this offline failure
	# fixture is independent of models installed by earlier smoke checks.
	var models: Dictionary = Registry.DATA.data.models
	var original_profile: Dictionary = models.bulbasaur.duplicate(true)
	models.bulbasaur.sha256 = "offline-fixture"
	models.bulbasaur.previous_sha256 = []
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	overlay.root_control = host
	overlay._setup_pokemon_summary_popup()
	overlay.pokemon_summary_popup.show()
	var pokemon := Pokemon.new("Bulbasaur", 5)
	overlay.pokemon_summary_preview_pokemon = pokemon
	overlay._set_pokemon_summary_sprite(pokemon)
	var card_preview = overlay.pokemon_summary_sprite.get_parent().get_node("SummaryModelPreview")
	var generation: int = card_preview.request_generation
	overlay._set_pokemon_summary_sprite(pokemon)
	_check(card_preview.request_generation == generation, "card refresh preserves an in-flight download")
	await process_frame
	probe.completed.emit()
	_check(not card_preview.visible and (overlay.pokemon_summary_sprite.visible or overlay.pokemon_summary_animated_sprite.visible), "summary restores sprites on failure")
	overlay._setup_pokedex_popup()
	overlay.pokedex_selected_species = {"id": "bulbasaur", "name": "Bulbasaur"}
	overlay._set_pokedex_species_sprite(overlay.pokedex_selected_species)
	_check(overlay.pokedex_3d_preview.visible and not overlay.pokedex_animated_sprite.visible, "Pokédex shows loading instead of an interim GIF")
	await process_frame
	probe.completed.emit()
	_check(not overlay.pokedex_3d_preview.visible and (overlay.pokedex_sprite.visible or overlay.pokedex_animated_sprite.visible), "Pokédex restores sprites on failure")
	models.bulbasaur = original_profile
	for property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader: Node = overlay.get(property)
		if is_instance_valid(loader):
			loader.free()
	host.free()
	overlay.free()
	probe.free()
	root.add_child(downloader)
	if old_catalog.is_empty():
		OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	else:
		OS.set_environment("POKEAETHER_MODEL_CATALOG", old_catalog)
	if not failed:
		print("PASS pokedex_on_demand_3d_check normal=true shiny=true cached=true selection_safety=true summary_refresh=true sprite_fallback=true")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("FAIL " + message)
