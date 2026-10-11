extends SceneTree

const Assets := preload("res://scripts/data/pokemon_assets.gd")
const TARGETS := {
	"tandemaus": ["maushold", "maushold-four"],
	"dunsparce": ["dudunsparce", "dudunsparce-three-segment"],
	"spewpa": ["vivillon", "vivillon-archipelago", "vivillon-continental", "vivillon-elegant", "vivillon-fancy", "vivillon-garden", "vivillon-high-plains", "vivillon-icy-snow", "vivillon-jungle", "vivillon-marine", "vivillon-modern", "vivillon-monsoon", "vivillon-ocean", "vivillon-pokeball", "vivillon-polar", "vivillon-river", "vivillon-sandstorm", "vivillon-savanna", "vivillon-sun", "vivillon-tundra"],
	"milcery": ["alcremie", "alcremie-caramel-swirl", "alcremie-lemon-cream", "alcremie-matcha-cream", "alcremie-mint-cream", "alcremie-rainbow-swirl", "alcremie-ruby-cream", "alcremie-ruby-swirl", "alcremie-salted-cream"],
}
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(20).timeout.connect(func() -> void: quit(1))
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	var auth := root.get_node("AuthService")
	auth.current_user = {"id": 1}
	auth.session_token = "form-choice-fixture"
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	var localization := root.get_node("LocalizationManager")
	var settings := root.get_node("SettingsManager")
	var old_locale: String = localization.current_locale
	var old_language: String = settings.content_name_language
	settings.content_name_language = "localized"
	localization.set_locale("en")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 740)
	root.add_child(viewport)
	var overlay = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	# These loaders are normally parented by _ready; release the original
	# script instances before installing the fixture script.
	overlay.pokemon_summary_sprite_loader.free()
	overlay.pokedex_sprite_loader.free()
	overlay.set_script(load("res://tests/support/evolution_form_choice_probe.gd"))
	viewport.add_child(overlay)
	overlay._setup_evolution_prompt_popup()
	for source: String in TARGETS:
		for target: String in TARGETS[source]:
			for shiny: bool in [false, true]:
				var texture := Assets.load_home_sprite(target, shiny)
				_check(texture != null and not texture.resource_path.contains("home_unknown"), "%s preview loads (shiny=%s)" % [target, shiny])
		if source == "milcery":
			continue
		overlay.fixture_pokemon = Pokemon.new(source.capitalize(), 32)
		overlay.fixture_pokemon.owned_pokemon_id = 77
		overlay.evolution_active_prompt.clear()
		overlay.evolution_prompt_queue.clear()
		overlay.evolution_prompt_popup.hide()
		var queued := 0
		for target: String in TARGETS[source]:
			if overlay._queue_evolution_prompt(_choice(source, target)):
				queued += 1
		_check(queued == 1 and overlay.evolution_prompt_queue.size() == 1, source + " forms share one prompt")
		overlay._queue_evolution_prompt(_choice(source, TARGETS[source][-1]))
		_check(overlay.evolution_prompt_queue[0].formChoices.size() == TARGETS[source].size(), source + " repeated rewards add no duplicate forms")
		overlay._show_next_evolution_prompt()
		await process_frame
		_check(overlay.evolution_prompt_popup.size.x <= viewport.size.x and overlay.evolution_prompt_popup.size.y <= viewport.size.y, source + " choice popup fits a mobile viewport")
		_check(overlay.evolution_prompt_form_row.visible and overlay.evolution_prompt_form_selector.item_count == TARGETS[source].size(), source + " shows every selectable form")
		for index: int in range(TARGETS[source].size()):
			overlay.evolution_prompt_form_selector.item_selected.emit(index)
			_check(overlay.evolution_active_prompt.toSpeciesId == TARGETS[source][index], source + " selection updates target " + TARGETS[source][index])
			_check(overlay.evolution_prompt_form_selector.selected == index, source + " selector keeps the chosen form")
		await overlay._submit_evolution_choice(true)
		_check(overlay.submitted.targetSpeciesId == TARGETS[source][-1] and overlay.submitted.confirm, source + " confirmation sends the selected target")
		_check(not overlay.evolution_prompt_form_selector.disabled, source + " failed save re-enables choice")
		_check(overlay.evolution_active_prompt.toSpeciesId == TARGETS[source][-1], source + " failed save preserves selection")
		overlay.evolution_prompt_processing = true
		overlay._on_evolution_form_selected(0)
		_check(overlay.evolution_active_prompt.toSpeciesId == TARGETS[source][-1], source + " selection is locked during confirmation")
		overlay.evolution_prompt_processing = false
	# The Bag retains server choices through normalization and sends the chosen
	# flavor via the real inventory transport.
	var choices: Array = []
	for target: String in TARGETS.milcery:
		choices.append(_choice("milcery", target))
	var normalized: Array = overlay._normalize_bag_inventory_items([{"itemId": "strawberry-sweet", "quantity": 2, "evolutionChoices": {"77": choices}}])
	var item: Dictionary = normalized[0]
	_check(item.evolutionChoices["77"].size() == 9, "Bag normalization preserves nine flavors")
	overlay.bag_item_use_pending_item = item
	overlay.bag_item_use_form_selector = OptionButton.new()
	overlay.bag_item_use_form_row = overlay._create_evolution_form_row(overlay.bag_item_use_form_selector)
	overlay.root_control.add_child(overlay.bag_item_use_form_row)
	var milcery := Pokemon.new("Milcery", 20)
	milcery.owned_pokemon_id = 77
	overlay._refresh_bag_evolution_form_choices(milcery)
	_check(overlay.bag_item_use_form_selector.item_count == 9 and overlay.bag_item_use_form_row.visible, "Bag displays all nine flavors")
	overlay.bag_item_use_form_selector.select(5)
	var selected: String = overlay._selected_bag_evolution_target()
	_check(selected == "alcremie-rainbow-swirl", "Bag keeps the chosen flavor")
	var transport = load("res://tests/support/inventory_use_response_transport.gd").new()
	root.add_child(transport)
	await transport.use_pokemon_item(77, "strawberry-sweet", 1, selected)
	var payload: Dictionary = JSON.parse_string(transport.requests[0].body)
	_check(payload.targetSpeciesId == selected and payload.quantity == 1, "item request sends the chosen flavor and one sweet")
	_check(not transport._pokemon_item_use_request_payload("potion", 1).has("targetSpeciesId"), "ordinary item requests keep their existing shape")
	milcery.owned_pokemon_id = 99
	overlay._refresh_bag_evolution_form_choices(milcery)
	_check(not overlay.bag_item_use_form_row.visible and overlay._selected_bag_evolution_target().is_empty(), "changing Pokemon clears stale flavor selection")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		_check(localization.text("ui.evolution.choose_form") != "ui.evolution.choose_form", locale + " translates form selector")
		var flavor_name: String = overlay._evolution_form_display_name(_choice("milcery", "alcremie"))
		_check(not flavor_name.contains("ui.evolution.form.") and (flavor_name.contains("(") or flavor_name.contains("（")), locale + " identifies default flavor")
	localization.set_locale(old_locale)
	settings.content_name_language = old_language
	milcery = null
	overlay.fixture_pokemon = null
	transport.queue_free()
	viewport.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)

func _choice(source: String, target: String) -> Dictionary:
	return {"pokemonId": 77, "fromSpecies": source.capitalize(), "toSpeciesId": target, "toSpecies": target.capitalize(), "choose_form": true, "level": 25}

func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
