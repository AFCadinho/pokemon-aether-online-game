extends SceneTree
const Review = preload("res://scripts/ui/local_model_review.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const PokedexPreview = preload("res://scripts/ui/pokedex_model_preview.gd")
const SummaryPreview = preload("res://scripts/ui/summary_model_preview.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := Review.catalog_path()
	assert(FileAccess.file_exists(catalog))
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(catalog))
	assert(entries.size() == 81)
	var names := {}
	var approved := 0
	for entry: Dictionary in entries:
		assert(not names.has(entry.species))
		names[entry.species] = true
		if Registry.supports(entry.species):
			approved += 1
		else:
			assert(not Review.resolve(entry.species).is_empty())
		assert(Review.resolve(entry.species + "@shiny").is_empty())
	assert(approved == 71)
	assert(Review.resolve("slakoth").is_empty())
	assert(Review.resolve("arceus").is_empty())
	var settings := root.get_node("SettingsManager")
	var previous: String = settings.battle_presentation_mode
	settings.battle_presentation_mode = "3d"
	var dex := PokedexPreview.new()
	dex.size = Vector2(380, 276)
	root.add_child(dex)
	var summary := SummaryPreview.new()
	summary.size = Vector2(380, 276)
	root.add_child(summary)
	var button := MenuButton.new()
	root.add_child(button)
	summary.bind_animation_button(button)
	for name in ["numel", "kyogre", "dialga"]:
		assert(dex.show_species(name, false))
		assert(summary.show_species(name, false))
		var deadline := Time.get_ticks_msec() + 20000
		while dex.player == null or summary.configured_player == null:
			assert(Time.get_ticks_msec() < deadline)
			await process_frame
		assert(dex.profile.review_candidate and summary.profile.review_candidate)
		assert(dex.status.text == "Review candidate" and summary.status.text == "Review candidate")
		assert(button.get_popup().item_count == 8)
		for i in button.get_popup().item_count:
			summary.play_clip(str(button.get_popup().get_item_metadata(i)))
			assert(summary.player.is_playing())
		print("BATCH02_HELD_PREVIEW_OK ", name)
	settings.battle_presentation_mode = previous
	dex.queue_free()
	summary.queue_free()
	button.queue_free()
	print("BATCH02_REVIEW_CHECK_OK 71 approved / 10 local previews / 3 UI previews / 8 native clips")
	quit()
