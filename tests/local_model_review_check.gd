extends SceneTree
const Review = preload("res://scripts/ui/local_model_review.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const PokedexPreview = preload("res://scripts/ui/pokedex_model_preview.gd")
const SummaryPreview = preload("res://scripts/ui/summary_model_preview.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := Review.catalog_path()
	print("LOCAL_REVIEW_CATALOG ", path)
	assert(FileAccess.file_exists(path))
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(entries.size() == 18)
	var settings := root.get_node("SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	settings.battle_presentation_mode = "3d" # In-memory test setting, never saved.
	var dex := PokedexPreview.new()
	dex.size = Vector2(380, 276)
	root.add_child(dex)
	var summary := SummaryPreview.new()
	summary.size = Vector2(380, 276)
	root.add_child(summary)
	var button := MenuButton.new()
	root.add_child(button)
	summary.bind_animation_button(button)
	for entry: Dictionary in entries:
		assert(not Registry.supports(entry.species), "Preview admission must not grant battle approval")
		assert(not Review.resolve(entry.species).is_empty())
		assert(Review.resolve(entry.species + "@shiny").is_empty())
		assert(dex.show_species(entry.species, false))
		assert(summary.show_species(entry.species, false))
		var deadline := Time.get_ticks_msec() + 20000
		while dex.player == null or summary.configured_player == null:
			assert(Time.get_ticks_msec() < deadline)
			await process_frame
		assert(dex.profile.review_candidate and summary.profile.review_candidate)
		assert(dex.status.text == "Review candidate" and summary.status.text == "Review candidate")
		assert(dex.tooltip_text.contains("not approved") and summary.tooltip_text.contains("not approved"))
		assert(not dex.preview_floor.visible and not summary.preview_floor.visible)
		assert(dex.player != summary.player)
		assert(button.get_popup().item_count == 7)
		for i in button.get_popup().item_count:
			summary.play_clip(str(button.get_popup().get_item_metadata(i)))
			assert(summary.player.is_playing())
		print("LOCAL_REVIEW_PREVIEW_OK ", entry.species)
	assert(not dex.show_species("charmeleon", true))
	assert(Review.resolve("venomoth").is_empty())
	assert(Review.resolve("unknown").is_empty())
	settings.battle_presentation_mode = "2.5d"
	assert(not dex.show_species("charmeleon", false))
	settings.battle_presentation_mode = old_mode
	var negative := ProjectSettings.globalize_path("user://local-model-review-negative.json")
	OS.set_environment("POKEAETHER_PREVIEW_REVIEW_CATALOG", negative)
	var first: Dictionary = entries[0].duplicate(true)
	_write(negative, [first, first])
	assert(Review.resolve(first.species).is_empty(), "Duplicate identities rejected")
	first.runtime_sha256 = "0".repeat(64)
	_write(negative, [first])
	assert(Review.resolve(first.species).is_empty(), "Unknown digest rejected")
	first = entries[0].duplicate(true)
	first.runtime_path = entries[1].runtime_path
	_write(negative, [first])
	assert(Review.resolve(first.species).is_empty(), "Wrong scene bytes rejected")
	OS.set_environment("POKEAETHER_PREVIEW_REVIEW_CATALOG", path)
	dex.queue_free()
	summary.queue_free()
	button.queue_free()
	for frame in 4:
		await process_frame
	print("LOCAL_REVIEW_CHECK_OK 18 models / two previews / seven clips / strict admission / fallbacks")
	quit()

func _write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
